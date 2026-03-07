// T037: ContentView - Main navigation container
// Session Timer - 主导航容器

import SwiftUI
import SwiftData

/// 主内容视图 - 作为应用的根导航容器
struct ContentView: View {
    // MARK: - State
    
    @State private var navigationPath = NavigationPath()
    @State private var selectedSessionForDetail: Session?
    @State private var quickStartSession: Session?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            SessionListView(
                navigationPath: $navigationPath,
                selectedSessionForDetail: $selectedSessionForDetail,
                quickStartSession: $quickStartSession
            )
            .navigationDestination(for: TimerDestination.self) { destination in
                switch destination {
                case .saved(let session):
                    TimerView(session: session)
                case .quickStart(let session):
                    TimerView(session: session, isQuickStartMode: true)
                }
            }
        }
        .sheet(item: $selectedSessionForDetail) { session in
            NavigationStack {
                SessionDetailView(session: session) {
                    selectedSessionForDetail = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigationPath.append(TimerDestination.saved(session))
                    }
                }
            }
        }
        .onChange(of: quickStartSession) { _, newSession in
            guard let session = newSession else { return }
            quickStartSession = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                navigationPath.append(TimerDestination.quickStart(session))
            }
        }
    }
}

/// 计时器导航目的地
enum TimerDestination: Hashable {
    case saved(Session)
    case quickStart(Session)
}

// MARK: - Preview

#Preview("Content View - Empty") {
    ContentView()
        .modelContainer(for: [Session.self, Block.self], inMemory: true)
}

#Preview("Content View - With Sessions") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Session.self, Block.self, configurations: config)
    
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
