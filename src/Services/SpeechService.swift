import AVFoundation
import NaturalLanguage

/// 语音播报服务 — 封装 AVSpeechSynthesizer，提供文本转语音播报能力
@MainActor
final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    /// 当前是否正在播报
    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    /// 播报指定文本
    /// 自动检测语言并选择匹配语音；如有正在播报的内容则立即中断
    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectVoice(for: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }

    /// 立即停止当前播报
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Private

    private func detectLanguage(for text: String) -> String {
        // 含中文字符时优先使用中文语音，中文 TTS 能正确处理夹杂的英文
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
