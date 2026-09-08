// 数据模型层，纯数据结构

import Foundation
import SwiftUI

// 节假日调休状态（名称保持不变）
enum WorkRestStatus: Equatable {
    case none       // 普通工作日/周末
    case rest       // 法定节假日休息（绿"休"）
    case work       // 调休上班（红"班"）
}

/// 日历单元格展示模型
struct ChineseCalendarInfo: Equatable {
    let holiday: String?          // 节日名称
    let isOffDay: Bool            // 是否休息（包括周末）
    let workRestStatus: WorkRestStatus
    let lunarDay: String?         // 农历日（如“初三”）
    let jieQi: String?            // 节气名称（如“清明”）

    /// 副标题：按优先级返回节日、节气、农历
    var subtitle: String {
        if let holiday = holiday, !holiday.isEmpty {
            return holiday
        }
        if let jieQi = jieQi, !jieQi.isEmpty {
            return jieQi
        }
        if let lunarDay = lunarDay, !lunarDay.isEmpty {
            return lunarDay
        }
        return ""
    }

    var subtitleColor: Color {
        if holiday != nil { return .red }
        if jieQi != nil { return .green }
        if lunarDay != nil { return .secondary }
        return .secondary
    }
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
