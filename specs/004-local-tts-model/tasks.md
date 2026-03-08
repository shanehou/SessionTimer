# Tasks: 本地 TTS 模型替换

**Input**: Design documents from `/specs/004-local-tts-model/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested in spec — test tasks omitted. Validation via `make run-device` and manual device testing.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: vendor 依赖获取脚本、项目构建配置、C API 桥接

- [x] T001 Create vendor setup script that clones sherpa-onnx repo and runs `build-ios.sh`, downloads model files from modelscope/huggingface/cppjieba, and assembles `vendor/matcha-icefall-zh-en/` in `scripts/setup-vendor.sh`
- [x] T002 Add `vendor/` to `.gitignore`
- [x] T003 Add `setup-vendor` target to `Makefile`
- [x] T004 Create Clang module map for sherpa-onnx C API (adapted from bridging header to `src/CModules/SherpaOnnx/module.modulemap` for Xcode 26 compatibility)
- [x] T005 Update `project.yml` to add: `SWIFT_INCLUDE_PATHS`, `sherpa-onnx.xcframework` and `onnxruntime.xcframework` dependencies, `Accelerate.framework`, `CoreML.framework`, `libc++.tbd` SDK links, `vendor/matcha-icefall-zh-en` as folder resource, `src/Resources/DefaultAnnouncements` as folder resource
- [x] T006 Run `scripts/setup-vendor.sh` to populate vendor directory, then run `make generate` to verify project compiles with vendor dependencies

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: sherpa-onnx Swift 封装和音频缓存服务 — 所有 User Story 的共享基础

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T007 Create sherpa-onnx Swift helper functions (toCPointer, sherpaOnnxOfflineTtsMatchaModelConfig, sherpaOnnxOfflineTtsModelConfig, sherpaOnnxOfflineTtsConfig, SherpaOnnxOfflineTtsWrapper, SherpaOnnxGeneratedAudioWrapper) referencing official `SherpaOnnx.swift` patterns in `src/Services/SherpaOnnxHelpers.swift`
- [x] T008 Implement TTSEngine that initializes matcha-icefall-zh-en model from Bundle (model-steps-6.onnx, vocos-16khz-univ.onnx, lexicon.txt, tokens.txt, espeak-ng-data, dict, FST rules) and provides `synthesize(text:speed:) -> (samples: [Float], sampleRate: Int32)?` method in `src/Services/TTSEngine.swift`
- [x] T009 Implement AudioCacheService with SHA256-based file naming, `cachedURL(for:)` lookup (Bundle defaults → TTSCache directory), `save(samples:sampleRate:for:)` WAV writer, and `hasCached(text:)` check in `src/Services/AudioCacheService.swift`
- [x] T010 Generate default announcement WAV files ("准备", "休息", "继续", "练习完成") using TTSEngine at dev time and place them in `src/Resources/DefaultAnnouncements/` as preparing.wav, rest.wav, continue.wav, complete.wav
- [x] T011 Run `make run-device` to verify TTSEngine loads model from Bundle and AudioCacheService can read/write WAV files without crash

**Checkpoint**: Foundation ready — TTSEngine can synthesize text, AudioCacheService can cache/retrieve WAV files, default audio bundled

---

## Phase 3: User Story 1 — 使用本地模型生成的高质量语音进行播报 (Priority: P1) 🎯 MVP

**Goal**: 计时执行时语音播报使用预缓存的音频文件播放，替代 AVSpeechSynthesizer。默认播报和已缓存的自定义播报使用 AVAudioPlayer 播放，无缓存时降级到 AVSpeechSynthesizer。

**Independent Test**: 使用默认设置启动 Session 计时，验证所有阶段切换（准备/开始/休息/继续/完成）的语音播报使用内置高质量音频，发音自然清晰无延迟。

### Implementation for User Story 1

- [x] T012 [US1] Refactor SpeechService to add AVAudioPlayer-based playback: `speak(text:)` first checks `AudioCacheService.cachedURL(for:)`, plays via AVAudioPlayer if found, falls back to AVSpeechSynthesizer if not; add `stop()` that stops both AVAudioPlayer and AVSpeechSynthesizer; maintain `isSpeaking` computed property covering both playback paths in `src/Services/SpeechService.swift`
- [x] T013 [US1] Ensure SpeechService.speak() interrupts any currently playing audio (stop current AVAudioPlayer or AVSpeechSynthesizer) before starting new playback, matching existing FR-011 behavior in `src/Services/SpeechService.swift`
- [x] T014 [US1] Verify that audio playback uses existing AudioService AVAudioSession configuration (.playback, .mixWithOthers, .duckOthers) for background and music mixing compatibility — no changes needed in `src/Services/AudioService.swift` if SpeechService reuses the shared session
- [x] T015 [US1] Run `make run-device` and verify: default announcements play from Bundle, audio is natural quality, phase transitions trigger correct audio, voice announcement toggle still works, no playback delay

**Checkpoint**: User Story 1 complete — default播报使用内置高质量音频，自定义文本降级到 AVSpeechSynthesizer（预生成在 US2 实现）

---

## Phase 4: User Story 2 — 保存时生成语音并缓存 (Priority: P2)

**Goal**: 用户保存 Block/Session 时，后台异步为自定义播报文本调用 TTSEngine 生成音频并缓存到本地。生成不阻塞保存操作。

**Independent Test**: 编辑 Block 的播报文本并保存，等待几秒后启动计时，验证播放的是本地模型缓存的音频而非系统 TTS。

### Implementation for User Story 2

- [x] T016 [US2] Add `pregenerate(texts:)` method to SpeechService that: filters out already-cached texts, submits remaining to background Task calling TTSEngine.synthesize() on each, saves results via AudioCacheService.save(), logs failures without blocking in `src/Services/SpeechService.swift`
- [x] T017 [US2] Add announcement text collection logic: after `save(modelContext:)` returns, collect all non-default announcement texts per the rules in data-model.md (Block: announcementStart ?? name, non-empty announcementRest, non-empty announcementContinue; Session: non-empty announcementComplete), then call `SpeechService.shared.pregenerate(texts:)` in `src/ViewModels/SessionEditorViewModel.swift`
- [x] T018 [US2] Handle rapid save scenario: if pregenerate is called while a previous generation is in progress, cancel the previous Task before starting a new one (store reference to current generation Task in SpeechService) in `src/Services/SpeechService.swift`
- [x] T019 [US2] Run `make run-device` and verify: saving a Block with custom text triggers background audio generation, subsequent timer playback uses cached audio not system TTS, save operation returns immediately without blocking, editing and re-saving regenerates audio

**Checkpoint**: User Story 2 complete — 自定义文本保存时后台生成，计时时播放缓存音频，未生成完成时降级到系统 TTS

---

## Phase 5: User Story 3 — 内置默认语音与后台播放兼容 (Priority: P3)

**Goal**: 确认内置默认音频开箱即用，后台播放和音乐混音场景下语音播报正常工作。

**Independent Test**: 全新安装应用后不做任何设置直接启动 Session，验证默认播报使用内置音频；切到后台并播放音乐，验证播报正常混音。

### Implementation for User Story 3

- [x] T020 [US3] Verify AudioCacheService.cachedURL correctly returns Bundle URL for all 4 default texts ("准备", "休息", "继续", "练习完成") and that clearing custom text falls back to default Bundle audio in `src/Services/AudioCacheService.swift`
- [x] T021 [US3] Verify SpeechService AVAudioPlayer playback works in background mode by confirming it shares the AVAudioSession configured by AudioService (category .playback with background audio entitlement) — add configureAudioSession() call before playback if not already active in `src/Services/SpeechService.swift`
- [x] T022 [US3] Run `make run-device` and verify: fresh install plays default announcements without any setup, background playback works (switch to home screen during timer), music ducking works (play music then start timer), silent mode behavior matches existing sound behavior

**Checkpoint**: All user stories complete — 默认音频开箱即用，自定义文本预生成，后台/混音兼容

---

## Phase 6: Polish & Edge Cases

**Purpose**: 边界情况处理和代码健壮性

- [x] T023 Add TTSEngine availability check: if model files missing from Bundle (should not happen but defensive), set `isAvailable = false` and SpeechService skips TTS path entirely, using only AVSpeechSynthesizer in `src/Services/TTSEngine.swift`
- [x] T024 Handle cache miss during playback: when AudioCacheService.cachedURL returns nil for non-default text, SpeechService uses AVSpeechSynthesizer AND triggers background regeneration for that text in `src/Services/SpeechService.swift`
- [x] T025 Verify edge cases with `make run-device`: special characters in text, pure numbers, empty strings, very long text, rapid phase transitions (short work/rest durations)
- [x] T026 Run quickstart.md validation: execute full verification flow from quickstart.md on a clean build

---

## Phase 7: TTS 可靠性与用户反馈

**Purpose**: 修复 TTS 引擎 C 字符串生命周期问题，添加 Session 级别的语音生成状态追踪、删除清理、UI 指示器

- [x] T027 Fix TTSEngine.loadModel() C string lifetime: replace toCPointer() with strdup pool pattern to ensure all C strings remain valid through SherpaOnnxCreateOfflineTts call in `src/Services/TTSEngine.swift`
- [x] T028 Fix SherpaOnnxOfflineTtsWrapper.generate() to use String.withCString for safe pointer passing in `src/Services/SherpaOnnxHelpers.swift`
- [x] T029 Add AudioCacheService.removeCache(for:) method for cleanup of cached WAV files on Session deletion in `src/Services/AudioCacheService.swift`
- [x] T030 Add Session.announcementTexts computed property to collect all custom announcement texts for a Session in `src/Models/Session.swift`
- [x] T031 Add AudioGenerationTracker (@Observable) for per-Session generation status tracking (generating/ready), add per-Session task tracking in SpeechService.pregenerate(texts:sessionId:), add cleanupCache(for:) in `src/Services/SpeechService.swift`
- [x] T032 Refactor SessionEditorViewModel.pregenerateAnnouncements to use Session.announcementTexts and pass sessionId in `src/ViewModels/SessionEditorViewModel.swift`
- [x] T033 Add cache cleanup on Session deletion in SessionListViewModel.confirmDelete/delete, SessionDetailView.deleteSession, SessionService.deleteSession in `src/ViewModels/SessionListViewModel.swift`, `src/Views/Session/SessionDetailView.swift`, `src/Services/SessionService.swift`
- [x] T034 Add audio generation status badge to SessionCard (ProgressView for generating, waveform icon for ready) with onAppear status refresh in `src/Views/Components/SessionCard.swift`
- [x] T035 Add audio generation status row to SessionDetailView header section showing "正在生成语音…" or "语音已就绪" in `src/Views/Session/SessionDetailView.swift`
- [ ] T036 Run `make run-device` and verify: TTS model loads correctly, save triggers audio generation with visible status badge, deletion cleans up cache, fallback to system TTS when generation incomplete

---

## Phase 8: 移除预生成默认 WAV（运行时按需生成）

**Purpose**: TTS 模型生成速度足够快，不需要 Bundle 内置默认 WAV 文件。默认文本与自定义文本走相同的"按需生成 + 缓存"路径。

- [x] T037 Remove `AudioCacheService.defaultAnnouncements` dictionary and Bundle lookup from `cachedURL(for:)`, simplify `removeCache(for:)` to not skip any texts in `src/Services/AudioCacheService.swift`
- [x] T038 Update `Session.announcementTexts` to include default texts ("准备"/"休息"/"继续"/"练习完成") alongside custom texts, with deduplication in `src/Models/Session.swift`
- [x] T039 Update `AudioGenerationTracker.refreshStatus` to remove `defaultAnnouncements` filter — all texts now treated equally in `src/Services/SpeechService.swift`
- [x] T040 Remove `src/Resources/DefaultAnnouncements` folder resource from `project.yml`
- [x] T041 Delete pre-generated WAV files (`src/Resources/DefaultAnnouncements/`) and generation script (`scripts/generate-default-announcements.py`)
- [x] T042 Run `make generate` to verify project compiles after removal of DefaultAnnouncements resource

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational — can start after Phase 2
- **User Story 2 (Phase 4)**: Depends on User Story 1 (SpeechService refactor)
- **User Story 3 (Phase 5)**: Depends on User Story 1 (AVAudioPlayer playback)
- **Polish (Phase 6)**: Depends on all user stories

### Within Each Phase

```
Phase 1: T001 → T002, T003, T004 (parallel) → T005 → T006
Phase 2: T007 → T008 → T009 → T010 → T011
Phase 3: T012 → T013 → T014 → T015
Phase 4: T016 → T017 → T018 → T019
Phase 5: T020, T021 (parallel) → T022
Phase 6: T023, T024 (parallel) → T025 → T026
```

### Parallel Opportunities

- **Phase 1**: T002, T003, T004 can run in parallel (different files)
- **Phase 5**: T020, T021 can run in parallel (different files)
- **Phase 6**: T023, T024 can run in parallel (different files)
- **Cross-phase**: US3 (Phase 5) can start as soon as US1 (Phase 3) completes, without waiting for US2

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (vendor script, project config)
2. Complete Phase 2: Foundational (TTSEngine, AudioCacheService, default WAVs)
3. Complete Phase 3: User Story 1 (SpeechService refactor, cached playback)
4. **STOP and VALIDATE**: Default announcements play with high-quality audio, fallback works
5. This delivers the core value: natural-sounding voice for default texts

### Incremental Delivery

1. Setup + Foundational → Engine and cache infrastructure ready
2. User Story 1 → Default高质量语音播报可用 (MVP!)
3. User Story 2 → 自定义文本也使用高质量语音
4. User Story 3 → 后台/混音场景验证
5. Polish → 边界情况处理

---

## Notes

- vendor/ 不提交到 git — 首次需运行 `scripts/setup-vendor.sh`
- SwiftData 模型不需要修改 — 缓存完全通过文件系统管理
- ~~T010（生成默认 WAV）是开发时一次性操作，生成后作为资源文件提交到 git~~ → Phase 8 移除了预生成默认 WAV，所有文本（含默认）统一走运行时生成+缓存路径
- 所有阶段完成后执行 `make run-device` 验证（宪法 Article 9 要求）
