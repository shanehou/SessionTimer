# Implementation Plan: 快速开始与预备倒计时

**Branch**: `003-quick-start` | **Date**: 2026-03-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-quick-start/spec.md`

## Summary

为 Session Timer 新增"快速开始"功能入口和"预备倒计时"阶段。快速开始允许用户跳过保存流程，在专用页面快速配置练习项目后立即开始计时；预备倒计时在正式计时前提供可配置的准备时间（蓝底白字全屏倒计时）。训练结束后可选择将配置保存为正式 Session。技术方案基于现有 SwiftData 模型扩展和 TimerPhase 状态机增强，复用现有计时器基础设施。

## Technical Context

**Language/Version**: Swift 6.0, Strict Concurrency  
**Primary Dependencies**: SwiftUI, SwiftData, CADisplayLink, AVFoundation, ActivityKit  
**Storage**: SwiftData with CloudKit sync  
**Testing**: XCTest  
**Target Platform**: iOS 17.0+  
**Project Type**: Mobile (iOS)  
**Performance Goals**: 60fps 计时动画; 快速开始页面到开始计时 ≤ 30 秒 (SC-001)  
**Constraints**: 预备时间 0-30 秒; 快速开始缓存仅内存（App 重启丢失）; 离线可用  
**Scale/Scope**: 新增 2 个 View + 1 个 ViewModel; 修改 Session 模型、TimerPhase、TimerService、TimerView 等

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-design Gate

| Article | Requirement | Compliance | Notes |
|---------|-------------|------------|-------|
| Art. 1: Eyes-Free & Hands-Busy | 计时中支持全屏手势 | ✅ Compliant | 快速开始复用现有 TimerView，预备阶段继承所有手势 |
| Art. 2: Sensory Feedback Hierarchy | 听觉/触觉优先于视觉 | ✅ Compliant | 预备倒计时最后 3 秒 Warning haptic + 提示音；完成过渡 Heavy Impact |
| Art. 3: Flat Start | 最短启动路径 | ✅ Compliant | 快速开始在主页一级可达，3 步启动 (FR-001, SC-005) |
| Art. 4: Intuitive Mapping | Session → Block → Set 映射 | ✅ Compliant | 快速开始使用相同的 Block 模型，保存后与手动创建无差异 |
| Art. 5: Flexible Rigidity | 运行时临时调整 | ✅ Compliant | 计时执行完全复用现有 TimerView，所有调整能力继承 |
| Art. 6: Island & Lock Screen | Live Activities + Dynamic Island | ✅ Compliant | 快速开始使用相同的计时基础设施，Live Activities 自动支持 |
| Art. 7: Idle Timer Strategy | 屏幕常亮策略 | ✅ Compliant | 预备阶段保持屏幕常亮（用户即将开始练习） |
| Art. 8: Declarative Config | XcodeGen | ✅ Compliant | 新文件通过 project.yml 管理 |
| Art. 9: Automated Build | make run-device | ✅ Compliant | 使用现有构建脚本 |
| Art. 10: Distance Legibility | 2 米可读 | ✅ Compliant | 预备倒计时使用 128pt 单色大号字体 + 蓝底白字高对比 |

**Gate Result**: ✅ PASS — 无违规项

### Post-design Re-check

| Article | Design Element | Compliance | Notes |
|---------|---------------|------------|-------|
| Art. 1: Eyes-Free | QuickStartView 配置页使用标准 Form 控件（非计时中）；TimerView 预备阶段继承全屏手势 | ✅ | 配置阶段允许精确操作（用户此时双手空闲）；计时阶段完全复用 |
| Art. 2: Sensory Feedback | Preparing 最后 3 秒 Warning haptic + 倒数提示音；preparing→work Heavy Impact + "开始"音效 | ✅ | 反馈层级与 work→rest 过渡一致 |
| Art. 3: Flat Start | 快速开始按钮在 SessionListView 一级可达；3 步启动（打开→配置→开始） | ✅ | 符合 SC-005 |
| Art. 4: Intuitive Mapping | 快速开始使用相同 Session→Block 模型；保存后与手动创建 Session 无差异 | ✅ | 临时 Session 不引入新概念 |
| Art. 5: Flexible Rigidity | TimerView 运行时调整（加组、跳过、延长）完全继承 | ✅ | 无新增限制 |
| Art. 6: Island & Lock Screen | Preparing 阶段通过现有 TimerService 基础设施支持 Live Activities | ✅ | Dynamic Island 显示蓝色主题 |
| Art. 7: Idle Timer | Preparing 阶段保持屏幕常亮（与 Work 一致） | ✅ | 用户即将开始练习，需要看到倒计时 |
| Art. 8: Declarative Config | 新文件通过 project.yml 管理；不修改 .xcodeproj | ✅ | 3 个新文件 + 修改已有文件 |
| Art. 9: Automated Build | 使用现有 make run-device 验证 | ✅ | 无构建流程变更 |
| Art. 10: Distance Legibility | Preparing 倒计时使用 128pt 单色字体 + 蓝底白字高对比度 | ✅ | 2 米距离可读 |

**Re-check Result**: ✅ PASS — 设计阶段无新增违规

## Project Structure

### Documentation (this feature)

```text
specs/003-quick-start/
├── plan.md              # This file
├── research.md          # Phase 0: 技术研究
├── data-model.md        # Phase 1: 数据模型变更
├── quickstart.md        # Phase 1: 实现快速入门
└── contracts/
    └── quick-start-service.md  # Phase 1: 快速开始服务契约
```

### Source Code (repository root)

```text
src/
├── Models/
│   ├── Session.swift              # [MODIFY] 添加 preparingDuration 字段
│   ├── TimerPhase.swift           # [MODIFY] 添加 .preparing case
│   ├── TimerState.swift           # [MODIFY] 支持 preparing 阶段流转
│   └── QuickStartCache.swift      # [NEW] 内存缓存快速开始配置
├── Views/
│   ├── Home/
│   │   └── SessionListView.swift  # [MODIFY] 添加快速开始入口按钮
│   ├── QuickStart/
│   │   └── QuickStartView.swift   # [NEW] 快速开始配置页面
│   ├── Timer/
│   │   ├── TimerView.swift        # [MODIFY] 支持 preparing 阶段显示 + 结束后保存弹窗
│   │   └── TimerDisplay.swift     # [MODIFY] 蓝底白字 preparing 状态
│   └── Session/
│       └── SessionEditorView.swift # [MODIFY] 添加预备时间配置
├── ViewModels/
│   ├── QuickStartViewModel.swift  # [NEW] 快速开始页面状态管理
│   └── TimerViewModel.swift       # [MODIFY] 支持 preparing 阶段反馈
└── Services/
    ├── TimerService.swift         # [MODIFY] preparing 阶段状态机
    ├── AudioService.swift         # [MODIFY] preparing 音效
    └── HapticService.swift        # [MODIFY] preparing 触觉反馈
```

**Structure Decision**: 沿用现有 iOS 单应用结构。新增 `Views/QuickStart/` 目录放置快速开始专属视图；模型和服务层以修改为主，新增最少文件。

## Complexity Tracking

无宪法违规，无需记录。
