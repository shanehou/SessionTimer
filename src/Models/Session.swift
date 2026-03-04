// T014: Session SwiftData Model
// Session Timer - Session 数据模型

import Foundation
import SwiftData

/// Session (练习计划) - 代表一次完整的练习计划
/// 如 "练腿日" 或 "音阶爬格子"
@Model
final class Session {
    // MARK: - Properties
    
    /// 唯一标识符
    var id: UUID
    
    /// Session 名称
    var name: String
    
    /// 创建时间
    var createdAt: Date
    
    /// 最近使用时间，用于排序
    var lastUsedAt: Date?
    
    /// 是否收藏，收藏的 Session 显示在列表顶部
    var isFavorite: Bool
    
    /// Session 完成时的播报文本，nil 或空字符串时回退到"训练完成"
    var announcementComplete: String?
    
    /// 包含的 Block 列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \Block.session)
    var blocks: [Block]
    
    // MARK: - Computed Properties
    
    /// 总时长（秒）
    var totalDuration: Int {
        blocks.reduce(0) { total, block in
            total + block.totalDuration
        }
    }
    
    /// 总组数
    var totalSets: Int {
        blocks.reduce(0) { $0 + $1.setCount }
    }
    
    /// 按 orderIndex 排序的 Blocks
    var sortedBlocks: [Block] {
        blocks.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    // MARK: - Initializer
    
    /// 创建 Session
    /// - Parameters:
    ///   - name: Session 名称
    ///   - blocks: 初始 Block 列表，默认为空
    init(
        name: String,
        blocks: [Block] = []
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.lastUsedAt = nil
        self.isFavorite = false
        self.blocks = blocks
    }
    
    // MARK: - Validation
    
    /// Session 验证规则常量
    enum ValidationConstants {
        static let maxBlocks = 50
        static let maxNameLength = 100
    }
    
    /// 验证 Session 数据有效性
    /// - Throws: ValidationError 如果验证失败
    func validate() throws {
        // 名称不能为空
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptySessionName
        }
        
        // 至少需要一个 Block
        guard !blocks.isEmpty else {
            throw ValidationError.noBlocks
        }
        
        // Block 数量限制
        guard blocks.count <= ValidationConstants.maxBlocks else {
            throw ValidationError.tooManyBlocks(max: ValidationConstants.maxBlocks)
        }
        
        // 验证每个 Block
        for block in blocks {
            try block.validate()
        }
    }
}

// MARK: - Convenience Extensions

extension Session {
    /// 格式化的总时长
    var formattedTotalDuration: String {
        totalDuration.formattedDuration
    }
    
    /// 日期格式化器（静态缓存，避免重复创建）
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// 格式化的创建时间
    var formattedCreatedAt: String {
        Self.dateFormatter.string(from: createdAt)
    }
    
    /// 格式化的最近使用时间
    var formattedLastUsedAt: String? {
        guard let lastUsedAt = lastUsedAt else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUsedAt, relativeTo: Date())
    }
    
    /// Session 摘要描述
    var summary: String {
        let blockCount = blocks.count
        let blockText = blockCount == 1 ? "1 个项目" : "\(blockCount) 个项目"
        return "\(blockText) · \(totalSets) 组 · \(formattedTotalDuration)"
    }
    
    /// 添加 Block
    /// - Parameter block: 要添加的 Block
    func addBlock(_ block: Block) {
        block.orderIndex = blocks.count
        blocks.append(block)
    }
    
    /// 移除 Block
    /// - Parameter block: 要移除的 Block
    func removeBlock(_ block: Block) {
        blocks.removeAll { $0.id == block.id }
        // 重新排序
        for (index, b) in blocks.enumerated() {
            b.orderIndex = index
        }
    }
    
    /// 重新排序 Blocks
    /// - Parameters:
    ///   - fromIndex: 原位置
    ///   - toIndex: 新位置
    func reorderBlocks(from fromIndex: Int, to toIndex: Int) {
        var sortedBlocks = self.sortedBlocks
        let block = sortedBlocks.remove(at: fromIndex)
        sortedBlocks.insert(block, at: toIndex)
        
        for (index, b) in sortedBlocks.enumerated() {
            b.orderIndex = index
        }
    }
    
    /// 标记为已使用
    func markAsUsed() {
        lastUsedAt = Date()
    }
}

// MARK: - Hashable

extension Session: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}
