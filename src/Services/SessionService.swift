// T021: SessionService - Session/Block CRUD operations
// Session Timer - Session 管理服务

import Foundation
import SwiftData

/// Session 管理服务
@MainActor
final class SessionService {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initializer
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Session CRUD
    
    /// 创建新 Session
    /// - Parameters:
    ///   - name: Session 名称
    ///   - blocks: 初始 Block 列表
    /// - Returns: 创建的 Session
    /// - Throws: ValidationError 如果验证失败
    func createSession(name: String, blocks: [Block]) throws -> Session {
        // 验证名称
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ValidationError.emptySessionName
        }
        
        // 验证 Blocks
        guard !blocks.isEmpty else {
            throw ValidationError.noBlocks
        }
        
        guard blocks.count <= Session.ValidationConstants.maxBlocks else {
            throw ValidationError.tooManyBlocks(max: Session.ValidationConstants.maxBlocks)
        }
        
        // 验证每个 Block
        for block in blocks {
            try block.validate()
        }
        
        // 更新 Block 的 orderIndex
        for (index, block) in blocks.enumerated() {
            block.orderIndex = index
        }
        
        // 创建 Session
        let session = Session(name: trimmedName, blocks: blocks)
        modelContext.insert(session)
        
        return session
    }
    
    /// 获取所有 Session，按收藏和最近使用时间排序
    /// - Returns: Session 列表
    func getAllSessions() -> [Session] {
        let descriptor = FetchDescriptor<Session>()
        
        do {
            let sessions = try modelContext.fetch(descriptor)
            // 手动排序：收藏优先，然后按最近使用时间，最后按创建时间
            return sessions.sorted { s1, s2 in
                // 收藏的排在前面
                if s1.isFavorite != s2.isFavorite {
                    return s1.isFavorite
                }
                // 然后按最近使用时间（有的优先于没有的）
                if let lastUsed1 = s1.lastUsedAt, let lastUsed2 = s2.lastUsedAt {
                    return lastUsed1 > lastUsed2
                } else if s1.lastUsedAt != nil {
                    return true
                } else if s2.lastUsedAt != nil {
                    return false
                }
                // 最后按创建时间
                return s1.createdAt > s2.createdAt
            }
        } catch {
            #if DEBUG
            print("Error fetching sessions: \(error)")
            #endif
            return []
        }
    }
    
    /// 根据 ID 获取 Session
    /// - Parameter id: Session UUID
    /// - Returns: Session 或 nil
    func getSession(by id: UUID) -> Session? {
        let predicate = #Predicate<Session> { session in
            session.id == id
        }
        
        var descriptor = FetchDescriptor<Session>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            let sessions = try modelContext.fetch(descriptor)
            return sessions.first
        } catch {
            #if DEBUG
            print("Error fetching session by ID: \(error)")
            #endif
            return nil
        }
    }
    
    /// 更新 Session
    /// - Parameter session: 要更新的 Session
    /// - Throws: ValidationError 如果验证失败
    func updateSession(_ session: Session) throws {
        try session.validate()
        // SwiftData 自动追踪更改，无需显式保存
    }
    
    /// 删除 Session
    /// - Parameter session: 要删除的 Session
    func deleteSession(_ session: Session) {
        SpeechService.shared.cleanupCache(for: session)
        modelContext.delete(session)
    }
    
    /// 更新 Session 最近使用时间
    /// - Parameter session: 要更新的 Session
    func markAsUsed(_ session: Session) {
        session.lastUsedAt = Date()
    }
    
    /// 切换 Session 收藏状态
    /// - Parameter session: 要切换的 Session
    func toggleFavorite(_ session: Session) {
        session.isFavorite.toggle()
    }
    
    // MARK: - Block Operations
    
    /// 添加 Block 到 Session
    /// - Parameters:
    ///   - block: 要添加的 Block
    ///   - session: 目标 Session
    func addBlock(_ block: Block, to session: Session) {
        block.orderIndex = session.blocks.count
        session.blocks.append(block)
    }
    
    /// 从 Session 移除 Block
    /// - Parameters:
    ///   - block: 要移除的 Block
    ///   - session: 目标 Session
    func removeBlock(_ block: Block, from session: Session) {
        session.removeBlock(block)
    }
    
    /// 重新排序 Session 中的 Block
    /// - Parameters:
    ///   - session: 目标 Session
    ///   - fromIndex: 原位置
    ///   - toIndex: 新位置
    func reorderBlocks(in session: Session, from fromIndex: Int, to toIndex: Int) {
        session.reorderBlocks(from: fromIndex, to: toIndex)
    }
}

// MARK: - Preview Helper

extension SessionService {
    /// 创建用于预览的 SessionService
    static var preview: SessionService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Session.self, Block.self,
            configurations: config
        )
        return SessionService(modelContext: container.mainContext)
    }
}
