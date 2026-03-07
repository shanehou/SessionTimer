# Data Model: 快速开始与预备倒计时

**Feature**: 003-quick-start  
**Date**: 2026-03-07  
**Status**: Complete

## Overview

本功能涉及三类数据模型变更：
1. **Session 模型扩展** — 新增 `preparingDuration` 字段
2. **TimerPhase 枚举扩展** — 新增 `.preparing` case
3. **新增 QuickStartCache** — 纯内存缓存，不持久化

## Entity Changes

### 1. Session (SwiftData @Model) — 修改

#### New Fields

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| `preparingDuration` | `Int` | `0` | 0-30 | 预备倒计时时长（秒）。0 = 不启用预备倒计时 |

#### Existing Fields (unchanged)

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | 唯一标识 |
| `name` | `String` | Session 名称 |
| `createdAt` | `Date` | 创建时间 |
| `lastUsedAt` | `Date?` | 最后使用时间 |
| `isFavorite` | `Bool` | 是否收藏 |
| `announcementComplete` | `String?` | 完成播报文本 |
| `blocks` | `[Block]` | 关联的 Block 列表 |

#### Validation Rules

- `preparingDuration` 必须在 `0...30` 范围内
- `preparingDuration == 0` 表示跳过预备阶段（兼容现有行为）

### 2. Block (SwiftData @Model) — 无变更

Block 模型不需要任何修改。快速开始使用与手动创建完全相同的 Block 结构。

### 3. TimerPhase (Enum) — 修改

#### Updated Definition

| Case | Raw Value | Background Color | Status Label | Description |
|------|-----------|-----------------|--------------|-------------|
| `.preparing` | `"preparing"` | Blue (#007AFF) | "准备" | **[NEW]** 预备倒计时阶段 |
| `.work` | `"work"` | Black | "WORK" | 练习阶段 |
| `.rest` | `"rest"` | Rest | "REST" | 休息阶段 |

### 4. TimerState (Struct) — 修改

#### Updated Phase Transition Logic

```
start(session)
    │
    ├─ preparingDuration > 0 ──→ TimerState(phase: .preparing, remaining: preparingDuration)
    │                                │
    │                                ↓ (remaining → 0)
    │                           TimerState(phase: .work, remaining: firstBlock.workDuration)
    │
    └─ preparingDuration == 0 ──→ TimerState(phase: .work, remaining: firstBlock.workDuration)
                                     │
                                     ↓ (existing flow)
                                 .work → .rest → .work → ... → completed
```

TimerState struct 本身的字段不需要修改。Preparing 阶段使用 `currentBlockIndex = 0, currentSet = 1` 作为占位值，过渡到 work 后保持不变。

### 5. QuickStartCache (@Observable) — 新增

纯内存对象，不使用 SwiftData 持久化。

#### QuickStartCache

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `blocks` | `[BlockConfig]` | `[]` | 上次使用的 Block 配置列表 |
| `preparingDuration` | `Int` | `0` | 上次使用的预备时间 |

#### BlockConfig (内嵌 Struct)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `String` | `"项目 N"` | 项目名称 |
| `setCount` | `Int` | `3` | 组数 |
| `workDuration` | `Int` | `30` | 练习时长（秒） |
| `restDuration` | `Int` | `15` | 休息时长（秒） |

#### Lifecycle

- **创建**: App 启动时作为单例初始化，内容为空
- **写入**: 用户在快速开始页面点击"开始训练"时保存当前配置
- **读取**: 用户打开快速开始页面时加载缓存（无缓存则使用默认值）
- **销毁**: App 进程终止时自然释放

## Entity Relationships

```
┌─────────────────────────┐
│       Session           │
│  (SwiftData @Model)     │
│─────────────────────────│
│  id: UUID               │
│  name: String           │
│  preparingDuration: Int  │ ← NEW
│  ...                    │
│                         │
│  blocks: [Block] ──────────┐
└─────────────────────────┘  │
                             │ 1:N (cascade delete)
┌─────────────────────────┐  │
│        Block            │◄─┘
│  (SwiftData @Model)     │
│─────────────────────────│
│  id: UUID               │
│  name: String           │
│  setCount: Int          │
│  workDuration: Int      │
│  restDuration: Int      │
│  orderIndex: Int        │
│  ...                    │
└─────────────────────────┘

┌─────────────────────────┐       ┌─────────────────────────┐
│    QuickStartCache      │       │      BlockConfig         │
│  (@Observable singleton)│       │    (value type struct)   │
│─────────────────────────│       │─────────────────────────│
│  blocks: [BlockConfig] ─────►  │  name: String           │
│  preparingDuration: Int │       │  setCount: Int          │
└─────────────────────────┘       │  workDuration: Int      │
     ▲                            │  restDuration: Int      │
     │ 内存缓存                    └─────────────────────────┘
     │ (App 重启后丢失)
     │
   [QuickStartView 读写]
```

## State Transitions

### 完整计时阶段流转

```
[用户点击开始]
      │
      ▼
  ┌────────────┐    preparingDuration > 0
  │  Preparing  │◄─── 蓝底白字，显示"准备"
  │  (Blue)     │     倒数 N → 0
  └──────┬─────┘
         │ remaining → 0
         ▼
  ┌────────────┐
  │    Work     │◄─── 黑底白字，显示"WORK"
  │  (Black)    │     倒数 workDuration → 0
  └──────┬─────┘
         │ remaining → 0
         ▼
  ┌────────────┐
  │    Rest     │◄─── 绿底白字，显示"REST"
  │  (Green)    │     倒数 restDuration → 0
  └──────┬─────┘
         │ remaining → 0
         ▼
    ┌──────────┐
    │ 还有组？  │──Yes──→ Work (同 Block 下一组)
    └────┬─────┘
         │ No
    ┌──────────┐
    │ 还有项目？│──Yes──→ Work (下一 Block 第 1 组)
    └────┬─────┘
         │ No
         ▼
  ┌────────────┐
  │  Completed  │
  └────────────┘
```

### 快速开始生命周期

```
[主页] ──点击快速开始──→ [QuickStartView]
                              │
                         配置项目/预备时间
                              │
                         点击开始训练
                              │
                     ┌── 创建临时 Session ──┐
                     │   (不插入 ModelContext) │
                     └────────┬──────────────┘
                              │
                         [TimerView 计时]
                              │
                         训练结束/手动结束
                              │
                     ┌── 保存弹窗 ──┐
                     │              │
                  [保存]         [不保存]
                     │              │
              insert into       丢弃对象
              ModelContext       返回主页
                     │
                返回主页
           (Session 出现在列表中)
```

## Migration Strategy

### SwiftData Migration

- Session 新增 `preparingDuration` 字段使用默认值 `0`，属于轻量级迁移（Lightweight Migration）
- SwiftData 自动处理，无需编写 `SchemaMigrationPlan`
- 所有现有 Session 的 `preparingDuration` 默认为 `0`，行为与当前完全一致

### CloudKit Compatibility

- 新增可选字段（带默认值）与 CloudKit 向后兼容
- 旧版本 App 忽略 `preparingDuration` 字段，不影响数据同步

### Rollback

- 回滚时删除 `preparingDuration` 字段，SwiftData 自动丢弃未知字段数据
- 不会造成数据丢失或损坏
