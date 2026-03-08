# Quick Start: 本地 TTS 模型替换

**Feature**: 004-local-tts-model | **Date**: 2026-03-08

## 前置条件

- Xcode 16.0+, iOS 17.0+ SDK
- XcodeGen 已安装 (`brew install xcodegen`)
- CMake 已安装 (`brew install cmake`)，sherpa-onnx 编译依赖
- Git LFS 已安装 (`brew install git-lfs && git lfs install`)，huggingface 模型下载依赖

## 初始化 vendor 依赖

vendor 目录不纳入版本控制。首次克隆仓库后，运行以下脚本获取所有依赖：

```bash
# 编译 sherpa-onnx + 下载模型文件 → vendor/
scripts/setup-vendor.sh
```

脚本执行内容：

| 步骤 | 操作 | 产出 |
|------|------|------|
| 1 | 克隆 [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) → 运行 `build-ios.sh` | `vendor/sherpa-onnx.xcframework/`, `vendor/ios-onnxruntime/` |
| 2 | 克隆 [modelscope/matcha_tts](https://www.modelscope.cn/dengcunqin/matcha_tts_zh_en_20251010.git) → 复制模型 | `model-steps-6.onnx`, `vocos-16khz-univ.onnx`, `vocab_tts.txt` |
| 3 | 克隆 [huggingface/matcha-icefall-zh-en](https://huggingface.co/csukuangfj/matcha-icefall-zh-en) → 复制辅助文件 | `tokens.txt`, `lexicon.txt`, `*.fst`, `espeak-ng-data/` |
| 4 | 克隆 [cppjieba](https://github.com/yanyiwu/cppjieba.git) → 复制 `dict/` | `dict/` (jieba 分词词典) |

> 脚本支持增量运行：已存在的组件会跳过。sherpa-onnx 编译耗时较长（首次约 10-20 分钟）。

## 新增文件清单

### 源码文件

| 文件 | 路径 | 说明 |
|------|------|------|
| setup-vendor.sh | `scripts/setup-vendor.sh` | vendor 依赖获取脚本 |
| TTSEngine.swift | `src/Services/TTSEngine.swift` | sherpa-onnx C API Swift 封装 |
| AudioCacheService.swift | `src/Services/AudioCacheService.swift` | 音频缓存管理 |
| SherpaOnnx-Bridging-Header.h | `src/App/SherpaOnnx-Bridging-Header.h` | C API 桥接头文件 |
| SherpaOnnxHelpers.swift | `src/Services/SherpaOnnxHelpers.swift` | 官方 Swift wrapper 函数 (toCPointer, config builders, wrapper classes) |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/Services/SpeechService.swift` | 重构为缓存优先 + 降级架构 |
| `src/ViewModels/SessionEditorViewModel.swift` | save() 后触发音频预生成 |
| `project.yml` | 添加 vendor 依赖、模型资源、bridging header |
| `.gitignore` | 添加 `vendor/` |
| `Makefile` | 添加 `setup-vendor` target |

### 资源文件

| 文件 | 说明 |
|------|------|
| `src/Resources/DefaultAnnouncements/preparing.wav` | 默认播报"准备" |
| `src/Resources/DefaultAnnouncements/rest.wav` | 默认播报"休息" |
| `src/Resources/DefaultAnnouncements/continue.wav` | 默认播报"继续" |
| `src/Resources/DefaultAnnouncements/complete.wav` | 默认播报"练习完成" |

## project.yml 变更要点

```yaml
# 在 SessionTimer target 下添加:
settings:
  base:
    SWIFT_OBJC_BRIDGING_HEADER: src/App/SherpaOnnx-Bridging-Header.h
    HEADER_SEARCH_PATHS:
      - vendor/sherpa-onnx.xcframework/ios-arm64/Headers

dependencies:
  - framework: vendor/sherpa-onnx.xcframework
    embed: false          # 静态库不需要 embed
  - framework: vendor/ios-onnxruntime/onnxruntime.xcframework
    embed: true           # 动态库需要 embed
  - sdk: Accelerate.framework
  - sdk: CoreML.framework

# 资源文件 (模型 + 默认音频)
sources:
  - path: vendor/matcha-icefall-zh-en
    type: folder           # 作为文件夹引用，保留目录结构
    buildPhase: resources
  - path: src/Resources/DefaultAnnouncements
    type: folder
    buildPhase: resources
```

## 验证步骤

```bash
# 0. 初始化 vendor 依赖（首次或 vendor/ 不存在时）
scripts/setup-vendor.sh

# 1. 生成 Xcode 项目
make generate

# 2. 构建并安装到设备
make run-device

# 3. 验证流程
# - 创建一个 Session，添加 Block
# - 保存后等待几秒（后台生成音频）
# - 启动计时，验证语音播报使用本地模型生成的音频
# - 验证默认播报（"准备"/"休息"/"继续"/"练习完成"）正常
# - 验证后台播放正常
# - 验证与音乐混音正常
```

## 架构概览

```
┌─────────────────────────────────────────────────────┐
│                    TimerViewModel                     │
│  handlePhaseChange() → speechService.speak(text)     │
└────────────────────────┬────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│                   SpeechService                      │
│  speak(text):                                        │
│    if cache.cachedURL(text) → AVAudioPlayer.play()   │
│    else → AVSpeechSynthesizer.speak() (fallback)     │
│                                                      │
│  pregenerate(texts):                                 │
│    Task.detached {                                   │
│      for text in texts where !cached:                │
│        let audio = ttsEngine.synthesize(text)        │
│        cache.save(audio, for: text)                  │
│    }                                                 │
└──────┬───────────────────────┬──────────────────────┘
       │                       │
┌──────▼──────┐   ┌───────────▼──────────────┐
│  TTSEngine  │   │   AudioCacheService      │
│  (sherpa-   │   │   Bundle defaults +      │
│   onnx)     │   │   TTSCache/ directory    │
└─────────────┘   └──────────────────────────┘
```
