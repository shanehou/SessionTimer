// T022: TimerEngine - RunLoop Timer-based tick engine
// Session Timer - 核心计时引擎

import Foundation
import QuartzCore

/// 计时引擎 - 基于 RunLoop Timer 的计时器
/// 负责每秒触发 tick 回调
@MainActor
final class TimerEngine {
    // MARK: - Types
    
    /// Tick 回调类型
    typealias TickHandler = @MainActor () -> Void
    
    // MARK: - Properties
    
    /// Tick 回调
    private var tickHandler: TickHandler?
    
    /// 是否正在运行（已启动且未停止）
    private(set) var isRunning: Bool = false
    
    /// 是否已暂停
    private(set) var isSuspended: Bool = false
    
    /// 计时间隔
    private let interval: TimeInterval
    
    /// DisplayLink 用于稳定的帧回调
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    
    /// 上次 tick 时间
    private var lastTickTime: CFTimeInterval = 0
    
    /// 用于追踪的唯一 ID
    private var engineId: UUID = UUID()
    
    /// Timer 创建计数（用于调试）
    private var timerCreationCount: Int = 0
    
    // MARK: - Initializer
    
    /// 创建计时引擎
    /// - Parameter interval: 计时间隔，默认 1.0 秒
    init(interval: TimeInterval = 1.0) {
        self.interval = interval
        print("[TimerEngine-\(engineId.uuidString.prefix(8))] 初始化")
    }
    
    deinit {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Public Methods
    
    /// 设置 tick 回调
    /// - Parameter handler: 每次 tick 时调用的函数
    func setTickHandler(_ handler: @escaping TickHandler) {
        self.tickHandler = handler
    }
    
    /// 启动计时器
    func start() {
        print("[TimerEngine-\(engineId.uuidString.prefix(8))] start() called, isRunning=\(isRunning)")
        stop() // 先停止任何现有的计时器
        
        isRunning = true
        isSuspended = false
        lastTickTime = CACurrentMediaTime()
        
        createDisplayLink()
    }
    
    /// 停止计时器
    func stop() {
        print("[TimerEngine-\(engineId.uuidString.prefix(8))] stop() called, isRunning=\(isRunning), displayLink=\(displayLink != nil)")
        invalidateDisplayLink()
        isRunning = false
        isSuspended = false
    }
    
    /// 暂停计时器
    func pause() {
        print("[TimerEngine-\(engineId.uuidString.prefix(8))] pause() called, isRunning=\(isRunning), isSuspended=\(isSuspended)")
        
        isRunning = true
        isSuspended = true
        displayLink?.isPaused = true
        
        print("[TimerEngine-\(engineId.uuidString.prefix(8))] pause() done, displayLink.isPaused=\(displayLink?.isPaused ?? true)")
    }
    
    /// 继续计时器
    func resume() {
        print("[TimerEngine-\(engineId.uuidString.prefix(8))] resume() called, isRunning=\(isRunning), isSuspended=\(isSuspended)")
        
        isRunning = true
        isSuspended = false
        lastTickTime = CACurrentMediaTime() // 重置时间，避免暂停期间累积
        displayLink?.isPaused = false
        
        print("[TimerEngine-\(engineId.uuidString.prefix(8))] resume() done, displayLink.isPaused=\(displayLink?.isPaused ?? true)")
    }
    
    // MARK: - Private Methods
    
    /// 创建 DisplayLink
    private func createDisplayLink() {
        invalidateDisplayLink()
        
        timerCreationCount += 1
        let currentCount = timerCreationCount
        print("[TimerEngine-\(engineId.uuidString.prefix(8))] createDisplayLink() #\(currentCount)")
        
        // 创建一个 wrapper 对象来持有 displayLink 的 target
        let link = CADisplayLink(target: DisplayLinkTarget(handler: { [weak self] in
            self?.handleDisplayLinkFire()
        }), selector: #selector(DisplayLinkTarget.tick))
        
        // 设置首选帧率（iOS 15+）- 我们不需要 60fps，10fps 足够检测 1 秒间隔
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 15)
        }
        
        link.add(to: .main, forMode: .common)
        self.displayLink = link
        
        print("[TimerEngine-\(engineId.uuidString.prefix(8))] DisplayLink #\(currentCount) created, displayLink=\(self.displayLink != nil)")
    }
    
    /// 销毁 DisplayLink
    private func invalidateDisplayLink() {
        if let link = displayLink {
            print("[TimerEngine-\(engineId.uuidString.prefix(8))] invalidateDisplayLink()")
            link.invalidate()
        }
        displayLink = nil
    }
    
    /// 处理 DisplayLink 触发
    private func handleDisplayLinkFire() {
        guard isRunning, !isSuspended else { return }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - lastTickTime
        
        // 检查是否已经过了 interval 时间
        if elapsed >= interval {
            // 关键：增加 interval 而不是设置为 currentTime
            // 这样可以避免累积误差，保持精确的节奏
            // 如果有多个 interval 累积（例如应用被暂停后恢复），会触发多次 tick
            lastTickTime += interval
            print("[TimerEngine-\(engineId.uuidString.prefix(8))] tick at \(currentTime), elapsed=\(String(format: "%.3f", elapsed))")
            tickHandler?()
            
            // 如果累积了多个 interval（例如应用后台恢复），继续处理
            // 但限制单次最多补发 5 次，避免极端情况
            var catchUpCount = 0
            while CACurrentMediaTime() - lastTickTime >= interval && catchUpCount < 5 {
                lastTickTime += interval
                print("[TimerEngine-\(engineId.uuidString.prefix(8))] catch-up tick #\(catchUpCount + 1)")
                tickHandler?()
                catchUpCount += 1
            }
            
            // 如果仍然落后太多，重置到当前时间（避免无限追赶）
            if CACurrentMediaTime() - lastTickTime >= interval * 2 {
                lastTickTime = CACurrentMediaTime()
                print("[TimerEngine-\(engineId.uuidString.prefix(8))] reset lastTickTime due to large drift")
            }
        }
    }
}

// MARK: - DisplayLink Target Wrapper

/// DisplayLink 需要一个 NSObject 作为 target
private final class DisplayLinkTarget: NSObject {
    private let handler: () -> Void
    
    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init()
    }
    
    @objc func tick() {
        handler()
    }
}

// MARK: - Convenience Methods

extension TimerEngine {
    /// 启动计时器并设置回调
    /// - Parameter handler: 每次 tick 时调用的函数
    func start(with handler: @escaping TickHandler) {
        setTickHandler(handler)
        start()
    }
    
    /// 重置计时器
    func reset() {
        stop()
        tickHandler = nil
    }
    
    /// 是否处于暂停状态
    var isPaused: Bool {
        isSuspended
    }
}

// MARK: - Deinit

extension TimerEngine {
    /// 确保 Timer 被正确清理
    func cleanup() {
        stop()
        tickHandler = nil
    }
}
