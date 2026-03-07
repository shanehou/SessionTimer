// Session Timer - 快速开始内存配置缓存

import Foundation

/// 快速开始配置的内存缓存
/// 纯内存存储，App 重启后丢失
@Observable
@MainActor
final class QuickStartCache {
    static let shared = QuickStartCache()
    
    struct BlockConfig: Sendable {
        var name: String
        var setCount: Int
        var workDuration: Int
        var restDuration: Int
        
        static var `default`: BlockConfig {
            BlockConfig(name: "项目 1", setCount: 3, workDuration: 30, restDuration: 15)
        }
    }
    
    private(set) var blocks: [BlockConfig] = []
    private(set) var preparingDuration: Int = 0
    
    var hasCache: Bool { !blocks.isEmpty }
    
    func save(blocks: [BlockConfig], preparingDuration: Int) {
        self.blocks = blocks
        self.preparingDuration = preparingDuration
    }
    
    func load() -> (blocks: [BlockConfig], preparingDuration: Int) {
        if hasCache {
            return (blocks, preparingDuration)
        }
        return ([.default], 0)
    }
    
    private init() {}
}
