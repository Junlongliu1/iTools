// 数据模型层，纯数据结构

import Foundation
import SwiftUI

// 节假日调休状态（名称保持不变）
enum WorkRestStatus: Equatable {
    case none       // 普通工作日/周末
    case rest       // 法定节假日休息（绿"休"）
    case work       // 调休上班（红"班"）
}

/// 日历单元格展示模型（名称保持不变，字段精简）
struct ChineseCalendarInfo: Equatable {
    let lunarDay: String          // 保留字段名，实际不再使用，传空字符串
    let jieQi: String?            // 保留字段名，实际不再使用，始终为nil
    let holiday: String?          // 仅节日当天有值
    let isOffDay: Bool
    let yi: [String]              // 保留字段名，实际不再使用，传空数组
    let ji: [String]              // 保留字段名，实际不再使用，传空数组
    let workRestStatus: WorkRestStatus
    
    /// 副标题：仅显示节日名称，无节日时返回空字符串
    var subtitle: String {
        holiday ?? ""
    }
    
    var subtitleColor: Color {
        if holiday != nil { return .red }
        return .secondary
    }
}
