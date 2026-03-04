# Research: 语音播报

**Feature**: 002-voice-announcements
**Date**: 2026-03-04
**Status**: Complete

## Research Task 1: AVSpeechSynthesizer 行为与最佳实践

### Decision
使用 `AVSpeechSynthesizer` 作为语音合成引擎。

### Rationale
- iOS 内置 TTS，无需网络连接，满足离线可用需求
- iOS 17+ 提供高质量 Personal Voice 和增强 Siri 语音，发音自然清晰
- API 简单：创建 `AVSpeechUtterance`，设置 `voice`，调用 `speak()`
- 支持中断：调用 `stopSpeaking(at: .immediate)` 可立即停止当前播报
- 与 `AVAudioSession` 共享会话，复用现有 `.playback` + `.duckOthers` 配置

### Key API Details

```swift
let synthesizer = AVSpeechSynthesizer()
let utterance = AVSpeechUtterance(string: "深蹲")
utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
utterance.rate = AVSpeechUtteranceDefaultSpeechRate
utterance.pitchMultiplier = 1.0
utterance.volume = 1.0
synthesizer.speak(utterance)
```

### Concurrency Considerations (Swift 6 Strict)
- `AVSpeechSynthesizer` 不是 `Sendable`，需要限制在 `@MainActor` 或用 actor 隔离
- 项目使用 `SWIFT_STRICT_CONCURRENCY: complete`，需要确保所有 TTS 调用在同一 actor 上
- 推荐：`SpeechService` 标记为 `@MainActor`，与现有 `AudioService` 保持一致

### Background Support
- `AVSpeechSynthesizer` 在 `.playback` audio session 下支持后台播报
- 项目已配置 `UIBackgroundModes: audio`，无需额外配置
- 后台时 `AudioService` 的静音播放器已在运行，audio session 处于活跃状态

### Alternatives Considered
- **预录制音频文件**：发音自然但无法支持用户自定义文本，排除
- **第三方 TTS SDK (如 Azure Speech)**：语音质量更高但需要网络，违反离线需求，排除
- **AVAudioEngine + 自定义语音**：过度复杂，排除

---

## Research Task 2: 语言检测与语音匹配

### Decision
使用 `NLLanguageRecognizer` 检测文本主要语言，映射到 `AVSpeechSynthesisVoice`。

### Rationale
- `NLLanguageRecognizer` 是 Apple 内置的自然语言框架，轻量高效
- 可处理中英混合文本，返回"主要语言"（满足 FR-009 "混合语言以主要语言为准"）
- 短文本（如 "休息"、"Squat"）也能准确识别

### Implementation Strategy

```swift
import NaturalLanguage

func detectLanguage(for text: String) -> String {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let language = recognizer.dominantLanguage else {
        return "zh-CN" // 默认中文
    }
    switch language {
    case .simplifiedChinese, .traditionalChinese:
        return "zh-CN"
    case .english:
        return "en-US"
    case .japanese:
        return "ja-JP"
    default:
        return language.rawValue
    }
}
```

### Voice Selection Strategy
- 优先使用 `AVSpeechSynthesisVoice(language:)` 获取系统默认语音
- iOS 17+ 默认语音质量已较高（Enhanced / Premium 质量）
- 无需手动指定特定语音标识符，系统会选择最佳可用语音

### Alternatives Considered
- **手动正则检测**：只能检测 ASCII vs CJK，无法处理多语言混合，排除
- **CFStringTokenizer**：可用但 API 较老旧，`NLLanguageRecognizer` 更现代，排除

---

## Research Task 3: SwiftData 模型迁移策略

### Decision
使用 SwiftData 的轻量级自动迁移（添加可选属性）。

### Rationale
- 新增的属性均为 `String?`（可选类型），SwiftData 自动处理为 `nil` 默认值
- 无需编写 `SchemaMigrationPlan` 或 `MigrationStage`
- CloudKit 同步兼容：新增可选字段对 CloudKit schema 是安全的（additive change）

### Migration Details
- `Block` 新增 3 个 `String?` 属性 → 现有数据自动填充 `nil` → 运行时 `nil` 回退到默认值
- `Session` 新增 1 个 `String?` 属性 → 同上
- 无需版本化 schema，SwiftData 自动检测新属性并迁移

### Risk Assessment
- **低风险**：仅添加可选属性，不修改/删除已有属性
- **CloudKit 安全**：additive-only 变更，旧版本 App 忽略新字段
- **回滚安全**：如果用户降级 App 版本，新字段被忽略不会导致崩溃

### Alternatives Considered
- **显式 VersionedSchema**：可用但此场景不需要，过度工程化，排除
- **单独存储播报配置（UserDefaults/JSON 文件）**：打破 Block/Session 数据内聚性，不支持 iCloud 同步，排除

---

## Research Task 4: 语音播报与现有音效的协调

### Decision
语音播报启用时，在 `TimerViewModel` 层面条件性跳过 Work/Rest 音效调用，改为调用 `SpeechService`。

### Rationale
- Spec 要求：语音播报**替代** Work/Rest 开始音效 (FR-010)
- 倒计时音效和 Session 完成音效保持不变 (FR-010)
- 语音播报关闭时恢复原有 Work/Rest 音效 (Assumption)

### Integration Strategy

```
handlePhaseChange(phase, blockIndex, set):
  if voiceAnnouncementEnabled:
    speechService.speak(text: determineAnnouncementText(...))
  else:
    // 原有逻辑
    audioService.playWorkStart() / playRestStart()
  hapticService.playPhaseTransition()  // 触觉反馈始终保留

handleSessionComplete():
  if voiceAnnouncementEnabled:
    speechService.speak(text: completionText)
  // Session 完成音效根据 spec: "倒计时音效和 Session 完成音效保持不变"
  // 但 FR-004 要求 "Session 完成时播报"，所以播报替代完成音效
  hapticService.playSessionComplete()  // 触觉反馈保留
```

### Announcement Text Resolution Logic

```
determineAnnouncementText(phase, blockIndex, set, blocks, session):
  case .work where set == 1:
    return block.announcementStart ?? block.name  // Block 首组 Work
  case .work where set > 1:
    return block.announcementContinue ?? "继续"    // 后续组 Work
  case .rest:
    return block.announcementRest ?? "休息"        // Rest
  case sessionComplete:
    return session.announcementComplete ?? "训练完成"  // Session 完成
```

### Alternatives Considered
- **在 AudioService 内部集成语音**：违反单一职责，AudioService 管理音效文件，SpeechService 管理 TTS，排除
- **事件总线 / Notification**：增加间接性，当前回调模式足够清晰，排除

---

## Research Task 5: 全局设置持久化

### Decision
使用 `@AppStorage` 存储语音播报全局开关。

### Rationale
- 只有一个布尔值需要持久化（`isVoiceAnnouncementEnabled`）
- `@AppStorage` 基于 UserDefaults，SwiftUI 原生支持，视图自动更新
- 与现有项目中尚未持久化的 `isSoundEnabled` 问题分离（本功能不负责修复已有问题）

### Key

```swift
@AppStorage("isVoiceAnnouncementEnabled") var isVoiceAnnouncementEnabled: Bool = true
```

### Alternatives Considered
- **SwiftData 存储设置**：过重，设置不属于业务实体，排除
- **自定义 Settings model**：只有一个值，不值得，排除

---

## Research Task 6: 阶段快速切换时的中断行为

### Decision
使用 `AVSpeechSynthesizer.stopSpeaking(at: .immediate)` 立即中断当前播报。

### Rationale
- FR-012 要求："当阶段快速切换时，系统必须中断当前播报并开始新播报"
- `stopSpeaking(at: .immediate)` 立即停止，不等待当前词朗读完毕
- 停止后可立即调用新的 `speak()` 开始新播报

### Implementation

```swift
func speak(text: String) {
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = selectVoice(for: text)
    synthesizer.speak(utterance)
}
```

### Edge Case: Empty Text
- 当 text 为空时（用户清空自定义文本），回退到默认值（在调用层处理，不传空文本给 SpeechService）
- `AVSpeechUtterance(string: "")` 不会崩溃但也不会有任何输出，仍应在调用层防守

---

## Summary of Resolved Items

| # | Unknown | Resolution |
|---|---------|-----------|
| 1 | TTS 引擎选型 | AVSpeechSynthesizer（内置、离线、自然） |
| 2 | 语言检测方案 | NLLanguageRecognizer → AVSpeechSynthesisVoice |
| 3 | 数据迁移策略 | SwiftData 自动迁移（可选属性，零代码） |
| 4 | 音效协调方案 | ViewModel 层条件分支，语音替代 Work/Rest 音效 |
| 5 | 设置持久化 | @AppStorage（UserDefaults） |
| 6 | 快速切换中断 | stopSpeaking(.immediate) + 立即 speak() |

All NEEDS CLARIFICATION items resolved. Ready for Phase 1.
