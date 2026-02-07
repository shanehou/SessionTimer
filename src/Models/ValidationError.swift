// T016: ValidationError enum
// Session Timer - 验证错误类型

import Foundation

/// 验证错误
enum ValidationError: LocalizedError, Sendable {
    case emptySessionName
    case noBlocks
    case tooManyBlocks(max: Int)
    case emptyBlockName
    case invalidSetCount
    case invalidDuration
    case zeroDuration
    case sessionNotFound
    
    var errorDescription: String? {
        switch self {
        case .emptySessionName:
            return "Session 名称不能为空"
        case .noBlocks:
            return "至少需要添加一个练习项目"
        case .tooManyBlocks(let max):
            return "练习项目不能超过 \(max) 个"
        case .emptyBlockName:
            return "练习项目名称不能为空"
        case .invalidSetCount:
            return "组数必须在 1-99 之间"
        case .invalidDuration:
            return "时间必须在 0-99:59 之间"
        case .zeroDuration:
            return "练习时间和休息时间不能都为 0"
        case .sessionNotFound:
            return "练习计划不存在或已被删除"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptySessionName:
            return "请输入一个有意义的名称，如「练腿日」或「音阶练习」"
        case .noBlocks:
            return "点击「添加练习项目」按钮添加至少一个练习"
        case .tooManyBlocks(let max):
            return "删除一些练习项目，使总数不超过 \(max) 个"
        case .emptyBlockName:
            return "请为每个练习项目命名"
        case .invalidSetCount:
            return "请设置 1 到 99 之间的组数"
        case .invalidDuration:
            return "请设置 0 到 99 分 59 秒之间的时间"
        case .zeroDuration:
            return "练习时间或休息时间至少有一个需要大于 0"
        case .sessionNotFound:
            return "请返回列表重新选择一个练习计划"
        }
    }
}
