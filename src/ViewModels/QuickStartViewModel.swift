// Session Timer - 快速开始 ViewModel

import Foundation
import SwiftData

/// 快速开始 Block 编辑数据
@Observable
final class EditableQuickStartBlock: Identifiable {
    let id: UUID
    var name: String
    var setCount: Int
    var workDuration: Int
    var restDuration: Int
    
    init(
        id: UUID = UUID(),
        name: String = "项目 1",
        setCount: Int = 3,
        workDuration: Int = 30,
        restDuration: Int = 15
    ) {
        self.id = id
        self.name = name
        self.setCount = setCount
        self.workDuration = workDuration
        self.restDuration = restDuration
    }
    
    init(from config: QuickStartCache.BlockConfig) {
        self.id = UUID()
        self.name = config.name
        self.setCount = config.setCount
        self.workDuration = config.workDuration
        self.restDuration = config.restDuration
    }
    
    func toBlockConfig() -> QuickStartCache.BlockConfig {
        QuickStartCache.BlockConfig(
            name: name,
            setCount: setCount,
            workDuration: workDuration,
            restDuration: restDuration
        )
    }
}

/// 快速开始 ViewModel
@Observable
@MainActor
final class QuickStartViewModel {
    // MARK: - State
    
    var blocks: [EditableQuickStartBlock]
    var preparingDuration: Int
    
    var canStart: Bool { !blocks.isEmpty }
    
    // MARK: - Lifecycle
    
    init() {
        let (cachedBlocks, cachedPreparing) = QuickStartCache.shared.load()
        self.blocks = cachedBlocks.map { EditableQuickStartBlock(from: $0) }
        self.preparingDuration = cachedPreparing
    }
    
    // MARK: - Block Management
    
    func addBlock() {
        let nextIndex = blocks.count + 1
        let block = EditableQuickStartBlock(name: "项目 \(nextIndex)")
        blocks.append(block)
    }
    
    func removeBlock(at index: Int) {
        guard blocks.count > 1, blocks.indices.contains(index) else { return }
        blocks.remove(at: index)
    }
    
    func moveBlock(from source: IndexSet, to destination: Int) {
        blocks.move(fromOffsets: source, toOffset: destination)
    }
    
    // MARK: - Session Creation
    
    func createSession() -> Session {
        QuickStartCache.shared.save(
            blocks: blocks.map { $0.toBlockConfig() },
            preparingDuration: preparingDuration
        )
        
        let session = Session(
            name: "快速训练",
            preparingDuration: preparingDuration
        )
        
        for (index, editableBlock) in blocks.enumerated() {
            let block = Block(
                name: editableBlock.name,
                setCount: editableBlock.setCount,
                workDuration: editableBlock.workDuration,
                restDuration: editableBlock.restDuration,
                orderIndex: index
            )
            block.session = session
            session.blocks.append(block)
        }
        
        return session
    }
}
