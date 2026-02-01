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
    
    /// 开始时间
    var startedAt: Date
    
    /// 暂停时间
    var pausedAt: Date?
    
    // MARK: - Initializer
    
    /// 创建初始计时状态
    /// - Parameters:
    ///   - session: 要运行的 Session
    init(session: Session) {
        self.sessionId = session.id
        self.currentBlockIndex = 0
        self.currentSet = 1
        self.currentPhase = .work
        
        // 获取第一个 Block 的 workDuration
        let firstBlock = session.sortedBlocks.first
        self.remainingSeconds = firstBlock?.workDuration ?? 0
        
        self.isPaused = false
        self.startedAt = Date()
        self.pausedAt = nil
    }
    
    // MARK: - Computed Properties
    
    /// 是否正在运行（未暂停）
    var isRunning: Bool {
        !isPaused
    }
    
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
        
        // 当前阶段已用时间
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
        state.pausedAt = Date()
        return state
    }
    
    /// 继续计时器
    /// - Returns: 更新后的状态
    func resumed() -> TimerState {
        var state = self
        state.isPaused = false
        state.pausedAt = nil
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
        case .work:
            // Work → Rest
            state.currentPhase = .rest
            state.remainingSeconds = currentBlock.restDuration
            
        case .rest:
            // Rest → 下一组 Work 或下一个 Block
            if currentSet < currentBlock.setCount {
                // 还有更多组
                state.currentSet += 1
                state.currentPhase = .work
                state.remainingSeconds = currentBlock.workDuration
            } else {
                // 当前 Block 完成，进入下一个 Block
                let nextBlockIndex = currentBlockIndex + 1
                if nextBlockIndex < sortedBlocks.count {
                    // 还有更多 Block
                    state.currentBlockIndex = nextBlockIndex
                    state.currentSet = 1
                    state.currentPhase = .work
                    state.remainingSeconds = sortedBlocks[nextBlockIndex].workDuration
                } else {
                    // Session 完成
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
