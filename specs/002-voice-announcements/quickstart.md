# Quickstart: 语音播报

**Feature**: 002-voice-announcements
**Date**: 2026-03-04

## Prerequisites

- Xcode 16.0+
- iOS 17.0+ 设备（模拟器可用但语音质量较低）
- XcodeGen (`brew install xcodegen`)
- xcbeautify (`brew install xcbeautify`)

## Implementation Order

按优先级顺序实现，每个步骤完成后可独立验证：

### Step 1: 数据模型扩展 (P1 基础)

**修改文件**:
- `src/Models/Block.swift` — 添加 3 个 `String?` 属性
- `src/Models/Session.swift` — 添加 1 个 `String?` 属性

```swift
// Block.swift — 在现有属性后添加：
var announcementStart: String?
var announcementRest: String?
var announcementContinue: String?

// Session.swift — 在现有属性后添加：
var announcementComplete: String?
```

**验证**: 编译通过，App 正常启动，现有数据不受影响。

### Step 2: SpeechService 实现 (P1 核心)

**新增文件**:
- `src/Services/SpeechService.swift`

**核心实现要点**:
1. `@MainActor final class SpeechService`
2. 持有 `AVSpeechSynthesizer` 实例
3. `speak(_ text: String)` — 先 `stopSpeaking(.immediate)` 再 `speak(utterance)`
4. 语言检测使用 `NLLanguageRecognizer`
5. `static let shared = SpeechService()`

**验证**: 在 Playground 或简单测试中调用 `SpeechService.shared.speak("测试")` 确认语音输出。

### Step 3: 计时器集成 (P1 完成)

**修改文件**:
- `src/ViewModels/TimerViewModel.swift`

**修改要点**:
1. 添加 `speechService` 和 `isVoiceAnnouncementEnabled` 属性
2. 在 `handlePhaseChange()` 中：
   - 根据 `phase`、`set`、`blockIndex` 解析播报文本
   - 语音启用时调用 `speechService.speak()` 替代音效
   - 语音禁用时保持原有 `audioService` 调用
3. 在 `handleSessionComplete()` 中添加完成播报

**验证**: 启动一个多 Block 的 Session，确认各阶段切换时播报正确文本。

### Step 4: 自定义播报 UI (P2)

**修改文件**:
- `src/Views/Components/BlockEditorRow.swift` — 添加播报文本输入区域
- `src/Views/Session/SessionEditorView.swift` — 添加完成播报文本输入

**UI 设计要点**:
- Block 编辑界面：可展开的"语音播报"区域，含 3 个 TextField
- 每个 TextField 使用 placeholder 显示默认值（如 "默认：深蹲"）
- Session 编辑界面：单独 Section 包含完成播报 TextField
- 文本超过 50 字符时显示提示

**验证**: 编辑 Block 设置自定义播报文本 → 启动计时 → 确认播报自定义内容。

### Step 5: 全局开关 (P3)

**修改/新增文件**:
- 可能需要新增设置入口或在现有界面添加 Toggle

**实现要点**:
1. `@AppStorage("isVoiceAnnouncementEnabled") var isVoiceAnnouncementEnabled: Bool = true`
2. 关闭时恢复 Work/Rest 原有音效
3. 计时过程中切换立即生效

**验证**: 关闭开关 → 启动计时 → 确认无语音播报但有音效；重新开启 → 语音恢复。

## Build & Run

```bash
# 生成项目（添加新文件后）
make generate

# 构建并运行到设备
make run-device

# 或使用模拟器
make run-simulator
```

## Key Files Summary

| File | Action | Priority |
|------|--------|----------|
| `src/Models/Block.swift` | 修改 | P1 |
| `src/Models/Session.swift` | 修改 | P1 |
| `src/Services/SpeechService.swift` | **新增** | P1 |
| `src/ViewModels/TimerViewModel.swift` | 修改 | P1 |
| `src/Views/Components/BlockEditorRow.swift` | 修改 | P2 |
| `src/Views/Session/SessionEditorView.swift` | 修改 | P2 |
| `src/Services/AudioService.swift` | 无需修改 | — |

**Note**: `AudioService` 本身不需要修改。播报/音效的条件切换在 `TimerViewModel` 层面完成，保持 `AudioService` 职责单一。
