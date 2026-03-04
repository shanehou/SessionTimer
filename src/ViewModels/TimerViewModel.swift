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
    private let notificationService: NotificationService
    private let speechService = SpeechService.shared
    
    // MARK: - Voice Announcement
    
    @ObservationIgnored
    @AppStorage("isVoiceAnnouncementEnabled") private var isVoiceAnnouncementEnabled: Bool = true
    
    // MARK: - Live Activity Update Throttle
    
    /// 上次更新 Live Activity 的时间（避免过于频繁更新）
    private var lastLiveActivityUpdate: Date = .distantPast
    
    /// Live Activity 最小更新间隔（秒）
    private let liveActivityUpdateInterval: TimeInterval = 1.0
    
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
        Color.background(for: currentPhase)
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
        "\(currentBlockIndex + 1)/\(session.sortedBlocks.count)"
    }
    
    // MARK: - Initializer
    
    init(
        session: Session,
        timerService: TimerService = .shared,
        hapticService: HapticService = .shared,
        audioService: AudioService = .shared,
        screenService: ScreenService = .shared,
        notificationService: NotificationService = .shared
    ) {
        self.session = session
        self.timerService = timerService
        self.hapticService = hapticService
        self.audioService = audioService
        self.screenService = screenService
        self.notificationService = notificationService
        
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
            .sink { [weak self] state in
                guard let self = self, let state = state else { return }
                self.updateFromState(state)
            }
            .store(in: &cancellables)
        
        timerService.$isCompleted
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
        
        // 启动后台音频保活
        audioService.startBackgroundAudioSession()
        
        // 启动计时
        timerService.start(session: session)
        
        // 请求通知权限并启动 Live Activity
        Task {
            _ = await notificationService.requestPermission()
            
            if let state = timerService.currentState {
                await notificationService.startLiveActivity(for: session, state: state)
            }
        }
        
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
        
        // 暂停/恢复时立即更新 Live Activity
        if let state = timerService.currentState {
            lastLiveActivityUpdate = Date()
            Task {
                await notificationService.updateLiveActivity(state: state, session: session)
            }
        }
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
        audioService.endBackgroundAudioSession()

        // 结束 Live Activity 并清除所有通知
        Task {
            await notificationService.endLiveActivity()
        }
        notificationService.cancelScheduledPhaseNotifications()

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
    
    // MARK: - Voice Announcement Resolution
    
    /// 根据阶段、Block、组号解析播报文本
    private func resolveAnnouncementText(phase: TimerPhase, block: Block, set: Int) -> String {
        switch phase {
        case .work where set == 1:
            let text = block.announcementStart ?? ""
            return text.isEmpty ? block.name : text
        case .work:
            let text = block.announcementContinue ?? ""
            return text.isEmpty ? "继续" : text
        case .rest:
            let text = block.announcementRest ?? ""
            return text.isEmpty ? "休息" : text
        }
    }
    
    /// 解析 Session 完成播报文本
    private func resolveCompletionText(session: Session) -> String {
        let text = session.announcementComplete ?? ""
        return text.isEmpty ? "训练完成" : text
    }
    
    // MARK: - Private Methods
    
    /// 从 TimerState 更新 ViewModel 状态
    private func updateFromState(_ state: TimerState) {
        currentBlockIndex = state.currentBlockIndex
        currentSet = state.currentSet
        currentPhase = state.currentPhase
        remainingSeconds = state.remainingSeconds
        isPaused = state.isPaused
        
        // 节流更新 Live Activity（每秒最多一次）
        let now = Date()
        if now.timeIntervalSince(lastLiveActivityUpdate) >= liveActivityUpdateInterval {
            lastLiveActivityUpdate = now
            Task {
                await notificationService.updateLiveActivity(state: state, session: session)
            }
        }
    }
    
    /// 处理阶段切换
    private func handlePhaseChange(phase: TimerPhase, blockIndex: Int, set: Int) {
        // 更新屏幕状态
        if let block = session.sortedBlocks[safe: blockIndex] {
            screenService.updateScreenState(for: phase, restDuration: block.restDuration)
        }
        
        // 语音播报或音效（互斥）
        if isVoiceAnnouncementEnabled, let block = session.sortedBlocks[safe: blockIndex] {
            let text = resolveAnnouncementText(phase: phase, block: block, set: set)
            speechService.speak(text)
        } else {
            switch phase {
            case .work:
                audioService.playWorkStart()
            case .rest:
                audioService.playRestStart()
            }
        }
        
        // 播放触觉反馈
        hapticService.playPhaseTransition()
        
        // 阶段切换时立即更新 Live Activity（不受节流限制）
        if let state = timerService.currentState {
            lastLiveActivityUpdate = Date()
            Task {
                await notificationService.updateLiveActivity(state: state, session: session)
            }
        }
        
        // 后台时发送阶段切换通知 (T059)
        let blockName = session.sortedBlocks[safe: blockIndex]?.name ?? ""
        notificationService.sendPhaseChangeNotification(phase: phase, blockName: blockName)
    }
    
    /// 处理 Session 完成
    private func handleSessionComplete() {
        isCompleted = true
        isPaused = false

        // 完成播报或音效（互斥）
        if isVoiceAnnouncementEnabled {
            let text = resolveCompletionText(session: session)
            speechService.speak(text)
        } else {
            audioService.playSessionComplete()
        }
        hapticService.playSessionComplete()

        // 重置屏幕状态
        screenService.onSessionEnd()

        // 结束后台音频
        audioService.endBackgroundAudioSession()

        // 取消预调度的通知
        notificationService.cancelScheduledPhaseNotifications()

        // 结束 Live Activity 并发送完成通知
        Task {
            await notificationService.endLiveActivity()
        }
        notificationService.sendSessionCompleteNotification(sessionName: session.name)
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

// MARK: - Background / Foreground Handling

extension TimerViewModel {
    /// App 进入后台时调用
    func handleDidEnterBackground() {
        notificationService.isInBackground = true

        // 记录后台进入时间，用于前台恢复时精确快进
        timerService.recordBackgroundEntry()

        // 立即更新 Live Activity，确保后台同步
        if let state = timerService.currentState {
            lastLiveActivityUpdate = Date()
            Task {
                await notificationService.updateLiveActivity(state: state, session: session)
            }
        }

        // 预调度后台阶段切换通知
        if let state = timerService.currentState {
            notificationService.scheduleUpcomingPhaseNotifications(from: state, session: session)
        }
    }

    /// App 回到前台时调用 - 重新同步状态 (T058)
    func handleWillEnterForeground() {
        notificationService.isInBackground = false

        // 取消预调度的通知（前台时由 app 实时触发）
        notificationService.cancelScheduledPhaseNotifications()

        // 清除后台期间送达的通知
        notificationService.removeAllNotifications()

        // 基于墙钟时间恢复计时状态（处理后台期间的阶段切换）
        let hadTransitions = timerService.recoverFromBackground()

        // 如果计时器已完成（在后台完成的）
        if timerService.isCompleted && !isCompleted {
            handleSessionComplete()
            return
        }

        // 从 TimerService 同步最新状态
        if let state = timerService.currentState {
            updateFromState(state)

            // 立即更新 Live Activity
            lastLiveActivityUpdate = Date()
            Task {
                await notificationService.updateLiveActivity(state: state, session: session)
            }
        }

        // 如果发生了阶段切换，恢复屏幕状态
        if hadTransitions, let state = timerService.currentState {
            let sortedBlocks = session.sortedBlocks
            if let block = sortedBlocks[safe: state.currentBlockIndex] {
                screenService.updateScreenState(for: state.currentPhase, restDuration: block.restDuration)
            }
        }
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
