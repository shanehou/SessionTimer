// Array+SafeSubscript - 安全下标扩展
// Session Timer - 数组安全访问

import Foundation

extension Array {
    /// 安全下标访问，越界时返回 nil
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
