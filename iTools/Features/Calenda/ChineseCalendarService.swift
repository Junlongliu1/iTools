// 服务层，封装所有 Tyme4Swift 调用逻辑

import Foundation
import Tyme4Swift

// 类名保持不变
final class ChineseCalendarService {
    static let shared = ChineseCalendarService()
    
    private let gregorianCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }()
    
    // 函数名保持不变，内部逻辑精简为仅获取节假日
    func getInfo(for date: Date) -> ChineseCalendarInfo {
        let components = gregorianCalendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let solarDay = try? SolarDay.fromYmd(year, month, day) else {
            return fallbackInfo()
        }
        
        // 仅获取公历节日名（节日当天）
        let festivalName = solarDay.festival?.description
        
        // 仅获取法定假期区间（含调休）
        let legal = solarDay.legalHoliday
        
        // 计算休/班状态
        let workRestStatus: WorkRestStatus
        let isOffDay: Bool
        
        if let legal {
            workRestStatus = legal.isWork ? .work : .rest
            isOffDay = !legal.isWork
        } else {
            workRestStatus = .none
            let weekday = gregorianCalendar.component(.weekday, from: date)
            isOffDay = (weekday == 1 || weekday == 7)
        }
        
        // 返回精简后的模型，废弃字段填空值
        return ChineseCalendarInfo(
            lunarDay: "",
            jieQi: nil,
            holiday: festivalName,
            isOffDay: isOffDay,
            yi: [],
            ji: [],
            workRestStatus: workRestStatus
        )
    }
    
    // 函数名保持不变
    private func fallbackInfo() -> ChineseCalendarInfo {
        ChineseCalendarInfo(
            lunarDay: "",
            jieQi: nil,
            holiday: nil,
            isOffDay: false,
            yi: [],
            ji: [],
            workRestStatus: .none
        )
    }
}
