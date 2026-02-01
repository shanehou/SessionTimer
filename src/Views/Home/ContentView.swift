// T037: ContentView - Main navigation container
// Session Timer - 主导航容器

import SwiftUI
import SwiftData

/// 主内容视图 - 作为应用的根导航容器
struct ContentView: View {
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Query
    
    @Query(sort: \Session.createdAt, order: .reverse)
    private var sessions: [Session]
    
    /// 排序后的 Sessions（收藏优先，最近使用优先）
    private var sortedSessions: [Session] {
        sessions.sorted { s1, s2 in
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
    
    // MARK: - State
    
    @State private var showSessionEditor: Bool = false
    @State private var selectedSession: Session?
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("Session Timer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSessionEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSessionEditor) {
                SessionEditorView { session in
                    // 新创建的 Session，可以选择直接开始
                }
            }
            .navigationDestination(for: Session.self) { session in
                TimerView(session: session)
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
    
    /// Session 列表视图
    private var sessionListView: some View {
        List {
            ForEach(sortedSessions, id: \.id) { session in
                SessionListRow(
                    session: session,
                    onStart: {
                        navigationPath.append(session)
                    },
                    onEdit: {
                        selectedSession = session
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteSession(session)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        toggleFavorite(session)
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
        .listStyle(.plain)
        .sheet(item: $selectedSession) { session in
            SessionEditorView(session: session)
        }
    }
    
    // MARK: - Actions
    
    /// 删除 Session
    private func deleteSession(_ session: Session) {
        withAnimation {
            modelContext.delete(session)
        }
    }
    
    /// 切换收藏状态
    private func toggleFavorite(_ session: Session) {
        withAnimation {
            session.isFavorite.toggle()
        }
    }
}

// MARK: - Session List Row

/// Session 列表行组件
struct SessionListRow: View {
    // MARK: - Properties
    
    let session: Session
    let onStart: () -> Void
    let onEdit: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // 主要内容
            VStack(alignment: .leading, spacing: 4) {
                // 名称和收藏标记
                HStack(spacing: 6) {
                    if session.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    
                    Text(session.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                // 摘要信息
                Text(session.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // 最近使用时间
                if let lastUsed = session.formattedLastUsedAt {
                    Text("上次使用: \(lastUsed)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // 快速开始按钮
            Button {
                onStart()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - Session Hashable

extension Session: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preview

#Preview("Content View - Empty") {
    ContentView()
        .modelContainer(for: [Session.self, Block.self], inMemory: true)
}

#Preview("Content View - With Sessions") {
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
    
    return ContentView()
        .modelContainer(container)
}
