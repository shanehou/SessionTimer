# Data Model: Session Timer

**Feature Branch**: `001-session-timer`  
**Date**: 2026-02-01  
**Status**: Complete

## Overview

本文档定义了 Session Timer App 的数据模型，基于 SwiftData 框架实现，支持 iCloud CloudKit 自动同步。

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                           Session                                │
│  ─────────────────────────────────────────────────────────────  │
│  id: UUID (PK)                                                   │
│  name: String                                                    │
│  createdAt: Date                                                 │
│  lastUsedAt: Date?                                               │
│  isFavorite: Bool                                                │
│  sortOrder: Int                                                  │
├─────────────────────────────────────────────────────────────────┤
│  blocks: [Block] (1:N, cascade delete)                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 1:N
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                            Block                                 │
│  ─────────────────────────────────────────────────────────────  │
│  id: UUID (PK)                                                   │
│  name: String                                                    │
│  setCount: Int                                                   │
│  workDuration: Int (seconds)                                     │
│  restDuration: Int (seconds)                                     │
│  orderIndex: Int                                                 │
├─────────────────────────────────────────────────────────────────┤
│  session: Session (N:1, inverse relationship)                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      TimerState (Runtime)                        │
│  ─────────────────────────────────────────────────────────────  │
│  NOT PERSISTED - In-memory only                                  │
│  ─────────────────────────────────────────────────────────────  │
│  sessionId: UUID                                                 │
│  currentBlockIndex: Int                                          │
│  currentSet: Int                                                 │
│  currentPhase: TimerPhase (.work | .rest)                       │
│  remainingSeconds: Int                                           │
│  isPaused: Bool                                                  │
│  startedAt: Date                                                 │
│  pausedAt: Date?                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Entity Definitions

### Session (练习计划)

代表一次完整的练习计划，如"练腿日"或"音阶爬格子"。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | `UUID` | Primary Key, Auto-generated | 唯一标识符 |
| `name` | `String` | Required, Max 100 chars | Session 名称 |
| `createdAt` | `Date` | Required, Auto-set | 创建时间 |
| `lastUsedAt` | `Date?` | Optional | 最近使用时间，用于排序 |
| `isFavorite` | `Bool` | Default: false | 是否收藏，收藏的 Session 显示在列表顶部 |
| `sortOrder` | `Int` | Default: 0 | 手动排序顺序 |
| `blocks` | `[Block]` | Cascade delete | 包含的 Block 列表 |

**Validation Rules**:
- `name` 不能为空
- `blocks` 至少包含 1 个 Block 才能保存
- `blocks` 最多 50 个

**SwiftData Model**:

```swift
import SwiftData
import Foundation

@Model
final class Session {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastUsedAt: Date?
    var isFavorite: Bool
    var sortOrder: Int
    
    @Relationship(deleteRule: .cascade, inverse: \Block.session)
    var blocks: [Block]
    
    init(
        name: String,
        blocks: [Block] = []
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.lastUsedAt = nil
        self.isFavorite = false
        self.sortOrder = 0
        self.blocks = blocks
    }
    
    // Computed: 总时长（秒）
    var totalDuration: Int {
        blocks.reduce(0) { total, block in
            total + block.totalDuration
        }
    }
    
    // Computed: 总组数
    var totalSets: Int {
        blocks.reduce(0) { $0 + $1.setCount }
    }
}
```

---

### Block (动作/项目)

代表 Session 中的一个动作或练习项目，如"深蹲"或"C大调音阶"。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | `UUID` | Primary Key, Auto-generated | 唯一标识符 |
| `name` | `String` | Required, Max 100 chars | Block 名称 |
| `setCount` | `Int` | Required, 1-99 | 组数 |
| `workDuration` | `Int` | Required, 0-5999 (seconds) | 每组练习时长 |
| `restDuration` | `Int` | Required, 0-5999 (seconds) | 组间休息时长 |
| `orderIndex` | `Int` | Required | 在 Session 中的顺序 |
| `session` | `Session` | Required, Inverse | 所属 Session |

**Validation Rules**:
- `name` 不能为空
- `setCount` 范围：1-99
- `workDuration` 范围：0-5999 秒（0秒~99分59秒）
- `restDuration` 范围：0-5999 秒（0秒~99分59秒）
- `workDuration` 和 `restDuration` 至少一个 > 0

**SwiftData Model**:

```swift
import SwiftData
import Foundation

@Model
final class Block {
    var id: UUID
    var name: String
    var setCount: Int
    var workDuration: Int  // seconds
    var restDuration: Int  // seconds
    var orderIndex: Int
    
    var session: Session?
    
    init(
        name: String,
        setCount: Int = 3,
        workDuration: Int = 30,
        restDuration: Int = 10,
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.setCount = setCount
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.orderIndex = orderIndex
    }
    
    // Computed: 单个 Block 总时长
    var totalDuration: Int {
        setCount * (workDuration + restDuration)
    }
    
    // Computed: 单组时长
    var setDuration: Int {
        workDuration + restDuration
    }
}
```

---

### TimerPhase (枚举)

计时器的当前阶段。

```swift
enum TimerPhase: String, Codable, Sendable {
    case work    // 练习阶段
    case rest    // 休息阶段
}
```

---

### TimerState (运行时状态)

计时器的运行时状态，**不持久化**，仅在内存中。

```swift
import Foundation

struct TimerState: Sendable {
    let sessionId: UUID
    var currentBlockIndex: Int
    var currentSet: Int           // 当前第几组 (1-based)
    var currentPhase: TimerPhase
    var remainingSeconds: Int
    var isPaused: Bool
    var startedAt: Date
    var pausedAt: Date?
    
    // Computed: 总进度百分比
    func progress(in session: Session) -> Double {
        let totalSeconds = session.totalDuration
        let elapsedSeconds = calculateElapsedSeconds(in: session)
        return Double(elapsedSeconds) / Double(totalSeconds)
    }
    
    // 计算已用时间
    private func calculateElapsedSeconds(in session: Session) -> Int {
        var elapsed = 0
        
        // 已完成的 Block
        for i in 0..<currentBlockIndex {
            elapsed += session.blocks[i].totalDuration
        }
        
        // 当前 Block 已完成的组
        let currentBlock = session.blocks[currentBlockIndex]
        elapsed += (currentSet - 1) * currentBlock.setDuration
        
        // 当前阶段已用时间
        let phaseDuration = currentPhase == .work 
            ? currentBlock.workDuration 
            : currentBlock.restDuration
        elapsed += phaseDuration - remainingSeconds
        
        return elapsed
    }
}
```

---

### ActivityAttributes (Live Activity)

用于 Live Activities 和 Dynamic Island 的数据结构。

```swift
import ActivityKit

struct SessionTimerAttributes: ActivityAttributes {
    // 静态属性（Activity 生命周期内不变）
    let sessionName: String
    let totalBlocks: Int
    
    // 动态状态（可更新）
    struct ContentState: Codable, Hashable {
        let currentBlockName: String
        let currentBlockIndex: Int  // 0-based
        let currentSet: Int         // 1-based
        let totalSets: Int
        let remainingSeconds: Int
        let phase: String           // "work" or "rest"
        let isPaused: Bool
    }
}
```

---

## State Transitions

### Session Lifecycle

```
[Created] ──▶ [Saved] ──▶ [Running] ──▶ [Completed]
                │              │
                │              ▼
                │         [Paused] ──▶ [Resumed] ──▶ [Completed]
                │              │
                ▼              ▼
           [Edited]       [Stopped]
                │
                ▼
           [Deleted]
```

### Timer State Transitions

```
                    ┌────────────────────────────────────────────────────┐
                    │                                                    │
                    ▼                                                    │
[Idle] ──▶ [Work] ──▶ [Rest] ──▶ [Work] ──▶ ... ──▶ [Completed]        │
             │          │          │                                     │
             │          │          │                                     │
             ▼          ▼          ▼                                     │
         [Paused] ◀────────────────────────────────────────────────────▶│
             │                                                           │
             │                                                           │
             ▼                                                           │
         [Stopped] ─────────────────────────────────────────────────────┘

Events:
- START: Idle → Work (first block, first set)
- TICK: remainingSeconds -= 1
- PHASE_END (Work): Work → Rest (same set)
- PHASE_END (Rest): Rest → Work (next set or next block)
- SET_COMPLETE: Rest → Work (current set + 1)
- BLOCK_COMPLETE: Rest → Work (next block, set = 1)
- SESSION_COMPLETE: Rest → Completed (last set of last block)
- PAUSE: Work/Rest → Paused
- RESUME: Paused → Work/Rest
- SKIP: Jump to next phase/set/block
- STOP: Any → Stopped → Idle
```

---

## Queries

### Common Queries

```swift
// 1. 获取所有 Session，按最近使用排序
@Query(sort: [
    SortDescriptor(\Session.isFavorite, order: .reverse),
    SortDescriptor(\Session.lastUsedAt, order: .reverse),
    SortDescriptor(\Session.createdAt, order: .reverse)
])
var sessions: [Session]

// 2. 获取收藏的 Session
@Query(filter: #Predicate<Session> { $0.isFavorite })
var favoriteSessions: [Session]

// 3. 根据名称搜索 Session
static func search(name: String) -> Predicate<Session> {
    #Predicate<Session> { session in
        session.name.localizedStandardContains(name)
    }
}
```

---

## CloudKit Considerations

### Sync Compatibility

SwiftData + CloudKit 要求：

1. **No Unique Constraints**: CloudKit 不支持 unique 约束，使用 UUID 作为主键
2. **Optional Relationships**: 所有关系必须是可选的或有 inverse
3. **No Default Values in CloudKit**: 默认值在 Swift 代码中处理
4. **Codable Types**: 所有自定义类型必须是 Codable

### Conflict Resolution

CloudKit 使用 "last write wins" 策略。对于 Session Timer：
- Session 和 Block 的修改冲突极少（单用户应用）
- 如有冲突，CloudKit 自动合并或使用最新版本

---

## Migration Strategy

### Version 1.0 (Initial)

无迁移需求，这是初始版本。

### Future Migrations

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Session.self, Block.self]
    }
}

// 未来版本迁移示例
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SessionV2.self, BlockV2.self]
    }
}

enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
```

---

## Summary

| Entity | Purpose | Persisted | CloudKit Sync |
|--------|---------|-----------|---------------|
| Session | 练习计划容器 | ✅ | ✅ |
| Block | 动作/练习项目 | ✅ | ✅ |
| TimerState | 运行时计时状态 | ❌ | ❌ |
| TimerPhase | 阶段枚举 | N/A | N/A |
| SessionTimerAttributes | Live Activity 数据 | ❌ | ❌ |
