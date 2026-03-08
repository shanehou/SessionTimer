import CryptoKit
import Foundation

/// 音频缓存服务 — 管理 TTS 预生成的 WAV 文件
final class AudioCacheService: Sendable {
    static let shared = AudioCacheService()

    let cacheDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("TTSCache", isDirectory: true)

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// 查找文本对应的缓存音频文件 URL
    func cachedURL(for text: String) -> URL? {
        let fileURL = cacheFileURL(for: text)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        return nil
    }

    /// 将 PCM 采样保存为 WAV 文件到缓存目录
    func save(samples: [Float], sampleRate: Int32, for text: String) throws {
        let fileURL = cacheFileURL(for: text)
        let wavData = encodeWAV(samples: samples, sampleRate: sampleRate)
        try wavData.write(to: fileURL, options: .atomic)
    }

    /// 检查文本是否已有缓存（含 Bundle 默认音频）
    func hasCached(text: String) -> Bool {
        cachedURL(for: text) != nil
    }

    /// 删除指定文本列表的缓存文件
    func removeCache(for texts: [String]) {
        for text in texts {
            let fileURL = cacheFileURL(for: text)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Private

    private func cacheKey(for text: String) -> String {
        let hash = SHA256.hash(data: Data(text.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private func cacheFileURL(for text: String) -> URL {
        cacheDirectory.appendingPathComponent("\(cacheKey(for: text)).wav")
    }

    /// 将 Float PCM 采样编码为 16-bit PCM WAV 数据
    private func encodeWAV(samples: [Float], sampleRate: Int32) -> Data {
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int32(numChannels) * Int32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = Int32(samples.count * Int(bitsPerSample / 8))
        let chunkSize = 36 + dataSize

        var data = Data()
        data.reserveCapacity(44 + Int(dataSize))

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(littleEndian: chunkSize)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.append(littleEndian: Int32(16))                 // subchunk1 size
        data.append(littleEndian: Int16(1))                  // PCM format
        data.append(littleEndian: numChannels)
        data.append(littleEndian: sampleRate)
        data.append(littleEndian: byteRate)
        data.append(littleEndian: blockAlign)
        data.append(littleEndian: bitsPerSample)

        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(littleEndian: dataSize)

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * Float(Int16.max))
            data.append(littleEndian: intSample)
        }

        return data
    }
}

// MARK: - Data Helpers

private extension Data {
    mutating func append(littleEndian value: Int16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: MemoryLayout<Int16>.size))
    }

    mutating func append(littleEndian value: Int32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: MemoryLayout<Int32>.size))
    }
}
