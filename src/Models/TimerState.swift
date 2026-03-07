// T015: TimerState runtime struct
// Session Timer - 计时器运行时状态

import Foundation

/// 计时器的运行时状态
/// **不持久化** - 仅在内存中
struct TimerState: Sendable {
    // MARK: - Properties
    
    /// 当前运行的 Session ID
    let sessionId: UUID
    
    /// 当前 Block 索引 (0-based)
    var currentBlockIndex: Int
    
    /// 当前组号 (1-based)
    var currentSet: Int
    
    /// 当前阶段
    var currentPhase: TimerPhase
    
    /// 剩余秒数
    var remainingSeconds: Int
    
    /// 是否暂停
    var isPaused: Bool
    
    // MARK: - Initializer
    
    /// 创建初始计时状态
    /// - Parameters:
    ///   - session: 要运行的 Session
    init(session: Session) {
        self.sessionId = session.id
        self.currentBlockIndex = 0
        self.currentSet = 1
        
        if session.preparingDuration > 0 {
            self.currentPhase = .preparing
            self.remainingSeconds = session.preparingDuration
        } else {
            self.currentPhase = .work
            self.remainingSeconds = session.sortedBlocks.first?.workDuration ?? 0
        }
        
        self.isPaused = false
    }
    
    // MARK: - Computed Properties
    
    /// 计算总进度百分比 (0.0 - 1.0)
    /// - Parameter session: 当前 Session
    /// - Returns: 进度百分比
    func progress(in session: Session) -> Double {
        let totalSeconds = session.totalDuration
        guard totalSeconds > 0 else { return 0.0 }
        
        let elapsedSeconds = calculateElapsedSeconds(in: session)
        return min(1.0, Double(elapsedSeconds) / Double(totalSeconds))
    }
    
    /// 格式化的剩余时间 "MM:SS"
    var formattedRemainingTime: String {
        remainingSeconds.formatted_MMSS
    }
    
    // MARK: - Private Methods
    
    /// 计算已用时间（秒）
    /// - Parameter session: 当前 Session
    /// - Returns: 已用秒数
    private func calculateElapsedSeconds(in session: Session) -> Int {
        let sortedBlocks = session.sortedBlocks
        var elapsed = 0
        
        // 已完成的 Block
        for i in 0..<currentBlockIndex {
            guard i < sortedBlocks.count else { break }
            elapsed += sortedBlocks[i].totalDuration
        }
        
        // 当前 Block 已完成的组
        guard currentBlockIndex < sortedBlocks.count else { return elapsed }
        let currentBlock = sortedBlocks[currentBlockIndex]
        elapsed += (currentSet - 1) * currentBlock.setDuration
        
        // preparing 阶段不计入总进度
        guard currentPhase != .preparing else { return 0 }
        
        let phaseDuration = currentPhase == .work
            ? currentBlock.workDuration
            : currentBlock.restDuration
        elapsed += phaseDuration - remainingSeconds
        
        return elapsed
    }
}

// MARK: - State Mutations

extension TimerState {
    /// 暂停计时器
    /// - Returns: 更新后的状态
    func paused() -> TimerState {
        var state = self
        state.isPaused = true
        return state
    }
    
    /// 继续计时器
    /// - Returns: 更新后的状态
    func resumed() -> TimerState {
        var state = self
        state.isPaused = false
        return state
    }
    
    /// 减少剩余时间
    /// - Returns: 更新后的状态
    func tick() -> TimerState {
        var state = self
        if state.remainingSeconds > 0 {
            state.remainingSeconds -= 1
        }
        return state
    }
    
    /// 切换到下一个阶段
    /// - Parameter session: 当前 Session
    /// - Returns: 更新后的状态，如果 Session 完成则返回 nil
    func nextPhase(in session: Session) -> TimerState? {
        let sortedBlocks = session.sortedBlocks
        guard currentBlockIndex < sortedBlocks.count else { return nil }
        
        let currentBlock = sortedBlocks[currentBlockIndex]
        var state = self
        
        switch currentPhase {
        case .preparing:
            state.currentPhase = .work
            state.currentBlockIndex = 0
            state.currentSet = 1
            state.remainingSeconds = sortedBlocks.first?.workDuration ?? 0
            
        case .work:
            state.currentPhase = .rest
            state.remainingSeconds = currentBlock.restDuration
            
        case .rest:
            if currentSet < currentBlock.setCount {
                state.currentSet += 1
                state.currentPhase = .work
                state.remainingSeconds = currentBlock.workDuration
            } else {
                let nextBlockIndex = currentBlockIndex + 1
                if nextBlockIndex < sortedBlocks.count {
                    state.currentBlockIndex = nextBlockIndex
                    state.currentSet = 1
                    state.currentPhase = .work
                    state.remainingSeconds = sortedBlocks[nextBlockIndex].workDuration
                } else {
                    return nil
                }
            }
        }
        
        return state
    }
    
    /// 跳过当前阶段
    /// - Parameter session: 当前 Session
    /// - Returns: 更新后的状态，如果 Session 完成则返回 nil
    func skip(in session: Session) -> TimerState? {
        var state = self
        state.remainingSeconds = 0
        return state.nextPhase(in: session)
    }
    
    /// 为当前 Block 加一组
    /// - Parameter session: 当前 Session
    /// - Returns: 是否成功（如果当前 Block 组数已达上限则失败）
    mutating func addSet(in session: Session) -> Bool {
        let sortedBlocks = session.sortedBlocks
        guard currentBlockIndex < sortedBlocks.count else { return false }
        
        let currentBlock = sortedBlocks[currentBlockIndex]
        guard currentBlock.setCount < 99 else { return false }
        
        currentBlock.setCount += 1
        return true
    }
    
    /// 延长当前休息时间
    /// - Parameter seconds: 延长的秒数
    mutating func extendRest(by seconds: Int) {
        guard currentPhase == .rest else { return }
        remainingSeconds += seconds
    }
}

// MARK: - Background Recovery

extension TimerState {
    /// 快进结果
    struct AdvanceResult: Sendable {
        /// 最终状态（nil 表示 Session 已完成）
        let finalState: TimerState?
        /// 期间发生的阶段切换列表 (phase, blockIndex, set)
        let phaseTransitions: [(TimerPhase, Int, Int)]
        /// Session 是否已完成
        var isCompleted: Bool { finalState == nil }
    }

    /// 快进指定秒数，正确处理所有阶段切换
    /// - Parameters:
    ///   - seconds: 要快进的秒数
    ///   - session: 当前 Session
    /// - Returns: 快进结果，包含最终状态和期间的阶段切换
    func advancing(by seconds: Int, in session: Session) -> AdvanceResult {
        guard seconds > 0, !isPaused else {
            return AdvanceResult(finalState: self, phaseTransitions: [])
        }

        var remaining = seconds
        var state = self
        var transitions: [(TimerPhase, Int, Int)] = []

        while remaining > 0 {
            if remaining < state.remainingSeconds {
                // 当前阶段还没结束
                state.remainingSeconds -= remaining
                remaining = 0
            } else {
                // 当前阶段结束，消耗剩余秒数后切换
                remaining -= state.remainingSeconds
                state.remainingSeconds = 0

                if let nextState = state.nextPhase(in: session) {
                    state = nextState
                    transitions.append((state.currentPhase, state.currentBlockIndex, state.currentSet))
                } else {
                    // Session 完成
                    return AdvanceResult(finalState: nil, phaseTransitions: transitions)
                }
            }
        }

        return AdvanceResult(finalState: state, phaseTransitions: transitions)
    }
}

// MARK: - Debug Description

extension TimerState: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        TimerState(
            sessionId: \(sessionId),
            block: \(currentBlockIndex),
            set: \(currentSet),
            phase: \(currentPhase),
            remaining: \(remainingSeconds)s,
            isPaused: \(isPaused)
        )
        """
    }
}
