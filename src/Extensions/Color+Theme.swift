// T020: Color+Theme extension
// Session Timer - 主题颜色扩展

import SwiftUI

extension Color {
    // MARK: - Timer Phase Colors
    
    /// Work 阶段背景色 - 黑色
    static let workBackground = Color.black
    
    /// Rest 阶段背景色 - 绿色
    static let restBackground = Color.green
    
    // MARK: - Text Colors
    
    /// 主要文字颜色 - 白色（用于深色背景）
    static let textPrimary = Color.white
    
    /// 次要文字颜色
    static let textSecondary = Color.white.opacity(0.7)
    
    /// 暂停状态文字颜色
    static let textPaused = Color.yellow
    
    // MARK: - UI Element Colors
    
    /// 进度条背景色
    static let progressBackground = Color.white.opacity(0.3)
    
    // MARK: - Helper Methods
    
    /// 根据计时阶段返回对应的背景颜色
    /// - Parameter phase: 计时器阶段
    /// - Returns: 对应的背景颜色
    static func background(for phase: TimerPhase) -> Color {
        switch phase {
        case .work:
            return .workBackground
        case .rest:
            return .restBackground
        }
    }
    
}
