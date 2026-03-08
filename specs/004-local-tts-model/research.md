# Research: 本地 TTS 模型替换

**Feature**: 004-local-tts-model | **Date**: 2026-03-08

## R1: sherpa-onnx iOS 集成方式

**Decision**: 通过 C API 桥接 + Swift 封装类调用 sherpa-onnx 离线 TTS

**Rationale**:
- sherpa-onnx 提供 C API（`c-api.h`），Swift 可直接通过 bridging header 调用
- 官方 iOS SwiftUI 示例（`ios-swiftui/SherpaOnnxTts`）验证了这一集成路径
- 静态库 `libsherpa-onnx.a` 已在 xcframework 中提供 arm64 和 simulator 两种架构
- 需要同时链接 `sherpa-onnx.xcframework` 和 `onnxruntime.xcframework`

**Alternatives considered**:
- Swift Package Manager 集成：sherpa-onnx 未提供官方 SPM 包，且模型文件体积大不适合 SPM
- 直接调用 C++ API：增加复杂度，C API 已足够覆盖 TTS 功能

## R2: matcha-icefall-zh-en 模型配置

**Decision**: 使用 `SherpaOnnxOfflineTtsMatchaModelConfig` 配置 matcha 模型

**Rationale**:
根据 sherpa-onnx 官方示例 `getTtsFor_matcha_icefall_zh_baker()` 和 C API 头文件，matcha 模型需要以下配置：

```swift
let matcha = sherpaOnnxOfflineTtsMatchaModelConfig(
    acousticModel: "model-steps-6.onnx",   // 声学模型（最高质量）
    vocoder: "vocos-16khz-univ.onnx",      // 声码器
    lexicon: "lexicon.txt",                 // 词典
    tokens: "tokens.txt",                   // token 映射
    dataDir: "espeak-ng-data",             // 音素数据目录
    dictDir: "dict"                         // jieba 分词词典目录
)

let ruleFsts = "\(dateFst),\(phoneFst),\(numberFst)"  // FST 规则
```

注意 matcha-icefall-zh-en 模型与 zh-baker 模型的差异：
- zh-en 模型使用 `vocos-16khz-univ.onnx`（16kHz），zh-baker 使用 `vocos-22khz-univ.onnx`（22kHz）
- zh-en 模型包含 `espeak-ng-data` 目录（用于英文音素），zh-baker 不需要
- zh-en 模型包含 `dict` 目录（jieba 分词），zh-baker 不需要
- FST 文件名带 `-zh` 后缀：`date-zh.fst`, `number-zh.fst`, `phone-zh.fst`

**Alternatives considered**:
- model-steps-3.onnx：质量较低但推理更快。已在 spec 中确认使用 model-steps-6（最高质量优先）
- VITS 模型：matcha 是更新的架构，语音质量更好

## R3: 音频生成输出格式与播放方式

**Decision**: 生成 PCM float 采样 → 保存为 16-bit PCM WAV 文件 → 通过 AVAudioPlayer 播放

**Rationale**:
- sherpa-onnx `SherpaOnnxOfflineTtsGenerate` 返回 `SherpaOnnxGeneratedAudio`，包含 `float *samples`（范围 [-1, 1]）和 `sample_rate`（16000Hz）
- 官方提供 `SherpaOnnxWriteWave` 函数直接将采样写入 WAV 文件
- WAV 文件可直接通过 `AVAudioPlayer(contentsOf:)` 加载播放，与现有 AudioService 架构完全兼容
- 16kHz 16-bit mono WAV 格式，短文本（2-4 个字）预计每个文件 ~30-80KB

**Alternatives considered**:
- 直接播放 PCM buffer（通过 AVAudioPCMBuffer）：增加复杂度，不便于缓存
- 保存为 AAC/M4A 压缩格式：额外的编码开销，短音频压缩收益微小
- Core Audio 直接播放：与现有 AVAudioPlayer 架构不一致

## R4: 音频缓存策略

**Decision**: 以播报文本 SHA256 哈希命名，存储在 Application Support/TTSCache/ 目录

**Rationale**:
- 使用文本哈希作为文件名，天然实现去重（相同文本 → 相同缓存文件）
- Application Support 目录不会被系统自动清理（与 Caches 不同），保证缓存持久性
- 缓存查找逻辑简单：hash(text) → 文件路径 → 检查文件是否存在
- 默认播报文本内置在 Bundle 中，不需要缓存（直接从 Bundle 读取）

缓存目录结构：
```
Application Support/TTSCache/
├── a1b2c3d4...wav   # SHA256("深蹲").wav
├── e5f6g7h8...wav   # SHA256("继续练习").wav
└── ...
```

**Alternatives considered**:
- 以文本明文命名：可能包含特殊字符，文件名不安全
- CoreData 存储音频数据：过度设计，简单的文件缓存已足够
- Caches 目录：系统可能在存储紧张时自动清理，导致缓存丢失

## R5: 线程模型与并发安全

**Decision**: TTSEngine 在独立的后台串行队列上运行推理；SpeechService 在 MainActor 上协调

**Rationale**:
- sherpa-onnx 推理是 CPU 密集型操作（短文本预计 0.5-2s），不能在主线程运行
- 使用 Swift 的 actor 隔离或 DispatchQueue 确保 sherpa-onnx 实例的线程安全
- SpeechService 保持 `@MainActor`，与 ViewModel 在同一线程协调
- 音频生成任务通过 Swift Concurrency（async/await）提交到后台

并发流程：
```
MainActor (保存时):
  SessionEditorViewModel.save()
    → SpeechService.pregenerate(texts:)  // 提交生成任务
       → Task.detached { TTSEngine.generate(text:) }  // 后台推理
          → AudioCacheService.save(samples:, for: text) // 保存 WAV

MainActor (播放时):
  TimerViewModel.handlePhaseChange()
    → SpeechService.speak(text:)
       → AudioCacheService.cachedURL(for: text) // 查找缓存
       → AVAudioPlayer(contentsOf: url).play()  // 播放
```

**Alternatives considered**:
- 全部在 MainActor 运行：会导致 UI 卡顿
- 多线程并发生成：sherpa-onnx 实例可能不是线程安全的，需要串行化
- GCD concurrent queue：不如 Swift actor 语义清晰

## R6: Bridging Header 与 XcodeGen 配置

**Decision**: 创建 bridging header 导入 sherpa-onnx C API，通过 project.yml 配置依赖

**Rationale**:
- sherpa-onnx 是 C 库，Swift 需要通过 bridging header 访问 C API
- XcodeGen 的 project.yml 中需要：
  1. 添加 `SWIFT_OBJC_BRIDGING_HEADER` 指向 bridging header
  2. 添加 `sherpa-onnx.xcframework` 和 `onnxruntime.xcframework` 为 framework 依赖
  3. 添加模型文件目录为 Copy Bundle Resources
  4. 添加 `HEADER_SEARCH_PATHS` 指向 sherpa-onnx headers
  5. 链接系统 framework: `Accelerate`（onnxruntime 依赖）
- SherpaOnnx.swift 封装文件包含 Swift 友好的 wrapper 函数（参考官方示例）

**Alternatives considered**:
- module.modulemap：对于 xcframework 中的 C 库，bridging header 更简单直接
- 手动 clang 模块：增加维护成本

## R7: 降级策略

**Decision**: 三级降级：Bundle 默认音频 → 缓存音频 → AVSpeechSynthesizer 实时播报

**Rationale**:
播放时的查找顺序：
1. 如果是默认文本（"准备"/"休息"/"继续"/"练习完成"），优先使用 Bundle 内置 WAV
2. 查找 TTSCache 目录中的缓存文件
3. 如果都没有（生成中/模型故障/缓存清理），降级到 AVSpeechSynthesizer

降级触发场景：
- 用户刚保存自定义文本，生成尚未完成 → 降级到 AVSpeechSynthesizer
- 模型文件损坏或缺失（不太可能，因为打包在 App 内） → 降级
- 缓存文件被意外删除 → 降级，后台重新触发生成

**Alternatives considered**:
- 无降级（生成不了就不播报）：违反 FR-010，用户体验差
- 只保留 AVSpeechSynthesizer 降级：已是当前方案，Bundle 默认音频只是额外的优化层

## R8: vendor 依赖获取策略（不提交到 git）

**Decision**: 提供 `scripts/setup-vendor.sh` 脚本，从源码编译 sherpa-onnx 并从三个仓库组装模型文件

**Rationale**:
vendor 目录包含 ~200MB+ 的二进制文件（xcframeworks + 模型），不适合提交到 git。通过脚本自动化获取：

### 数据来源

| 组件 | 来源 | 获取方式 |
|------|------|---------|
| sherpa-onnx.xcframework | https://github.com/k2-fsa/sherpa-onnx | `git clone` → 运行 `build-ios.sh` 编译 |
| ios-onnxruntime/ | 同上（build-ios.sh 自动下载 v1.17.1 预编译包） | build-ios.sh 内部处理 |
| model-steps-6.onnx | https://www.modelscope.cn/dengcunqin/matcha_tts_zh_en_20251010.git | `git clone` 或直接下载 |
| vocos-16khz-univ.onnx | 同上 | 同上 |
| vocab_tts.txt | 同上 | 同上 |
| tokens.txt, lexicon.txt | https://huggingface.co/csukuangfj/matcha-icefall-zh-en | `git clone`（需 git-lfs） |
| date-zh.fst, number-zh.fst, phone-zh.fst | 同上 | 同上 |
| espeak-ng-data/ | 同上 | 同上 |
| dict/ (jieba 分词词典) | https://github.com/yanyiwu/cppjieba.git | `git clone` → 复制 `dict/` 目录 |

### 脚本执行流程

```bash
scripts/setup-vendor.sh
├── 1. 检查 vendor/ 是否已存在（跳过已有组件）
├── 2. 克隆 sherpa-onnx 仓库 → 运行 build-ios.sh
│      → 产出: vendor/sherpa-onnx.xcframework/
│      → 产出: vendor/ios-onnxruntime/
├── 3. 克隆 modelscope 仓库 → 复制模型文件
│      → model-steps-6.onnx, vocos-16khz-univ.onnx, vocab_tts.txt
├── 4. 克隆 huggingface 仓库 → 复制辅助文件
│      → tokens.txt, lexicon.txt, *.fst, espeak-ng-data/
├── 5. 克隆 cppjieba 仓库 → 复制 dict/ 目录
└── 6. 清理临时克隆目录
```

### .gitignore 配置

```
# vendor 依赖（通过 scripts/setup-vendor.sh 获取）
vendor/
```

**Alternatives considered**:
- Git LFS：仍然增加仓库体积，且 LFS 配额有限
- 预编译 Release 下载：sherpa-onnx 提供了预编译的 iOS 包（如 `sherpa-onnx-v1.12.28-ios.tar.bz2`），但用户明确要求从源码编译
- 将 vendor 提交到 git：二进制文件过大，不适合版本控制
