// 数据模型层，纯数据结构

import Foundation
import SwiftUI

/// 日历单元格展示模型
struct ChineseCalendarInfo {
    let lunarDay: String      // 农历日（如"十七"）
    let jieQi: String?        // 节气（仅当天有节气时非空）
    let holiday: String?      // 节日名称
    let isOffDay: Bool        // 是否休息日
    let yi: [String]          // 宜
    let ji: [String]          // 忌
    
    /// 副标题显示优先级：节气 > 节日 > 农历日
    var subtitle: String {
        if let jieQi { return jieQi }
        if let holiday { return holiday }
        return lunarDay
    }
    
    /// 副标题颜色
    var subtitleColor: Color {
        if jieQi != nil { return .green }
        if holiday != nil { return isOffDay ? .red : .orange }
        return .secondary
    }
}
