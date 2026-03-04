// T013: Block SwiftData Model
// Session Timer - Block 数据模型

import Foundation
import SwiftData

/// Block (动作/项目) - 代表 Session 中的一个动作或练习项目
/// 如 "深蹲" 或 "C大调音阶"
@Model
final class Block {
    // MARK: - Properties
    
    /// 唯一标识符
    var id: UUID
    
    /// Block 名称
    var name: String
    
    /// 组数 (1-99)
    var setCount: Int
    
    /// 每组练习时长（秒）(0-5999)
    var workDuration: Int
    
    /// 组间休息时长（秒）(0-5999)
    var restDuration: Int
    
    /// 在 Session 中的顺序
    var orderIndex: Int
    
    /// 所属 Session (inverse relationship)
    var session: Session?
    
    // MARK: - Voice Announcement Properties
    
    /// Block 首组 Work 开始时的播报文本，nil 或空字符串时回退到 name
    var announcementStart: String?
    
    /// Rest 阶段开始时的播报文本，nil 或空字符串时回退到"休息"
    var announcementRest: String?
    
    /// 非首组 Work 开始时的播报文本，nil 或空字符串时回退到"继续"
    var announcementContinue: String?
    
    // MARK: - Computed Properties
    
    /// 单个 Block 总时长（秒）
    var totalDuration: Int {
        setCount * setDuration
    }
    
    /// 单组时长（练习 + 休息）（秒）
    var setDuration: Int {
        workDuration + restDuration
    }
    
    // MARK: - Initializer
    
    /// 创建 Block
    /// - Parameters:
    ///   - name: Block 名称
    ///   - setCount: 组数，默认 3
    ///   - workDuration: 练习时长（秒），默认 30
    ///   - restDuration: 休息时长（秒），默认 10
    ///   - orderIndex: 排序索引，默认 0
    init(
        name: String,
        setCount: Int = 3,
        workDuration: Int = 30,
        restDuration: Int = 10,
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.setCount = setCount
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.orderIndex = orderIndex
    }
    
    // MARK: - Validation
    
    /// 验证 Block 数据有效性
    /// - Throws: ValidationError 如果验证失败
    func validate() throws {
        // 名称不能为空
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyBlockName
        }
        
        // 组数范围：1-99
        guard setCount >= 1 && setCount <= 99 else {
            throw ValidationError.invalidSetCount
        }
        
        // 时长范围：0-5999 秒
        guard workDuration >= 0 && workDuration <= 5999 else {
            throw ValidationError.invalidDuration
        }
        
        guard restDuration >= 0 && restDuration <= 5999 else {
            throw ValidationError.invalidDuration
        }
        
        // 练习时间和休息时间至少一个 > 0
        guard workDuration > 0 || restDuration > 0 else {
            throw ValidationError.zeroDuration
        }
    }
}

// MARK: - Convenience Extensions

extension Block {
    /// 格式化的练习时长
    var formattedWorkDuration: String {
        workDuration.formatted_MMSS
    }
    
    /// 格式化的休息时长
    var formattedRestDuration: String {
        restDuration.formatted_MMSS
    }
    
    /// 格式化的总时长
    var formattedTotalDuration: String {
        totalDuration.formattedDuration
    }
    
}
