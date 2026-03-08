# Implementation Plan: 本地 TTS 模型替换

**Branch**: `004-local-tts-model` | **Date**: 2026-03-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-local-tts-model/spec.md`

## Summary

将语音播报从系统 AVSpeechSynthesizer 替换为本地 sherpa-onnx + matcha-icefall-zh-en 模型。采用"保存时预生成 + 缓存音频文件 + 计时时直接播放"的架构，消除运行时推理延迟。默认播报文本（"准备"、"休息"、"继续"、"练习完成"）内置预生成 WAV 文件，自定义文本在用户保存时后台生成。AVSpeechSynthesizer 保留为降级方案。

## Technical Context

**Language/Version**: Swift 6.0, C interop (sherpa-onnx C API)
**Primary Dependencies**: sherpa-onnx.xcframework (TTS 引擎), onnxruntime.xcframework (推理运行时), matcha-icefall-zh-en 模型 (model-steps-6.onnx + vocos-16khz-univ.onnx), AVFoundation (音频播放), AVSpeechSynthesizer (降级方案)
**Storage**: 文件系统缓存 (Application Support 目录) 存储生成的 WAV 音频文件；SwiftData 现有模型不变
**Testing**: XCTest, 手动设备测试 (`make run-device`)
**Target Platform**: iOS 17.0+
**Project Type**: mobile (iOS SwiftUI)
**Performance Goals**: 音频播放延迟 < 50ms（预缓存文件直接播放）；单次音频生成 < 3s（后台线程，短文本）
**Constraints**: 完全离线运行；模型文件 ~130MB 打包进 App；音频缓存空间可忽略（每个文件几十 KB）
**Scale/Scope**: 4 个默认播报 + 每个 Block 最多 3 个自定义播报 + Session 1 个完成播报

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Article | Requirement | Compliance | Notes |
|---------|------------|------------|-------|
| Art.1 盲操作优先 | 核心计时操作支持全屏手势 | ✅ 不受影响 | 本功能不修改手势交互 |
| Art.2 感官反馈层级 | 听觉第一公民，支持 Audio Ducking | ✅ 合规 | 复用现有 AudioService 的 `.mixWithOthers, .duckOthers` 配置；音频文件播放与音乐混音 |
| Art.2 提示音区分度 | 开始/休息/结束/倒数各不相同 | ✅ 合规 | 语音播报内容本身有区分（"准备"/"休息"/"继续"/"练习完成"），与音效互斥 |
| Art.6 后台播放 | 支持后台运行 + 通知 | ✅ 合规 | AVAudioPlayer 播放缓存文件在后台正常工作，与现有 AudioService 后台保活机制兼容 |
| Art.7 屏幕策略 | Work 常亮，长 Rest 变暗 | ✅ 不受影响 | 本功能不修改屏幕策略 |
| Art.8 声明式配置 | 使用 XcodeGen，禁止直接改 pbxproj | ✅ 合规 | 通过 project.yml 添加 vendor 依赖和模型资源 |
| Art.9 自动化构建 | `make run-device` 验证 | ✅ 合规 | 构建后通过 `make run-device` 验证 |
| Art.10 远距离可读性 | 计时数字 2m 可见 | ✅ 不受影响 | 本功能不修改视觉界面 |

**GATE RESULT**: ✅ PASS — 无违规

## Project Structure

### Documentation (this feature)

```text
specs/004-local-tts-model/
├── plan.md              # This file
├── research.md          # Phase 0: sherpa-onnx 集成研究
├── data-model.md        # Phase 1: 数据模型与接口设计
├── quickstart.md        # Phase 1: 快速开始指南
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
scripts/
└── setup-vendor.sh              # 新增：vendor 依赖获取脚本（编译 + 下载）

src/
├── Services/
│   ├── SpeechService.swift          # 重构：预生成 + 缓存播放架构
│   ├── TTSEngine.swift              # 新增：sherpa-onnx C API Swift 封装
│   ├── AudioCacheService.swift      # 新增：音频文件缓存管理
│   └── AudioService.swift           # 微调：复用 AVAudioPlayer 播放缓存音频
├── ViewModels/
│   ├── TimerViewModel.swift         # 微调：speak() 调用方式不变，内部实现变化
│   └── SessionEditorViewModel.swift # 微调：save() 后触发音频预生成
└── Resources/
    └── DefaultAnnouncements/        # 新增：内置默认播报 WAV 文件
        ├── preparing.wav            # "准备"
        ├── rest.wav                 # "休息"
        ├── continue.wav             # "继续"
        └── complete.wav             # "练习完成"

vendor/                              # .gitignore — 通过 scripts/setup-vendor.sh 获取
├── sherpa-onnx.xcframework/         # build-ios.sh 编译产出
├── ios-onnxruntime/                 # build-ios.sh 自动下载
│   └── onnxruntime.xcframework/
└── matcha-icefall-zh-en/            # 从三个仓库组装
    ├── model-steps-6.onnx           # ← modelscope (最高质量)
    ├── vocos-16khz-univ.onnx        # ← modelscope (vocoder)
    ├── vocab_tts.txt                # ← modelscope
    ├── tokens.txt                   # ← huggingface
    ├── lexicon.txt                  # ← huggingface
    ├── date-zh.fst                  # ← huggingface
    ├── number-zh.fst                # ← huggingface
    ├── phone-zh.fst                 # ← huggingface
    ├── espeak-ng-data/              # ← huggingface (音素数据)
    └── dict/                        # ← cppjieba (jieba 分词词典)
```

**Structure Decision**: 沿用现有 iOS 单项目结构。新增 `scripts/setup-vendor.sh` 脚本从源码编译/下载所有 vendor 依赖（不提交到 git）。新增 3 个 Service 文件（TTSEngine、AudioCacheService、SpeechService 重构），修改 2 个 ViewModel，新增 4 个默认音频资源文件。通过 project.yml 配置 vendor 依赖和模型资源。

## Complexity Tracking

> 无宪法违规，无需额外说明。
