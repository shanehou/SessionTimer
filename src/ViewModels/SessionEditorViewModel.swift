// T028: SessionEditorViewModel - Session creation/editing
// Session Timer - Session 编辑器 ViewModel

import Foundation
import SwiftData
import SwiftUI

/// 可编辑的 Block 数据
/// 用于编辑界面，与 SwiftData @Model 分离
@Observable
final class EditableBlock: Identifiable {
    let id: UUID
    var name: String
    var setCount: Int
    var workDuration: Int  // seconds
    var restDuration: Int  // seconds
    var announcementStart: String
    var announcementRest: String
    var announcementContinue: String
    
    init(
        id: UUID = UUID(),
        name: String = "新练习",
        setCount: Int = 3,
        workDuration: Int = 30,
        restDuration: Int = 10,
        announcementStart: String = "",
        announcementRest: String = "",
        announcementContinue: String = ""
    ) {
        self.id = id
        self.name = name
        self.setCount = setCount
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.announcementStart = announcementStart
        self.announcementRest = announcementRest
        self.announcementContinue = announcementContinue
    }
    
    /// 从 Block 模型创建
    convenience init(from block: Block) {
        self.init(
            id: block.id,
            name: block.name,
            setCount: block.setCount,
            workDuration: block.workDuration,
            restDuration: block.restDuration,
            announcementStart: block.announcementStart ?? "",
            announcementRest: block.announcementRest ?? "",
            announcementContinue: block.announcementContinue ?? ""
        )
    }
    
    /// 转换为 Block 模型
    func toBlock(orderIndex: Int) -> Block {
        let block = Block(
            name: name,
            setCount: setCount,
            workDuration: workDuration,
            restDuration: restDuration,
            orderIndex: orderIndex
        )
        block.announcementStart = announcementStart.isEmpty ? nil : announcementStart
        block.announcementRest = announcementRest.isEmpty ? nil : announcementRest
        block.announcementContinue = announcementContinue.isEmpty ? nil : announcementContinue
        return block
    }
    
    /// 单组时长
    var setDuration: Int {
        workDuration + restDuration
    }
    
    /// 总时长
    var totalDuration: Int {
        setCount * setDuration
    }
}

/// Session 编辑器 ViewModel
@Observable
@MainActor
final class SessionEditorViewModel {
    // MARK: - State
    
    /// Session 名称
    var name: String = ""
    
    /// Session 完成播报文本
    var announcementComplete: String = ""
    
    /// Block 列表
    var blocks: [EditableBlock] = []
    
    /// 是否为编辑模式
    let isEditing: Bool
    
    /// 正在编辑的 Session ID（编辑模式）
    private let editingSessionId: UUID?
    
    /// 验证错误信息
    var validationError: ValidationError?
    
    /// 是否显示验证错误（由 validationError 驱动）
    var showValidationError: Bool {
        get { validationError != nil }
        set { if !newValue { validationError = nil } }
    }
    
    // MARK: - Computed Properties
    
    /// 是否可以保存
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !blocks.isEmpty
    }
    
    /// 总时长（秒）
    var totalDuration: Int {
        blocks.reduce(0) { $0 + $1.totalDuration }
    }
    
    /// 格式化的总时长
    var formattedTotalDuration: String {
        totalDuration.formattedDuration
    }
    
    /// 总组数
    var totalSets: Int {
        blocks.reduce(0) { $0 + $1.setCount }
    }
    
    /// Session 摘要
    var summary: String {
        let blockCount = blocks.count
        let blockText = blockCount == 1 ? "1 个项目" : "\(blockCount) 个项目"
        return "\(blockText) · \(totalSets) 组 · \(formattedTotalDuration)"
    }
    
    // MARK: - Initializers
    
    /// 创建模式
    init() {
        self.isEditing = false
        self.editingSessionId = nil
        
        // 添加一个默认 Block
        addBlock()
    }
    
    /// 编辑模式
    init(session: Session) {
        self.isEditing = true
        self.editingSessionId = session.id
        self.name = session.name
        self.announcementComplete = session.announcementComplete ?? ""
        self.blocks = session.sortedBlocks.map { EditableBlock(from: $0) }
    }
    
    // MARK: - Actions
    
    /// 添加新 Block
    func addBlock() {
        let newBlock = EditableBlock()
        blocks.append(newBlock)
    }
    
    /// 删除 Block
    /// - Parameter index: 要删除的索引
    func deleteBlock(at index: Int) {
        guard blocks.indices.contains(index) else { return }
        blocks.remove(at: index)
    }
    
    /// 删除 Block（通过 IndexSet）
    /// - Parameter offsets: 要删除的索引集合
    func deleteBlocks(at offsets: IndexSet) {
        blocks.remove(atOffsets: offsets)
    }
    
    /// 移动 Block
    /// - Parameters:
    ///   - source: 源索引集合
    ///   - destination: 目标索引
    func moveBlock(from source: IndexSet, to destination: Int) {
        blocks.move(fromOffsets: source, toOffset: destination)
    }
    
    /// 验证输入
    /// - Returns: 是否验证通过
    @discardableResult
    func validate() -> Bool {
        validationError = nil
        
        // 验证名称
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            validationError = .emptySessionName
            return false
        }
        
        // 验证 Blocks
        if blocks.isEmpty {
            validationError = .noBlocks
            return false
        }
        
        if blocks.count > Session.ValidationConstants.maxBlocks {
            validationError = .tooManyBlocks(max: Session.ValidationConstants.maxBlocks)
            return false
        }
        
        // 验证每个 Block
        for block in blocks {
            if block.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationError = .emptyBlockName
                return false
            }
            
            if block.setCount < 1 || block.setCount > 99 {
                validationError = .invalidSetCount
                return false
            }
            
            if block.workDuration < 0 || block.workDuration > 5999 {
                validationError = .invalidDuration
                return false
            }
            
            if block.restDuration < 0 || block.restDuration > 5999 {
                validationError = .invalidDuration
                return false
            }
            
            if block.workDuration == 0 && block.restDuration == 0 {
                validationError = .zeroDuration
                return false
            }
        }
        
        return true
    }
    
    /// 保存 Session
    /// - Parameter modelContext: SwiftData ModelContext
    /// - Returns: 保存的 Session
    /// - Throws: ValidationError 如果验证失败
    func save(modelContext: ModelContext) throws -> Session {
        // 验证
        guard validate() else {
            throw validationError!
        }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isEditing, let sessionId = editingSessionId {
            // 编辑模式：更新现有 Session
            let predicate = #Predicate<Session> { session in
                session.id == sessionId
            }
            var descriptor = FetchDescriptor<Session>(predicate: predicate)
            descriptor.fetchLimit = 1
            
            guard let session = try? modelContext.fetch(descriptor).first else {
                throw ValidationError.sessionNotFound
            }
            
            // 更新名称和播报文本
            session.name = trimmedName
            session.announcementComplete = announcementComplete.isEmpty ? nil : announcementComplete
            
            // 删除旧的 Blocks
            for block in session.blocks {
                modelContext.delete(block)
            }
            session.blocks.removeAll()
            
            // 添加新的 Blocks
            for (index, editableBlock) in blocks.enumerated() {
                let block = editableBlock.toBlock(orderIndex: index)
                session.blocks.append(block)
            }
            
            return session
        } else {
            // 创建模式：创建新 Session
            let newBlocks = blocks.enumerated().map { index, editableBlock in
                editableBlock.toBlock(orderIndex: index)
            }
            
            let session = Session(name: trimmedName, blocks: newBlocks)
            session.announcementComplete = announcementComplete.isEmpty ? nil : announcementComplete
            modelContext.insert(session)
            
            return session
        }
    }
    
    /// 清除验证错误
    func clearValidationError() {
        validationError = nil
    }
}

// MARK: - Preview Helper

extension SessionEditorViewModel {
    /// 创建用于预览的 ViewModel
    static var preview: SessionEditorViewModel {
        let viewModel = SessionEditorViewModel()
        viewModel.name = "练腿日"
        viewModel.blocks = [
            EditableBlock(name: "深蹲", setCount: 3, workDuration: 30, restDuration: 10),
            EditableBlock(name: "箭步蹲", setCount: 3, workDuration: 30, restDuration: 10)
        ]
        return viewModel
    }
}
