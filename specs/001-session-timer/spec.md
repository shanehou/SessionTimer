# Feature Specification: Session Timer - 重复练习计时器App

**Feature Branch**: `001-session-timer`  
**Created**: 2026-02-01  
**Status**: Draft  
**Input**: User description: "我想做一个iOS的计时器App，主要针对于各种需要重复练习的场景，比如练习乐器或者健身。日常使用的场景举例：1. 某次健身Session，包含多个动作，每个动作有多组，每组都有动作时间和休息时间。2. 某次练习乐器基本功的Session，包含多项基本功需要练习，每项有多组，每组有练习时间和休息时间。我希望App可以直观、符合直觉、操作起来高效率"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 创建并执行练习Session (Priority: P1)

用户希望创建一个完整的练习Session，包含多个练习项目，每个项目有多组，每组有练习时间和休息时间，然后开始执行这个Session。

**Why this priority**: 这是App的核心价值主张。没有创建和执行Session的能力，App就没有存在的意义。这是用户最基本、最频繁使用的功能。

**Independent Test**: 可以通过创建一个包含2个练习项目的Session（每个项目2组，每组30秒练习+10秒休息），然后完整执行一遍来验证。成功标准是用户能够从创建到完成整个流程。

**Acceptance Scenarios**:

1. **Given** 用户在主界面, **When** 用户点击创建新Session, **Then** 系统显示Session创建界面，用户可以输入Session名称
2. **Given** 用户在Session创建界面, **When** 用户添加练习项目并设置组数、练习时间、休息时间, **Then** 系统保存这些设置并显示在项目列表中
3. **Given** 用户已创建包含练习项目的Session, **When** 用户点击开始, **Then** 系统开始计时并显示当前进度（当前项目、当前组、剩余时间）
4. **Given** 计时器正在运行, **When** 练习时间结束, **Then** 系统自动切换到休息倒计时，并通过声音/震动提醒用户
5. **Given** 计时器正在运行, **When** 休息时间结束, **Then** 系统自动开始下一组或下一个项目的练习时间

---

### User Story 2 - 快速启动常用Session (Priority: P2)

用户希望能够保存创建的Session，并在之后快速启动常用的练习计划，无需每次重新创建。

**Why this priority**: 用户使用的主要场景是重复练习，因此保存和复用Session是提高效率的关键功能。没有这个功能，用户每次都需要重新设置，体验会很差。

**Independent Test**: 可以通过创建一个Session，保存后退出App，重新打开App后在列表中找到并一键启动该Session来验证。

**Acceptance Scenarios**:

1. **Given** 用户创建了一个Session, **When** 用户保存Session, **Then** Session出现在主界面的Session列表中
2. **Given** 主界面显示已保存的Session列表, **When** 用户点击某个Session, **Then** 系统显示Session详情和开始按钮
3. **Given** 用户在Session详情页, **When** 用户点击开始按钮, **Then** 系统立即开始执行该Session的计时流程
4. **Given** 用户有多个已保存的Session, **When** 用户查看主界面, **Then** Session列表按最近使用时间排序，方便快速找到常用Session

---

### User Story 3 - 计时过程中的控制操作 (Priority: P3)

用户希望在计时过程中能够暂停、继续、跳过当前组或直接结束Session。由于用户在练习时手可能无法精准操作（如正在举铁或手持乐器），交互必须支持盲操作。

**Why this priority**: 这是计时App的基础交互功能。虽然不如创建和执行核心，但没有这些控制会让用户在实际使用中感到受限（比如接电话需要暂停）。

**Independent Test**: 可以通过启动一个Session，然后测试暂停/继续、跳过当前组、提前结束等操作来验证。

**Acceptance Scenarios**:

1. **Given** 计时器正在运行, **When** 用户单击屏幕任意位置, **Then** 计时暂停，界面显示已暂停状态
2. **Given** 计时器已暂停, **When** 用户单击屏幕任意位置, **Then** 计时从暂停位置继续
3. **Given** 计时器正在运行, **When** 用户双击屏幕, **Then** 系统跳过当前阶段（练习或休息），进入下一个阶段
4. **Given** 计时器正在运行, **When** 用户长按屏幕, **Then** 系统停止计时并返回主界面

---

### User Story 4 - 编辑和管理已有Session (Priority: P4)

用户希望能够编辑已保存的Session（修改时间、增删项目）或删除不需要的Session。

**Why this priority**: 用户的练习计划可能会随时间调整，需要能够修改现有Session。这是管理功能，优先级低于核心使用功能。

**Independent Test**: 可以通过修改一个已保存Session的练习时间，保存后重新打开验证修改是否生效来测试。

**Acceptance Scenarios**:

1. **Given** 用户在Session详情页, **When** 用户点击编辑, **Then** 系统进入编辑模式，用户可以修改Session设置
2. **Given** 用户在编辑模式, **When** 用户修改练习项目的时间或组数并保存, **Then** 系统保存修改并更新Session详情
3. **Given** 用户在Session列表, **When** 用户左滑某个Session并点击删除, **Then** 系统确认后删除该Session

---

### User Story 5 - 后台运行与提醒 (Priority: P5)

用户希望在App切换到后台或锁屏时，计时器继续运行并在阶段切换时提醒用户。由于练习时手机常置于谱架或地板上，用户需要在锁屏界面看到进度。

**Why this priority**: 练习场景中用户可能不会一直盯着屏幕（如健身时），后台运行和提醒是实用性的重要保障。

**Independent Test**: 可以通过启动一个Session，锁屏等待，验证阶段切换时是否收到声音/震动提醒，以及锁屏界面是否显示进度来测试。

**Acceptance Scenarios**:

1. **Given** 计时器正在运行, **When** 用户锁屏或切换到其他App, **Then** 计时器继续在后台运行
2. **Given** 计时器在后台运行, **When** 练习或休息阶段结束, **Then** 系统通过通知提醒用户阶段切换
3. **Given** 用户收到阶段切换通知, **When** 用户点击通知, **Then** 系统返回App并显示当前计时状态
4. **Given** 计时器正在运行且设备锁屏, **When** 用户查看锁屏界面, **Then** 系统通过 Live Activities 显示当前进度、剩余时间、下一动作
5. **Given** 设备支持灵动岛且计时器正在运行, **When** 用户查看灵动岛, **Then** 系统显示倒计时饼图和当前组数/总组数

---

### Edge Cases

- 当用户在创建Session时未添加任何练习项目就点击保存，系统应提示至少添加一个练习项目
- 当用户设置的练习时间或休息时间为0秒，系统应允许（可能用于无休息的连续练习）
- 当计时器运行中App被系统强制终止（如内存不足），重新打开App时应显示之前的Session并提供继续选项
- 当用户在最后一组的最后阶段点击跳过，系统应结束整个Session并显示完成界面
- 当设备处于静音模式，阶段切换时系统应通过震动提醒用户

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统必须允许用户创建新的练习Session，包含Session名称
- **FR-002**: 系统必须允许用户在Session中添加多个Block（动作/项目），每个Block包含名称、组数（Set）、练习时间（Work Duration）、休息时间（Rest Duration）
- **FR-003**: 系统必须按顺序执行Session中的所有Block，每个Block按组数循环练习时间和休息时间
- **FR-004**: 系统必须在练习界面清晰显示当前状态：当前Block名称、当前组数/总组数、当前阶段（Work/Rest）、剩余时间
- **FR-005**: 系统必须在阶段切换时提供多层次感官反馈：
  - 听觉：区分度明确的提示音（开始、休息、结束、倒数），支持音频混音不打断背景音乐
  - 触觉：Heavy Impact（组间切换）、Success（Session完成）、Warning（倒计时最后3秒）
- **FR-006**: 系统必须支持全屏手势控制：单击暂停/继续、双击跳过、长按结束
- **FR-007**: 计时过程中所有触控区域必须不小于44pt × 44pt
- **FR-008**: 系统必须允许用户在计时过程中一步完成临时调整（加一组、跳过休息、延长休息）
- **FR-009**: 系统必须持久化保存用户创建的Session，App重启后数据不丢失
- **FR-010**: 系统必须在主界面一级页面显示最近使用/收藏的Session，支持One-tap Start
- **FR-011**: 系统必须允许用户编辑已保存的Session（修改名称、Block、时间设置）
- **FR-012**: 修改Block模板时，系统必须询问用户是"仅修改本次"还是"更新所有引用"
- **FR-013**: 系统必须允许用户删除不需要的Session
- **FR-014**: 系统必须支持后台运行，锁屏或切换App后计时继续
- **FR-015**: 系统必须通过Time Sensitive Notification在后台阶段切换时强提醒用户
- **FR-016**: 系统必须实现Live Activities，在锁屏界面展示当前进度、剩余时间、下一动作
- **FR-017**: 系统必须实现Dynamic Island支持，展示倒计时饼图和当前Set/Total Set
- **FR-018**: Work状态下系统必须保持屏幕常亮（用户可配置）
- **FR-019**: 长Rest（>60s）时允许屏幕变暗，但结束前5秒必须唤醒或强提醒
- **FR-020**: 系统必须在Session完成后显示完成界面
- **FR-021**: Work与Rest状态必须有全屏幕级别的视觉区分（如背景色反转：Working=黑底白字，Resting=绿底白字）
- **FR-022**: 核心计时数字在2米距离必须清晰可见

### Key Entities

- **Session（练习计划）**: 代表一次完整的练习（如"练腿日"或"音阶爬格子"），包含名称、创建时间、最近使用时间、Block列表
- **Block（动作/项目）**: 代表Session中的一个动作或练习项目（如"深蹲"或"C大调"），包含名称、组数、单组练习时长（Work Duration）、组间休息时长（Rest Duration）、在Session中的顺序。Block可作为模板复用。
- **Set（组）**: 代表Block中的一组，由Work Duration + Rest Duration组成
- **Timer State（计时状态）**: 代表当前的计时运行状态，包含当前Session引用、当前Block索引、当前Set数、当前阶段（Work/Rest）、剩余秒数、是否暂停

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 用户能在60秒内创建一个包含3个Block的新Session
- **SC-002**: 用户能在1次点击内从主界面启动一个最近使用的Session（One-tap Start）
- **SC-003**: 阶段切换提醒在切换发生时的1秒内触达用户（声音/震动/通知）
- **SC-004**: 90%的用户能在首次使用时无需教程即可完成创建和执行Session的完整流程
- **SC-005**: App在后台运行时，计时精度偏差不超过1秒
- **SC-006**: 用户创建的Session数据在App重启、设备重启后100%保留
- **SC-007**: 核心计时数字在2米距离100%清晰可辨
- **SC-008**: 用户利用余光即可感知Work/Rest状态变化（全屏背景色区分）
- **SC-009**: 计时过程中所有控制操作通过全屏手势完成，无需精确点击

## Assumptions

- 用户使用的iOS设备支持后台运行和本地通知
- 用户已授予App发送通知的权限（如未授予，后台提醒功能受限）
- 每个Session的Block数量合理（假设上限为50个Block）
- 单组练习时间和休息时间范围为0秒至99分59秒
- 用户主要使用场景为健身和乐器练习，但App设计不限定特定领域
- 目标设备支持Live Activities和Dynamic Island（iOS 16.1+）
- 用户设备支持Taptic Engine触觉反馈

## Constitution Compliance

本规格遵循 Session Timer Constitution v1.0.0，具体对应关系：

| 宪法条款 | 对应需求 |
|---------|---------|
| Article 1: Eyes-Free & Hands-Busy | FR-006, FR-007, SC-009 |
| Article 2: Sensory Feedback Hierarchy | FR-005 |
| Article 3: Flat Start | FR-010, SC-002 |
| Article 4: Intuitive Mapping | Key Entities |
| Article 5: Flexible Rigidity | FR-008, FR-012 |
| Article 6: Island & Lock Screen | FR-016, FR-017, FR-015 |
| Article 7: Idle Timer Strategy | FR-018, FR-019 |
| Article 8: Distance Legibility | FR-021, FR-022, SC-007, SC-008 |
