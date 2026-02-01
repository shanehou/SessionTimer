// T012: TimerPhase enum
// Session Timer - 计时器阶段枚举

import Foundation

/// 计时器的当前阶段
enum TimerPhase: String, Codable, Sendable, CaseIterable {
    /// 练习阶段
    case work
    /// 休息阶段
    case rest
    
    /// 阶段显示名称
    var displayName: String {
        switch self {
        case .work:
            return "WORK"
        case .rest:
            return "REST"
        }
    }
    
    /// 切换到下一个阶段
    var next: TimerPhase {
        switch self {
        case .work:
            return .rest
        case .rest:
            return .work
        }
    }
}
