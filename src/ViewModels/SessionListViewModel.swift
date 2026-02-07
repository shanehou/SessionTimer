// T038: SessionListViewModel - Session list management
// Session Timer - Session 列表 ViewModel

import Foundation
import SwiftData

/// Session 列表 ViewModel
@Observable
@MainActor
final class SessionListViewModel {
    // MARK: - State
    
    /// 搜索文本
    var searchText: String = ""
    
    /// 是否显示删除确认
    var showDeleteConfirmation: Bool = false
    
    /// 待删除的 Session
    var sessionToDelete: Session?
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    
    // MARK: - Initializer
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Filtering
    
    /// 过滤并排序 Sessions
    /// - Parameter sessions: 原始 Session 列表
    /// - Returns: 过滤并排序后的列表
    func filteredSessions(_ sessions: [Session]) -> [Session] {
        var result = sessions
        
        // 搜索过滤
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { session in
                session.name.lowercased().contains(lowercasedSearch) ||
                session.blocks.contains { $0.name.lowercased().contains(lowercasedSearch) }
            }
        }
        
        // 排序：收藏优先，最近使用优先
        return result.sorted { s1, s2 in
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
    }
    
    // MARK: - Actions
    
    /// 切换收藏状态
    /// - Parameter session: 要切换的 Session
    func toggleFavorite(_ session: Session) {
        session.isFavorite.toggle()
    }
    
    /// 请求删除 Session（显示确认对话框）
    /// - Parameter session: 要删除的 Session
    func requestDelete(_ session: Session) {
        sessionToDelete = session
        showDeleteConfirmation = true
    }
    
    /// 确认删除 Session
    func confirmDelete() {
        guard let session = sessionToDelete else { return }
        modelContext.delete(session)
        sessionToDelete = nil
        showDeleteConfirmation = false
    }
    
    /// 取消删除
    func cancelDelete() {
        sessionToDelete = nil
        showDeleteConfirmation = false
    }
    
    /// 直接删除 Session（无确认）
    /// - Parameter session: 要删除的 Session
    func delete(_ session: Session) {
        modelContext.delete(session)
    }
}

// MARK: - Preview Helper

extension SessionListViewModel {
    /// 创建用于预览的 ViewModel
    static var preview: SessionListViewModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Session.self, Block.self,
            configurations: config
        )
        return SessionListViewModel(modelContext: container.mainContext)
    }
}
