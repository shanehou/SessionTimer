import Foundation
import SherpaOnnx

// MARK: - C String Helpers

func toCPointer(_ s: String) -> UnsafePointer<CChar>? {
    (s as NSString).utf8String
}

// MARK: - Config Builders

func sherpaOnnxOfflineTtsMatchaModelConfig(
    acousticModel: String = "",
    vocoder: String = "",
    lexicon: String = "",
    tokens: String = "",
    dataDir: String = "",
    noiseScale: Float = 0.667,
    lengthScale: Float = 1.0,
    dictDir: String = ""
) -> SherpaOnnxOfflineTtsMatchaModelConfig {
    SherpaOnnxOfflineTtsMatchaModelConfig(
        acoustic_model: toCPointer(acousticModel),
        vocoder: toCPointer(vocoder),
        lexicon: toCPointer(lexicon),
        tokens: toCPointer(tokens),
        data_dir: toCPointer(dataDir),
        noise_scale: noiseScale,
        length_scale: lengthScale,
        dict_dir: toCPointer(dictDir)
    )
}

func sherpaOnnxOfflineTtsVitsModelConfig(
    model: String = "",
    lexicon: String = "",
    tokens: String = "",
    dataDir: String = "",
    noiseScale: Float = 0.667,
    noiseScaleW: Float = 0.8,
    lengthScale: Float = 1.0,
    dictDir: String = ""
) -> SherpaOnnxOfflineTtsVitsModelConfig {
    SherpaOnnxOfflineTtsVitsModelConfig(
        model: toCPointer(model),
        lexicon: toCPointer(lexicon),
        tokens: toCPointer(tokens),
        data_dir: toCPointer(dataDir),
        noise_scale: noiseScale,
        noise_scale_w: noiseScaleW,
        length_scale: lengthScale,
        dict_dir: toCPointer(dictDir)
    )
}

func sherpaOnnxOfflineTtsModelConfig(
    vits: SherpaOnnxOfflineTtsVitsModelConfig = sherpaOnnxOfflineTtsVitsModelConfig(),
    numThreads: Int32 = 1,
    debug: Int32 = 0,
    provider: String = "cpu",
    matcha: SherpaOnnxOfflineTtsMatchaModelConfig = sherpaOnnxOfflineTtsMatchaModelConfig()
) -> SherpaOnnxOfflineTtsModelConfig {
    SherpaOnnxOfflineTtsModelConfig(
        vits: vits,
        num_threads: numThreads,
        debug: debug,
        provider: toCPointer(provider),
        matcha: matcha,
        kokoro: SherpaOnnxOfflineTtsKokoroModelConfig(
            model: toCPointer(""),
            voices: toCPointer(""),
            tokens: toCPointer(""),
            data_dir: toCPointer(""),
            length_scale: 1.0,
            dict_dir: toCPointer(""),
            lexicon: toCPointer(""),
            lang: toCPointer("")
        ),
        kitten: SherpaOnnxOfflineTtsKittenModelConfig(
            model: toCPointer(""),
            voices: toCPointer(""),
            tokens: toCPointer(""),
            data_dir: toCPointer(""),
            length_scale: 1.0
        ),
        zipvoice: SherpaOnnxOfflineTtsZipvoiceModelConfig(
            tokens: toCPointer(""),
            encoder: toCPointer(""),
            decoder: toCPointer(""),
            vocoder: toCPointer(""),
            data_dir: toCPointer(""),
            lexicon: toCPointer(""),
            feat_scale: 1.0,
            t_shift: 0,
            target_rms: 0,
            guidance_scale: 0
        ),
        pocket: SherpaOnnxOfflineTtsPocketModelConfig(
            lm_flow: toCPointer(""),
            lm_main: toCPointer(""),
            encoder: toCPointer(""),
            decoder: toCPointer(""),
            text_conditioner: toCPointer(""),
            vocab_json: toCPointer(""),
            token_scores_json: toCPointer(""),
            voice_embedding_cache_capacity: 0
        )
    )
}

func sherpaOnnxOfflineTtsConfig(
    model: SherpaOnnxOfflineTtsModelConfig = sherpaOnnxOfflineTtsModelConfig(),
    ruleFsts: String = "",
    maxNumSentences: Int32 = 1,
    ruleFars: String = "",
    silenceScale: Float = 0.2
) -> SherpaOnnxOfflineTtsConfig {
    SherpaOnnxOfflineTtsConfig(
        model: model,
        rule_fsts: toCPointer(ruleFsts),
        max_num_sentences: maxNumSentences,
        rule_fars: toCPointer(ruleFars),
        silence_scale: silenceScale
    )
}

// MARK: - Wrapper Classes (using OpaquePointer for opaque C structs)

final class SherpaOnnxOfflineTtsWrapper: @unchecked Sendable {
    let tts: OpaquePointer

    init?(config: UnsafePointer<SherpaOnnxOfflineTtsConfig>) {
        guard let tts = SherpaOnnxCreateOfflineTts(config) else {
            return nil
        }
        self.tts = tts
    }

    deinit {
        SherpaOnnxDestroyOfflineTts(tts)
    }

    var sampleRate: Int32 {
        SherpaOnnxOfflineTtsSampleRate(tts)
    }

    var numSpeakers: Int32 {
        SherpaOnnxOfflineTtsNumSpeakers(tts)
    }

    func generate(text: String, sid: Int32 = 0, speed: Float = 1.0) -> SherpaOnnxGeneratedAudioWrapper? {
        text.withCString { cText in
            guard let audio = SherpaOnnxOfflineTtsGenerate(tts, cText, sid, speed) else {
                return nil
            }
            return SherpaOnnxGeneratedAudioWrapper(audio: audio)
        }
    }
}

final class SherpaOnnxGeneratedAudioWrapper: @unchecked Sendable {
    let audio: UnsafePointer<SherpaOnnxGeneratedAudio>

    init(audio: UnsafePointer<SherpaOnnxGeneratedAudio>) {
        self.audio = audio
    }

    deinit {
        SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio)
    }

    var sampleRate: Int32 {
        audio.pointee.sample_rate
    }

    var n: Int32 {
        audio.pointee.n
    }

    var samples: UnsafePointer<Float>? {
        audio.pointee.samples
    }

    func save(filename: String) -> Bool {
        guard let s = samples else { return false }
        return SherpaOnnxWriteWave(s, n, sampleRate, toCPointer(filename)) == 1
    }
}
