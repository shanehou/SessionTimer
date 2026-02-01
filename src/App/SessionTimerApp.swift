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

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Block.self], inMemory: true)
}
