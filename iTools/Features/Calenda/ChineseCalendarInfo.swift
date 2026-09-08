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
    let holiday: String?          // 节日名称
    let isOffDay: Bool            // 是否休息（包括周末）
    let workRestStatus: WorkRestStatus
}

extension Calendar {
    /// 中国标准时间日历（GMT+8）
    static let chinese: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        cal.locale = Locale(identifier: "zh_CN") // 可选，影响月份、星期的本地化显示
        return cal
    }()
}
