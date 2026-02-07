// T051: NotificationService - Live Activity & Local Notifications
// Session Timer - 通知与 Live Activity 服务

import Foundation
import ActivityKit
import UserNotifications

/// 通知服务协议
@MainActor
protocol NotificationServiceProtocol {
    /// 请求通知权限
    func requestPermission() async -> Bool
    
    /// 启动 Live Activity
    func startLiveActivity(for session: Session, state: TimerState) async
    
    /// 更新 Live Activity
    func updateLiveActivity(state: TimerState, session: Session) async
    
    /// 结束 Live Activity
    func endLiveActivity() async
    
    /// 发送阶段切换通知 (后台时)
    func sendPhaseChangeNotification(phase: TimerPhase, blockName: String)
    
    /// 发送 Session 完成通知 (后台时)
    func sendSessionCompleteNotification(sessionName: String)
}

/// 通知服务实现
@MainActor
final class NotificationService: NotificationServiceProtocol {
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
            print("[NotificationService] Failed to request permission: \(error)")
            return false
        }
    }
    
    // MARK: - Live Activities
    
    /// 启动 Live Activity
    func startLiveActivity(for session: Session, state: TimerState) async {
        // 结束旧的 Activity
        await endLiveActivity()
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[NotificationService] Live Activities not enabled")
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
            print("[NotificationService] Live Activity started: \(activity.id)")
        } catch {
            print("[NotificationService] Failed to start Live Activity: \(error)")
        }
    }
    
    /// 更新 Live Activity
    func updateLiveActivity(state: TimerState, session: Session) async {
        guard let activityId = currentActivityId else { return }
        guard let activity = findActivity(id: activityId) else { return }
        
        let sortedBlocks = session.sortedBlocks
        guard state.currentBlockIndex < sortedBlocks.count else { return }
        let currentBlock = sortedBlocks[state.currentBlockIndex]
        
        let contentState = makeContentState(from: state, block: currentBlock)
        let content = ActivityContent(
            state: contentState,
            staleDate: nil
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
        print("[NotificationService] Live Activity ended")
    }
    
    // MARK: - Local Notifications
    
    /// 发送阶段切换通知 (后台时)
    func sendPhaseChangeNotification(phase: TimerPhase, blockName: String) {
        guard isInBackground else { return }
        
        let content = UNMutableNotificationContent()
        content.interruptionLevel = .timeSensitive
        
        switch phase {
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
                print("[NotificationService] Failed to send phase change notification: \(error)")
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
                print("[NotificationService] Failed to send session complete notification: \(error)")
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
