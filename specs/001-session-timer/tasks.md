# Tasks: Session Timer - 重复练习计时器App

**Input**: Design documents from `/specs/001-session-timer/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/services.md ✅, quickstart.md ✅

**Tests**: Not explicitly requested in spec - tests are NOT included in this task list.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Source**: `src/` (主 App)
- **Widgets**: `src-widgets/` (Live Activity Widget Extension)
- All paths relative to repository root

---

## Phase 1: Setup (Project Infrastructure)

**Purpose**: Project initialization, build configuration, and basic structure

- [ ] T001 Create XcodeGen configuration `src/project.yml` with targets (SessionTimer, SessionTimerWidgets), Swift 6.0, iOS 16.1+ deployment target
- [ ] T002 [P] Create `src/Makefile` with generate, build, run-simulator, run-device, test, clean targets
- [ ] T003 [P] Create `src/scripts/generate.sh` for Xcode project generation
- [ ] T004 [P] Create `src/scripts/build.sh` for project compilation
- [ ] T005 [P] Create `src/scripts/run.sh` for build and run to device
- [ ] T006 [P] Create `src/scripts/test.sh` for running tests
- [ ] T007 Create `src/App/Info.plist` with NSSupportsLiveActivities, UIBackgroundModes (audio)
- [ ] T008 [P] Create `src/App/SessionTimer.entitlements` with iCloud and CloudKit capabilities
- [ ] T009 [P] Create `src/Resources/Assets.xcassets` with AppIcon placeholder
- [ ] T010 Run `make generate` to generate `SessionTimer.xcodeproj` and verify project builds

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T011 Create `src/App/SessionTimerApp.swift` with SwiftData ModelContainer configuration (CloudKit enabled), main WindowGroup entry point
- [ ] T012 [P] Create `src/Models/TimerPhase.swift` with TimerPhase enum (.work, .rest) - Codable, Sendable
- [ ] T013 Create `src/Models/Block.swift` with SwiftData @Model: id, name, setCount, workDuration, restDuration, orderIndex, session relationship, computed totalDuration/setDuration
- [ ] T014 Create `src/Models/Session.swift` with SwiftData @Model: id, name, createdAt, lastUsedAt, isFavorite, sortOrder, blocks relationship (cascade delete), computed totalDuration/totalSets
- [ ] T015 Create `src/Models/TimerState.swift` with runtime struct: sessionId, currentBlockIndex, currentSet, currentPhase, remainingSeconds, isPaused, startedAt, pausedAt, progress calculation
- [ ] T016 [P] Create `src/Models/ValidationError.swift` with LocalizedError enum for all validation cases
- [ ] T017 [P] Create `src/Models/TimerEvent.swift` with enum for timer events (started, paused, resumed, stopped, phaseChanged, etc.)
- [ ] T018 Create `src/Shared/SessionTimerAttributes.swift` with ActivityAttributes for Live Activity (sessionName, totalBlocks, ContentState)
- [ ] T019 [P] Create `src/Extensions/TimeInterval+Formatting.swift` with extension for "MM:SS" formatting
- [ ] T020 [P] Create `src/Extensions/Color+Theme.swift` with theme colors (workBackground, restBackground, textPrimary)

**Checkpoint**: Foundation ready - SwiftData models defined, shared types available

---

## Phase 3: User Story 1 - 创建并执行练习Session (Priority: P1) 🎯 MVP

**Goal**: User can create a complete practice Session with multiple Blocks, each with sets/work/rest times, and execute it with visual progress display

**Independent Test**: Create a Session with 2 Blocks (each 2 sets, 30s work, 10s rest), run through completion, verify all phase transitions with visual feedback

### Core Services for User Story 1

- [ ] T021 [US1] Create `src/Services/SessionService.swift` implementing SessionServiceProtocol: createSession, getAllSessions, getSession, updateSession, deleteSession, markAsUsed, toggleFavorite, block operations
- [ ] T022 [US1] Create `src/Services/TimerEngine.swift` with DispatchSourceTimer-based tick engine, start/stop/pause/resume control, callback handlers
- [ ] T023 [US1] Create `src/Services/TimerService.swift` implementing TimerServiceProtocol: start, pause, resume, stop, skip, phase transition logic, state management
- [ ] T024 [P] [US1] Create `src/Services/HapticService.swift` implementing HapticServiceProtocol: prepare, playSetTransition (Heavy), playSessionComplete (Success), playCountdownWarning (Warning), playPauseResume (Light)
- [ ] T025 [P] [US1] Create `src/Services/AudioService.swift` implementing AudioServiceProtocol: preloadSounds, playWorkStart, playRestStart, playCountdown, playSessionComplete with AVAudioSession mixWithOthers/duckOthers
- [ ] T026 [P] [US1] Create `src/Services/ScreenService.swift` implementing ScreenServiceProtocol: setScreenAlwaysOn, updateScreenState (Work=on, long Rest=off)
- [ ] T027 [P] [US1] Create placeholder sound files in `src/Resources/Sounds/` (work_start.wav, rest_start.wav, countdown.wav, session_complete.wav)

### ViewModels for User Story 1

- [ ] T028 [US1] Create `src/ViewModels/SessionEditorViewModel.swift` with @Observable: name, blocks array, isEditing, validationError, canSave computed, addBlock, deleteBlock, moveBlock, save, validate
- [ ] T029 [US1] Create `src/ViewModels/TimerViewModel.swift` with @Observable: session, currentBlock, currentSet, currentPhase, remainingSeconds, isPaused, isCompleted, progress, formattedTime, backgroundColor, statusText, start, togglePause, skip, stop

### Views for User Story 1

- [ ] T030 [P] [US1] Create `src/Views/Components/BlockEditorRow.swift` - reusable Block editing row (name, setCount, workDuration, restDuration pickers)
- [ ] T031 [P] [US1] Create `src/Views/Components/DurationPicker.swift` - minutes:seconds picker component
- [ ] T032 [US1] Create `src/Views/Session/SessionEditorView.swift` - Session creation/editing form with name TextField, Block list, add Block button, save button
- [ ] T033 [US1] Create `src/Views/Timer/TimerDisplay.swift` - large countdown display (2m legible), current Block name, set count (e.g., "2/3")
- [ ] T034 [US1] Create `src/Views/Timer/TimerView.swift` - full-screen timer with backgroundColor (Work=black, Rest=green), TimerDisplay, fullscreen gesture support (tap=pause, double-tap=skip, long-press=stop)
- [ ] T035 [US1] Create `src/Views/Timer/SessionCompleteView.swift` - completion celebration screen with session stats

### Integration for User Story 1

- [ ] T036 [US1] Wire TimerService to HapticService/AudioService/ScreenService - trigger feedback on phase changes
- [ ] T037 [US1] Create `src/Views/Home/ContentView.swift` as main navigation container with NavigationStack, route to SessionEditorView and TimerView

**Checkpoint**: User Story 1 complete - Users can create Sessions and run through them with full sensory feedback

---

## Phase 4: User Story 2 - 快速启动常用Session (Priority: P2)

**Goal**: User can save Sessions, view them in a sorted list, and one-tap start any saved Session

**Independent Test**: Create a Session, save it, close and reopen app, verify Session appears in list sorted by last used time, one-tap to start

### Views for User Story 2

- [ ] T038 [US2] Create `src/ViewModels/SessionListViewModel.swift` with @Observable: sessions array, searchText, filteredSessions computed, loadSessions, delete, toggleFavorite, start
- [ ] T039 [P] [US2] Create `src/Views/Components/SessionCard.swift` - Session list item showing name, total duration, Block count, favorite indicator
- [ ] T040 [US2] Create `src/Views/Home/SessionListView.swift` - main list view with @Query sorted by isFavorite/lastUsedAt, search bar, swipe actions (delete, favorite), tap to view detail, one-tap start button
- [ ] T041 [US2] Create `src/Views/Session/SessionDetailView.swift` - Session overview with Block list, total duration, edit button, start button

### Integration for User Story 2

- [ ] T042 [US2] Update `src/Views/Home/ContentView.swift` to use SessionListView as root, add navigation to SessionDetailView and SessionEditorView
- [ ] T043 [US2] Implement SessionService.markAsUsed() call when starting a Session to update lastUsedAt

**Checkpoint**: User Story 2 complete - Users can save, browse, and one-tap start Sessions

---

## Phase 5: User Story 3 - 计时过程中的控制操作 (Priority: P3)

**Goal**: User can pause/resume, skip phases, and stop Session using full-screen gestures (eyes-free control)

**Independent Test**: Start a Session, test single-tap (pause/resume), double-tap (skip phase), long-press (stop and return)

### Implementation for User Story 3

- [ ] T044 [US3] Enhance `src/Views/Timer/TimerView.swift` with full-screen gesture recognition: .onTapGesture(count: 1) for pause/resume, .onTapGesture(count: 2) for skip, .onLongPressGesture(minimumDuration: 1.0) for stop
- [ ] T045 [US3] Add paused state visual indicator to TimerDisplay (pulsing animation or "PAUSED" overlay)
- [ ] T046 [US3] Implement skip logic in TimerService: Work→Rest, Rest→next Work, last phase→complete Session

**Checkpoint**: User Story 3 complete - Full eyes-free control during timer operation

---

## Phase 6: User Story 4 - 编辑和管理已有Session (Priority: P4)

**Goal**: User can edit existing Sessions (modify times, add/remove Blocks) and delete unwanted Sessions

**Independent Test**: Edit a saved Session's work time, save, reopen and verify change persisted. Delete a Session and verify removal.

### Implementation for User Story 4

- [ ] T047 [US4] Enhance SessionEditorViewModel init(session:) for edit mode - populate from existing Session
- [ ] T048 [US4] Add edit button to SessionDetailView that navigates to SessionEditorView in edit mode
- [ ] T049 [US4] Implement swipe-to-delete in SessionListView with confirmation alert
- [ ] T050 [US4] Add delete Session option in SessionDetailView with confirmation

**Checkpoint**: User Story 4 complete - Full CRUD operations for Sessions

---

## Phase 7: User Story 5 - 后台运行与提醒 (Priority: P5)

**Goal**: Timer continues in background, notifies on phase changes, displays progress on Lock Screen via Live Activities and Dynamic Island

**Independent Test**: Start Session, lock screen, wait for phase transition, verify notification and Live Activity updates, verify Dynamic Island shows countdown

### Services for User Story 5

- [ ] T051 [US5] Create `src/Services/NotificationService.swift` implementing NotificationServiceProtocol: requestPermission, startLiveActivity, updateLiveActivity, endLiveActivity, sendPhaseChangeNotification, sendSessionCompleteNotification
- [ ] T052 [US5] Configure AVAudioSession for background audio in AudioService - enable app to run in background

### Widget Extension for User Story 5

- [ ] T053 [P] [US5] Create `src-widgets/Info.plist` for Widget Extension
- [ ] T054 [US5] Create `src-widgets/SessionTimerWidgets.swift` - Widget bundle entry point
- [ ] T055 [US5] Create `src-widgets/LiveActivityView.swift` - Lock Screen Live Activity UI showing current Block, set count, remaining time, phase (Work/Rest colors)
- [ ] T056 [US5] Create `src-widgets/DynamicIslandView.swift` - Dynamic Island views (compact, minimal, expanded) with countdown pie chart, set progress

### Integration for User Story 5

- [ ] T057 [US5] Wire TimerService to NotificationService - start/update/end Live Activity on timer events
- [ ] T058 [US5] Implement background state restoration - recalculate timer state from elapsed time when app returns to foreground
- [ ] T059 [US5] Send Time Sensitive notifications on phase change when app is in background

**Checkpoint**: User Story 5 complete - Full background operation with Lock Screen and Dynamic Island support

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T060 [P] Implement runtime adjustments in TimerService: addSet(), skipRest(), extendRest(by:) per FR-008
- [ ] T061 [P] Add runtime adjustment UI to TimerView (swipe up for options sheet: +1 set, skip rest, extend rest)
- [ ] T062 Implement countdown warning feedback (last 3 seconds) - HapticService.playCountdownWarning + AudioService.playCountdown
- [ ] T063 [P] Add accessibility labels to all interactive elements for VoiceOver support
- [ ] T064 [P] Add App lifecycle handling in SessionTimerApp - handle scenePhase changes, pause timer on background if needed
- [ ] T065 Run quickstart.md validation - verify all build commands work (make generate, make build, make run-simulator)
- [ ] T066 Final UI polish - ensure 44pt minimum touch targets, 2m legibility for timer digits, Work/Rest color contrast

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - can start immediately
- **Phase 2 (Foundational)**: Depends on Setup completion - BLOCKS all user stories
- **Phases 3-7 (User Stories)**: All depend on Foundational phase completion
  - User stories should be implemented sequentially in priority order (P1 → P2 → P3 → P4 → P5)
  - Each story builds on previous stories' infrastructure
- **Phase 8 (Polish)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Core MVP, no dependencies
- **User Story 2 (P2)**: Can start after US1 - Uses SessionService and navigation from US1
- **User Story 3 (P3)**: Can start after US1 - Enhances TimerView from US1
- **User Story 4 (P4)**: Can start after US2 - Uses SessionListView and SessionEditorView from US1/US2
- **User Story 5 (P5)**: Can start after US1 - Adds background/notification layer to timer

### Within Each User Story

- Services before ViewModels
- ViewModels before Views
- Components before complex Views
- Integration tasks last

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Service implementations marked [P] can run in parallel within a story
- Component Views marked [P] can run in parallel

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch these in parallel (different files, no dependencies):
Task: T012 "Create src/Models/TimerPhase.swift"
Task: T016 "Create src/Models/ValidationError.swift"
Task: T017 "Create src/Models/TimerEvent.swift"
Task: T019 "Create src/Extensions/TimeInterval+Formatting.swift"
Task: T020 "Create src/Extensions/Color+Theme.swift"
```

## Parallel Example: User Story 1 Services

```bash
# Launch these in parallel (different files, independent services):
Task: T024 "Create src/Services/HapticService.swift"
Task: T025 "Create src/Services/AudioService.swift"
Task: T026 "Create src/Services/ScreenService.swift"
Task: T027 "Create placeholder sound files"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Create a Session, run it, verify all feedback works
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test → MVP ready (Create + Run Session)
3. Add User Story 2 → Test → Save + Quick Start
4. Add User Story 3 → Test → Full gesture control
5. Add User Story 4 → Test → Edit + Delete
6. Add User Story 5 → Test → Background + Live Activities
7. Add Polish → Production ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All source files use Swift 6.0 with strict concurrency
- Use @Observable (not ObservableObject) for ViewModels
- Use @MainActor for all UI-related classes
- SwiftData @Model for persisted entities only
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
