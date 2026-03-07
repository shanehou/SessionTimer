# Tasks: 快速开始与预备倒计时

**Input**: Design documents from `/specs/003-quick-start/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Foundational (Data Model & Infrastructure)

**Purpose**: 数据模型扩展与共享基础设施，所有用户故事的前置依赖

**⚠️ CRITICAL**: 所有用户故事的实现必须等待本阶段完成

- [X] T001 Add `preparingDuration: Int` field (default `0`, range 0-30) to Session model in `src/Models/Session.swift` — 轻量级迁移，现有 Session 自动获得默认值 0
- [X] T002 [P] Add `.preparing` case to TimerPhase enum in `src/Models/TimerPhase.swift` — 包括 `backgroundColor` (Color.blue/#007AFF)、`statusLabel` ("准备") 等关联属性扩展
- [X] T003 [P] Create QuickStartCache singleton in `src/Models/QuickStartCache.swift` — `@Observable` 单例，包含 `BlockConfig` struct (name/setCount/workDuration/restDuration)、`save()`、`load()` 方法，纯内存不持久化

**Checkpoint**: 编译通过，现有功能不受影响（所有 Session 的 preparingDuration = 0，TimerPhase 新 case 在现有代码中无引用）

---

## Phase 2: User Story 1 — 快速配置并立即开始计时 (Priority: P1) 🎯 MVP

**Goal**: 用户从主页一键进入快速开始页面，配置一个练习项目后立即开始计时，无需保存步骤

**Independent Test**: 打开快速开始页面，设定一个项目（如"俯卧撑"，3组，30秒练习，15秒休息），点击开始，验证计时器能正确按设定运行

### Implementation for User Story 1

- [X] T004 [US1] Implement QuickStartViewModel in `src/ViewModels/QuickStartViewModel.swift`
- [X] T005 [US1] Implement QuickStartView in `src/Views/QuickStart/QuickStartView.swift`
- [X] T006 [US1] Add quick start entry button to `src/Views/Home/SessionListView.swift`
- [X] T007 [US1] Wire QuickStartView sheet presentation and TimerView navigation in `src/Views/Home/ContentView.swift`
- [X] T008 [US1] Run `xcodegen generate` and verify build and basic flow with `make run-device`

**Checkpoint**: 用户可以从主页进入快速开始，配置单个项目，点击开始进入现有 TimerView 计时。训练结束后回到主页（此时无保存弹窗）。再次打开快速开始，上次配置自动恢复

---

## Phase 3: User Story 2 — 添加多个练习项目 (Priority: P2)

**Goal**: 用户在快速开始页面可以添加多个练习项目，组成完整的临时 Session

**Independent Test**: 在快速开始页面添加 3 个不同项目，分别设定不同的组数和时长，点击开始后验证计时器按顺序执行所有项目

### Implementation for User Story 2

- [X] T009 [US2] Add multi-block management to `src/ViewModels/QuickStartViewModel.swift`
- [X] T010 [US2] Add multi-block UI to `src/Views/QuickStart/QuickStartView.swift`
- [X] T011 [US2] Verify multi-block quick start flow with `make run-device`

**Checkpoint**: 用户可以在快速开始页面添加、删除、重排多个项目，计时器按顺序正确执行

---

## Phase 4: User Story 3 — 完成后保存为计划 (Priority: P3)

**Goal**: 快速开始训练结束后弹窗询问是否保存，保存后的 Session 与手动创建的完全一致

**Independent Test**: 通过快速开始完成一次训练，在弹窗中选择保存，验证保存后的 Session 出现在主界面 Session 列表中，且可正常启动

### Implementation for User Story 3

- [X] T012 [US3] Add quick start save logic to `src/ViewModels/TimerViewModel.swift`
- [X] T013 [US3] Add save dialog UI to `src/Views/Timer/TimerView.swift`
- [X] T014 [US3] Verify save flow with `make run-device`

**Checkpoint**: 快速开始训练结束后出现保存弹窗，保存成功的 Session 在主页可见且功能完整

---

## Phase 5: User Story 4 — 预备倒计时 (Priority: P4)

**Goal**: 计时开始前执行可配置的预备倒计时（蓝底白字），支持快速开始和已保存 Session

**Independent Test**: 设定 5 秒预备时间，启动计时，验证系统先显示 5 秒蓝底白字预备倒计时，倒计时结束后自动进入第一个项目的 Work 阶段

### Implementation for User Story 4

- [X] T015 [US4] Add preparing → work transition logic to `src/Models/TimerState.swift`
- [X] T016 [US4] Modify `start()` to support preparing phase in `src/Services/TimerService.swift`
- [X] T017 [P] [US4] Add preparing phase sensory feedback in `src/ViewModels/TimerViewModel.swift`
- [X] T018 [P] [US4] Add preparing phase visual display in `src/Views/Timer/TimerDisplay.swift`
- [X] T019 [US4] Verify preparing phase gesture support in `src/Views/Timer/TimerView.swift`
- [X] T020 [US4] Add preparingDuration property to `src/ViewModels/SessionEditorViewModel.swift`
- [X] T021 [P] [US4] Add preparing duration picker to `src/Views/QuickStart/QuickStartView.swift`
- [X] T022 [P] [US4] Add preparing duration picker to `src/Views/Session/SessionEditorView.swift`
- [X] T023 [US4] Update Live Activity and Dynamic Island for preparing phase
- [X] T024 [US4] Update ScreenService for preparing phase in `src/Services/ScreenService.swift`
- [X] T025 [US4] Verify preparing countdown end-to-end with `make run-device`

**Checkpoint**: 预备倒计时在快速开始和已保存 Session 中均正常工作，蓝底白字视觉正确，手势/音效/触觉反馈完整

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 边界情况处理与最终验证

- [X] T026 [P] Handle edge case: work/rest duration = 0 auto-skip verification
- [X] T027 [P] Handle edge case: large number of blocks (>20) scrolling performance
- [X] T028 Handle edge case: App backgrounding during quick start
- [X] T029 Final end-to-end validation with `make run-device`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: 无依赖，可直接开始 — BLOCKS 所有用户故事
- **US1 (Phase 2)**: 依赖 Phase 1 完成 — 不依赖其他用户故事
- **US2 (Phase 3)**: 依赖 US1 完成（扩展 QuickStartView/ViewModel）
- **US3 (Phase 4)**: 依赖 US1 完成（需要快速开始 → 计时流程）
- **US4 (Phase 5)**: 依赖 Phase 1 完成 — 与 US2/US3 无互相依赖
- **Polish (Phase 6)**: 依赖所有用户故事完成

### User Story Dependencies

```
Phase 1 (Foundational) ─── 无依赖
    │
    ├──→ Phase 2 (US1: 快速配置) ── 依赖 Phase 1
    │       │
    │       ├──→ Phase 3 (US2: 多项目) ── 依赖 US1
    │       │
    │       └──→ Phase 4 (US3: 保存弹窗) ── 依赖 US1
    │
    └──→ Phase 5 (US4: 预备倒计时) ── 依赖 Phase 1，与 US2/US3 独立
            │
            └──→ Phase 6 (Polish) ── 依赖所有 US
```

### Within Each Phase

- ViewModel before View（View 依赖 ViewModel 接口）
- Model/Service before ViewModel（ViewModel 依赖数据层）
- Core logic before UI adaptation
- 每个 Phase 最后一个 task 为构建验证

### Parallel Opportunities

**Phase 1 (Foundational):**
- T002 (TimerPhase) 和 T003 (QuickStartCache) 可与 T001 并行

**Phase 2 (US1):**
- T004 (ViewModel) 需先于 T005 (View)，但 T006 (SessionListView) 可与 T004/T005 并行

**Phase 5 (US4):**
- T015 → T016 必须顺序执行（状态机 → 服务层）
- T017 (feedback) 和 T018 (display) 可并行（不同文件，均依赖 T016 完成后）
- T021 (QuickStartView picker) 和 T022 (SessionEditorView picker) 可并行
- T023 (Live Activity) 和 T024 (ScreenService) 可与 UI 任务并行

**跨 Phase:**
- US2 (Phase 3) 和 US4 (Phase 5) 可在 US1 完成后并行推进（US4 仅依赖 Phase 1）
- US3 (Phase 4) 可与 US4 (Phase 5) 并行

---

## Parallel Example: User Story 4

```bash
# T015 → T016 必须顺序执行
Task: "T015 Add preparing → work transition logic to src/Models/TimerState.swift"
Task: "T016 Modify start() to support preparing phase in src/Services/TimerService.swift"

# T016 完成后，以下任务可并行启动:
Task: "T017 [P] Add preparing phase sensory feedback in src/ViewModels/TimerViewModel.swift"
Task: "T018 [P] Add preparing phase visual display in src/Views/Timer/TimerDisplay.swift"
Task: "T021 [P] Add preparing duration picker to src/Views/QuickStart/QuickStartView.swift"
Task: "T022 [P] Add preparing duration picker to src/Views/Session/SessionEditorView.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Foundational (T001-T003)
2. Complete Phase 2: US1 快速配置并立即开始计时 (T004-T008)
3. **STOP and VALIDATE**: 快速开始 → 单项目配置 → 计时 → 完成 → 返回主页
4. MVP 完成 — 用户已可使用快速开始核心功能

### Incremental Delivery

1. Phase 1 → 数据模型就绪
2. + US1 → 单项目快速开始 (MVP!) ✅
3. + US2 → 多项目快速开始 ✅
4. + US3 → 保存为计划 ✅
5. + US4 → 预备倒计时 ✅
6. + Polish → 边界情况与性能 ✅

每个阶段交付一个完整、可独立验证的功能增量。

---

## Summary

| Phase | User Story | Tasks | Parallel Tasks |
|-------|-----------|-------|----------------|
| Phase 1 | Foundational | 3 | 2 |
| Phase 2 | US1: 快速配置 (P1) 🎯 MVP | 5 | 0 |
| Phase 3 | US2: 多项目 (P2) | 3 | 0 |
| Phase 4 | US3: 保存弹窗 (P3) | 3 | 0 |
| Phase 5 | US4: 预备倒计时 (P4) | 11 | 4 |
| Phase 6 | Polish | 4 | 2 |
| **Total** | | **29** | **8** |

---

## Notes

- [P] tasks = 不同文件，无依赖，可并行执行
- [Story] label 将任务映射到具体用户故事，便于追溯
- 每个 Phase 独立可测试，checkpoint 后验证功能完整性
- 新增文件后必须运行 `xcodegen generate` 更新项目
- 所有验证任务使用 `make run-device` 进行真机测试
- 临时 Session 使用 SwiftData @Model 延迟插入模式（不插入 ModelContext）
