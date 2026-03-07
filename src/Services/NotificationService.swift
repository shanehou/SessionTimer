// T051: NotificationService - Live Activity & Local Notifications
// Session Timer - 通知与 Live Activity 服务

import Foundation
import ActivityKit
@preconcurrency import UserNotifications

/// 通知与 Live Activity 服务
@MainActor
final class NotificationService {
    // MARK: - Properties
    
    /// 当前 Live Activity ID
    private var currentActivityId: String?
    
    /// 是否已获取通知权限
    private var hasNotificationPermission: Bool = false
    
    /// App 是否在后台
    var isInBackground: Bool = false
    
    // MARK: - Permissions
    
    /// 请求通知权限
    /// - Returns: 是否获得权限
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            hasNotificationPermission = granted
            return granted
        } catch {
            #if DEBUG
            print("[NotificationService] Failed to request permission: \(error)")
            #endif
            return false
        }
    }
    
    // MARK: - Notification Cleanup

    /// 清除所有已送达和待送达的本地通知
    func removeAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Live Activities

    /// 启动 Live Activity
    func startLiveActivity(for session: Session, state: TimerState) async {
        // 结束旧的 Activity
        await endLiveActivity()

        // 清除旧通知，避免重复
        removeAllNotifications()
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            #if DEBUG
            print("[NotificationService] Live Activities not enabled")
            #endif
            return
        }
        
        let sortedBlocks = session.sortedBlocks
        guard state.currentBlockIndex < sortedBlocks.count else { return }
        let currentBlock = sortedBlocks[state.currentBlockIndex]
        
        let attributes = SessionTimerAttributes(
            sessionName: session.name,
            totalBlocks: sortedBlocks.count
        )
        
        let contentState = makeContentState(from: state, block: currentBlock)
        let content = ActivityContent(
            state: contentState,
            staleDate: nil
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivityId = activity.id
            #if DEBUG
            print("[NotificationService] Live Activity started: \(activity.id)")
            #endif
        } catch {
            #if DEBUG
            print("[NotificationService] Failed to start Live Activity: \(error)")
            #endif
        }
    }
    
    /// 更新 Live Activity
    /// - Parameters:
    ///   - state: 当前计时状态
    ///   - session: 当前 Session
    ///   - staleDate: 数据过期时间（当前阶段结束时间），便于系统知道何时数据不再准确
    func updateLiveActivity(state: TimerState, session: Session) async {
        guard let activityId = currentActivityId else { return }
        guard let activity = findActivity(id: activityId) else { return }

        let sortedBlocks = session.sortedBlocks
        guard state.currentBlockIndex < sortedBlocks.count else { return }
        let currentBlock = sortedBlocks[state.currentBlockIndex]

        let contentState = makeContentState(from: state, block: currentBlock)

        // 设置 staleDate 为当前阶段结束时间，让系统知道数据何时不再准确
        let staleDate: Date? = state.isPaused ? nil : Date().addingTimeInterval(TimeInterval(state.remainingSeconds + 1))

        let content = ActivityContent(
            state: contentState,
            staleDate: staleDate
        )

        await activity.update(content)
    }
    
    /// 结束 Live Activity
    func endLiveActivity() async {
        guard let activityId = currentActivityId else { return }
        guard let activity = findActivity(id: activityId) else {
            currentActivityId = nil
            return
        }
        
        let finalState = SessionTimerAttributes.ContentState.completed()
        let content = ActivityContent(
            state: finalState,
            staleDate: nil
        )
        
        await activity.end(content, dismissalPolicy: .default)
        currentActivityId = nil

        // 清除残留的本地通知
        removeAllNotifications()

        #if DEBUG
        print("[NotificationService] Live Activity ended")
        #endif
    }
    
    // MARK: - Local Notifications
    
    /// 发送阶段切换通知 (后台时)
    func sendPhaseChangeNotification(phase: TimerPhase, blockName: String) {
        guard isInBackground else { return }
        
        let content = UNMutableNotificationContent()
        content.interruptionLevel = .timeSensitive
        
        switch phase {
        case .preparing:
            return
        case .work:
            content.title = "开始练习"
            content.body = "\(blockName) - WORK"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("work_start.wav"))
        case .rest:
            content.title = "休息时间"
            content.body = "\(blockName) - REST"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("rest_start.wav"))
        }
        
        let request = UNNotificationRequest(
            identifier: "phase-change-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                #if DEBUG
                print("[NotificationService] Failed to send phase change notification: \(error)")
                #endif
            }
        }
    }
    
    /// 发送 Session 完成通知 (后台时)
    func sendSessionCompleteNotification(sessionName: String) {
        guard isInBackground else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "练习完成！"
        content.body = "\(sessionName) 已完成"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("session_complete.wav"))
        content.interruptionLevel = .timeSensitive
        
        let request = UNNotificationRequest(
            identifier: "session-complete-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                #if DEBUG
                print("[NotificationService] Failed to send session complete notification: \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Scheduled Background Notifications

    /// 预调度的通知 ID 前缀
    private nonisolated static let scheduledNotificationPrefix = "scheduled-phase-"

    /// 预调度所有即将到来的阶段切换通知（进入后台时调用）
    /// 基于当前计时状态计算所有未来阶段切换的确切时间，提前注册通知
    func scheduleUpcomingPhaseNotifications(from state: TimerState, session: Session) {
        guard !state.isPaused else { return }

        // 先取消之前调度的通知
        cancelScheduledPhaseNotifications()

        let sortedBlocks = session.sortedBlocks
        var currentState = state
        var offsetSeconds = 0

        // 遍历所有未来的阶段切换
        for index in 0..<200 {  // 安全上限，避免无限循环
            // 当前阶段的剩余时间
            offsetSeconds += currentState.remainingSeconds

            // 尝试切换到下一阶段
            guard let nextState = currentState.nextPhase(in: session) else {
                // Session 完成 - 调度完成通知
                scheduleNotification(
                    identifier: "\(Self.scheduledNotificationPrefix)complete-\(index)",
                    title: "练习完成！",
                    body: "\(session.name) 已完成",
                    soundName: "session_complete.wav",
                    afterSeconds: offsetSeconds
                )
                break
            }

            // 调度阶段切换通知
            let blockIndex = nextState.currentBlockIndex
            guard blockIndex < sortedBlocks.count else { break }
            let block = sortedBlocks[blockIndex]

            switch nextState.currentPhase {
            case .preparing:
                break
            case .work:
                scheduleNotification(
                    identifier: "\(Self.scheduledNotificationPrefix)\(index)",
                    title: "开始练习",
                    body: "\(block.name) - WORK",
                    soundName: "work_start.wav",
                    afterSeconds: offsetSeconds
                )
            case .rest:
                scheduleNotification(
                    identifier: "\(Self.scheduledNotificationPrefix)\(index)",
                    title: "休息时间",
                    body: "\(block.name) - REST",
                    soundName: "rest_start.wav",
                    afterSeconds: offsetSeconds
                )
            }

            currentState = nextState
        }
    }

    /// 取消所有预调度的阶段切换通知（回到前台时调用）
    func cancelScheduledPhaseNotifications() {
        let prefix = Self.scheduledNotificationPrefix
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let scheduledIds = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map(\.identifier)
            if !scheduledIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: scheduledIds)
            }
        }
    }

    /// 调度一个延迟通知
    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        soundName: String,
        afterSeconds: Int
    ) {
        guard afterSeconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(afterSeconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                #if DEBUG
                print("[NotificationService] Failed to schedule notification: \(error)")
                #endif
            }
        }
    }

    // MARK: - Private Helpers
    
    /// 根据 ID 查找活跃的 Live Activity
    private nonisolated func findActivity(id: String) -> Activity<SessionTimerAttributes>? {
        Activity<SessionTimerAttributes>.activities.first { $0.id == id }
    }
    
    /// 从 TimerState 创建 ContentState
    private func makeContentState(
        from state: TimerState,
        block: Block
    ) -> SessionTimerAttributes.ContentState {
        // 计算计时器结束时间
        // Widget 使用 Text(timerInterval:) 实现系统级精确倒计时
        let timerEndDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        
        return SessionTimerAttributes.ContentState(
            currentBlockName: block.name,
            currentBlockIndex: state.currentBlockIndex,
            currentSet: state.currentSet,
            totalSets: block.setCount,
            remainingSeconds: state.remainingSeconds,
            timerEndDate: timerEndDate,
            phase: state.currentPhase.rawValue,
            isPaused: state.isPaused
        )
    }
}

// MARK: - Singleton

extension NotificationService {
    /// 共享实例
    static let shared = NotificationService()
}
