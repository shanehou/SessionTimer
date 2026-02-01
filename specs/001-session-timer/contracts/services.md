# Session Timer - Internal API Contracts

**Feature Branch**: `001-session-timer`  
**Date**: 2026-02-01  
**Type**: iOS Native App (No REST API)

## Overview

Session Timer 是一个纯 iOS 本地应用，不需要后端 API。本文档定义了应用内部的服务层契约，用于指导 ViewModel 和 Service 层的实现。

---

## Service Contracts

### 1. SessionService

管理 Session 和 Block 的 CRUD 操作。

```swift
/// Session 管理服务协议
protocol SessionServiceProtocol {
    
    // MARK: - Session CRUD
    
    /// 创建新 Session
    /// - Parameters:
    ///   - name: Session 名称
    ///   - blocks: 初始 Block 列表
    /// - Returns: 创建的 Session
    /// - Throws: ValidationError 如果 name 为空或 blocks 为空
    func createSession(name: String, blocks: [Block]) throws -> Session
    
    /// 获取所有 Session
    /// - Returns: Session 列表，按收藏、最近使用时间排序
    func getAllSessions() -> [Session]
    
    /// 根据 ID 获取 Session
    /// - Parameter id: Session UUID
    /// - Returns: Session 或 nil
    func getSession(by id: UUID) -> Session?
    
    /// 更新 Session
    /// - Parameter session: 要更新的 Session
    /// - Throws: ValidationError 如果验证失败
    func updateSession(_ session: Session) throws
    
    /// 删除 Session
    /// - Parameter session: 要删除的 Session
    func deleteSession(_ session: Session)
    
    /// 更新 Session 最近使用时间
    /// - Parameter session: 要更新的 Session
    func markAsUsed(_ session: Session)
    
    /// 切换 Session 收藏状态
    /// - Parameter session: 要切换的 Session
    func toggleFavorite(_ session: Session)
    
    // MARK: - Block Operations
    
    /// 添加 Block 到 Session
    /// - Parameters:
    ///   - block: 要添加的 Block
    ///   - session: 目标 Session
    func addBlock(_ block: Block, to session: Session)
    
    /// 从 Session 移除 Block
    /// - Parameters:
    ///   - block: 要移除的 Block
    ///   - session: 目标 Session
    func removeBlock(_ block: Block, from session: Session)
    
    /// 重新排序 Session 中的 Block
    /// - Parameters:
    ///   - session: 目标 Session
    ///   - fromIndex: 原位置
    ///   - toIndex: 新位置
    func reorderBlocks(in session: Session, from fromIndex: Int, to toIndex: Int)
}
```

---

### 2. TimerService

管理计时器的核心逻辑。

```swift
/// 计时器服务协议
protocol TimerServiceProtocol {
    
    /// 当前计时状态
    var currentState: TimerState? { get }
    
    /// 状态变化回调
    var onStateChanged: ((TimerState) -> Void)? { get set }
    
    /// 阶段切换回调
    var onPhaseChanged: ((TimerPhase, Block, Int) -> Void)? { get set }
    
    /// Session 完成回调
    var onSessionCompleted: ((Session) -> Void)? { get set }
    
    // MARK: - Timer Control
    
    /// 启动 Session 计时
    /// - Parameter session: 要启动的 Session
    func start(session: Session)
    
    /// 暂停计时
    func pause()
    
    /// 继续计时
    func resume()
    
    /// 停止并重置计时器
    func stop()
    
    /// 跳过当前阶段
    /// - 如果在 Work 阶段，跳到 Rest
    /// - 如果在 Rest 阶段，跳到下一组的 Work
    /// - 如果是最后一组最后阶段，结束 Session
    func skip()
    
    // MARK: - Runtime Adjustments
    
    /// 为当前 Block 加一组
    func addSet()
    
    /// 跳过当前休息时间
    func skipRest()
    
    /// 延长当前休息时间
    /// - Parameter seconds: 延长的秒数
    func extendRest(by seconds: Int)
}
```

---

### 3. HapticService

管理触觉反馈。

```swift
/// 触觉反馈服务协议
protocol HapticServiceProtocol {
    
    /// 准备触觉引擎
    func prepare()
    
    /// 播放组切换反馈 (Heavy Impact)
    func playSetTransition()
    
    /// 播放 Session 完成反馈 (Success)
    func playSessionComplete()
    
    /// 播放倒计时警告反馈 (Warning)
    func playCountdownWarning()
    
    /// 播放暂停/继续反馈 (Light Impact)
    func playPauseResume()
}
```

---

### 4. AudioService

管理音频提示。

```swift
/// 音频服务协议
protocol AudioServiceProtocol {
    
    /// 是否启用音效
    var isSoundEnabled: Bool { get set }
    
    /// 预加载所有音效
    func preloadSounds()
    
    /// 播放 Work 开始音效
    func playWorkStart()
    
    /// 播放 Rest 开始音效
    func playRestStart()
    
    /// 播放倒计时音效 (最后 3 秒)
    func playCountdown()
    
    /// 播放 Session 完成音效
    func playSessionComplete()
}
```

---

### 5. NotificationService

管理本地通知和 Live Activities。

```swift
/// 通知服务协议
protocol NotificationServiceProtocol {
    
    // MARK: - Permissions
    
    /// 请求通知权限
    func requestPermission() async -> Bool
    
    // MARK: - Live Activities
    
    /// 启动 Live Activity
    /// - Parameter session: 当前 Session
    /// - Returns: Activity ID
    func startLiveActivity(for session: Session) async throws -> String
    
    /// 更新 Live Activity
    /// - Parameters:
    ///   - activityId: Activity ID
    ///   - state: 新状态
    func updateLiveActivity(id: String, with state: TimerState) async
    
    /// 结束 Live Activity
    /// - Parameter activityId: Activity ID
    func endLiveActivity(id: String) async
    
    // MARK: - Local Notifications
    
    /// 发送阶段切换通知 (后台时)
    /// - Parameters:
    ///   - phase: 新阶段
    ///   - blockName: 当前 Block 名称
    func sendPhaseChangeNotification(phase: TimerPhase, blockName: String)
    
    /// 发送 Session 完成通知 (后台时)
    /// - Parameter sessionName: Session 名称
    func sendSessionCompleteNotification(sessionName: String)
}
```

---

### 6. ScreenService

管理屏幕常亮状态。

```swift
/// 屏幕服务协议
protocol ScreenServiceProtocol {
    
    /// 设置屏幕常亮
    /// - Parameter enabled: 是否保持屏幕常亮
    func setScreenAlwaysOn(_ enabled: Bool)
    
    /// 根据计时状态更新屏幕常亮
    /// - Parameter state: 当前计时状态
    func updateScreenState(for state: TimerState)
}
```

---

## ViewModel Contracts

### 1. SessionListViewModel

主界面的 Session 列表。

```swift
/// Session 列表 ViewModel
@Observable
@MainActor
final class SessionListViewModel {
    
    // MARK: - State
    
    /// Session 列表
    private(set) var sessions: [Session] = []
    
    /// 搜索关键词
    var searchText: String = ""
    
    /// 过滤后的 Session 列表
    var filteredSessions: [Session] { get }
    
    // MARK: - Actions
    
    /// 加载 Session 列表
    func loadSessions()
    
    /// 删除 Session
    func delete(_ session: Session)
    
    /// 切换收藏状态
    func toggleFavorite(_ session: Session)
    
    /// 开始 Session (导航到 TimerView)
    func start(_ session: Session)
}
```

---

### 2. SessionEditorViewModel

Session 创建/编辑界面。

```swift
/// Session 编辑器 ViewModel
@Observable
@MainActor
final class SessionEditorViewModel {
    
    // MARK: - State
    
    /// Session 名称
    var name: String = ""
    
    /// Block 列表
    var blocks: [Block] = []
    
    /// 是否为编辑模式
    let isEditing: Bool
    
    /// 验证错误信息
    var validationError: String?
    
    /// 是否可以保存
    var canSave: Bool { get }
    
    // MARK: - Initializers
    
    /// 创建模式
    init()
    
    /// 编辑模式
    init(session: Session)
    
    // MARK: - Actions
    
    /// 添加新 Block
    func addBlock()
    
    /// 删除 Block
    func deleteBlock(at index: Int)
    
    /// 移动 Block
    func moveBlock(from source: IndexSet, to destination: Int)
    
    /// 保存 Session
    func save() throws -> Session
    
    /// 验证输入
    func validate() -> Bool
}
```

---

### 3. TimerViewModel

计时器界面。

```swift
/// 计时器 ViewModel
@Observable
@MainActor
final class TimerViewModel {
    
    // MARK: - State
    
    /// 当前 Session
    private(set) var session: Session
    
    /// 当前 Block
    var currentBlock: Block? { get }
    
    /// 当前组号 (1-based)
    private(set) var currentSet: Int = 1
    
    /// 当前阶段
    private(set) var currentPhase: TimerPhase = .work
    
    /// 剩余秒数
    private(set) var remainingSeconds: Int = 0
    
    /// 是否暂停
    private(set) var isPaused: Bool = false
    
    /// 是否完成
    private(set) var isCompleted: Bool = false
    
    /// 总进度 (0.0 - 1.0)
    var progress: Double { get }
    
    /// 格式化的剩余时间 "MM:SS"
    var formattedTime: String { get }
    
    // MARK: - Computed UI Properties
    
    /// 背景颜色 (Work: 黑色, Rest: 绿色)
    var backgroundColor: Color { get }
    
    /// 状态文本 ("WORK" / "REST" / "PAUSED")
    var statusText: String { get }
    
    // MARK: - Actions
    
    /// 开始计时
    func start()
    
    /// 暂停/继续切换
    func togglePause()
    
    /// 跳过当前阶段
    func skip()
    
    /// 停止并返回
    func stop()
    
    /// 加一组
    func addSet()
    
    /// 延长休息 30 秒
    func extendRest()
}
```

---

## Error Types

```swift
/// 验证错误
enum ValidationError: LocalizedError {
    case emptySessionName
    case noBlocks
    case tooManyBlocks(max: Int)
    case emptyBlockName
    case invalidSetCount
    case invalidDuration
    case zeroDuration
    
    var errorDescription: String? {
        switch self {
        case .emptySessionName:
            return "Session 名称不能为空"
        case .noBlocks:
            return "至少需要添加一个练习项目"
        case .tooManyBlocks(let max):
            return "练习项目不能超过 \(max) 个"
        case .emptyBlockName:
            return "练习项目名称不能为空"
        case .invalidSetCount:
            return "组数必须在 1-99 之间"
        case .invalidDuration:
            return "时间必须在 0-99:59 之间"
        case .zeroDuration:
            return "练习时间和休息时间不能都为 0"
        }
    }
}
```

---

## Event Types

用于服务间通信的事件类型。

```swift
/// 计时器事件
enum TimerEvent {
    case started(Session)
    case paused
    case resumed
    case stopped
    case phaseChanged(TimerPhase, Block, Int)  // phase, block, set
    case setCompleted(Block, Int)              // block, completed set
    case blockCompleted(Block)
    case sessionCompleted(Session)
    case tick(Int)                             // remaining seconds
}
```

---

## Summary

| Service | Responsibility |
|---------|----------------|
| SessionService | Session/Block CRUD, 数据持久化 |
| TimerService | 计时器核心逻辑, 状态管理 |
| HapticService | 触觉反馈 |
| AudioService | 音效播放, 混音 |
| NotificationService | Live Activity, 本地通知 |
| ScreenService | 屏幕常亮控制 |

| ViewModel | View |
|-----------|------|
| SessionListViewModel | 主界面 Session 列表 |
| SessionEditorViewModel | Session 创建/编辑页 |
| TimerViewModel | 计时器运行界面 |
