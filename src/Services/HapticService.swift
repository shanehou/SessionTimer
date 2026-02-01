// T024: HapticService - Haptic feedback
// Session Timer - 触觉反馈服务

import UIKit

/// 触觉反馈服务协议
@MainActor
protocol HapticServiceProtocol {
    /// 准备触觉引擎
    func prepare()
    
    /// 播放组切换反馈 (Heavy Impact)
    func playSetTransition()
    
    /// 播放 Session 完成反馈 (Success)
    func playSessionComplete()
    
    /// 播放倒计时警告反馈 (Warning)
    func playCountdownWarning()
    
    /// 播放暂停/继续反馈 (Light Impact)
    func playPauseResume()
}

/// 触觉反馈服务实现
@MainActor
final class HapticService: HapticServiceProtocol {
    // MARK: - Properties
    
    /// Heavy Impact 反馈生成器（用于组切换）
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    /// Medium Impact 反馈生成器（用于阶段切换）
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    /// Light Impact 反馈生成器（用于暂停/继续）
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    
    /// 通知反馈生成器（用于 Session 完成和警告）
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    /// 是否启用触觉反馈
    var isEnabled: Bool = true
    
    // MARK: - Initializer
    
    init() {
        // 预热所有反馈生成器
        prepare()
    }
    
    // MARK: - HapticServiceProtocol
    
    /// 准备触觉引擎
    func prepare() {
        heavyImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        lightImpactGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    /// 播放组切换反馈 (Heavy Impact)
    func playSetTransition() {
        guard isEnabled else { return }
        heavyImpactGenerator.impactOccurred()
        heavyImpactGenerator.prepare()
    }
    
    /// 播放 Session 完成反馈 (Success)
    func playSessionComplete() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    /// 播放倒计时警告反馈 (Warning)
    func playCountdownWarning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
    
    /// 播放暂停/继续反馈 (Light Impact)
    func playPauseResume() {
        guard isEnabled else { return }
        lightImpactGenerator.impactOccurred()
        lightImpactGenerator.prepare()
    }
    
    // MARK: - Additional Methods
    
    /// 播放阶段切换反馈 (Medium Impact)
    func playPhaseTransition() {
        guard isEnabled else { return }
        mediumImpactGenerator.impactOccurred()
        mediumImpactGenerator.prepare()
    }
    
    /// 播放错误反馈
    func playError() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
}

// MARK: - Singleton

extension HapticService {
    /// 共享实例
    static let shared = HapticService()
}
