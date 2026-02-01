// T029: TimerViewModel - Timer interface ViewModel
// Session Timer - 计时器 ViewModel

import Foundation
import SwiftUI
import Combine

/// 计时器 ViewModel
@Observable
@MainActor
final class TimerViewModel {
    // MARK: - State
    
    /// 当前 Session
    private(set) var session: Session
    
    /// 当前 Block
    var currentBlock: Block? {
        let sortedBlocks = session.sortedBlocks
        guard currentBlockIndex < sortedBlocks.count else { return nil }
        return sortedBlocks[currentBlockIndex]
    }
    
    /// 当前 Block 索引 (0-based)
    private(set) var currentBlockIndex: Int = 0
    
    /// 当前组号 (1-based)
    private(set) var currentSet: Int = 1
    
    /// 当前阶段
    private(set) var currentPhase: TimerPhase = .work
    
    /// 剩余秒数
    private(set) var remainingSeconds: Int = 0
    
    /// 是否暂停
    private(set) var isPaused: Bool = false
    
    /// 是否已完成
    private(set) var isCompleted: Bool = false
    
    /// 是否已启动
    private(set) var isStarted: Bool = false
    
    // MARK: - Services
    
    private let timerService: TimerService
    private let hapticService: HapticService
    private let audioService: AudioService
    private let screenService: ScreenService
    
    // MARK: - Subscriptions
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// 总进度 (0.0 - 1.0)
    var progress: Double {
        guard let state = timerService.currentState else { return 0.0 }
        return state.progress(in: session)
    }
    
    /// 格式化的剩余时间 "MM:SS"
    var formattedTime: String {
        remainingSeconds.formatted_MMSS
    }
    
    /// 背景颜色 (Work: 黑色, Rest: 绿色)
    var backgroundColor: Color {
        if isPaused {
            return currentPhase == .work ? .workBackground : .restBackground
        }
        return Color.background(for: currentPhase)
    }
    
    /// 状态文本 ("WORK" / "REST" / "PAUSED")
    var statusText: String {
        if isPaused {
            return "PAUSED"
        }
        return currentPhase.displayName
    }
    
    /// 当前 Block 名称
    var currentBlockName: String {
        currentBlock?.name ?? ""
    }
    
    /// 当前 Block 总组数
    var totalSetsInCurrentBlock: Int {
        currentBlock?.setCount ?? 0
    }
    
    /// 组进度文本 (e.g., "2/3")
    var setProgressText: String {
        "\(currentSet)/\(totalSetsInCurrentBlock)"
    }
    
    /// Block 进度文本 (e.g., "1/4")
    var blockProgressText: String {
        "\(currentBlockIndex + 1)/\(session.blocks.count)"
    }
    
    // MARK: - Initializer
    
    init(
        session: Session,
        timerService: TimerService = .shared,
        hapticService: HapticService = .shared,
        audioService: AudioService = .shared,
        screenService: ScreenService = .shared
    ) {
        self.session = session
        self.timerService = timerService
        self.hapticService = hapticService
        self.audioService = audioService
        self.screenService = screenService
        
        // 初始化状态
        if let firstBlock = session.sortedBlocks.first {
            self.remainingSeconds = firstBlock.workDuration
        }
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // 使用 Combine 监听 TimerService 的 Published 属性
        // 这比回调更可靠，因为新订阅会自动获取当前值
        
        timerService.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self, let state = state else { return }
                self.updateFromState(state)
            }
            .store(in: &cancellables)
        
        timerService.$isCompleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completed in
                guard let self = self else { return }
                if completed {
                    self.handleSessionComplete()
                }
            }
            .store(in: &cancellables)
        
        // 仍然使用回调来处理事件（这些是一次性事件）
        timerService.onPhaseChanged = { [weak self] phase, blockIndex, set in
            self?.handlePhaseChange(phase: phase, blockIndex: blockIndex, set: set)
        }
        
        timerService.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }
    }
    
    // MARK: - Actions
    
    /// 开始计时
    func start() {
        // 如果 TimerService 已经在运行相同的 Session，则同步状态而不是重新启动
        if let currentState = timerService.currentState,
           currentState.sessionId == session.id {
            // 已经在运行，只需要同步本地状态
            isStarted = true
            isCompleted = timerService.isCompleted
            updateFromState(currentState)
            return
        }
        
        guard !isStarted else { return }
        
        isStarted = true
        isCompleted = false
        
        // 准备反馈服务
        hapticService.prepare()
        audioService.preloadSounds()
        screenService.onSessionStart()
        
        // 启动计时
        timerService.start(session: session)
        
        // 标记 Session 为已使用
        session.markAsUsed()
    }
    
    /// 暂停/继续切换
    func togglePause() {
        guard isStarted && !isCompleted else { return }
        
        // 直接查询 timerService 的当前状态，避免异步回调导致的状态不同步
        let currentlyPaused = timerService.currentState?.isPaused ?? false
        
        if currentlyPaused {
            timerService.resume()
        } else {
            timerService.pause()
        }
        
        hapticService.playPauseResume()
    }
    
    /// 暂停
    func pause() {
        guard isStarted && !isCompleted else { return }
        // 直接查询 timerService 的当前状态
        guard !(timerService.currentState?.isPaused ?? true) else { return }
        timerService.pause()
        hapticService.playPauseResume()
    }
    
    /// 继续
    func resume() {
        guard isStarted && !isCompleted else { return }
        // 直接查询 timerService 的当前状态
        guard timerService.currentState?.isPaused ?? false else { return }
        timerService.resume()
        hapticService.playPauseResume()
    }
    
    /// 跳过当前阶段
    func skip() {
        guard isStarted && !isCompleted else { return }
        timerService.skip()
    }
    
    /// 停止并返回
    func stop() {
        timerService.stop()
        screenService.onSessionEnd()
        isStarted = false
        isCompleted = false
    }
    
    /// 加一组
    func addSet() {
        timerService.addSet()
    }
    
    /// 延长休息 30 秒
    func extendRest() {
        timerService.extendRest(by: 30)
    }
    
    /// 跳过当前休息
    func skipRest() {
        guard currentPhase == .rest else { return }
        timerService.skipRest()
    }
    
    // MARK: - Private Methods
    
    /// 从 TimerState 更新 ViewModel 状态
    private func updateFromState(_ state: TimerState) {
        currentBlockIndex = state.currentBlockIndex
        currentSet = state.currentSet
        currentPhase = state.currentPhase
        remainingSeconds = state.remainingSeconds
        isPaused = state.isPaused
    }
    
    /// 处理阶段切换
    private func handlePhaseChange(phase: TimerPhase, blockIndex: Int, set: Int) {
        // 更新屏幕状态
        if let block = session.sortedBlocks[safe: blockIndex] {
            screenService.updateScreenState(for: phase, restDuration: block.restDuration)
        }
        
        // 播放音效
        switch phase {
        case .work:
            audioService.playWorkStart()
        case .rest:
            audioService.playRestStart()
        }
        
        // 播放触觉反馈
        hapticService.playPhaseTransition()
    }
    
    /// 处理 Session 完成
    private func handleSessionComplete() {
        isCompleted = true
        isPaused = false
        
        // 播放完成反馈
        audioService.playSessionComplete()
        hapticService.playSessionComplete()
        
        // 重置屏幕状态
        screenService.onSessionEnd()
    }
    
    /// 处理计时器事件
    private func handleEvent(_ event: TimerEvent) {
        switch event {
        case .countdownWarning(let seconds):
            // 最后几秒播放倒计时警告
            audioService.playCountdown()
            hapticService.playCountdownWarning()
            
            // 如果在长休息期间，唤醒屏幕
            if currentPhase == .rest && screenService.shouldWakeUpScreen(remainingSeconds: seconds) {
                screenService.setScreenAlwaysOn(true)
            }
            
        case .setCompleted:
            // 组完成反馈
            hapticService.playSetTransition()
            
        case .blockCompleted:
            // Block 完成反馈
            hapticService.playSetTransition()
            
        default:
            break
        }
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview Helper

extension TimerViewModel {
    /// 创建用于预览的 ViewModel
    static var preview: TimerViewModel {
        let block1 = Block(name: "深蹲", setCount: 3, workDuration: 30, restDuration: 10)
        let block2 = Block(name: "箭步蹲", setCount: 3, workDuration: 30, restDuration: 10)
        block2.orderIndex = 1
        
        let session = Session(name: "练腿日", blocks: [block1, block2])
        return TimerViewModel(session: session)
    }
}
