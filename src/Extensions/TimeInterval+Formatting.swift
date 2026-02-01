// T019: TimeInterval+Formatting extension
// Session Timer - 时间格式化扩展

import Foundation

extension TimeInterval {
    /// 格式化为 "MM:SS" 格式
    /// - Returns: 格式化的时间字符串
    var formatted_MMSS: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 格式化为 "M:SS" 格式（分钟不补零）
    /// - Returns: 格式化的时间字符串
    var formatted_MSS: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension Int {
    /// 将秒数格式化为 "MM:SS" 格式
    /// - Returns: 格式化的时间字符串
    var formatted_MMSS: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 将秒数格式化为 "M:SS" 格式（分钟不补零）
    /// - Returns: 格式化的时间字符串
    var formatted_MSS: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// 将秒数格式化为可读的时长描述
    /// - Returns: 如 "1分30秒" 或 "30秒"
    var formattedDuration: String {
        let minutes = self / 60
        let seconds = self % 60
        
        if minutes > 0 && seconds > 0 {
            return "\(minutes)分\(seconds)秒"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "\(seconds)秒"
        }
    }
}
