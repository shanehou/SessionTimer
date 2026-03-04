# Data Model: 语音播报

**Feature**: 002-voice-announcements
**Date**: 2026-03-04

## Entity Changes

### Block (扩展现有模型)

**File**: `src/Models/Block.swift`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `announcementStart` | `String?` | `nil` | Block 首组 Work 开始时的播报文本。`nil` 或空字符串时回退到 `name` |
| `announcementRest` | `String?` | `nil` | Rest 阶段开始时的播报文本。`nil` 或空字符串时回退到 `"休息"` |
| `announcementContinue` | `String?` | `nil` | 非首组 Work 开始时的播报文本。`nil` 或空字符串时回退到 `"继续"` |

**Existing Fields** (unchanged):

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | 唯一标识 |
| `name` | `String` | Block 名称（如"深蹲"） |
| `setCount` | `Int` | 组数 (1-99) |
| `workDuration` | `Int` | Work 时长（秒） |
| `restDuration` | `Int` | Rest 时长（秒） |
| `orderIndex` | `Int` | 排序索引 |
| `session` | `Session?` | 所属 Session |

**Validation Rules**:
- `announcementStart/Rest/Continue` 为 `nil` 或空字符串时使用默认值
- 播报文本无最大长度硬限制，但 UI 提示建议不超过 50 字符（Edge Case 规定）
- 文本允许任意语言字符（中文、英文、日文等）

### Session (扩展现有模型)

**File**: `src/Models/Session.swift`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `announcementComplete` | `String?` | `nil` | Session 完成时的播报文本。`nil` 或空字符串时回退到 `"训练完成"` |

**Existing Fields** (unchanged):

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | 唯一标识 |
| `name` | `String` | Session 名称 |
| `createdAt` | `Date` | 创建时间 |
| `lastUsedAt` | `Date?` | 最后使用时间 |
| `isFavorite` | `Bool` | 是否收藏 |
| `blocks` | `[Block]` | 关联的 Block 列表 |

**Validation Rules**:
- `announcementComplete` 为 `nil` 或空字符串时使用默认值 `"训练完成"`

### Global Settings (新增)

**Storage**: `UserDefaults` via `@AppStorage`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `isVoiceAnnouncementEnabled` | `Bool` | `true` | 语音播报全局开关。关闭时恢复 Work/Rest 原有音效 |

## Relationships

```
Session 1 ──── * Block
   │                │
   │                ├── announcementStart?
   │                ├── announcementRest?
   │                └── announcementContinue?
   │
   └── announcementComplete?

UserDefaults
   └── isVoiceAnnouncementEnabled (Bool)
```

## State Transitions (播报触发时机)

```
                    ┌─────────────────────────────────────┐
                    │           Session Start              │
                    └──────────────┬──────────────────────┘
                                   │
                                   ▼
               ┌─── Block[0] 首组 Work ◄── 播报: announcementStart ?? block.name
               │          │
               │          ▼
               │       Rest ◄──────────── 播报: announcementRest ?? "休息"
               │          │
               │          ▼
               │    后续组 Work ◄──────── 播报: announcementContinue ?? "继续"
               │          │
               │          ▼
               │       Rest ◄──────────── 播报: announcementRest ?? "休息"
               │          │
               │          ▼
               │     (重复至 setCount)
               │          │
               └──► Block[1] 首组 Work ◄── 播报: announcementStart ?? block.name
                          │
                         ...
                          │
                          ▼
                  Session Complete ◄───── 播报: announcementComplete ?? "训练完成"
```

## Migration Strategy

- **Type**: SwiftData 轻量级自动迁移
- **Approach**: 所有新增字段为 `String?` 类型，SwiftData 自动为现有数据填充 `nil`
- **CloudKit**: Additive-only 变更，与 CloudKit schema 演化兼容
- **Code Required**: 无额外迁移代码
- **Rollback Safety**: 旧版 App 忽略新字段，不影响数据完整性
