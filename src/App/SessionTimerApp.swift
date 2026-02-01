// T011: SessionTimerApp with SwiftData ModelContainer
// Session Timer - App 入口

import SwiftUI
import SwiftData

@main
struct SessionTimerApp: App {
    // MARK: - SwiftData Container
    
    /// 共享的 ModelContainer，支持 iCloud 同步
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Session.self,
            Block.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // 启用 iCloud CloudKit 自动同步
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            // 如果 ModelContainer 创建失败，这是一个致命错误
            // 在生产环境中应该有更好的错误处理
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // MARK: - App Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - ContentView Placeholder

/// 主内容视图 - 将在 Phase 3 中实现完整功能
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.createdAt, order: .reverse)
    private var sessions: [Session]
    
    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "没有练习计划",
                        systemImage: "timer",
                        description: Text("点击右上角的 + 创建你的第一个练习计划")
                    )
                } else {
                    List {
                        ForEach(sessions, id: \.id) { session in
                            SessionRowView(session: session)
                        }
                        .onDelete(perform: deleteSessions)
                    }
                }
            }
            .navigationTitle("Session Timer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addSampleSession()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func addSampleSession() {
        let block1 = Block(name: "深蹲", setCount: 3, workDuration: 30, restDuration: 10)
        let block2 = Block(name: "箭步蹲", setCount: 3, workDuration: 30, restDuration: 10)
        block2.orderIndex = 1
        
        let session = Session(name: "练腿日", blocks: [block1, block2])
        
        modelContext.insert(session)
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
    }
}

// MARK: - Session Row View

/// Session 列表行视图
struct SessionRowView: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if session.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                Text(session.name)
                    .font(.headline)
            }
            
            Text(session.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Block.self], inMemory: true)
}
