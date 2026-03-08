# Data Model: 本地 TTS 模型替换

**Feature**: 004-local-tts-model | **Date**: 2026-03-08

## 现有模型 (不变)

### Block (SwiftData @Model)

现有字段与语音播报相关的部分：

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | Block 名称，作为默认开始播报文本 |
| `announcementStart` | `String?` | 自定义开始播报文本（nil 时使用 name） |
| `announcementRest` | `String?` | 自定义休息播报文本（nil 时使用"休息"） |
| `announcementContinue` | `String?` | 自定义继续播报文本（nil 时使用"继续"） |

### Session (SwiftData @Model)

| Field | Type | Description |
|-------|------|-------------|
| `announcementComplete` | `String?` | 自定义完成播报文本（nil 时使用"练习完成"） |

> 注意：SwiftData 模型不需要任何修改。音频缓存完全通过文件系统管理，以文本内容的哈希值作为索引。

## 新增服务接口

### TTSEngine

sherpa-onnx C API 的 Swift 封装，负责模型初始化和文本到音频的转换。

```swift
/// sherpa-onnx 离线 TTS 引擎封装
/// 非 Sendable — 所有调用必须在同一个串行队列/actor 上
final class TTSEngine {
    /// 模型是否成功加载
    var isAvailable: Bool { get }

    /// 初始化引擎，加载模型文件
    /// - 从 Bundle 中定位模型文件路径
    /// - 创建 SherpaOnnxOfflineTts 实例
    init()

    /// 将文本合成为 PCM 音频采样
    /// - Parameters:
    ///   - text: 要合成的文本
    ///   - speed: 语速 (默认 1.0)
    /// - Returns: (samples: [Float], sampleRate: Int32)? — nil 表示生成失败
    func synthesize(text: String, speed: Float) -> (samples: [Float], sampleRate: Int32)?
}
```

### AudioCacheService

管理预生成音频文件的缓存存储。

```swift
/// 音频缓存服务 — 管理 TTS 预生成的 WAV 文件
final class AudioCacheService: Sendable {
    /// 默认播报文本及其对应的 Bundle 资源名
    static let defaultAnnouncements: [String: String]
    // "准备" → "preparing", "休息" → "rest", "继续" → "continue", "练习完成" → "complete"

    /// 查找文本对应的缓存音频文件 URL
    /// 查找顺序：1. Bundle 默认音频 → 2. TTSCache 目录缓存
    /// - Returns: 音频文件 URL，nil 表示无缓存
    func cachedURL(for text: String) -> URL?

    /// 将 PCM 采样保存为 WAV 文件到缓存目录
    /// - Parameters:
    ///   - samples: Float 采样数组 [-1, 1]
    ///   - sampleRate: 采样率
    ///   - text: 原始文本（用于生成缓存 key）
    func save(samples: [Float], sampleRate: Int32, for text: String) throws

    /// 检查文本是否已有缓存（含 Bundle 默认音频）
    func hasCached(text: String) -> Bool

    /// 缓存目录路径
    var cacheDirectory: URL { get }
}
```

### SpeechService (重构)

从纯 AVSpeechSynthesizer 封装重构为"缓存优先 + 降级"架构。

```swift
/// 语音播报服务 — 预缓存音频播放 + AVSpeechSynthesizer 降级
@MainActor
final class SpeechService {
    static let shared: SpeechService

    /// 当前是否正在播报
    var isSpeaking: Bool { get }

    /// 播报指定文本
    /// 1. 查找缓存音频 → AVAudioPlayer 播放
    /// 2. 无缓存 → AVSpeechSynthesizer 降级播报
    /// 如有正在播报的内容则立即中断
    func speak(_ text: String)

    /// 立即停止当前播报
    func stop()

    /// 为一组文本预生成音频（后台异步）
    /// 跳过已有缓存的文本
    /// - Parameter texts: 需要预生成的文本列表
    func pregenerate(texts: [String])
}
```

## 缓存文件命名规则

```
缓存 Key = SHA256(text).prefix(32)
文件路径 = Application Support/TTSCache/{key}.wav
```

示例：
| 文本 | 缓存 Key (前32字符) | 文件名 |
|------|---------------------|--------|
| "深蹲" | `a1b2c3d4e5f6...` | `a1b2c3d4e5f6....wav` |
| "C大调 Scale" | `f7g8h9i0j1k2...` | `f7g8h9i0j1k2....wav` |

## 默认播报音频 (Bundle 内置)

| 文本 | 资源文件名 | 触发场景 |
|------|-----------|---------|
| "准备" | `DefaultAnnouncements/preparing.wav` | `.preparing` 阶段开始 |
| "休息" | `DefaultAnnouncements/rest.wav` | `.rest` 阶段开始（无自定义文本） |
| "继续" | `DefaultAnnouncements/continue.wav` | `.work` 阶段开始，非首组（无自定义文本） |
| "练习完成" | `DefaultAnnouncements/complete.wav` | Session 完成 |

> 这些 WAV 文件在开发阶段通过 TTSEngine 预生成，作为应用资源内置。

## 状态转换

### 音频生成状态

```
[用户保存] → [收集播报文本] → [过滤已缓存] → [后台生成] → [保存到缓存]
                                                  ↓ 失败
                                            [记录日志，不阻塞]
```

### 播放时降级状态

```
[播报请求(text)]
    → [查找缓存 URL]
        → 找到 → [AVAudioPlayer 播放缓存文件]
        → 未找到 → [AVSpeechSynthesizer 实时播报]
```

## 播报文本收集规则

当用户保存 Block 或 Session 时，需要为以下文本预生成音频：

**Per Block**:
1. `announcementStart ?? name` — 开始播报
2. `announcementRest.isEmpty ? nil : announcementRest` — 休息播报（为空则使用默认"休息"，已内置）
3. `announcementContinue.isEmpty ? nil : announcementContinue` — 继续播报（为空则使用默认"继续"，已内置）

**Per Session**:
4. `announcementComplete.isEmpty ? nil : announcementComplete` — 完成播报（为空则使用默认"练习完成"，已内置）

> 默认文本（"准备"/"休息"/"继续"/"练习完成"）不需要运行时生成，因为已内置在 Bundle 中。
> Block 名称始终需要生成（作为默认的开始播报），因为名称是用户自定义的。
