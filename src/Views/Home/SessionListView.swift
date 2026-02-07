// T040: SessionListView - Main session list view
// Session Timer - Session 列表视图

import SwiftUI
import SwiftData

/// Session 列表视图
struct SessionListView: View {
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Query
    
    @Query(sort: \Session.createdAt, order: .reverse)
    private var sessions: [Session]
    
    // MARK: - State
    
    @State private var viewModel: SessionListViewModel?
    @State private var showSessionEditor: Bool = false
    
    // MARK: - Bindings
    
    @Binding var navigationPath: NavigationPath
    @Binding var selectedSessionForDetail: Session?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyStateView
            } else {
                sessionListContent
            }
        }
        .navigationTitle("Session Timer")
        .searchable(
            text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            ),
            prompt: "搜索练习计划"
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSessionEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建练习计划")
                .accessibilityHint("创建一个新的练习计划")
            }
        }
        .sheet(isPresented: $showSessionEditor) {
            SessionEditorView()
        }
        .alert(
            "确认删除",
            isPresented: Binding(
                get: { viewModel?.showDeleteConfirmation ?? false },
                set: { _ in viewModel?.cancelDelete() }
            )
        ) {
            Button("取消", role: .cancel) {
                viewModel?.cancelDelete()
            }
            Button("删除", role: .destructive) {
                viewModel?.confirmDelete()
            }
        } message: {
            if let session = viewModel?.sessionToDelete {
                Text("确定要删除「\(session.name)」吗？此操作不可撤销。")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SessionListViewModel(modelContext: modelContext)
            }
        }
    }
    
    // MARK: - Subviews
    
    /// 空状态视图
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("没有练习计划", systemImage: "timer")
        } description: {
            Text("点击右上角的 + 创建你的第一个练习计划")
        } actions: {
            Button {
                showSessionEditor = true
            } label: {
                Text("创建练习计划")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    /// Session 列表内容
    private var sessionListContent: some View {
        List {
            let filteredSessions = viewModel?.filteredSessions(sessions) ?? sessions
            
            if filteredSessions.isEmpty && !(viewModel?.searchText.isEmpty ?? true) {
                ContentUnavailableView.search(text: viewModel?.searchText ?? "")
            } else {
                ForEach(filteredSessions, id: \.id) { session in
                    SessionCard(
                        session: session,
                        onTap: {
                            selectedSessionForDetail = session
                        },
                        onStart: {
                            navigationPath.append(session)
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel?.requestDelete(session)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            viewModel?.toggleFavorite(session)
                        } label: {
                            Label(
                                session.isFavorite ? "取消收藏" : "收藏",
                                systemImage: session.isFavorite ? "star.slash" : "star"
                            )
                        }
                        .tint(.yellow)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Session List - Empty") {
    NavigationStack {
        SessionListView(
            navigationPath: .constant(NavigationPath()),
            selectedSessionForDetail: .constant(nil)
        )
    }
    .modelContainer(for: [Session.self, Block.self], inMemory: true)
}

#Preview("Session List - With Sessions") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Session.self, Block.self, configurations: config)
    
    // 添加示例数据
    let block1 = Block(name: "深蹲", setCount: 3, workDuration: 30, restDuration: 10)
    let session1 = Session(name: "练腿日", blocks: [block1])
    session1.isFavorite = true
    session1.lastUsedAt = Date().addingTimeInterval(-3600)
    container.mainContext.insert(session1)
    
    let block2 = Block(name: "C大调音阶", setCount: 5, workDuration: 60, restDuration: 10)
    let session2 = Session(name: "音阶练习", blocks: [block2])
    container.mainContext.insert(session2)
    
    let block3 = Block(name: "俯卧撑", setCount: 4, workDuration: 45, restDuration: 15)
    let session3 = Session(name: "上肢力量", blocks: [block3])
    container.mainContext.insert(session3)
    
    return NavigationStack {
        SessionListView(
            navigationPath: .constant(NavigationPath()),
            selectedSessionForDetail: .constant(nil)
        )
    }
    .modelContainer(container)
}
