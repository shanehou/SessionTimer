# Quickstart: 快速开始与预备倒计时

**Feature**: 003-quick-start  
**Date**: 2026-03-07  
**Status**: Complete

## 实现概览

本功能分为两个核心模块和一系列适配修改：

| 模块 | 范围 | 复杂度 |
|------|------|--------|
| **快速开始流程** | 新页面 + ViewModel + 缓存 + 保存弹窗 | 中 |
| **预备倒计时** | TimerPhase 扩展 + TimerService 修改 + 视觉/反馈适配 | 低-中 |
| **已有页面适配** | SessionEditorView + SessionListView | 低 |

## 实现顺序（推荐）

### Step 1: 数据模型扩展

**目标**: 为后续所有功能提供数据基础

1. **Session.swift** — 添加 `preparingDuration: Int` 字段（默认值 0）
2. **TimerPhase.swift** — 添加 `.preparing` case，扩展背景色和状态标签
3. **QuickStartCache.swift** — 新建内存缓存单例

**验证**: 编译通过，现有测试不受影响（所有现有 Session 的 preparingDuration = 0）

### Step 2: 预备倒计时核心逻辑

**目标**: 计时器支持 preparing 阶段

1. **TimerState.swift** — 修改 `nextPhase()` 方法，处理 `.preparing → .work` 过渡
2. **TimerService.swift** — 修改 `start()` 方法，根据 `preparingDuration` 决定初始阶段
3. **TimerViewModel.swift** — 处理 preparing 阶段的感官反馈（音效、触觉）

**验证**: 手动创建一个 `preparingDuration = 5` 的 Session，启动后先显示 5 秒预备倒计时，然后自动进入 Work 阶段

### Step 3: 预备倒计时 UI

**目标**: 计时界面正确显示 preparing 状态

1. **TimerDisplay.swift** — 蓝底白字背景、"准备"状态标签
2. **TimerView.swift** — preparing 阶段支持手势（暂停、跳过、结束）
3. **Live Activity / Dynamic Island** — preparing 阶段的灵动岛和锁屏显示

**验证**: 预备倒计时界面视觉正确（蓝底白字），手势正常工作，双击可跳过

### Step 4: SessionEditorView 适配

**目标**: 已保存 Session 也可以配置预备时间

1. **SessionEditorView.swift** — 添加"预备时间"配置项（Stepper 或 Picker，0-30秒）
2. **SessionEditorViewModel.swift** — 添加 `preparingDuration` 属性

**验证**: 编辑已有 Session，设置预备时间，启动后正确执行预备倒计时

### Step 5: 快速开始页面

**目标**: 实现快速开始配置界面

1. **QuickStartView.swift** — 新建快速开始页面（项目配置卡片列表 + 预备时间 + 开始按钮）
2. **QuickStartViewModel.swift** — 新建 ViewModel（Block 管理、缓存读写、Session 创建）
3. **SessionListView.swift** — 添加"快速开始"入口按钮

**验证**: 从主页进入快速开始，配置项目，点击开始进入计时。退出后再次打开快速开始，上次配置自动恢复

### Step 6: 保存弹窗

**目标**: 训练结束后可保存为正式 Session

1. **TimerView.swift** — 添加保存弹窗 UI（Alert with TextField）
2. **TimerViewModel.swift** — 添加 `isQuickStartMode`、`showSaveDialog`、`saveQuickStartSession()` 等

**验证**: 快速开始训练结束后弹出保存对话框；选择保存后 Session 出现在主页列表；选择不保存则不持久化

### Step 7: 收尾与边界情况

**目标**: 处理边界情况和体验优化

1. 预备时间为 0 时跳过预备阶段（兼容测试）
2. 练习/休息时长为 0 的阶段自动跳过
3. 快速开始中 App 进入后台的行为验证
4. 大量项目（>20 个）的滚动性能验证
5. `make run-device` 真机验证

## 关键依赖关系

```
Step 1 (数据模型) ─── 无依赖，可直接开始
    │
    ├──→ Step 2 (预备逻辑) ── 依赖 TimerPhase.preparing
    │       │
    │       └──→ Step 3 (预备 UI) ── 依赖预备逻辑
    │
    ├──→ Step 4 (Editor 适配) ── 依赖 Session.preparingDuration
    │
    └──→ Step 5 (快速开始页面) ── 依赖 QuickStartCache
            │
            └──→ Step 6 (保存弹窗) ── 依赖快速开始流程
                    │
                    └──→ Step 7 (收尾) ── 依赖所有步骤
```

## 新增文件清单

| 文件路径 | 类型 | 描述 |
|----------|------|------|
| `src/Models/QuickStartCache.swift` | 新增 | 内存配置缓存 |
| `src/Views/QuickStart/QuickStartView.swift` | 新增 | 快速开始配置页面 |
| `src/ViewModels/QuickStartViewModel.swift` | 新增 | 快速开始 ViewModel |

## 修改文件清单

| 文件路径 | 修改范围 | 描述 |
|----------|----------|------|
| `src/Models/Session.swift` | 小 | 添加 `preparingDuration` 字段 |
| `src/Models/TimerPhase.swift` | 小 | 添加 `.preparing` case |
| `src/Models/TimerState.swift` | 中 | preparing → work 过渡逻辑 |
| `src/Services/TimerService.swift` | 中 | start() 初始阶段判断 |
| `src/ViewModels/TimerViewModel.swift` | 中 | preparing 反馈 + 保存弹窗状态 |
| `src/Views/Timer/TimerView.swift` | 中 | preparing 显示 + 保存弹窗 UI |
| `src/Views/Timer/TimerDisplay.swift` | 小 | 蓝底白字 + "准备"标签 |
| `src/Views/Home/SessionListView.swift` | 小 | 快速开始入口按钮 |
| `src/Views/Session/SessionEditorView.swift` | 小 | 预备时间配置 |
| `src/ViewModels/SessionEditorViewModel.swift` | 小 | preparingDuration 属性 |
| `project.yml` | 小 | 如有需要，添加新文件路径 |

## 注意事项

- **XcodeGen**: 新增文件后需运行 `xcodegen generate`
- **CloudKit**: Session 新字段 `preparingDuration` 使用默认值，向后兼容
- **并发安全**: QuickStartCache 为单例，需确保 `@MainActor` 隔离或线程安全
- **内存管理**: 用户选择不保存时，临时 Session 和 Block 对象需要被正确释放（无强引用循环）
