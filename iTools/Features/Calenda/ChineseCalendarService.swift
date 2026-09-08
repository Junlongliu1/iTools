// 服务层，封装所有 Tyme4Swift 调用逻辑

import Foundation
import Tyme4Swift

final class ChineseCalendarService {
    static let shared = ChineseCalendarService()
    
    private var cache: [Date: ChineseCalendarInfo] = [:]
    private let lock = NSLock()
    private var printedMonths = Set<String>()
    
    private init() {}
    
    func getInfo(for date: Date) -> ChineseCalendarInfo {
        let normalizedDate = Calendar.chinese.startOfDay(for: date)
        
        lock.lock()
        if let cached = cache[normalizedDate] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        let info = calculateInfo(for: normalizedDate)
        
        lock.lock()
        cache[normalizedDate] = info
        lock.unlock()
        
        return info
    }
    
    func getMonthInfo(year: Int, month: Int) async -> [Date: ChineseCalendarInfo] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result: [Date: ChineseCalendarInfo] = [:]
                
                var comps = DateComponents()
                comps.year = year
                comps.month = month
                comps.day = 1
                
                guard let firstDay = Calendar.chinese.date(from: comps),
                      let range = Calendar.chinese.range(of: .day, in: .month, for: firstDay) else {
                    continuation.resume(returning: [:])
                    return
                }
                
                for day in 1...range.count {
                    if let date = Calendar.chinese.date(byAdding: .day, value: day - 1, to: firstDay) {
                        result[date] = self.getInfo(for: date)
                    }
                }
                self.printHolidaysIfNeeded(year: year, month: month, data: result)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func printHolidaysIfNeeded(year: Int, month: Int, data: [Date: ChineseCalendarInfo]) {
        let key = "\(year)-\(month)"
        lock.lock()
        defer { lock.unlock() }
        
        guard !printedMonths.contains(key) else { return }
        printedMonths.insert(key)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "zh_CN")
        
        let holidays = data
            .filter { $0.value.holiday != nil && !$0.value.holiday!.isEmpty }
            .sorted { $0.key < $1.key }
        
        print("========== \(year)年\(month)月节日列表 ==========")
        for (date, info) in holidays {
            print("\(dateFormatter.string(from: date)) - \(info.holiday!)")
        }
        print("==========================================")
    }
    
    private func calculateInfo(for date: Date) -> ChineseCalendarInfo {
        let components = Calendar.chinese.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let solarDay = try? SolarDay.fromYmd(year, month, day) else {
            return ChineseCalendarInfo(
                holiday: nil,
                isOffDay: false,
                workRestStatus: .none,
                lunarDay: nil,
                jieQi: nil
            )
        }
        
        // 法定节假日及调休状态（用于角标）
        let legal = solarDay.legalHoliday
        
        // 节日名称：仅公历节日正日显示
        var festivalName: String? = nil
        if let festivalDesc = solarDay.festival?.description {
            festivalName = festivalDesc.components(separatedBy: " ").last
        }
        if festivalName == nil {
            let monthDay = String(format: "%02d-%02d", month, day)
            festivalName = Self.solarFestivals[monthDay]
        }
        
        // 农历日期（初一显示月份，其他显示日）
        var lunarDayText: String? = nil
        let lunarDay = solarDay.getLunarDay()
        if lunarDay.day == 1 {
            lunarDayText = lunarDay.lunarMonth.getName() // 或 description
        } else {
            lunarDayText = lunarDay.getName()
        }
        
        // 节气（当天交节则显示）
        var jieQiText: String? = nil
        let termDay = solarDay.termDay
        if termDay.dayIndex == 0 {
            jieQiText = termDay.solarTerm.getName() // 或 description
        }
        
        // 休/班状态
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
            workRestStatus: workRestStatus,
            lunarDay: lunarDayText,
            jieQi: jieQiText
        )
    }
    
    private static let solarFestivals: [String: String] = [
        "01-01": "元旦",
        "02-14": "情人节",
        "03-08": "妇女节",
        "03-12": "植树节",
        "03-15": "消费者日",
        "03-21": "睡眠日",
        "04-01": "愚人节",
        "04-15": "国家安全",
        "04-22": "地球日",
        "05-01": "劳动节",
        "05-04": "青年节",
        "05-08": "微笑日",
        "05-10": "母亲节",
        "05-12": "护士节",
        "05-18": "博物馆日",
        "05-31": "无烟日",
        "06-01": "儿童节",
        "06-05": "环境日",
        "06-06": "爱眼日",
        "06-21": "父亲节",
        "06-26": "禁毒日",
        "07-01": "建党节",
        "08-01": "建军节",
        "08-08": "健身日",
        "08-15": "日本投降",
        "09-03": "抗战胜利",
        "09-10": "教师节",
        "09-18": "九一八",
        "09-20": "爱牙日",
        "09-27": "旅游日",
        "10-01": "国庆节",
        "10-24": "程序员节",
        "10-31": "万圣夜",
        "11-01": "万圣节",
        "11-11": "光棍节",
        "11-26": "感恩节",
        "12-13": "公祭日",
        "12-24": "平安夜",
        "12-25": "圣诞节",
    ]
}
