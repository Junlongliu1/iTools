// 服务层，封装所有 Tyme4Swift 调用逻辑

import Foundation
import Tyme4Swift

// 类名保持不变
final class ChineseCalendarService {
    static let shared = ChineseCalendarService()
    
    // 函数名保持不变，内部逻辑精简为仅获取节假日
    func getInfo(for date: Date) -> ChineseCalendarInfo {
        let components = Calendar.chinese.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let solarDay = try? SolarDay.fromYmd(year, month, day) else {
            return fallbackInfo()
        }
        
        let legal = solarDay.legalHoliday
        
        // 节日名称：优先使用法定节假日名称（如“春节”），否则从公历节日描述中提取
        let festivalName: String?
        if let legal = legal {
            festivalName = legal.name
        } else if let festivalDesc = solarDay.festival?.description {
            // 假设格式类似 "2026-01-01 元旦" 或 "2026年1月1日 元旦"
            // 取最后一个空格后的内容作为节日名称
            festivalName = festivalDesc.components(separatedBy: " ").last
        } else {
            festivalName = nil
        }
        
        // 计算休/班状态
        let workRestStatus: WorkRestStatus
        let isOffDay: Bool
        
        if let legal = legal {
            workRestStatus = legal.isWork ? .work : .rest
            isOffDay = !legal.isWork
        } else {
            workRestStatus = .none
            let weekday = Calendar.chinese.component(.weekday, from: date)
            isOffDay = (weekday == 1 || weekday == 7)
        }
        
        return ChineseCalendarInfo(
            holiday: festivalName,
            isOffDay: isOffDay,
            workRestStatus: workRestStatus
        )
    }
    
    private func fallbackInfo() -> ChineseCalendarInfo {
        ChineseCalendarInfo(
            holiday: nil,
            isOffDay: false,
            workRestStatus: .none
        )
    }
}
