import Foundation
import Combine

// MARK: - 节假日数据源协议
protocol HolidayDataProvider {
    func getHolidayInfo(for date: Date) -> (name: String, isOffDay: Bool)?
}

// MARK: - HolidayManager
class HolidayManager: ObservableObject {
    static let shared = HolidayManager()
    
    struct HolidayInfo {
        let name: String
        let isOffDay: Bool
    }
    
    @Published private var holidays: [String: HolidayInfo] = [:]
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    private init() {
        loadMockData()
    }
    
    // ✅ 修改：重命名为 fetchHolidayInfo，避免与协议方法同名产生歧义
    func fetchHolidayInfo(for date: Date) -> HolidayInfo? {
        let key = Self.dateFormatter.string(from: date)
        return holidays[key]
    }
    
    private func loadMockData() {
        let mockData: [(String, String, Bool)] = [
            ("2026-01-01", "元旦", true),
            ("2026-01-02", "元旦", true),
            ("2026-01-03", "元旦", true),
            ("2026-02-15", "春节", false),
            ("2026-02-16", "春节", true),
            ("2026-02-17", "春节", true),
            ("2026-02-18", "春节", true),
            ("2026-02-19", "春节", true),
            ("2026-02-20", "春节", true),
            ("2026-02-21", "春节", true),
            ("2026-02-22", "春节", true),
            ("2026-02-28", "春节", false),
            ("2026-04-04", "清明", true),
            ("2026-04-05", "清明", true),
            ("2026-04-06", "清明", true),
            ("2026-04-26", "劳动节", false),
            ("2026-05-01", "劳动节", true),
            ("2026-05-02", "劳动节", true),
            ("2026-05-03", "劳动节", true),
            ("2026-05-04", "劳动节", true),
            ("2026-05-05", "劳动节", true),
            ("2026-06-19", "端午", true),
            ("2026-06-20", "端午", true),
            ("2026-06-21", "端午", true),
            ("2026-09-25", "中秋", true),
            ("2026-09-26", "中秋", true),
            ("2026-09-27", "中秋", true),
            ("2026-10-01", "国庆", true),
            ("2026-10-02", "国庆", true),
            ("2026-10-03", "国庆", true),
            ("2026-10-04", "国庆", true),
            ("2026-10-05", "国庆", true),
            ("2026-10-06", "国庆", true),
            ("2026-10-07", "国庆", true),
            ("2026-10-10", "国庆", false)
        ]
        
        for (dateStr, name, isOff) in mockData {
            holidays[dateStr] = HolidayInfo(name: name, isOffDay: isOff)
        }
    }
}

// MARK: - 协议遵循
extension HolidayManager: HolidayDataProvider {
    // ✅ 现在这里不再有歧义，因为类内部方法已改名为 fetchHolidayInfo
    func getHolidayInfo(for date: Date) -> (name: String, isOffDay: Bool)? {
        guard let info = self.fetchHolidayInfo(for: date) else { return nil }
        return (info.name, info.isOffDay)
    }
}
