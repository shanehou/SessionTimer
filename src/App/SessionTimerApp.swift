// T011: SessionTimerApp with SwiftData ModelContainer
// T064: App lifecycle handling for scene phase changes
// Session Timer - App 入口

import SwiftUI
import SwiftData

@main
struct SessionTimerApp: App {
    // MARK: - Environment
    
    @Environment(\.scenePhase) private var scenePhase
    
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
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    // MARK: - Scene Phase Handling
    
    /// 处理 App 生命周期变化
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // App 进入后台 - 通知 NotificationService
            NotificationService.shared.isInBackground = true
            
            // 如果有活跃计时器，确保 Live Activity 是最新的
            if let state = TimerService.shared.currentState,
               let session = TimerService.shared.currentSession {
                Task {
                    await NotificationService.shared.updateLiveActivity(
                        state: state,
                        session: session
                    )
                }
            }
            
            // 确保屏幕恢复正常（避免后台时 idle timer 仍被禁用）
            // 注意：后台时 iOS 会自动处理，但前台恢复时需要重新设置
            
        case .active:
            // App 回到前台 - 同步状态
            NotificationService.shared.isInBackground = false
            
            // 重新同步 Live Activity
            if let state = TimerService.shared.currentState,
               let session = TimerService.shared.currentSession {
                Task {
                    await NotificationService.shared.updateLiveActivity(
                        state: state,
                        session: session
                    )
                }
                
                // 恢复屏幕常亮状态
                ScreenService.shared.updateScreenState(for: state, in: session)
            }
            
        case .inactive:
            // 即将进入后台或从后台恢复的过渡状态
            break
            
        @unknown default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Block.self], inMemory: true)
}
