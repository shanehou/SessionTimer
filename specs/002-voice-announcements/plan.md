# Implementation Plan: 语音播报

**Branch**: `002-voice-announcements` | **Date**: 2026-03-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-voice-announcements/spec.md`

## Summary

为 Session Timer 添加语音播报功能，在计时阶段切换时使用 `AVSpeechSynthesizer` 播报自然语音提示（Block 名称、"休息"、"继续"、"训练完成"），替代现有的 Work/Rest 开始音效。支持用户自定义播报文本（Block 级别 3 项 + Session 级别 1 项），以及全局开关控制。利用 `NLLanguageRecognizer` 自动检测文本语言并匹配语音，实现中英文自然朗读。

## Technical Context

**Language/Version**: Swift 6.0, Strict Concurrency: complete
**Primary Dependencies**: SwiftUI, SwiftData, AVFoundation (`AVSpeechSynthesizer`), NaturalLanguage (`NLLanguageRecognizer`)
**Storage**: SwiftData (CloudKit/iCloud 自动同步), `@AppStorage` (UserDefaults) 用于全局开关
**Testing**: XCTest (手动验证为主，语音合成需真机)
**Target Platform**: iOS 17.0+
**Project Type**: Mobile (iOS native)
**Performance Goals**: 语音播报在阶段切换后 0.5s 内开始 (SC-002)；前后台均正常工作 (SC-003)
**Constraints**: 离线可用（设备内置 TTS）；与背景音乐混音；阶段快速切换时中断当前播报
**Scale/Scope**: 2 个 SwiftData 模型扩展 + 1 个新 Service + 3 个 View 修改

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| Art. 1 - Eyes-Free & Hands-Busy | 核心计时操作支持盲操作 | ✅ ALIGNED | 语音播报增强了免视觉操作能力，用户无需看屏幕即知当前阶段 |
| Art. 2 - Sensory Feedback Hierarchy | 听觉是第一公民；支持音频混音 | ✅ ALIGNED | 使用 `.duckOthers` 压低背景音乐；语音提示有明确区分度（不同文本内容） |
| Art. 3 - Flat Start | 启动到计时路径最短 | ✅ N/A | 不影响启动流程 |
| Art. 4 - Intuitive Mapping | 结构映射现实心理模型 | ✅ ALIGNED | Block 级播报文本直觉对应"项目开始/休息/继续"；Session 级对应"训练完成" |
| Art. 5 - Flexible Rigidity | 执行中可临时调整 | ✅ N/A | 不影响临时调整能力 |
| Art. 6 - Island & Lock Screen | 后台/锁屏正常运行 | ✅ ALIGNED | AVSpeechSynthesizer 复用现有 `.playback` audio session，后台播报能力继承 |
| Art. 7 - Idle Timer Strategy | 屏幕常亮策略 | ✅ N/A | 不影响 |
| Art. 8 - Declarative Project Config | 使用 XcodeGen；禁止修改 xcodeproj | ✅ WILL COMPLY | 仅修改源文件，通过 `xcodegen generate` 同步 |
| Art. 9 - Automated Build Pipeline | 使用 `make run-device` 验证 | ✅ WILL COMPLY | 实现后通过 `make run-device` 验证 |
| Art. 10 - Distance Legibility | 远距离可读 | ✅ N/A | 纯音频功能，不影响视觉 |

**Pre-design Gate**: ✅ PASS — 无违反项
**Post-design Re-check**: ✅ PASS — Phase 1 设计确认：SpeechService 复用现有 audio session (.duckOthers)；仅增加源文件无需改 project.yml；Block 属性扩展符合直觉映射原则

## Project Structure

### Documentation (this feature)

```text
specs/002-voice-announcements/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── speech-service.md
└── checklists/
    └── requirements.md  # Pre-existing
```

### Source Code (repository root)

```text
src/
├── Models/
│   ├── Session.swift          # 扩展: + announcementComplete: String?
│   └── Block.swift            # 扩展: + announcementStart/Rest/Continue: String?
├── Services/
│   ├── AudioService.swift     # 修改: 语音启用时跳过 Work/Rest 音效
│   └── SpeechService.swift    # 新增: AVSpeechSynthesizer 封装
├── ViewModels/
│   └── TimerViewModel.swift   # 修改: 阶段切换时调用 SpeechService
├── Views/
│   ├── Session/
│   │   └── SessionEditorView.swift  # 修改: + 完成播报文本输入
│   └── Components/
│       └── BlockEditorRow.swift     # 修改: + 播报文本输入区域
└── Extensions/                      # (无变更)
```

**Structure Decision**: 沿用现有 iOS 单项目结构 (Option 3 简化版)。新功能通过模型扩展 + 新增 Service + View 修改实现，无需新目录。

## Complexity Tracking

> 无宪法违反项，此表为空。

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (无) | — | — |
