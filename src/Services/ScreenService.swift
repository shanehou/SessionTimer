// T026: ScreenService - Screen wake control
// Session Timer - 屏幕控制服务

import UIKit

/// 屏幕控制服务
@MainActor
final class ScreenService {
    // MARK: - Properties
    
    /// 长休息时间阈值（秒）- 超过此阈值的休息时间会关闭屏幕常亮
    private let longRestThreshold: Int = 60
    
    /// 休息结束前唤醒屏幕的提前时间（秒）
    private let wakeUpAdvanceTime: Int = 5
    
    /// 是否启用智能屏幕控制
    var isSmartScreenControlEnabled: Bool = true
    
    // MARK: - Public Methods
    
    /// 设置屏幕常亮
    /// - Parameter enabled: 是否保持屏幕常亮
    func setScreenAlwaysOn(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }
    
    /// 根据计时状态更新屏幕常亮
    /// - Parameters:
    ///   - phase: 当前计时阶段
    ///   - restDuration: 休息时长（秒）
    func updateScreenState(for phase: TimerPhase, restDuration: Int) {
        guard isSmartScreenControlEnabled else {
            // 如果禁用智能控制，始终保持常亮
            setScreenAlwaysOn(true)
            return
        }
        
        switch phase {
        case .preparing, .work:
            setScreenAlwaysOn(true)
            
        case .rest:
            if restDuration > longRestThreshold {
                setScreenAlwaysOn(false)
            } else {
                setScreenAlwaysOn(true)
            }
        }
    }
    
    // MARK: - Additional Methods
    
    /// 根据 TimerState 更新屏幕状态
    /// - Parameters:
    ///   - state: 计时器状态
    ///   - session: 当前 Session
    func updateScreenState(for state: TimerState, in session: Session) {
        let sortedBlocks = session.sortedBlocks
        guard state.currentBlockIndex < sortedBlocks.count else { return }
        
        let currentBlock = sortedBlocks[state.currentBlockIndex]
        updateScreenState(for: state.currentPhase, restDuration: currentBlock.restDuration)
    }
    
    /// 检查是否应该唤醒屏幕（休息结束前）
    /// - Parameter remainingSeconds: 剩余秒数
    /// - Returns: 是否应该唤醒屏幕
    func shouldWakeUpScreen(remainingSeconds: Int) -> Bool {
        return remainingSeconds <= wakeUpAdvanceTime && remainingSeconds > 0
    }
    
    /// 在 Session 开始时设置屏幕状态
    func onSessionStart() {
        setScreenAlwaysOn(true)
    }
    
    /// 在 Session 结束时重置屏幕状态
    func onSessionEnd() {
        setScreenAlwaysOn(false)
    }
}

// MARK: - Singleton

extension ScreenService {
    /// 共享实例
    static let shared = ScreenService()
}
