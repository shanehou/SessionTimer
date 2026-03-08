import AVFoundation
import NaturalLanguage

// MARK: - Audio Generation Status

enum AudioGenerationStatus {
    case generating
    case ready
}

/// 音频生成状态追踪器 — 供 UI 观察 Session 级别的语音生成进度
@Observable
@MainActor
final class AudioGenerationTracker {
    static let shared = AudioGenerationTracker()

    private(set) var sessionStatus: [UUID: AudioGenerationStatus] = [:]

    func status(for sessionId: UUID) -> AudioGenerationStatus? {
        sessionStatus[sessionId]
    }

    func setStatus(_ status: AudioGenerationStatus?, for sessionId: UUID) {
        if let status {
            sessionStatus[sessionId] = status
        } else {
            sessionStatus.removeValue(forKey: sessionId)
        }
    }

    /// 根据文件系统缓存刷新 Session 的就绪状态（用于 app 启动后恢复）
    func refreshStatus(for session: Session) {
        if sessionStatus[session.id] == .generating { return }

        let texts = session.announcementTexts
        guard !texts.isEmpty else { return }

        let allCached = texts.allSatisfy { AudioCacheService.shared.hasCached(text: $0) }
        if allCached {
            sessionStatus[session.id] = .ready
        } else {
            sessionStatus.removeValue(forKey: session.id)
        }
    }
}

// MARK: - Speech Service

/// 语音播报服务 — 预缓存音频播放 + AVSpeechSynthesizer 降级
@MainActor
final class SpeechService: NSObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let audioCacheService = AudioCacheService.shared
    private let ttsEngine = TTSEngine()
    private var pregenerateTasks: [UUID: Task<Void, Never>] = [:]
    private let tracker = AudioGenerationTracker.shared

    /// 当前是否正在播报
    var isSpeaking: Bool {
        audioPlayer?.isPlaying == true || synthesizer.isSpeaking
    }

    // MARK: - Public API

    /// 播报指定文本
    /// 1. 查找缓存音频 → AVAudioPlayer 播放
    /// 2. 无缓存 → AVSpeechSynthesizer 降级播报 + 后台触发生成
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()

        if let cachedURL = audioCacheService.cachedURL(for: trimmed) {
            playCachedAudio(url: cachedURL)
        } else {
            speakWithSystemTTS(trimmed)
            triggerBackgroundGeneration(for: trimmed)
        }
    }

    /// 立即停止当前播报
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// 为 Session 的所有播报文本预生成音频（后台异步）
    func pregenerate(texts: [String], sessionId: UUID) {
        pregenerateTasks[sessionId]?.cancel()

        let uncachedTexts = texts.filter { !$0.isEmpty && !audioCacheService.hasCached(text: $0) }

        if uncachedTexts.isEmpty {
            tracker.setStatus(.ready, for: sessionId)
            pregenerateTasks.removeValue(forKey: sessionId)
            return
        }

        tracker.setStatus(.generating, for: sessionId)

        let engine = ttsEngine
        let cache = audioCacheService
        let sid = sessionId
        let localTracker = tracker

        let task = Task.detached(priority: .utility) {
            var generatedCount = 0
            for text in uncachedTexts {
                if Task.isCancelled { break }

                guard let result = engine.synthesize(text: text) else {
                    #if DEBUG
                    print("[SpeechService] pregenerate failed for: \(text)")
                    #endif
                    continue
                }

                do {
                    try cache.save(samples: result.samples, sampleRate: result.sampleRate, for: text)
                    generatedCount += 1
                    #if DEBUG
                    print("[SpeechService] pregenerated (\(generatedCount)/\(uncachedTexts.count)): \(text)")
                    #endif
                } catch {
                    #if DEBUG
                    print("[SpeechService] save failed for '\(text)': \(error)")
                    #endif
                }
            }

            if !Task.isCancelled {
                await MainActor.run {
                    localTracker.setStatus(.ready, for: sid)
                }
            }
        }

        pregenerateTasks[sessionId] = task
    }

    /// 清理 Session 关联的缓存音频和跟踪状态
    func cleanupCache(for session: Session) {
        pregenerateTasks[session.id]?.cancel()
        pregenerateTasks.removeValue(forKey: session.id)
        tracker.setStatus(nil, for: session.id)
        audioCacheService.removeCache(for: session.announcementTexts)
    }

    // MARK: - Private — Cached Audio Playback

    private func playCachedAudio(url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            #if DEBUG
            print("[SpeechService] AVAudioPlayer failed: \(error)")
            #endif
        }
    }

    // MARK: - Private — System TTS Fallback

    private func speakWithSystemTTS(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectVoice(for: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    // MARK: - Private — Background Regeneration

    private func triggerBackgroundGeneration(for text: String) {
        guard ttsEngine.isAvailable else { return }

        let engine = ttsEngine
        let cache = audioCacheService

        Task.detached(priority: .utility) {
            guard let result = engine.synthesize(text: text) else { return }
            try? cache.save(samples: result.samples, sampleRate: result.sampleRate, for: text)
        }
    }

    // MARK: - Private — Language Detection

    private func detectLanguage(for text: String) -> String {
        if containsChinese(text) {
            return "zh-CN"
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let language = recognizer.dominantLanguage else {
            return "zh-CN"
        }

        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return "zh-CN"
        case .english:
            return "en-US"
        case .japanese:
            return "ja-JP"
        default:
            return "zh-CN"
        }
    }

    private func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value)
        }
    }

    private func selectVoice(for text: String) -> AVSpeechSynthesisVoice? {
        let languageCode = detectLanguage(for: text)
        return AVSpeechSynthesisVoice(language: languageCode)
    }
}

// MARK: - AVAudioPlayerDelegate

extension SpeechService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        Task { @MainActor [weak self] in
            self?.audioPlayer = nil
        }
    }
}
