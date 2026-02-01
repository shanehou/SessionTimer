# Research: Session Timer - 重复练习计时器App

**Feature Branch**: `001-session-timer`  
**Date**: 2026-02-01  
**Status**: Complete

## Research Tasks

本文档记录了在 Phase 0 阶段对关键技术点的研究结果，解决了 Technical Context 中的所有 NEEDS CLARIFICATION 项。

---

## 1. 数据存储与 iCloud 同步

### Decision: SwiftData + CloudKit 自动同步

### Rationale

- **SwiftData** 是 iOS 17+ 官方推荐的数据持久化框架，取代 Core Data
- SwiftData 原生支持 CloudKit 同步，只需在 `ModelConfiguration` 中启用即可
- 与 SwiftUI 深度集成，使用 `@Model` 宏和 `@Query` 属性包装器
- 自动处理 schema 迁移、冲突解决、离线数据同步

### Implementation Notes

```swift
// 启用 iCloud 同步的 ModelContainer 配置
@main
struct SessionTimerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Session.self, Block.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // 启用 iCloud 同步
        )
        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

### Requirements

1. 在 Xcode 中启用 iCloud capability，勾选 CloudKit
2. 在 Signing & Capabilities 中添加 Background Modes > Remote notifications
3. 确保 App ID 已启用 iCloud 和 Push Notifications
4. SwiftData 模型必须符合 CloudKit 限制（无 unique 约束、无 optional relationships without inverse）

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Core Data + NSPersistentCloudKitContainer | SwiftData 更现代，API 更简洁，与 SwiftUI 集成更好 |
| 纯 CloudKit | 需要手动处理同步逻辑、冲突解决，复杂度高 |
| Realm + Realm Sync | 第三方依赖，需要付费云服务 |

---

## 2. Live Activities 与 Dynamic Island

### Decision: ActivityKit + WidgetKit

### Rationale

- **ActivityKit** 是 iOS 16.1+ 官方 API，用于管理 Live Activities 的生命周期
- **WidgetKit** 用于定义 Live Activities 的 UI（锁屏和灵动岛）
- 支持本地更新（`Activity.update`）和远程推送更新
- 灵动岛有三种展示模式：紧凑型、最小型、展开型

### Implementation Notes

```swift
// 1. 定义 ActivityAttributes
struct SessionTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentBlockName: String
        var currentSet: Int
        var totalSets: Int
        var remainingSeconds: Int
        var phase: TimerPhase  // .work or .rest
    }
    
    var sessionName: String
}

// 2. 启动 Live Activity
let attributes = SessionTimerAttributes(sessionName: "练腿日")
let state = SessionTimerAttributes.ContentState(
    currentBlockName: "深蹲",
    currentSet: 1,
    totalSets: 3,
    remainingSeconds: 30,
    phase: .work
)
let activity = try Activity.request(
    attributes: attributes,
    content: .init(state: state, staleDate: nil),
    pushType: nil  // 本地更新，不使用推送
)

// 3. 更新 Live Activity
await activity.update(
    ActivityContent(state: newState, staleDate: nil)
)

// 4. 结束 Live Activity
await activity.end(
    ActivityContent(state: finalState, staleDate: nil),
    dismissalPolicy: .default
)
```

### Constraints

- 单个 App 最多同时 5 个 Live Activities
- 单个 Live Activity 最长持续 8 小时（活跃）+ 4 小时（锁屏展示）
- 灵动岛背景只能是黑色
- 更新频率：本地更新无硬性限制，但建议每秒 1 次避免性能问题
- 展开视图最大高度 160pt

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| 仅使用本地通知 | 无法实时显示进度，用户体验差 |
| Widget（Timeline） | Widget 有刷新间隔限制，不适合秒级更新 |

---

## 3. 后台运行计时器

### Decision: Background Audio Mode + DispatchSourceTimer

### Rationale

- iOS 不允许普通 App 在后台长时间运行
- 使用 **Background Audio Mode** 是计时器 App 的标准方案
- 播放静音音频可保持 App 在后台运行
- `DispatchSourceTimer` 在后台仍能准确触发

### Implementation Notes

```swift
// 1. Info.plist 配置
// UIBackgroundModes: audio

// 2. 配置 AVAudioSession
func setupBackgroundAudio() {
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]  // 关键：与其他音频混音
    )
    try? audioSession.setActive(true)
}

// 3. 使用 DispatchSourceTimer 实现精确计时
class TimerEngine {
    private var timer: DispatchSourceTimer?
    
    func start() {
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now(), repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.tick()
        }
        timer?.resume()
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
    }
}
```

### Alternative Strategy: Time Calculation

```swift
// 后台恢复时，根据时间差重新计算状态
func applicationDidBecomeActive() {
    let elapsed = Date().timeIntervalSince(lastBackgroundDate)
    currentSeconds -= Int(elapsed)
    // 处理阶段切换、Session 完成等
}
```

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| BGTaskScheduler | 最小间隔 15 分钟，不适合秒级计时 |
| 纯时间差计算 | 无法在后台播放提示音、触发通知 |
| Local Notifications 调度 | 需要预先调度大量通知，不灵活 |

---

## 4. 音频混音（不打断背景音乐）

### Decision: AVAudioSession.mixWithOthers + AVAudioPlayer

### Rationale

- 使用 `.mixWithOthers` 选项允许 App 音频与其他 App 音频同时播放
- 用户练习时可能在听音乐或节拍器，提示音不应打断
- `AVAudioPlayer` 适合播放短音效文件

### Implementation Notes

```swift
class AudioService {
    private var players: [String: AVAudioPlayer] = [:]
    
    init() {
        // 配置 Audio Session
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers, .duckOthers]  // 混音 + 临时降低其他音频音量
        )
        try? session.setActive(true)
        
        // 预加载音效
        preloadSound("work_start", extension: "wav")
        preloadSound("rest_start", extension: "wav")
        preloadSound("countdown", extension: "wav")
        preloadSound("session_complete", extension: "wav")
    }
    
    func playSound(_ name: String) {
        players[name]?.currentTime = 0
        players[name]?.play()
    }
}
```

### Sound Design Requirements

| 事件 | 音效特点 |
|------|---------|
| Work 开始 | 清脆、激励感 |
| Rest 开始 | 轻松、舒缓 |
| 倒计时 3-2-1 | 节奏感、紧迫感 |
| Session 完成 | 庆祝、成就感 |

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| SystemSoundID | 无法与其他音频混音 |
| 不使用 duckOthers | 提示音可能被背景音乐淹没 |

---

## 5. 触觉反馈（Haptic Feedback）

### Decision: CoreHaptics + UIFeedbackGenerator

### Rationale

- `UIFeedbackGenerator` 提供简单的系统触觉反馈
- `CoreHaptics` 提供更精细的自定义触觉模式
- 对于计时器 App，系统预设已足够

### Implementation Notes

```swift
class HapticService {
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    init() {
        impactGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    func playSetTransition() {
        // 组间切换：Heavy Impact
        impactGenerator.impactOccurred()
    }
    
    func playSessionComplete() {
        // Session 完成：Success
        notificationGenerator.notificationOccurred(.success)
    }
    
    func playCountdownTick() {
        // 倒计时最后 3 秒：Warning
        notificationGenerator.notificationOccurred(.warning)
    }
}
```

---

## 6. Swift 6 并发模式

### Decision: @MainActor + Sendable + async/await

### Rationale

- Swift 6 默认启用严格并发检查（Strict Concurrency）
- 项目已配置 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- UI 相关代码默认在 MainActor 上运行，简化线程安全

### Implementation Notes

```swift
// ViewModel 示例 - 默认 @MainActor
@Observable
class TimerViewModel {
    var remainingSeconds: Int = 0
    var currentPhase: TimerPhase = .work
    
    private let timerEngine: TimerEngine
    
    func start() {
        timerEngine.start { [weak self] in
            self?.tick()
        }
    }
    
    private func tick() {
        // 已在 MainActor 上，可以安全更新 UI 状态
        remainingSeconds -= 1
    }
}

// 后台任务需要显式标记
nonisolated func calculateBackgroundElapsedTime() async -> Int {
    // 可以在任意线程执行
    let elapsed = Date().timeIntervalSince(lastBackgroundDate)
    return Int(elapsed)
}
```

### Key Patterns

1. **@Observable** 替代 ObservableObject，自动细粒度更新
2. **@MainActor** 标记 UI 相关类，保证线程安全
3. **Sendable** 标记跨线程传递的类型
4. **nonisolated** 标记不需要 actor 隔离的方法

---

## 7. 屏幕常亮策略

### Decision: UIApplication.isIdleTimerDisabled

### Rationale

- 简单直接的系统 API
- Work 状态保持常亮，用户能看到进度
- 长 Rest 时关闭常亮省电

### Implementation Notes

```swift
class ScreenService {
    func setScreenAlwaysOn(_ enabled: Bool) {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = enabled
        }
    }
}

// 在 TimerEngine 中使用
func transitionToPhase(_ phase: TimerPhase) {
    switch phase {
    case .work:
        screenService.setScreenAlwaysOn(true)
    case .rest:
        if restDuration > 60 {
            screenService.setScreenAlwaysOn(false)
            // 休息结束前 5 秒重新点亮或发送强提醒
            scheduleWakeUp(at: restEndTime - 5)
        }
    }
}
```

---

## 8. 全屏手势控制

### Decision: SwiftUI Gesture Modifiers

### Rationale

- SwiftUI 提供声明式手势 API
- 可以组合多种手势（单击、双击、长按）
- 手势识别器自动处理优先级

### Implementation Notes

```swift
struct TimerView: View {
    @State private var viewModel: TimerViewModel
    
    var body: some View {
        ZStack {
            // 全屏背景
            backgroundColor
                .ignoresSafeArea()
            
            // 计时器显示
            TimerDisplay(viewModel: viewModel)
        }
        .contentShape(Rectangle())  // 确保整个区域可点击
        .onTapGesture(count: 2) {
            // 双击：跳过当前阶段
            viewModel.skip()
        }
        .onTapGesture(count: 1) {
            // 单击：暂停/继续
            viewModel.togglePause()
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            // 长按：结束 Session
            viewModel.stop()
        }
    }
}
```

### Note on Gesture Priority

SwiftUI 自动处理手势优先级：
- 双击会等待确认不是单击
- 长按会在达到时间阈值后触发
- 使用 `simultaneousGesture` 可以同时响应多个手势

---

## 9. 构建工具链

### Decision: XcodeGen + xcbeautify + xcodebuild

### Rationale

- **XcodeGen** 从 YAML 配置生成 `.xcodeproj`，避免项目文件冲突
- **xcbeautify** 美化 xcodebuild 输出，提升可读性
- 命令行构建支持 CI/CD 集成和自动化

### Implementation Notes

#### XcodeGen 配置 (src/project.yml)

```yaml
name: SessionTimer
options:
  bundleIdPrefix: me.melkor
  deploymentTarget:
    iOS: "16.1"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "6.0"
    DEVELOPMENT_TEAM: SW7BAJUMAC
    SWIFT_STRICT_CONCURRENCY: complete

targets:
  SessionTimer:
    type: application
    platform: iOS
    sources:
      - path: App
        excludes:
          - "**/.DS_Store"
      - Models
      - Views
      - ViewModels
      - Services
      - Extensions
      - Shared
      - Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: me.melkor.SessionTimer
        INFOPLIST_FILE: App/Info.plist
        CODE_SIGN_ENTITLEMENTS: App/SessionTimer.entitlements
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    info:
      path: App/Info.plist
      properties:
        NSSupportsLiveActivities: true
        UIBackgroundModes: [audio]
    entitlements:
      path: App/SessionTimer.entitlements
      properties:
        com.apple.developer.icloud-container-identifiers:
          - iCloud.me.melkor.SessionTimer
        com.apple.developer.icloud-services:
          - CloudKit
    dependencies:
      - target: SessionTimerWidgets

  SessionTimerWidgets:
    type: app-extension
    platform: iOS
    sources:
      - path: ../src-widgets
      - path: Shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: me.melkor.SessionTimer.widgets
        INFOPLIST_FILE: ../src-widgets/Info.plist
```

#### 构建脚本 (src/scripts/run.sh)

```bash
#!/bin/bash
set -e

# 自动检测连接的设备
DEVICE=$(xcrun xctrace list devices 2>&1 | grep -E "iPhone|iPad" | grep -v "Simulator" | head -1 | sed 's/ (.*//')

if [ -z "$DEVICE" ]; then
    echo "No iOS device connected, using simulator..."
    DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro"
else
    echo "Found device: $DEVICE"
    DESTINATION="platform=iOS,name=$DEVICE"
fi

# 构建并运行
xcodebuild -project SessionTimer.xcodeproj \
           -scheme SessionTimer \
           -destination "$DESTINATION" \
           build 2>&1 | xcbeautify

# 如果是真机，安装并启动
if [ -n "$DEVICE" ]; then
    xcrun devicectl device install app \
        --device "$DEVICE" \
        build/Debug-iphoneos/SessionTimer.app
    xcrun devicectl device process launch \
        --device "$DEVICE" \
        me.melkor.SessionTimer
fi
```

### Makefile (src/Makefile)

```makefile
.PHONY: generate build run-simulator run-device test clean

generate:
	xcodegen generate

build:
	xcodebuild -project SessionTimer.xcodeproj \
	           -scheme SessionTimer \
	           -destination 'generic/platform=iOS' \
	           build | xcbeautify

run-simulator:
	xcodebuild -project SessionTimer.xcodeproj \
	           -scheme SessionTimer \
	           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
	           build | xcbeautify
	xcrun simctl boot "iPhone 15 Pro" 2>/dev/null || true
	xcrun simctl install booted build/Debug-iphonesimulator/SessionTimer.app
	xcrun simctl launch booted me.melkor.SessionTimer

run-device:
	./scripts/run.sh

test:
	xcodebuild test \
	           -project SessionTimer.xcodeproj \
	           -scheme SessionTimer \
	           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
	           | xcbeautify

clean:
	rm -rf build/
	xcodebuild clean -project SessionTimer.xcodeproj -scheme SessionTimer

help:
	@echo "Available targets:"
	@echo "  generate      - Generate Xcode project from project.yml"
	@echo "  build         - Build the project"
	@echo "  run-simulator - Build and run on simulator"
	@echo "  run-device    - Build and run on connected device"
	@echo "  test          - Run unit tests"
	@echo "  clean         - Clean build artifacts"
```

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| 手动维护 .xcodeproj | 多人协作时冲突频繁，添加文件需要手动操作 |
| Tuist | 功能更强但学习曲线陡峭，本项目规模不需要 |
| Swift Package Manager only | 不支持 Widget Extension 和复杂的 Xcode 配置 |

---

## Summary

| 技术领域 | 选择 | 关键点 |
|---------|------|-------|
| 数据存储 | SwiftData | @Model, @Query, 自动迁移 |
| iCloud 同步 | CloudKit (自动) | ModelConfiguration.cloudKitDatabase |
| Live Activities | ActivityKit | 锁屏 + 灵动岛 |
| 后台运行 | Background Audio | mixWithOthers, DispatchSourceTimer |
| 音频反馈 | AVAudioPlayer | mixWithOthers, duckOthers |
| 触觉反馈 | UIFeedbackGenerator | Heavy, Success, Warning |
| 并发模式 | Swift 6 Strict | @MainActor, @Observable, Sendable |
| 屏幕常亮 | isIdleTimerDisabled | Work 常亮, 长 Rest 可暗 |
| 手势控制 | SwiftUI Gestures | 单击/双击/长按 组合 |
| 项目生成 | XcodeGen | project.yml → .xcodeproj |
| 构建美化 | xcbeautify | 可读的构建输出 |

所有 NEEDS CLARIFICATION 已解决，可以进入 Phase 1。
