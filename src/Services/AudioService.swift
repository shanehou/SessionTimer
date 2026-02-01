// T025: AudioService - Audio feedback with mixing
// Session Timer - 音频服务

import AVFoundation

/// 音频服务协议
@MainActor
protocol AudioServiceProtocol {
    /// 是否启用音效
    var isSoundEnabled: Bool { get set }
    
    /// 预加载所有音效
    func preloadSounds()
    
    /// 播放 Work 开始音效
    func playWorkStart()
    
    /// 播放 Rest 开始音效
    func playRestStart()
    
    /// 播放倒计时音效 (最后 3 秒)
    func playCountdown()
    
    /// 播放 Session 完成音效
    func playSessionComplete()
}

/// 音频服务实现
@MainActor
final class AudioService: AudioServiceProtocol {
    // MARK: - Properties
    
    /// 是否启用音效
    var isSoundEnabled: Bool = true
    
    /// 音频播放器缓存
    private var players: [String: AVAudioPlayer] = [:]
    
    /// 是否已配置 Audio Session
    private var isSessionConfigured: Bool = false
    
    // MARK: - Sound File Names
    
    private enum SoundFile: String, CaseIterable {
        case workStart = "work_start"
        case restStart = "rest_start"
        case countdown = "countdown"
        case sessionComplete = "session_complete"
        
        var fileExtension: String { "wav" }
    }
    
    // MARK: - Initializer
    
    init() {
        configureAudioSession()
        preloadSounds()
    }
    
    // MARK: - Audio Session Configuration
    
    /// 配置 AVAudioSession 以支持混音和后台播放
    private func configureAudioSession() {
        guard !isSessionConfigured else { return }
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 设置音频类别：
            // - .playback: 支持后台播放
            // - .mixWithOthers: 与其他音频（如音乐）混音
            // - .duckOthers: 播放时临时降低其他音频音量
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            
            try session.setActive(true)
            isSessionConfigured = true
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - AudioServiceProtocol
    
    /// 预加载所有音效
    func preloadSounds() {
        for soundFile in SoundFile.allCases {
            loadSound(soundFile)
        }
    }
    
    /// 播放 Work 开始音效
    func playWorkStart() {
        playSound(.workStart)
    }
    
    /// 播放 Rest 开始音效
    func playRestStart() {
        playSound(.restStart)
    }
    
    /// 播放倒计时音效 (最后 3 秒)
    func playCountdown() {
        playSound(.countdown)
    }
    
    /// 播放 Session 完成音效
    func playSessionComplete() {
        playSound(.sessionComplete)
    }
    
    // MARK: - Private Methods
    
    /// 加载音效文件
    private func loadSound(_ soundFile: SoundFile) {
        // 首先尝试从 bundle 加载
        if let url = Bundle.main.url(
            forResource: soundFile.rawValue,
            withExtension: soundFile.fileExtension
        ) {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[soundFile.rawValue] = player
            } catch {
                print("Failed to load sound \(soundFile.rawValue): \(error)")
            }
        } else {
            // 如果找不到音效文件，使用系统音效作为后备
            print("Sound file not found: \(soundFile.rawValue).\(soundFile.fileExtension)")
        }
    }
    
    /// 播放音效
    private func playSound(_ soundFile: SoundFile) {
        guard isSoundEnabled else { return }
        
        // 确保 Audio Session 已配置
        configureAudioSession()
        
        if let player = players[soundFile.rawValue] {
            // 如果正在播放，先重置
            if player.isPlaying {
                player.currentTime = 0
            }
            player.play()
        } else {
            // 如果没有加载成功，播放系统音效作为后备
            playSystemSound(for: soundFile)
        }
    }
    
    /// 播放系统音效作为后备
    private func playSystemSound(for soundFile: SoundFile) {
        let systemSoundID: SystemSoundID
        
        switch soundFile {
        case .workStart:
            systemSoundID = 1057  // Tink
        case .restStart:
            systemSoundID = 1054  // Pop
        case .countdown:
            systemSoundID = 1103  // Tock
        case .sessionComplete:
            systemSoundID = 1025  // Fanfare
        }
        
        AudioServicesPlaySystemSound(systemSoundID)
    }
}

// MARK: - Singleton

extension AudioService {
    /// 共享实例
    static let shared = AudioService()
}

// MARK: - Background Audio Support

extension AudioService {
    /// 开始后台音频会话（用于保持 App 在后台运行）
    func startBackgroundAudioSession() {
        configureAudioSession()
    }
    
    /// 结束后台音频会话
    func endBackgroundAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isSessionConfigured = false
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}
