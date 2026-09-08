// 服务层，封装所有 Tyme4Swift 调用逻辑

import Foundation
import Tyme4Swift

final class ChineseCalendarService {
    static let shared = ChineseCalendarService()
    
    private let gregorianCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }()
    
    func getInfo(for date: Date) -> ChineseCalendarInfo {
        let components = gregorianCalendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return fallbackInfo()
        }
        
        guard let solarDay = try? SolarDay.fromYmd(year, month, day) else {
            return fallbackInfo()
        }
        
        let lunarDay = solarDay.getLunarDay()
        
        // ✅ 节气：SolarDay.term 已确认
        let jieQi: String? = {
            let t = solarDay.term
            if t.getSolarDay() == solarDay {
                return t.description
            }
            return nil
        }()
        
        // ⚠️ 八字宜忌：LunarDay 无此 API，暂返回空数组
        // 后续如需八字，需探索 EightChar 类或 LunarMonth/LunarYear
        let yi: [String] = []
        let ji: [String] = []
        
        // ✅ 节日 & 休息日：基于真实 API (name + isWork)
        let holidayName: String?
        let isOffDay: Bool
        
        if let legal = solarDay.legalHoliday {
            holidayName = legal.name          // ✅ 真实属性
            isOffDay = !legal.isWork           // ✅ isWork=false 表示休息
        } else {
            holidayName = solarDay.festival?.description
            let weekday = gregorianCalendar.component(.weekday, from: date)
            isOffDay = (weekday == 1 || weekday == 7)
        }
        
        // ✅ 农历日：getName() 已确认可用
        let lunarDayText = lunarDay.getName()
        
        return ChineseCalendarInfo(
            lunarDay: lunarDayText,
            jieQi: jieQi,
            holiday: holidayName,
            isOffDay: isOffDay,
            yi: yi,
            ji: ji
        )
    }
    
    private func fallbackInfo() -> ChineseCalendarInfo {
        ChineseCalendarInfo(
            lunarDay: "",
            jieQi: nil,
            holiday: nil,
            isOffDay: false,
            yi: [],
            ji: []
        )
    }
}
