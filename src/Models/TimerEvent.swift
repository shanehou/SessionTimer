// T017: TimerEvent enum
// Session Timer - 计时器事件类型

import Foundation

/// 计时器事件，用于服务间通信
enum TimerEvent: Sendable {
    /// Session 开始
    case started(sessionId: UUID)
    
    /// 计时器暂停
    case paused
    
    /// 计时器继续
    case resumed
    
    /// 计时器停止
    case stopped
    
    /// 阶段切换
    /// - Parameters:
    ///   - phase: 新阶段
    ///   - blockIndex: 当前 Block 索引
    ///   - set: 当前组号 (1-based)
    case phaseChanged(phase: TimerPhase, blockIndex: Int, set: Int)
    
    /// 单组完成
    /// - Parameters:
    ///   - blockIndex: Block 索引
    ///   - completedSet: 完成的组号 (1-based)
    case setCompleted(blockIndex: Int, completedSet: Int)
    
    /// Block 完成
    /// - Parameter blockIndex: 完成的 Block 索引
    case blockCompleted(blockIndex: Int)
    
    /// Session 完成
    case sessionCompleted(sessionId: UUID)
    
    /// 计时器 tick
    /// - Parameter remainingSeconds: 剩余秒数
    case tick(remainingSeconds: Int)
    
    /// 倒计时警告 (最后几秒)
    /// - Parameter remainingSeconds: 剩余秒数
    case countdownWarning(remainingSeconds: Int)
}

// MARK: - Event Description

extension TimerEvent: CustomStringConvertible {
    var description: String {
        switch self {
        case .started(let sessionId):
            return "Timer started for session: \(sessionId)"
        case .paused:
            return "Timer paused"
        case .resumed:
            return "Timer resumed"
        case .stopped:
            return "Timer stopped"
        case .phaseChanged(let phase, let blockIndex, let set):
            return "Phase changed to \(phase) at block \(blockIndex), set \(set)"
        case .setCompleted(let blockIndex, let completedSet):
            return "Set \(completedSet) completed at block \(blockIndex)"
        case .blockCompleted(let blockIndex):
            return "Block \(blockIndex) completed"
        case .sessionCompleted(let sessionId):
            return "Session completed: \(sessionId)"
        case .tick(let remainingSeconds):
            return "Tick: \(remainingSeconds)s remaining"
        case .countdownWarning(let remainingSeconds):
            return "Countdown warning: \(remainingSeconds)s"
        }
    }
}
