# Tasks: 语音播报

**Input**: Design documents from `/specs/002-voice-announcements/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/speech-service.md, quickstart.md

**Tests**: Not requested — no test tasks included.

**Organization**: Tasks grouped by user story (US1→US2→US3) to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: No project initialization needed — existing project, existing build pipeline.

*This phase is empty. The project structure, XcodeGen configuration, and build scripts are already in place. Proceed directly to Phase 2.*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Data model extensions and core SpeechService that ALL user stories depend on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T001 [P] Add `announcementStart: String?`, `announcementRest: String?`, `announcementContinue: String?` properties to Block model in `src/Models/Block.swift`
  - Add three optional String properties after existing properties
  - SwiftData auto-migration handles existing data (nil defaults)
  - Reference: `specs/002-voice-announcements/data-model.md` § Block

- [X] T002 [P] Add `announcementComplete: String?` property to Session model in `src/Models/Session.swift`
  - Add one optional String property after existing properties
  - SwiftData auto-migration handles existing data (nil defaults)
  - Reference: `specs/002-voice-announcements/data-model.md` § Session

- [X] T003 [P] Create SpeechService with AVSpeechSynthesizer and NLLanguageRecognizer in `src/Services/SpeechService.swift`
  - `@MainActor final class SpeechService` with `static let shared`
  - Hold `AVSpeechSynthesizer` instance
  - `speak(_ text: String)`: guard empty → `stopSpeaking(.immediate)` → detect language → create utterance with matched voice → `speak(utterance)`
  - `stop()`: call `stopSpeaking(.immediate)`
  - `var isSpeaking: Bool`: proxy to synthesizer
  - Private `detectLanguage(for:) -> String`: use `NLLanguageRecognizer`, map `.simplifiedChinese/.traditionalChinese` → `"zh-CN"`, `.english` → `"en-US"`, `.japanese` → `"ja-JP"`, default fallback `"zh-CN"`
  - Private `selectVoice(for:) -> AVSpeechSynthesisVoice?`: call `detectLanguage` then `AVSpeechSynthesisVoice(language:)`
  - Configure utterance: `rate = AVSpeechUtteranceDefaultSpeechRate`, `pitchMultiplier = 1.0`, `volume = 1.0`
  - No separate AVAudioSession config needed (reuses AudioService's existing session)
  - Reference: `specs/002-voice-announcements/contracts/speech-service.md`, `specs/002-voice-announcements/research.md` § Task 1, 2, 6

- [X] T004 Run `make generate` to register new `SpeechService.swift` in Xcode project
  - `src/Services/` is already in project.yml sources, so `xcodegen generate` picks up the new file automatically
  - Verify compilation succeeds with `make build`

**Checkpoint**: Foundation ready — models extended, SpeechService created, project compiles. User story implementation can begin.

---

## Phase 3: User Story 1 — 计时阶段自动语音播报 (Priority: P1) 🎯 MVP

**Goal**: 在每个计时阶段切换时自动播报语音提示（Block 名称、"休息"、"继续"、"训练完成"），使用默认文本即可完整工作，语音替代 Work/Rest 开始音效。

**Independent Test**: 创建一个含有多个 Block（各含多组）的 Session，启动计时，验证：Block 首组 Work 播报 Block 名称、Rest 播报"休息"、后续组 Work 播报"继续"、Session 完成播报"训练完成"。倒计时音效保持不变。

### Implementation for User Story 1

- [X] T005 [US1] Add speechService property, @AppStorage flag, and announcement text resolution method to TimerViewModel in `src/ViewModels/TimerViewModel.swift`
  - Add `private let speechService = SpeechService.shared`
  - Add `@AppStorage("isVoiceAnnouncementEnabled") private var isVoiceAnnouncementEnabled: Bool = true`
  - Add `resolveAnnouncementText(phase: TimerPhase, block: Block, set: Int) -> String`:
    - `.work` where `set == 1` → `block.announcementStart?.isEmpty == false ? block.announcementStart! : block.name`
    - `.work` where `set > 1` → `block.announcementContinue?.isEmpty == false ? block.announcementContinue! : "继续"`
    - `.rest` → `block.announcementRest?.isEmpty == false ? block.announcementRest! : "休息"`
  - Add `resolveCompletionText(session: Session) -> String`:
    - `session.announcementComplete?.isEmpty == false ? session.announcementComplete! : "训练完成"`
  - Reference: `specs/002-voice-announcements/contracts/speech-service.md` § Integration Contract

- [X] T006 [US1] Modify `handlePhaseChange()` to conditionally use SpeechService instead of Work/Rest start sounds in `src/ViewModels/TimerViewModel.swift`
  - In `handlePhaseChange(phase:blockIndex:set:)`, replace the existing `switch phase` audio block:
    - When `isVoiceAnnouncementEnabled`: resolve text via `resolveAnnouncementText()` → call `speechService.speak(text)`
    - When disabled: keep original `audioService.playWorkStart()` / `audioService.playRestStart()`
  - Haptic feedback (`hapticService.playPhaseTransition()`) remains unconditional
  - Countdown sounds remain unconditional (handled separately in `handleEvent`)
  - Reference: `specs/002-voice-announcements/research.md` § Task 4, spec FR-010

- [X] T007 [US1] Modify `handleSessionComplete()` to conditionally use SpeechService for completion announcement in `src/ViewModels/TimerViewModel.swift`
  - When `isVoiceAnnouncementEnabled`: resolve text via `resolveCompletionText()` → call `speechService.speak(text)` instead of `audioService.playSessionComplete()`
  - When disabled: keep original `audioService.playSessionComplete()`
  - Haptic feedback remains unconditional
  - Reference: spec FR-004, FR-010

- [X] T008 [US1] Build and verify default voice announcements on device by running `make generate && make run-device`
  - Create a Session with 2+ Blocks, each with 2+ sets
  - Verify: Block 首组 Work → Block 名称, Rest → "休息", 后续组 Work → "继续", Session 完成 → "训练完成"
  - Verify: 倒计时音效 (最后 3 秒) 仍正常
  - Verify: 触觉反馈仍正常
  - Verify: 后台时语音仍播报
  - Reference: spec Acceptance Scenarios 1-6, SC-001 to SC-005

**Checkpoint**: User Story 1 complete. Voice announcements work end-to-end with default texts. This is the MVP — usable immediately.

---

## Phase 4: User Story 2 — 自定义播报内容 (Priority: P2)

**Goal**: 用户可以为每个 Block 设置三种自定义播报文本（开始、休息、继续），为 Session 设置完成播报文本。自定义文本为空时自动回退到默认值。

**Independent Test**: 在 Block 编辑界面修改三种播报文本并保存 → 启动计时 → 验证播报的是自定义内容。清空文本后 → 验证回退到默认值。Session 完成播报同理。

### Implementation for User Story 2

- [X] T009 [P] [US2] Add expandable voice announcement section with three TextFields to Block editor in `src/Views/Components/BlockEditorRow.swift`
  - Add a `DisclosureGroup` or expandable section titled "语音播报"
  - Three TextFields bound to `block.announcementStart`, `block.announcementRest`, `block.announcementContinue`
  - Each TextField shows placeholder with default value (e.g., `"默认：\(block.name)"`, `"默认：休息"`, `"默认：继续"`)
  - If text length > 50 chars, show inline hint "建议文本不超过 50 个字符"
  - Data persists via SwiftData (Block model already has the properties)
  - Reference: spec US2 Acceptance Scenarios 1-4, Edge Cases

- [X] T010 [P] [US2] Add completion announcement TextField to Session editor in `src/Views/Session/SessionEditorView.swift`
  - Add a Section titled "语音播报" with a TextField for `session.announcementComplete`
  - Placeholder: `"默认：训练完成"`
  - If text length > 50 chars, show inline hint
  - Data persists via SwiftData (Session model already has the property)
  - Reference: spec US2 Acceptance Scenario 1, FR-005

- [X] T011 [US2] Build and verify custom announcement text on device by running `make run-device`
  - Edit a Block: set custom "开始播报" → verify custom text is spoken at block first work
  - Clear "休息播报" → verify default "休息" is spoken
  - Edit Session: set custom "完成播报" → verify custom text at session complete
  - Verify persistence: close and reopen editor → custom text retained
  - Reference: spec US2 Acceptance Scenarios 1-4, SC-004

**Checkpoint**: User Stories 1 AND 2 complete. Users can customize all four announcement texts per Block/Session.

---

## Phase 5: User Story 3 — 语音播报开关 (Priority: P3)

**Goal**: 用户可以全局开启或关闭语音播报。关闭后恢复原有 Work/Rest/Session Complete 音效，倒计时音效始终不变。计时过程中切换立即生效。

**Independent Test**: 关闭开关 → 启动计时 → 验证无语音播报但有原有音效。开启 → 验证语音播报恢复。计时中切换 → 下次阶段切换立即生效。

### Implementation for User Story 3

- [X] T012 [US3] Add voice announcement toggle to the main interface in `src/Views/Home/SessionListView.swift`
  - Add `@AppStorage("isVoiceAnnouncementEnabled") private var isVoiceAnnouncementEnabled: Bool = true`
  - Add a `Toggle` in toolbar or as a section in the main view for "语音播报"
  - Toggle binding: `$isVoiceAnnouncementEnabled`
  - The TimerViewModel already reads this flag (from T005), so changes take effect immediately at next phase transition
  - Reference: spec US3, FR-007, research § Task 5

- [X] T013 [US3] Build and verify toggle on device by running `make run-device`
  - Toggle OFF → start timer → verify Work/Rest start sounds play (no voice)
  - Toggle ON → start timer → verify voice announcements play (no Work/Rest start sounds)
  - Toggle during active session → verify next phase transition respects new setting
  - Verify countdown sounds work regardless of toggle state
  - Reference: spec US3 Acceptance Scenarios 1-3, SC-005

**Checkpoint**: All user stories complete. Full feature functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Edge case handling, final validation across all stories.

- [X] T014 Verify edge cases on device: rapid phase switching (short durations), background/foreground transitions, music mixing behavior
  - Create a Session with very short Work/Rest (e.g., 3s each) → verify speech interrupts and new announcement starts (FR-012)
  - Play background music → verify ducking behavior (Art. 2)
  - Lock screen → verify voice continues in background (FR-011)
  - Test with English text (e.g., Block named "Squat") → verify English voice (FR-009)
  - Test with mixed text (e.g., "C大调 Scale") → verify language detection (FR-009)

- [X] T015 Final build and complete acceptance validation by running `make run-device`
  - Walk through ALL 6 acceptance scenarios from US1
  - Walk through ALL 4 acceptance scenarios from US2
  - Walk through ALL 3 acceptance scenarios from US3
  - Verify all 5 Success Criteria (SC-001 through SC-005)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Empty — no work needed
- **Foundational (Phase 2)**: No dependencies — start immediately. BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 completion
- **US2 (Phase 4)**: Depends on Phase 2 completion (model properties). Independent of US1 at code level, but US1 provides the runtime to verify announcements
- **US3 (Phase 5)**: Depends on Phase 2 completion. Independent of US2. The `@AppStorage` flag is introduced in US1 (T005), so US3's UI binds to the same key
- **Polish (Phase 6)**: Depends on all stories being complete

### User Story Dependencies

```
Phase 2 (Foundational)
  ├── T001 [P] Block model ──┐
  ├── T002 [P] Session model ─┼── T004 make generate ──► Phase 3 (US1)
  └── T003 [P] SpeechService ─┘                           │
                                                           ▼
                                                    Phase 4 (US2) ──► Phase 5 (US3) ──► Phase 6 (Polish)
```

### Within Each User Story

- US1: T005 → T006 → T007 → T008 (sequential, same file for T005-T007)
- US2: T009 ∥ T010 → T011 (T009 and T010 are parallel, different files)
- US3: T012 → T013 (sequential)

### Parallel Opportunities

- **Phase 2**: T001, T002, T003 are all in different files — run in parallel
- **Phase 4 (US2)**: T009 and T010 are in different files — run in parallel
- **Cross-story**: US2 (T009-T010) could theoretically start while US1 is in progress, since they modify different files. However, verification (T011) requires US1 to be complete for the speech engine to be integrated.

---

## Parallel Example: Phase 2 (Foundational)

```
# Launch all three foundational tasks together (different files):
Task: "Add announcement properties to Block model in src/Models/Block.swift"
Task: "Add announcementComplete to Session model in src/Models/Session.swift"
Task: "Create SpeechService in src/Services/SpeechService.swift"

# Then sequentially:
Task: "Run make generate to register new file"
```

## Parallel Example: Phase 4 (US2)

```
# Launch both UI tasks together (different files):
Task: "Add voice announcement TextFields to BlockEditorRow in src/Views/Components/BlockEditorRow.swift"
Task: "Add completion TextField to SessionEditorView in src/Views/Session/SessionEditorView.swift"

# Then sequentially:
Task: "Build and verify on device"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (T001-T004)
2. Complete Phase 3: User Story 1 (T005-T008)
3. **STOP and VALIDATE**: Voice announcements work with default texts
4. Feature is immediately usable — Block names, "休息", "继续", "训练完成" all play automatically

### Incremental Delivery

1. Phase 2 → Foundation ready (models + service)
2. + US1 → Default voice announcements work → **MVP!**
3. + US2 → Custom text editing works → Enhanced personalization
4. + US3 → Global toggle works → Complete user control
5. + Polish → All edge cases verified → Release ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Total: **15 tasks** across 6 phases
- No test tasks generated (not requested in spec)
- `AudioService.swift` requires NO modifications — all conditional logic is in `TimerViewModel`
- `project.yml` requires NO modifications — `src/Services/` is already a source directory
- SwiftData migration is automatic — no migration code needed
