<!--
  ============================================================================
  SYNC IMPACT REPORT
  ============================================================================
  Version Change: 1.0.0 → 1.1.0

  Added Sections:
  - Core Vision (核心愿景)
  - Section I: Interaction Principles (交互原则) - Articles 1-3
  - Section II: Data & Structural Principles (数据模型与结构原则) - Articles 4-5
  - Section III: Platform Specifics (iOS 平台特性规范) - Articles 6-7
  - Section IV: Development Toolchain (开发工具链规范) - Articles 8-9 [NEW in v1.1.0]
  - Section V: Visual Constraints (视觉设计底线) - Article 10
  - Governance

  Templates Status:
  - .specify/templates/plan-template.md: ✅ Compatible (Constitution Check section exists)
  - .specify/templates/spec-template.md: ✅ Compatible (No constitution-specific changes needed)
  - .specify/templates/tasks-template.md: ✅ Compatible (Task structure supports constitution compliance)
  - .specify/templates/commands/: N/A (Directory does not exist)

  Follow-up TODOs: None
  ============================================================================
-->

# Session Timer Constitution

本宪法定义了 Session Timer App 的核心设计原则与不可妥协的产品底线。所有功能规格、技术方案与实现代码必须遵守本宪法。

## Core Vision (核心愿景)

本 App 旨在为**"刻意练习"（Deliberate Practice）提供零摩擦的辅助**。

**核心理念**：它不是为了记录数据，而是为了**维持心流（Flow）**。用户在健身或练琴时，手和脑都应专注于当下，而非 App 的交互。

**设计准则**：每一个交互决策都必须回答这个问题——"这会打断用户的心流吗？"

## Section I: Interaction Principles (交互原则)

### Article 1. Eyes-Free & Hands-Busy (盲操作优先)

用户在使用场景中通常无法精准点击屏幕（手持乐器、满手汗水、正在举铁）。

**原则**：
- 核心计时操作（开始、暂停、下一组、跳过）必须支持**全屏手势或超大触控区**
- 推崇手势设计：
  - **单击屏幕任意位置**：暂停/继续
  - **长按**：结束 Session
  - **双击**：跳过当前阶段

**禁止**：
- 在计时进行中，强制用户点击小于 **44pt × 44pt** 的精确按钮

### Article 2. Sensory Feedback Hierarchy (感官反馈层级)

为了减少看屏幕的频率，**听觉和触觉反馈是第一公民，视觉是第二公民**。

**听觉 (Auditory)**：
- 必须支持**音频混音（Audio Ducking）**，不打断用户原本播放的背景音乐或节拍器
- 提示音必须有区分度：开始、休息、结束、倒数各不相同

**触觉 (Haptic)**：
- 利用 Taptic Engine 传达状态：
  - **Heavy Impact**：组间切换
  - **Success**：Session 完成
  - **Warning**：倒计时最后 3 秒

**视觉 (Visual)**：
- 仅在用户**瞥视（Glanceable）**时提供高对比度的关键信息（剩余时间、下一动作）

### Article 3. Flat Start (扁平化启动)

从"打开 App"到"开始计时"的路径必须最短。

**原则**：
- "最近使用的 Session"或"收藏的 Session"必须在一级页面直接可点击开始
- 实现 **One-tap Start**：一次点击即可开始计时

**禁止**：
- 每次开始前都强迫用户进入编辑页面确认时间设置

## Section II: Data & Structural Principles (数据模型与结构原则)

### Article 4. Intuitive Mapping (结构的直觉映射)

数据结构必须严格映射现实世界的心理模型，**不自造概念**。

**层级结构**：
- **Root - Session**：一次完整的练习（如"练腿日"或"音阶爬格子"）
- **Child - Block**：一个动作或项目（如"深蹲"或"C大调"）
- **Unit - Set**：一组，包含 Work Duration + Rest Duration

**复用性原则**：
- Block 应当是可复用的模版
- 修改一个模版时，必须询问用户："仅修改本次"还是"更新所有引用"

### Article 5. Flexible Rigidity (灵活的刚性)

计划是死的，人是活的。App 必须允许在执行过程中临时调整，且不破坏整体流程。

**原则**：
- 在计时过程中，允许临时操作：
  - **加一组**
  - **跳过休息**
  - **延长休息**
- 所有临时调整操作必须在**一步之内**完成

**禁止**：
- 修改当前运行的计时器需要先"停止"再"编辑"

## Section III: Platform Specifics (iOS 平台特性规范)

### Article 6. Island & Lock Screen (岛与锁屏)

鉴于练习时手机常置于谱架或地板上，屏幕可能锁定或运行后台。

**必须实现**：

**Live Activities**：
- 在锁屏界面展示当前进度、剩余时间、下一动作

**Dynamic Island**：
- 利用灵动岛展示极简状态：倒计时饼图、当前 Set / Total Set

**Background Mode**：
- 必须支持后台运行
- 计时结束时通过 **Time Sensitive Notification** 强提醒

### Article 7. Idle Timer Strategy (屏幕常亮策略)

**原则**：
- 当处于 **Work 状态**时，默认保持屏幕常亮（用户可配置）
- 当处于**长 Rest（> 60s）**时，允许屏幕变暗以省电
- 在休息倒计时结束前 **5 秒**，必须唤醒屏幕或发送强提醒

## Section IV: Development Toolchain (开发工具链规范)

### Article 8. Declarative Project Configuration (声明式项目配置)

为避免 Xcode 项目文件冲突和手动维护负担，项目必须使用声明式配置。

**原则**：
- **严禁修改项目配置**：绝对禁止直接修改 `.xcodeproj` 或 `project.pbxproj` 文件。
- **文档驱动 (SDD)**：在编写复杂功能前，MUST 先阅读或生成 `specs/` 下的文档。
- **语言规范**：思考过程、注释和文档使用**中文**；代码命名使用**英文**。
- 使用 **XcodeGen** 从 `project.yml` 生成 `.xcodeproj`
- `.xcodeproj` 文件由工具生成，**不纳入版本控制**
- 新增/删除/移动源文件后，运行 `xcodegen generate` 即可同步

**禁止**：
- 手动在 Xcode 中添加或移动文件到项目
- 直接编辑 `.pbxproj` 文件

### Article 9. Automated Build Pipeline (自动化构建流水线)

开发过程中的构建、测试、运行必须自动化。

**必须实现**：

**构建美化**：
- 使用 **xcbeautify** 美化 xcodebuild 输出，提升可读性

**一键运行**：
- 提供脚本自动检测连接的 iOS 设备
- 支持命令行一键编译 + 安装 + 运行到设备
- 构建失败时清晰显示错误位置
- 每次实现功能后，都需要运行`make run-device`来验证、构建和安装

**推荐工具链**：
```bash
# 生成项目
xcodegen generate

# 构建并运行（自动检测设备）
./scripts/run.sh
```

**禁止**：
- 要求开发者必须打开 Xcode GUI 才能运行应用
- 构建输出混乱难以阅读

## Section V: Visual Constraints (视觉设计底线)

### Article 10. Distance Legibility (远距离可读性)

**原则**：
- 核心计时数字（Timer）在 **2 米距离**（如手机放在健身房地板，人站立时）必须清晰可见

**对比度要求**：
- Work（工作）与 Rest（休息）状态必须有**全屏幕级别的视觉区分**
- 让用户利用余光即可感知状态变化
- 推荐方案：
  - **Working**：黑底白字
  - **Resting**：绿底白字（或其他高反差配色）

## Governance (治理)

### Amendment Procedure (修订程序)

1. 本宪法的任何修改必须记录在变更日志中
2. 重大修改（删除或重新定义原则）必须提供迁移方案
3. 所有功能开发必须在规格阶段进行宪法合规检查

### Compliance Requirements (合规要求)

- 所有 PR/代码审查必须验证是否符合本宪法
- 违反宪法的设计必须在 `plan.md` 的 Complexity Tracking 中提供正当理由
- 无法合规的需求应被拒绝或要求修改

### Versioning Policy (版本策略)

- **MAJOR**：删除或重新定义核心原则（不向后兼容）
- **MINOR**：新增原则或实质性扩展现有指导
- **PATCH**：澄清、措辞修正、非语义性优化

---

**Version**: 1.1.0 | **Ratified**: 2026-02-01 | **Last Amended**: 2026-02-01

### Changelog

#### v1.1.0 (2026-02-01)
- **MINOR**: Added Section IV: Development Toolchain (Articles 8-9)
  - Article 8: Declarative Project Configuration (XcodeGen)
  - Article 9: Automated Build Pipeline (xcbeautify, 一键运行)
- **MINOR**: Original Article 8 → Article 10
