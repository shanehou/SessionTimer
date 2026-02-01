// T018: SessionTimerAttributes for Live Activity
// Session Timer - Live Activity 数据结构
// 注意：此文件被主 App 和 Widget Extension 共享，不能依赖主 App 特有的类型

import ActivityKit
import Foundation

/// Live Activities 和 Dynamic Island 的数据结构
struct SessionTimerAttributes: ActivityAttributes {
    // MARK: - Static Properties (Activity 生命周期内不变)
    
    /// Session 名称
    let sessionName: String
    
    /// 总 Block 数量
    let totalBlocks: Int
    
    // MARK: - Content State (可动态更新)
    
    /// 动态状态内容
    struct ContentState: Codable, Hashable {
        /// 当前 Block 名称
        let currentBlockName: String
        
        /// 当前 Block 索引 (0-based)
        let currentBlockIndex: Int
        
        /// 当前组号 (1-based)
        let currentSet: Int
        
        /// 当前 Block 总组数
        let totalSets: Int
        
        /// 剩余秒数
        let remainingSeconds: Int
        
        /// 当前阶段 ("work" or "rest")
        let phase: String
        
        /// 是否暂停
        let isPaused: Bool
        
        // MARK: - Computed Properties
        
        /// 是否为 work 阶段
        var isWorkPhase: Bool {
            phase == "work"
        }
        
        /// 格式化的剩余时间 "MM:SS"
        var formattedTime: String {
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
        
        /// 组进度文本 (e.g., "2/3")
        var setProgressText: String {
            "\(currentSet)/\(totalSets)"
        }
        
        /// Block 进度文本 (e.g., "1/4")
        func blockProgressText(totalBlocks: Int) -> String {
            "\(currentBlockIndex + 1)/\(totalBlocks)"
        }
        
        /// 状态文本
        var statusText: String {
            if isPaused {
                return "PAUSED"
            }
            return isWorkPhase ? "WORK" : "REST"
        }
        
        // MARK: - Static Factory Methods
        
        /// 创建初始状态
        static func initial(
            blockName: String,
            totalSets: Int,
            workDuration: Int
        ) -> ContentState {
            ContentState(
                currentBlockName: blockName,
                currentBlockIndex: 0,
                currentSet: 1,
                totalSets: totalSets,
                remainingSeconds: workDuration,
                phase: "work",
                isPaused: false
            )
        }
        
        /// 创建完成状态
        static func completed() -> ContentState {
            ContentState(
                currentBlockName: "完成",
                currentBlockIndex: 0,
                currentSet: 0,
                totalSets: 0,
                remainingSeconds: 0,
                phase: "work",
                isPaused: false
            )
        }
    }
}
