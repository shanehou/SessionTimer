# Service Contract: SpeechService

**Feature**: 002-voice-announcements
**Date**: 2026-03-04

## Overview

`SpeechService` 封装 `AVSpeechSynthesizer`，提供文本转语音播报能力。负责语言检测、语音选择、播报执行和中断控制。

## Interface

```swift
@MainActor
final class SpeechService {

    /// 共享实例
    static let shared: SpeechService

    /// 播报指定文本
    /// - 自动检测文本语言并选择匹配语音
    /// - 如果当前有正在播报的内容，立即中断并开始新播报
    /// - 空字符串将被忽略（不播报）
    func speak(_ text: String)

    /// 立即停止当前播报
    func stop()

    /// 当前是否正在播报
    var isSpeaking: Bool { get }
}
```

## Behavior Specification

### speak(_ text: String)

| Scenario | Behavior |
|----------|----------|
| text 非空，无正在播报 | 检测语言 → 选择语音 → 开始播报 |
| text 非空，有正在播报 | 立即中断当前播报 → 开始新播报 (FR-012) |
| text 为空 | 不执行任何操作 |
| 系统 TTS 不可用 | 静默失败，打印 debug 日志 |

### Language Detection Rules

| Input Text | Detected Language | Voice |
|------------|-------------------|-------|
| "深蹲" | zh-CN | 中文语音 |
| "Squat" | en-US | 英文语音 |
| "C大调 Scale" | zh-CN (主要语言) | 中文语音 |
| "Deep squat 深蹲" | en-US (主要语言) | 英文语音 |
| "" | — | 不播报 |

### Voice Selection Priority

1. `AVSpeechSynthesisVoice(language: detectedLanguage)` — 系统默认语音
2. 如果检测失败 → fallback 到 `zh-CN`

## Integration Contract

### TimerViewModel Integration

```swift
// TimerViewModel.handlePhaseChange(phase:blockIndex:set:)
// 当 isVoiceAnnouncementEnabled == true 时：

func resolveAnnouncementText(
    phase: TimerPhase,
    block: Block,
    set: Int
) -> String {
    switch phase {
    case .work where set == 1:
        let text = block.announcementStart ?? ""
        return text.isEmpty ? block.name : text
    case .work:
        let text = block.announcementContinue ?? ""
        return text.isEmpty ? "继续" : text
    case .rest:
        let text = block.announcementRest ?? ""
        return text.isEmpty ? "休息" : text
    }
}

func resolveCompletionText(session: Session) -> String {
    let text = session.announcementComplete ?? ""
    return text.isEmpty ? "训练完成" : text
}
```

### AudioService Coordination

| Voice Announcement State | Work/Rest Start Sound | Countdown Sound | Session Complete Sound |
|--------------------------|----------------------|-----------------|----------------------|
| Enabled | ❌ 不播放（语音替代） | ✅ 保持 | ❌ 不播放（语音替代） |
| Disabled | ✅ 恢复原有音效 | ✅ 保持 | ✅ 恢复原有音效 |

### Audio Session Requirements

- 复用 `AudioService` 已配置的 `AVAudioSession`：
  - Category: `.playback`
  - Options: `.mixWithOthers`, `.duckOthers`
- 不需要单独配置 audio session
- 后台播报依赖已有的 background audio mode

## Error Handling

| Error Case | Strategy |
|------------|----------|
| AVSpeechSynthesizer 初始化失败 | 静默失败，不影响计时功能 |
| 语音不可用（语言包未下载） | 使用系统默认语音 fallback |
| 后台被系统杀死 | 依赖现有后台保活策略 (AudioService.silentPlayer) |

## Testing Notes

- `AVSpeechSynthesizer` 在模拟器上可用但语音质量较低，建议真机测试
- 单元测试可通过协议抽象 mock SpeechService
- 关键测试场景：中文文本、英文文本、中英混合、空文本、快速连续调用
