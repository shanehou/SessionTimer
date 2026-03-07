# Contract: Quick Start Service

**Feature**: 003-quick-start  
**Date**: 2026-03-07  
**Status**: Complete

## Overview

定义快速开始功能涉及的新增和修改接口。包括：
1. **QuickStartViewModel** — 快速开始页面的状态管理与业务逻辑
2. **QuickStartCache** — 内存配置缓存
3. **TimerService 扩展** — preparing 阶段支持
4. **TimerViewModel 扩展** — preparing 阶段 UI 状态与保存弹窗

---

## 1. QuickStartViewModel

### Interface

```swift
@Observable
final class QuickStartViewModel {
    // MARK: - State
    var blocks: [EditableQuickStartBlock]
    var preparingDuration: Int  // 0-30
    var canStart: Bool { !blocks.isEmpty }
    
    // MARK: - Lifecycle
    init()
    // 从 QuickStartCache 加载缓存配置，无缓存时使用默认值
    
    // MARK: - Block Management
    func addBlock()
    // 添加一个使用默认值的新 Block
    // 默认名称: "项目 N"（N = blocks.count + 1）
    // 默认值: setCount=3, workDuration=30, restDuration=15
    
    func removeBlock(at index: Int)
    // 移除指定位置的 Block
    // 前提: blocks.count > 1（至少保留一个）
    
    func moveBlock(from source: IndexSet, to destination: Int)
    // 重新排列 Block 顺序
    
    // MARK: - Session Creation
    func createSession() -> Session
    // 1. 将当前配置保存到 QuickStartCache
    // 2. 创建临时 Session 对象（不插入 ModelContext）
    // 3. 创建对应的 Block 对象并关联到 Session
    // 4. 返回 Session 供 TimerView 使用
}
```

### EditableQuickStartBlock

```swift
struct EditableQuickStartBlock: Identifiable {
    let id: UUID
    var name: String
    var setCount: Int       // 1-99
    var workDuration: Int   // 0-5999 (seconds)
    var restDuration: Int   // 0-5999 (seconds)
}
```

### Behavior Specification

| Scenario | Input | Behavior |
|----------|-------|----------|
| 首次打开（无缓存） | `QuickStartCache.shared.hasCache == false` | 初始化一个默认 Block："项目 1", 3组, 30s/15s |
| 再次打开（有缓存） | `QuickStartCache.shared.hasCache == true` | 从缓存加载所有 Block 配置和预备时间 |
| 添加 Block | `addBlock()` | 追加新 Block，名称自动递增 |
| 删除 Block（仅剩一个） | `removeBlock()` when `blocks.count == 1` | 操作被忽略或禁用删除按钮 |
| 创建 Session | `createSession()` | 缓存配置 + 返回非持久化 Session |
| 点击开始（无 Block） | `canStart == false` | 开始按钮禁用 |

---

## 2. QuickStartCache

### Interface

```swift
@Observable
final class QuickStartCache {
    static let shared: QuickStartCache
    
    struct BlockConfig: Codable {
        var name: String
        var setCount: Int
        var workDuration: Int
        var restDuration: Int
        
        static var `default`: BlockConfig
        // name: "项目 1", setCount: 3, workDuration: 30, restDuration: 15
    }
    
    private(set) var blocks: [BlockConfig]
    private(set) var preparingDuration: Int
    var hasCache: Bool { !blocks.isEmpty }
    
    func save(blocks: [BlockConfig], preparingDuration: Int)
    func load() -> (blocks: [BlockConfig], preparingDuration: Int)
    // 有缓存返回缓存值，无缓存返回 ([.default], 0)
}
```

### Lifecycle

- **单例**: `QuickStartCache.shared`，App 进程内唯一
- **内存存储**: 不使用任何磁盘持久化
- **写入时机**: `QuickStartViewModel.createSession()` 调用时
- **读取时机**: `QuickStartViewModel.init()` 调用时

---

## 3. TimerService 扩展

### Modified Interface

```swift
class TimerService {
    // MARK: - Existing (unchanged)
    @Published var currentState: TimerState?
    @Published var isCompleted: Bool
    var onPhaseChanged: ((TimerPhase, TimerPhase) -> Void)?
    var onEvent: ((TimerEvent) -> Void)?
    
    // MARK: - Modified
    func start(session: Session)
    // CHANGED: 如果 session.preparingDuration > 0，初始阶段为 .preparing
    //          remainingSeconds = session.preparingDuration
    //          否则行为与现有一致
}
```

### Phase Transition Rules (extended)

| Current Phase | Condition | Next Phase | Next Remaining |
|---------------|-----------|------------|----------------|
| `.preparing` | `remaining → 0` | `.work` | `firstBlock.workDuration` |
| `.preparing` | 用户双击跳过 | `.work` | `firstBlock.workDuration` |
| `.work` | `remaining → 0` | `.rest` | `currentBlock.restDuration` |
| `.rest` | `remaining → 0, hasNextSet` | `.work` | `currentBlock.workDuration` |
| `.rest` | `remaining → 0, hasNextBlock` | `.work` | `nextBlock.workDuration` |
| `.rest` | `remaining → 0, isLast` | completed | — |

### Event Emissions (extended)

| Event | When |
|-------|------|
| `phaseChanged(.preparing, .work)` | 预备倒计时结束，进入第一个 Work |
| `countdownTick(3)` / `countdownTick(2)` / `countdownTick(1)` | preparing 最后 3 秒（复用现有倒数事件） |

---

## 4. TimerViewModel 扩展

### Modified Interface

```swift
@Observable
class TimerViewModel {
    // MARK: - Existing (unchanged)
    var currentPhase: TimerPhase
    var remainingSeconds: Int
    var blockName: String
    var setProgress: String
    // ...
    
    // MARK: - New Properties
    var isQuickStartMode: Bool
    // 标识当前计时是否来自快速开始模式
    
    var showSaveDialog: Bool
    // 控制保存弹窗的显示
    
    var saveSessionName: String
    // 保存弹窗中的 Session 名称，默认值: "快速训练 yyyy-MM-dd HH:mm"
    
    // MARK: - New Methods
    func saveQuickStartSession(modelContext: ModelContext)
    // 将临时 Session 插入 ModelContext 并持久化
    // 更新 session.name 为 saveSessionName
    
    func discardQuickStartSession()
    // 丢弃临时 Session，不做任何持久化
}
```

### Save Dialog Behavior

| Trigger | Condition | Action |
|---------|-----------|--------|
| Session 自然完成 | `isQuickStartMode == true` | `showSaveDialog = true` |
| 用户手动结束（长按） | `isQuickStartMode == true` | `showSaveDialog = true` |
| 用户点击"保存" | — | `saveQuickStartSession(modelContext:)` |
| 用户点击"不保存" | — | `discardQuickStartSession()` |
| Session 自然完成 | `isQuickStartMode == false` | 现有行为不变 |

---

## 5. SessionEditorViewModel 扩展

### Modified Interface

```swift
@Observable
class SessionEditorViewModel {
    // MARK: - Existing (unchanged)
    var sessionName: String
    var blocks: [EditableBlock]
    // ...
    
    // MARK: - New Properties
    var preparingDuration: Int  // 0-30, default 0
    // 预备倒计时时长配置，显示在 Session 编辑页面中
}
```

---

## Integration Contract

### QuickStartView → TimerView 数据流

```
QuickStartView
    │
    ├── QuickStartViewModel.createSession()
    │   ├── 保存配置到 QuickStartCache
    │   └── 返回 Session（非持久化）
    │
    ├── Dismiss QuickStartView (Sheet)
    │
    └── NavigationStack.append(session)
        │
        └── TimerView(session: session, isQuickStartMode: true)
            │
            └── TimerViewModel(session: session, isQuickStartMode: true)
                │
                ├── TimerService.start(session: session)
                │   └── 根据 preparingDuration 决定初始阶段
                │
                └── 训练结束时
                    ├── isQuickStartMode → showSaveDialog
                    └── 用户选择 → save / discard
```

### Preparing Phase → 各服务集成

```
TimerService (preparing → 0 → work)
    │
    ├── onPhaseChanged(.preparing, .work)
    │   ├── AudioService: 播放"开始"提示音
    │   ├── HapticService: Heavy Impact
    │   └── TimerViewModel: 更新 UI 到 Work 状态
    │
    ├── onEvent(.countdownTick(3/2/1))  [preparing 最后 3 秒]
    │   ├── AudioService: 播放倒数提示音
    │   └── HapticService: Warning haptic
    │
    └── ScreenService: preparing 阶段保持屏幕常亮
```

---

## Error Handling

| Error Scenario | Handling |
|----------------|----------|
| 创建 Session 时 Block 列表为空 | `canStart == false` 阻止进入计时 |
| 保存时 ModelContext 写入失败 | 捕获异常，提示用户重试 |
| preparingDuration 超出范围 | UI 层 Stepper/Picker 限制范围 0-30 |
| 快速开始中 App 崩溃 | 临时 Session 未持久化，无数据残留 |

---

## Testing Notes

- **QuickStartCache**: 验证 `save → load` 循环一致性；验证 App 级别无持久化（无法通过单元测试模拟重启，需集成测试）
- **TimerService preparing**: 验证 `preparingDuration > 0` 时初始阶段为 `.preparing`；验证 `preparingDuration == 0` 时行为不变
- **Save dialog**: 验证快速开始模式结束时弹出保存对话框；验证非快速开始模式不弹出
- **Session conversion**: 验证保存后的 Session 在数据库中完整存在，与手动创建无差异
