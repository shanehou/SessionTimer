# Research: 快速开始与预备倒计时

**Feature**: 003-quick-start  
**Date**: 2026-03-07  
**Status**: Complete

## Research Tasks

## 1. SwiftData 非持久化 Session 对象策略

**背景**: 快速开始模式需要创建临时的 Session/Block 对象来驱动计时器，但在用户明确选择保存前不应持久化到数据库。需要确定如何在 SwiftData 中处理"先用后存"的场景。

### Decision

使用 SwiftData @Model 对象的"延迟插入"模式：创建 Session 和 Block 对象但不插入 ModelContext，计时完成后根据用户选择决定是否插入。

### Rationale

SwiftData 的 @Model 对象可以在不关联 ModelContext 的情况下独立存在于内存中。`@Relationship` 关系在内存中正常工作，只有调用 `modelContext.insert()` 时才会触发持久化和 CloudKit 同步。这种方式：
- 零重构：TimerService 接收 Session 对象，无需区分来源
- 无数据污染：未保存的配置不会出现在数据库或 CloudKit 中
- 保存简单：`modelContext.insert(session)` 一行代码完成持久化，级联插入所有 Block

### Implementation Strategy

```swift
// 创建临时 Session（不插入 ModelContext）
let session = Session(name: "快速训练", preparingDuration: 5)
let block = Block(name: "俯卧撑", setCount: 3, workDuration: 30, restDuration: 15, orderIndex: 0)
block.session = session
session.blocks = [block]

// 传递给 TimerService，正常计时
timerService.start(session: session)

// 用户选择保存时
modelContext.insert(session)  // Block 随 cascade 关系自动插入
try modelContext.save()

// 用户选择不保存时
// 无需任何操作，对象自然释放
```

### Alternatives Considered

| 方案 | 优点 | 缺点 | 排除原因 |
|------|------|------|----------|
| 独立内存 ModelContainer | 完全隔离 | 对象无法跨容器传递，保存需逐字段复制 | 复杂度高，保存逻辑冗余 |
| 插入后条件删除 (isTransient flag) | 实现简单 | 临时数据同步到 CloudKit，崩溃后残留 | 数据污染风险 |
| Protocol 抽象 (TimerConfigurable) | 架构优雅 | 需重构 TimerService、TimerState、TimerViewModel | 改动范围过大 |

### Risk Assessment

- **风险**: @Model 对象未插入 ModelContext 时的行为在 SwiftData 文档中未明确承诺稳定性
- **缓解**: 仅在临时使用场景（计时过程中）依赖此行为；一旦用户选择保存，立即插入正式 ModelContext

---

## 2. TimerPhase 状态机扩展（Preparing 阶段）

**背景**: 现有 TimerPhase 只有 `.work` 和 `.rest` 两种状态。需要新增 `.preparing` 状态作为计时开始前的预备阶段，且要与现有状态流转逻辑兼容。

### Decision

在 `TimerPhase` 枚举中新增 `.preparing` case，在 `TimerState.nextPhase()` 中处理 preparing → work 的过渡，在 `TimerService.start()` 中根据 `preparingDuration` 决定初始阶段。

### Rationale

- **最小侵入**: 仅在枚举中加一个 case，在 `nextPhase()` 中加一个分支
- **复用现有基础设施**: preparing 阶段的 tick、暂停/继续、跳过机制与 work/rest 完全一致
- **单次执行**: preparing 仅在 session 最开始执行一次，不在 block 之间重复

### Implementation Strategy

```swift
// TimerPhase.swift
enum TimerPhase: String, Codable {
    case preparing
    case work
    case rest
}

// TimerService.start()
func start(session: Session) {
    let initialPhase: TimerPhase
    let initialSeconds: Int
    
    if session.preparingDuration > 0 {
        initialPhase = .preparing
        initialSeconds = session.preparingDuration
    } else {
        initialPhase = .work
        initialSeconds = session.sortedBlocks.first?.workDuration ?? 0
    }
    
    currentState = TimerState(
        sessionId: session.id,
        currentBlockIndex: 0,
        currentSet: 1,
        currentPhase: initialPhase,
        remainingSeconds: initialSeconds,
        isPaused: false
    )
}

// TimerState.nextPhase()
// preparing → 0 时：切换到 (blockIndex: 0, set: 1, phase: .work)
// 后续流转逻辑不变
```

### Key Design Points

1. **preparing 仅在 Session 开始时触发一次**，不在 Block 切换时重复
2. **preparing 过渡到 work 时**保持 `currentBlockIndex = 0, currentSet = 1` 不变
3. **preparing 的 tick 机制**与 work/rest 完全一致（每秒 -1，到 0 触发 nextPhase）
4. **preparing 期间的手势**完全继承现有行为（单击暂停、双击跳过、长按结束）

### Alternatives Considered

- **独立的 PreparingTimer**: 在 TimerService 之外用单独定时器处理预备倒计时 → 排除：增加复杂度，手势/暂停/反馈需要重复实现
- **在 TimerView 层处理**: 计时界面先显示倒计时再启动 TimerService → 排除：预备阶段无法享受后台计时、Live Activities 等基础设施

---

## 3. 快速开始页面 UI 设计模式

**背景**: 快速开始页面需要在最短操作路径内完成项目配置。需要平衡配置灵活性与操作简洁性。

### Decision

采用独立的 `QuickStartView` 页面，以 Sheet 形式从主页呈现。页面结构为垂直滚动列表，每个 Block 作为一个可展开的配置卡片，底部固定"开始"按钮。

### Rationale

- **Sheet 呈现**：符合 iOS 模态操作模式，用户完成配置后 dismiss sheet 并进入计时
- **卡片式 Block 编辑**：比 SessionEditorView 更紧凑，将名称、组数、时长集中在一个卡片内
- **底部固定按钮**：用户配置完成后无需滚动即可点击开始
- **预备时间配置**：放在 Block 列表上方，作为 Session 级别设置

### UI Structure

```
┌─────────────────────────────┐
│  快速开始                  ✕  │  ← 导航栏 + 关闭按钮
├─────────────────────────────┤
│  预备时间    [0s ▾]          │  ← Stepper 或 Picker (0-30s)
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │ 项目 1: 俯卧撑         │  │  ← Block 配置卡片
│  │ 组数: [3]  工作: [30s]  │  │
│  │ 休息: [15s]      [删除] │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │ 项目 2: 深蹲           │  │
│  │ 组数: [3]  工作: [30s]  │  │
│  │ 休息: [15s]      [删除] │  │
│  └───────────────────────┘  │
│                             │
│  [＋ 添加项目]               │
│                             │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │      开始训练           │  │  ← 固定底部按钮
│  └───────────────────────┘  │
└─────────────────────────────┘
```

### Default Values (from spec)

- 项目名称: "项目 1", "项目 2", ...（自动递增）
- 组数: 3
- 练习时长: 30 秒
- 休息时长: 15 秒
- 预备时间: 0 秒

### Navigation Flow

```
SessionListView → [快速开始 button] → QuickStartView (Sheet)
                                       ↓ [开始训练]
                                    Dismiss Sheet
                                       ↓
                                    TimerView (Push via NavigationStack)
                                       ↓ [训练结束]
                                    SaveSessionSheet (Alert/Sheet)
                                       ↓
                                    SessionListView
```

---

## 4. 内存配置缓存策略

**背景**: FR-015 要求快速开始页面再次打开时自动填入上次配置，但 App 重启后恢复默认值。需要一个纯内存的缓存方案。

### Decision

使用 `@Observable` 单例类 `QuickStartCache`，存储上次使用的 Block 配置列表和预备时间。

### Rationale

- **@Observable**: 与 SwiftUI 自然集成，缓存变更自动驱动 UI 更新
- **单例**: 全局唯一，生命周期跟随 App 进程
- **纯内存**: 不使用 UserDefaults 或文件存储，App 重启自动丢失

### Implementation Strategy

```swift
@Observable
final class QuickStartCache {
    static let shared = QuickStartCache()
    
    struct BlockConfig {
        var name: String
        var setCount: Int
        var workDuration: Int
        var restDuration: Int
    }
    
    var blocks: [BlockConfig] = []
    var preparingDuration: Int = 0
    var hasCache: Bool { !blocks.isEmpty }
    
    func save(blocks: [BlockConfig], preparingDuration: Int) {
        self.blocks = blocks
        self.preparingDuration = preparingDuration
    }
    
    func load() -> ([BlockConfig], Int) {
        if hasCache {
            return (blocks, preparingDuration)
        }
        return ([BlockConfig.default], 0)
    }
    
    private init() {}
}
```

### Alternatives Considered

- **UserDefaults**: 会在 App 重启后保留，不符合 spec 要求（仅内存）
- **Environment Object**: 需要在 View 层级注入，不够灵活；且生命周期绑定到 View
- **ViewModel 内部状态**: 会随 ViewModel 销毁而丢失，无法跨页面打开保留

---

## 5. 预备阶段视觉与感官反馈设计

**背景**: 预备倒计时需要与 Work（黑底）和 Rest（绿底）形成视觉区分，使用蓝底白字。同时需要设计配套的音频和触觉反馈。

### Decision

- **视觉**: 蓝底白字（`Color.blue` / `#007AFF`），状态标签显示"准备"，倒计时数字使用与 Work/Rest 相同的 128pt 单色字体
- **音频**: 预备开始时播放一个短促的"准备"提示音；最后 3 秒播放倒数提示音（与 Work/Rest 过渡的倒数音一致）
- **触觉**: 最后 3 秒 Warning haptic；预备结束过渡到 Work 时 Heavy Impact
- **屏幕**: 预备阶段保持屏幕常亮（与 Work 阶段一致）

### Rationale

三色区分方案形成清晰的视觉语义：
- 🔵 蓝色 = 准备（即将开始，做好姿势）
- ⚫ 黑色 = 工作（正在练习）
- 🟢 绿色 = 休息（组间休息）

用户通过余光即可感知当前所处阶段（符合 Art. 10 远距离可读性）。

### Implementation Details

```swift
// Color+Theme.swift 扩展
extension TimerPhase {
    var backgroundColor: Color {
        switch self {
        case .preparing: return Color.blue     // #007AFF
        case .work:      return Color.black
        case .rest:      return Color.green
        }
    }
    
    var statusLabel: String {
        switch self {
        case .preparing: return "准备"
        case .work:      return "WORK"
        case .rest:      return "REST"
        }
    }
}
```

### Live Activity / Dynamic Island

- 预备阶段的 Live Activity 显示 "准备" 状态和倒计时
- Dynamic Island 使用蓝色主题色
- 预备阶段不显示组进度信息（尚未开始正式计时）

---

## 6. 训练结束保存对话框 UX

**背景**: 快速开始训练结束后需要弹窗询问用户是否保存。需要确定对话框形式和交互细节。

### Decision

使用 SwiftUI `.alert` 配合 TextField 实现保存对话框。两步式：先询问是否保存（Alert），选择保存后展示名称输入（第二个 Alert 或 Sheet）。

### Rationale

考虑到训练刚结束时用户可能仍处于"手忙"状态，使用简单的 Alert 比复杂的 Sheet 更适合：
- 第一步 Alert: "是否将本次训练保存为计划？" → [保存] [不保存]
- 第二步 Alert: 输入 Session 名称，预填默认值 → [确认] [取消]

### Implementation Strategy

```swift
// 默认名称生成
func defaultSessionName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return "快速训练 \(formatter.string(from: Date()))"
}

// 保存流程
func saveQuickStartSession(session: Session, name: String, modelContext: ModelContext) {
    session.name = name
    session.createdAt = Date()
    modelContext.insert(session)
    try? modelContext.save()
}
```

### Edge Cases

- 用户在名称输入中留空：使用默认名称
- 用户取消第二步（名称输入）：回到第一步或直接不保存
- 保存后的 Session 立即出现在 SessionListView 中

### Alternatives Considered

- **全功能 Sheet**: 可以展示更多信息（训练摘要、统计等）→ 排除：训练刚结束时过于复杂
- **自动保存 + 撤销**: 自动保存所有快速开始，提供删除选项 → 排除：不符合 FR-008 "丢弃" 语义
- **Toast 提示**: 底部弹出轻量提示 → 排除：包含 TextField 输入不适合 Toast 形式
