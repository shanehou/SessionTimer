import Foundation
import SherpaOnnx

/// sherpa-onnx 离线 TTS 引擎封装
/// 使用内部串行队列保证 C API 的线程安全
final class TTSEngine: @unchecked Sendable {
    private var ttsWrapper: SherpaOnnxOfflineTtsWrapper?
    private let queue = DispatchQueue(label: "me.melkor.SessionTimer.ttsEngine")

    var isAvailable: Bool {
        queue.sync { ttsWrapper != nil }
    }

    init() {
        queue.sync { loadModel() }
    }

    /// 将文本合成为 PCM 音频采样（线程安全，可从任意线程调用）
    func synthesize(text: String, speed: Float = 1.0) -> (samples: [Float], sampleRate: Int32)? {
        queue.sync {
            guard let wrapper = ttsWrapper else { return nil }
            let prepared = Self.prepareForModel(text)
            guard !prepared.isEmpty else { return nil }

            guard let generated = wrapper.generate(text: prepared, sid: 0, speed: speed) else {
                #if DEBUG
                print("[TTSEngine] generate() returned nil for: \(prepared)")
                #endif
                return nil
            }

            guard let samplesPtr = generated.samples, generated.n > 0 else {
                #if DEBUG
                print("[TTSEngine] generate() produced 0 samples for: \(prepared) (n=\(generated.n))")
                #endif
                return nil
            }

            let buffer = Array(UnsafeBufferPointer(start: samplesPtr, count: Int(generated.n)))
            return (samples: buffer, sampleRate: generated.sampleRate)
        }
    }

    /// 预处理文本以适配 matcha-icefall-zh-en 模型的分词器：
    /// 1. 在中文/拉丁字符边界插入空格（避免 jieba 分不开）
    /// 2. 拉丁字母转小写（模型 lexicon 通常只收录小写）
    /// 3. 去除首尾空白
    static func prepareForModel(_ text: String) -> String {
        var result = ""
        var prevCategory: CharCategory = .other

        for char in text {
            let category = charCategory(of: char)

            if (!result.isEmpty &&
                ((prevCategory == .cjk && category == .latin) ||
                 (prevCategory == .latin && category == .cjk))) {
                result.append(" ")
            }

            if category == .latin {
                result.append(contentsOf: char.lowercased())
            } else {
                result.append(char)
            }

            if category != .other {
                prevCategory = category
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CharCategory {
        case cjk, latin, other
    }

    private static func charCategory(of char: Character) -> CharCategory {
        if char.unicodeScalars.contains(where: {
            (0x4E00...0x9FFF).contains($0.value) ||
            (0x3400...0x4DBF).contains($0.value) ||
            (0xF900...0xFAFF).contains($0.value)
        }) {
            return .cjk
        }
        if char.isLetter && char.isASCII {
            return .latin
        }
        return .other
    }

    // MARK: - Private

    /// 使用 strdup 池分配 C 字符串，确保在整个 loadModel() 作用域内有效。
    /// 调用 SherpaOnnxCreateOfflineTts 后，C 库已拷贝所有路径，pool 可安全释放。
    private func loadModel() {
        guard let modelDir = Bundle.main.path(forResource: "matcha-icefall-zh-en", ofType: nil) else {
            #if DEBUG
            print("[TTSEngine] Model directory not found in Bundle")
            #endif
            return
        }

        let acousticModel = "\(modelDir)/model-steps-6.onnx"
        let vocoder = "\(modelDir)/vocos-16khz-univ.onnx"
        let lexicon = "\(modelDir)/lexicon.txt"
        let tokens = "\(modelDir)/tokens.txt"
        let dataDir = "\(modelDir)/espeak-ng-data"
        let dictDir = "\(modelDir)/dict"

        guard FileManager.default.fileExists(atPath: acousticModel),
              FileManager.default.fileExists(atPath: vocoder) else {
            #if DEBUG
            print("[TTSEngine] Required model files not found")
            print("[TTSEngine]   acoustic: \(acousticModel)")
            print("[TTSEngine]   vocoder:  \(vocoder)")
            #endif
            return
        }

        var pool: [UnsafeMutablePointer<CChar>] = []
        func cstr(_ s: String) -> UnsafePointer<CChar> {
            let p = strdup(s)!
            pool.append(p)
            return UnsafePointer(p)
        }
        func cstrOrEmpty(_ s: String) -> UnsafePointer<CChar> {
            s.isEmpty ? cstr("") : cstr(s)
        }
        defer { pool.forEach { free($0) } }

        let matchaConfig = SherpaOnnxOfflineTtsMatchaModelConfig(
            acoustic_model: cstr(acousticModel),
            vocoder: cstr(vocoder),
            lexicon: cstr(lexicon),
            tokens: cstr(tokens),
            data_dir: cstr(dataDir),
            noise_scale: 0.667,
            length_scale: 1.0,
            dict_dir: cstr(dictDir)
        )

        let modelConfig = SherpaOnnxOfflineTtsModelConfig(
            vits: SherpaOnnxOfflineTtsVitsModelConfig(
                model: cstr(""), lexicon: cstr(""), tokens: cstr(""),
                data_dir: cstr(""), noise_scale: 0.667, noise_scale_w: 0.8,
                length_scale: 1.0, dict_dir: cstr("")
            ),
            num_threads: 2,
            debug: 0,
            provider: cstr("cpu"),
            matcha: matchaConfig,
            kokoro: SherpaOnnxOfflineTtsKokoroModelConfig(
                model: cstr(""), voices: cstr(""), tokens: cstr(""),
                data_dir: cstr(""), length_scale: 1.0, dict_dir: cstr(""),
                lexicon: cstr(""), lang: cstr("")
            ),
            kitten: SherpaOnnxOfflineTtsKittenModelConfig(
                model: cstr(""), voices: cstr(""), tokens: cstr(""),
                data_dir: cstr(""), length_scale: 1.0
            ),
            zipvoice: SherpaOnnxOfflineTtsZipvoiceModelConfig(
                tokens: cstr(""), encoder: cstr(""), decoder: cstr(""),
                vocoder: cstr(""), data_dir: cstr(""), lexicon: cstr(""),
                feat_scale: 1.0, t_shift: 0, target_rms: 0, guidance_scale: 0
            ),
            pocket: SherpaOnnxOfflineTtsPocketModelConfig(
                lm_flow: cstr(""), lm_main: cstr(""), encoder: cstr(""),
                decoder: cstr(""), text_conditioner: cstr(""),
                vocab_json: cstr(""), token_scores_json: cstr(""),
                voice_embedding_cache_capacity: 0
            )
        )

        // FST 规则文件（日期/电话/数字标准化）在 sherpa-onnx 新版本中
        // 格式不兼容，会导致文本被清空。短播报文本无需这些规则，直接跳过。
        let ruleFstsStr = ""

        var config = SherpaOnnxOfflineTtsConfig(
            model: modelConfig,
            rule_fsts: cstrOrEmpty(ruleFstsStr),
            max_num_sentences: 1,
            rule_fars: cstr(""),
            silence_scale: 0.2
        )

        ttsWrapper = SherpaOnnxOfflineTtsWrapper(config: &config)

        #if DEBUG
        if let wrapper = ttsWrapper {
            print("[TTSEngine] Model loaded — sampleRate=\(wrapper.sampleRate), speakers=\(wrapper.numSpeakers)")
        } else {
            print("[TTSEngine] Failed to create TTS instance")
            print("[TTSEngine]   modelDir: \(modelDir)")
        }
        #endif
    }
}
