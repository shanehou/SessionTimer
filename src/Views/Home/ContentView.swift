// T037: ContentView - Main navigation container
// Session Timer - 主导航容器

import SwiftUI
import SwiftData

/// 主内容视图 - 作为应用的根导航容器
struct ContentView: View {
    // MARK: - State
    
    @State private var navigationPath = NavigationPath()
    @State private var selectedSessionForDetail: Session?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            SessionListView(
                navigationPath: $navigationPath,
                selectedSessionForDetail: $selectedSessionForDetail
            )
            .navigationDestination(for: Session.self) { session in
                TimerView(session: session)
            }
        }
        .sheet(item: $selectedSessionForDetail) { session in
            NavigationStack {
                SessionDetailView(session: session) {
                    // 关闭详情页并开始计时
                    selectedSessionForDetail = nil
                    // 延迟一帧确保 sheet 关闭后再导航
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigationPath.append(session)
                    }
                }
            }
        }
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
