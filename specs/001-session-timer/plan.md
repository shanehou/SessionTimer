# Implementation Plan: Session Timer - 重复练习计时器App

**Branch**: `001-session-timer` | **Date**: 2026-02-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-session-timer/spec.md`

## Summary

构建一个专为"刻意练习"场景设计的 iOS 计时器 App，支持健身、乐器练习等需要重复练习的场景。用户可以创建包含多个 Block（动作/项目）的 Session，每个 Block 包含多组（Set），每组有练习时间和休息时间。App 支持全屏手势控制（盲操作）、多层次感官反馈、Live Activities、Dynamic Island、后台运行和 iCloud 数据同步。

## Technical Context

**Language/Version**: Swift 6.0  
**Primary Dependencies**: SwiftUI, SwiftData, ActivityKit (Live Activities), WidgetKit, AVFoundation (音频), CoreHaptics (触觉反馈), CloudKit (iCloud 同步), UserNotifications  
**Build Tools**: XcodeGen (项目生成), xcbeautify (构建输出美化), xcodebuild (编译)  
**Storage**: SwiftData + iCloud (CloudKit 自动同步)  
**Testing**: XCTest (Unit & UI Tests)  
**Target Platform**: iOS 16.1+ (Live Activities & Dynamic Island 最低要求)  
**Project Type**: Mobile (iOS single app)  
**Performance Goals**: 60fps 动画, 计时精度 ±1 秒, 后台唤醒 <1 秒  
**Constraints**: 后台运行时内存 <50MB, 离线可用, 数据跨设备同步  
**Scale/Scope**: 单用户, 最多 50 个 Session, 每个 Session 最多 50 个 Block

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Gate Evaluation

| Article | Requirement | Compliance | Notes |
|---------|-------------|------------|-------|
| **Article 1: Eyes-Free & Hands-Busy** | 全屏手势控制 (单击暂停/继续, 双击跳过, 长按结束), 触控区 ≥44pt | ✅ PASS | 计划实现全屏手势，无小按钮 |
| **Article 2: Sensory Feedback Hierarchy** | 听觉优先 (音频混音), 触觉分级 (Heavy/Success/Warning) | ✅ PASS | 将使用 AVFoundation 混音 + CoreHaptics |
| **Article 3: Flat Start** | One-tap Start, 最近 Session 在一级页面 | ✅ PASS | 主界面直接显示最近 Session 列表 |
| **Article 4: Intuitive Mapping** | Session > Block > Set 三级结构 | ✅ PASS | 数据模型严格遵循规范定义 |
| **Article 5: Flexible Rigidity** | 运行中支持加一组/跳过休息/延长休息 | ✅ PASS | 计划通过手势或快捷操作实现 |
| **Article 6: Island & Lock Screen** | Live Activities + Dynamic Island + 后台通知 | ✅ PASS | 使用 ActivityKit 实现 |
| **Article 7: Idle Timer Strategy** | Work 常亮, 长 Rest 可暗, 结束前 5 秒唤醒 | ✅ PASS | 通过 UIApplication.shared.isIdleTimerDisabled 控制 |
| **Article 8: Distance Legibility** | 2 米可读, Work/Rest 全屏区分 | ✅ PASS | 大字体 + 黑底白字(Work)/绿底白字(Rest) |

**Gate Status**: ✅ ALL PASSED - Proceed to Phase 0

### Post-Design Gate Evaluation (Phase 1 Complete)

| Article | Design Artifact | Compliance | Verification |
|---------|-----------------|------------|--------------|
| **Article 1: Eyes-Free & Hands-Busy** | `TimerView` 全屏手势 (research.md §8) | ✅ PASS | SwiftUI `.onTapGesture`, `.onLongPressGesture` 覆盖全屏 |
| **Article 2: Sensory Feedback Hierarchy** | `HapticService`, `AudioService` (contracts §3-4) | ✅ PASS | 音频 mixWithOthers + duckOthers, 触觉 Heavy/Success/Warning |
| **Article 3: Flat Start** | `SessionListView` (contracts §1) | ✅ PASS | 主界面直接 `@Query` 显示 Session 列表，One-tap Start |
| **Article 4: Intuitive Mapping** | `Session`, `Block` (data-model.md) | ✅ PASS | 三级结构: Session → Block → Set (运行时计算) |
| **Article 5: Flexible Rigidity** | `TimerViewModel.addSet()`, `extendRest()` (contracts §3) | ✅ PASS | 运行时调整方法已定义 |
| **Article 6: Island & Lock Screen** | `SessionTimerAttributes` (data-model.md), Widget Extension (project structure) | ✅ PASS | ActivityKit 数据结构和 Widget Extension 已规划 |
| **Article 7: Idle Timer Strategy** | `ScreenService` (contracts §6) | ✅ PASS | `updateScreenState(for:)` 根据 phase 和 duration 控制 |
| **Article 8: Distance Legibility** | `TimerViewModel.backgroundColor` (contracts §3) | ✅ PASS | Work 黑底白字, Rest 绿底白字 |

**Post-Design Gate Status**: ✅ ALL PASSED - Ready for Phase 2 (Tasks)

## Project Structure

### Documentation (this feature)

```text
specs/001-session-timer/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
src/
├── project.yml                      # XcodeGen 项目配置文件
├── Makefile                         # 构建命令快捷方式
├── scripts/
│   ├── generate.sh                  # 生成 Xcode 项目
│   ├── build.sh                     # 编译项目
│   ├── run.sh                       # 编译并运行到设备
│   └── test.sh                      # 运行测试
├── App/                             # App 入口 & 配置
│   ├── SessionTimerApp.swift
│   └── Info.plist
├── Models/                          # SwiftData models
│   ├── Session.swift
│   ├── Block.swift
│   └── TimerState.swift
├── Views/                           # SwiftUI views
│   ├── Home/                        # 主界面 (Session 列表)
│   ├── Session/                     # Session 创建/编辑
│   ├── Timer/                       # 计时器界面
│   └── Components/                  # 可复用 UI 组件
├── ViewModels/                      # Observable objects
│   ├── SessionListViewModel.swift
│   ├── SessionEditorViewModel.swift
│   └── TimerViewModel.swift
├── Services/                        # 业务逻辑
│   ├── TimerEngine.swift            # 核心计时逻辑
│   ├── HapticService.swift          # 触觉反馈
│   ├── AudioService.swift           # 音效管理
│   └── NotificationService.swift
├── Extensions/                      # Swift 扩展
├── Shared/                          # 主 App 与 Widget 共享代码
│   └── SessionTimerAttributes.swift # Live Activity 数据结构
├── Resources/                       # 资源文件
│   ├── Assets.xcassets
│   └── Sounds/
└── SessionTimer.xcodeproj/          # 由 XcodeGen 生成 (gitignore)

src-widgets/                         # Widget Extension (Live Activities)
├── SessionTimerWidgets.swift
├── LiveActivityView.swift
├── DynamicIslandView.swift
└── Info.plist
```

**Structure Decision**: 
- iOS 单应用结构，使用 SwiftUI + SwiftData + MVVM 架构
- 使用 **XcodeGen** 从 `project.yml` 生成 Xcode 项目，避免 `.xcodeproj` 冲突
- 使用 **xcbeautify** 美化构建输出
- Widget Extension 用于 Live Activities 和 Dynamic Island 支持
- 所有源码及构建配置放置于 `src/` 目录下

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*No violations - all Constitution requirements can be met with the proposed design.*
