// T023: TimerService - Timer control and state management
// Session Timer - 计时器服务

import Foundation
import Combine

/// 计时器服务
@MainActor
final class TimerService: ObservableObject {
    // MARK: - Published Properties
    
    /// 当前计时状态
    @Published private(set) var currentState: TimerState?
    
    /// 当前运行的 Session
    @Published private(set) var currentSession: Session?
    
    /// 是否已完成
    @Published private(set) var isCompleted: Bool = false
    
    // MARK: - Callbacks
    
    /// 状态变化回调
    var onStateChanged: ((TimerState) -> Void)?
    
    /// 阶段切换回调 (phase, blockIndex, set)
    var onPhaseChanged: ((TimerPhase, Int, Int) -> Void)?
    
    /// Session 完成回调
    var onSessionCompleted: ((Session) -> Void)?
    
    /// 事件回调
    var onEvent: ((TimerEvent) -> Void)?
    
    // MARK: - Private Properties
    
    /// 计时引擎
    private let engine: TimerEngine
    
    /// 倒计时警告阈值（秒）
    private let countdownWarningThreshold = 3

    /// 进入后台时的时间戳（用于后台恢复时计算经过的时间）
    private var backgroundEntryDate: Date?
    
    // MARK: - Initializer
    
    init(engine: TimerEngine = TimerEngine()) {
        self.engine = engine
        setupEngine()
    }
    
    // MARK: - Setup
    
    private func setupEngine() {
        engine.setTickHandler { [weak self] in
            self?.handleTick()
        }
    }
    
    // MARK: - Timer Control
    
    /// 启动 Session 计时
    /// - Parameter session: 要启动的 Session
    func start(session: Session) {
        // 停止现有计时
        stop()
        
        // 创建初始状态
        let state = TimerState(session: session)
        
        // 保存状态
        currentSession = session
        currentState = state
        isCompleted = false
        
        // 启动引擎
        engine.start()
        
        // 发送事件
        onEvent?(.started(sessionId: session.id))
        onStateChanged?(state)
        
        // 发送初始阶段变化
        onPhaseChanged?(state.currentPhase, state.currentBlockIndex, state.currentSet)
        onEvent?(.phaseChanged(phase: state.currentPhase, blockIndex: state.currentBlockIndex, set: state.currentSet))
    }
    
    /// 暂停计时
    func pause() {
        #if DEBUG
        print("[TimerService] pause() called, currentState.isPaused=\(currentState?.isPaused ?? true)")
        #endif
        guard var state = currentState else {
            #if DEBUG
            print("[TimerService] pause() - no currentState, returning")
            #endif
            return
        }
        
        // 移除 isPaused 检查，总是执行暂停
        state = state.paused()
        currentState = state
        engine.pause()
        
        onEvent?(.paused)
        onStateChanged?(state)
        #if DEBUG
        print("[TimerService] pause() done, state.isPaused=\(state.isPaused)")
        #endif
    }
    
    /// 继续计时
    func resume() {
        #if DEBUG
        print("[TimerService] resume() called, currentState.isPaused=\(currentState?.isPaused ?? false)")
        #endif
        guard var state = currentState else {
            #if DEBUG
            print("[TimerService] resume() - no currentState, returning")
            #endif
            return
        }
        
        // 移除 isPaused 检查，总是执行恢复
        state = state.resumed()
        currentState = state
        engine.resume()
        
        onEvent?(.resumed)
        onStateChanged?(state)
        #if DEBUG
        print("[TimerService] resume() done, state.isPaused=\(state.isPaused)")
        #endif
    }
    
    /// 停止并重置计时器
    func stop() {
        engine.stop()

        if currentState != nil {
            onEvent?(.stopped)
        }

        currentState = nil
        currentSession = nil
        isCompleted = false
        backgroundEntryDate = nil
    }
    
    /// 跳过当前阶段
    func skip() {
        guard let session = currentSession,
              let state = currentState else { return }
        
        if let nextState = state.skip(in: session) {
            handlePhaseTransition(from: state, to: nextState, session: session)
        } else {
            // Session 完成
            handleSessionComplete(session: session)
        }
    }
    
    // MARK: - Runtime Adjustments
    
    /// 为当前 Block 加一组
    func addSet() {
        guard let session = currentSession,
              var state = currentState else { return }
        
        if state.addSet(in: session) {
            currentState = state
            onStateChanged?(state)
        }
    }
    
    /// 跳过当前休息时间
    func skipRest() {
        guard let state = currentState,
              state.currentPhase == .rest else { return }
        
        skip()
    }
    
    /// 延长当前休息时间
    /// - Parameter seconds: 延长的秒数
    func extendRest(by seconds: Int) {
        guard var state = currentState,
              state.currentPhase == .rest else { return }
        
        state.extendRest(by: seconds)
        currentState = state
        onStateChanged?(state)
    }
    
    // MARK: - Private Methods
    
    /// 处理计时器 tick
    private func handleTick() {
        guard let session = currentSession,
              var state = currentState,
              !state.isPaused else { return }
        
        // 减少剩余时间
        state = state.tick()
        
        // 检查是否需要发送倒计时警告
        if state.remainingSeconds <= countdownWarningThreshold && state.remainingSeconds > 0 {
            onEvent?(.countdownWarning(remainingSeconds: state.remainingSeconds))
        }
        
        // 发送 tick 事件
        onEvent?(.tick(remainingSeconds: state.remainingSeconds))
        
        // 检查阶段是否结束
        if state.remainingSeconds <= 0 {
            // 尝试切换到下一阶段
            if let nextState = state.nextPhase(in: session) {
                handlePhaseTransition(from: state, to: nextState, session: session)
            } else {
                // Session 完成
                currentState = state
                handleSessionComplete(session: session)
            }
        } else {
            currentState = state
            onStateChanged?(state)
        }
    }
    
    /// 处理阶段切换
    private func handlePhaseTransition(from oldState: TimerState, to newState: TimerState, session: Session) {
        // 检查是否完成了一组
        if oldState.currentPhase == .rest && newState.currentPhase == .work {
            if newState.currentBlockIndex != oldState.currentBlockIndex {
                // Block 完成
                onEvent?(.blockCompleted(blockIndex: oldState.currentBlockIndex))
            } else {
                // 组完成
                onEvent?(.setCompleted(blockIndex: oldState.currentBlockIndex, completedSet: oldState.currentSet))
            }
        }
        
        // 更新状态
        currentState = newState
        
        // 发送事件
        onPhaseChanged?(newState.currentPhase, newState.currentBlockIndex, newState.currentSet)
        onEvent?(.phaseChanged(phase: newState.currentPhase, blockIndex: newState.currentBlockIndex, set: newState.currentSet))
        onStateChanged?(newState)
    }
    
    /// 处理 Session 完成
    private func handleSessionComplete(session: Session) {
        engine.stop()
        isCompleted = true
        
        onEvent?(.sessionCompleted(sessionId: session.id))
        onSessionCompleted?(session)
    }
}

// MARK: - Convenience Computed Properties

extension TimerService {
    /// 当前 Block
    var currentBlock: Block? {
        guard let session = currentSession,
              let state = currentState else { return nil }

        let sortedBlocks = session.sortedBlocks
        guard state.currentBlockIndex < sortedBlocks.count else { return nil }
        return sortedBlocks[state.currentBlockIndex]
    }

    /// 当前阶段
    var currentPhase: TimerPhase {
        currentState?.currentPhase ?? .work
    }

    /// 当前组号 (1-based)
    var currentSet: Int {
        currentState?.currentSet ?? 1
    }

    /// 剩余秒数
    var remainingSeconds: Int {
        currentState?.remainingSeconds ?? 0
    }

    /// 是否暂停
    var isPaused: Bool {
        currentState?.isPaused ?? false
    }

    /// 是否正在运行
    var isRunning: Bool {
        currentState != nil && !isCompleted
    }

    /// 总进度 (0.0 - 1.0)
    var progress: Double {
        guard let session = currentSession,
              let state = currentState else { return 0.0 }
        return state.progress(in: session)
    }
}

// MARK: - Background Recovery

extension TimerService {
    /// 记录进入后台的时间
    func recordBackgroundEntry() {
        backgroundEntryDate = Date()
    }

    /// 从后台恢复，基于墙钟时间快进计时状态
    /// - Returns: 是否发生了阶段切换
    @discardableResult
    func recoverFromBackground() -> Bool {
        guard let entryDate = backgroundEntryDate,
              let state = currentState,
              let session = currentSession,
              !state.isPaused else {
            backgroundEntryDate = nil
            return false
        }

        let elapsedSeconds = Int(Date().timeIntervalSince(entryDate))
        backgroundEntryDate = nil

        guard elapsedSeconds > 0 else { return false }

        let result = state.advancing(by: elapsedSeconds, in: session)

        if result.isCompleted {
            // Session 在后台期间完成
            currentState = TimerState(session: session) // 保持非 nil 以触发完成流程
            engine.stop()
            isCompleted = true
            onEvent?(.sessionCompleted(sessionId: session.id))
            onSessionCompleted?(session)
            return true
        }

        if let finalState = result.finalState {
            currentState = finalState
            onStateChanged?(finalState)

            // 通知所有阶段切换
            for (phase, blockIndex, set) in result.phaseTransitions {
                onPhaseChanged?(phase, blockIndex, set)
                onEvent?(.phaseChanged(phase: phase, blockIndex: blockIndex, set: set))
            }

            return !result.phaseTransitions.isEmpty
        }

        return false
    }
}

// MARK: - Singleton

extension TimerService {
    /// 共享实例
    static let shared = TimerService()
}
