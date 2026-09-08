// 服务层，封装所有 Tyme4Swift 调用逻辑

import Foundation
import Tyme4Swift

final class ChineseCalendarService {
    static let shared = ChineseCalendarService()
    
    // 全局缓存字典，key 为归一化后的日期（当天 0 点）
    private var cache: [Date: ChineseCalendarInfo] = [:]
    private let lock = NSLock()  // 线程安全锁
    
    private init() {}
    
    // MARK: - 同步单日查询（先查缓存，没有再计算）
    func getInfo(for date: Date) -> ChineseCalendarInfo {
        let normalizedDate = Calendar.chinese.startOfDay(for: date)
        
        // 加锁读取缓存
        lock.lock()
        if let cached = cache[normalizedDate] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        // 缓存未命中，计算
        let info = calculateInfo(for: normalizedDate)
        
        // 加锁写入缓存
        lock.lock()
        cache[normalizedDate] = info
        lock.unlock()
        
        return info
    }
    
    // MARK: - 异步批量加载某个月的所有日期信息
    func getMonthInfo(year: Int, month: Int) async -> [Date: ChineseCalendarInfo] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result: [Date: ChineseCalendarInfo] = [:]
                
                // 获取该月的天数范围
                var comps = DateComponents()
                comps.year = year
                comps.month = month
                comps.day = 1
                
                guard let firstDay = Calendar.chinese.date(from: comps),
                      let range = Calendar.chinese.range(of: .day, in: .month, for: firstDay) else {
                    continuation.resume(returning: [:])
                    return
                }
                
                // 遍历该月每一天，调用 getInfo（内部会使用缓存）
                for day in 1...range.count {
                    if let date = Calendar.chinese.date(byAdding: .day, value: day - 1, to: firstDay) {
                        result[date] = self.getInfo(for: date)  // 线程安全
                    }
                }
                
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - 核心计算逻辑（私有）
    private func calculateInfo(for date: Date) -> ChineseCalendarInfo {
        let components = Calendar.chinese.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let solarDay = try? SolarDay.fromYmd(year, month, day) else {
            return ChineseCalendarInfo(
                holiday: nil,
                isOffDay: false,
                workRestStatus: .none
            )
        }
        
        let legal = solarDay.legalHoliday
        
        let festivalName: String?
        if let legal = legal {
            festivalName = legal.name
        } else if let festivalDesc = solarDay.festival?.description {
            festivalName = festivalDesc.components(separatedBy: " ").last
        } else {
            festivalName = nil
        }
        
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
}
