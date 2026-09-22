// Anniversary.swift
import SwiftUI
import SwiftData

// MARK: - 分类

enum AnniversaryCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case birthday, anniversary, festival, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .birthday:    return "生日"
        case .anniversary: return "纪念日"
        case .festival:    return "节日"
        case .other:       return "其他"
        }
    }

    var symbol: String {
        switch self {
        case .birthday:    return "birthday.cake.fill"
        case .anniversary: return "heart.fill"
        case .festival:    return "party.popper.fill"
        case .other:       return "star.fill"
        }
    }

    var topColor: Color {
        switch self {
        case .birthday:    return Color(red: 1.00, green: 0.58, blue: 0.30)
        case .anniversary: return Color(red: 1.00, green: 0.36, blue: 0.52)
        case .festival:    return Color(red: 0.99, green: 0.72, blue: 0.20)
        case .other:       return Color(red: 0.36, green: 0.58, blue: 1.00)
        }
    }

    var bottomColor: Color {
        switch self {
        case .birthday:    return Color(red: 0.94, green: 0.38, blue: 0.10)
        case .anniversary: return Color(red: 0.84, green: 0.14, blue: 0.36)
        case .festival:    return Color(red: 0.90, green: 0.52, blue: 0.08)
        case .other:       return Color(red: 0.12, green: 0.34, blue: 0.88)
        }
    }
}

// MARK: - 提醒选项

enum ReminderOption: Int, CaseIterable, Identifiable {
    case off         = -1
    case sameDay     = 0
    case oneDay      = 1
    case threeDays   = 3
    case oneWeek     = 7
    case thirtyDays  = 30

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off:        return "不提醒"
        case .sameDay:    return "当天提醒"
        case .oneDay:     return "提前 1 天"
        case .threeDays:  return "提前 3 天"
        case .oneWeek:    return "提前 7 天"
        case .thirtyDays: return "提前 30 天"
        }
    }
}

// MARK: - 数据模型

@Model
final class Anniversary {
    var uuid: UUID = UUID()

    var title: String = ""
    var date: Date = Date()
    var isYearly: Bool = true
    var isLunar: Bool = false
    var lunarIsLeapMonth: Bool = false
    var notes: String = ""
    var categoryRaw: String = AnniversaryCategory.anniversary.rawValue
    var createdAt: Date = Date()
    var isPinned: Bool = false
    var reminderAdvanceDays: Int = ReminderOption.off.rawValue

    /// 计算属性 `nextDate` 的当日缓存。以「今天 0 点」为 key，
    /// 跨天后自动失效（无需手动清理）。
    @Transient private var cachedNextDate: Date?
    @Transient private var cachedNextDateAnchor: Date?

    init(
        title: String,
        date: Date,
        isYearly: Bool = true,
        isLunar: Bool = false,
        lunarIsLeapMonth: Bool = false,
        notes: String = "",
        category: AnniversaryCategory = .anniversary,
        isPinned: Bool = false,
        reminderAdvanceDays: Int = ReminderOption.off.rawValue
    ) {
        self.uuid = UUID()
        self.title = title
        self.date = date
        self.isYearly = isYearly
        self.isLunar = isLunar
        self.lunarIsLeapMonth = lunarIsLeapMonth
        self.notes = notes
        self.categoryRaw = category.rawValue
        self.createdAt = Date()
        self.isPinned = isPinned
        self.reminderAdvanceDays = reminderAdvanceDays
    }

    var category: AnniversaryCategory {
        get { AnniversaryCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var reminder: ReminderOption {
        get { ReminderOption(rawValue: reminderAdvanceDays) ?? .off }
        set { reminderAdvanceDays = newValue.rawValue }
    }

    // MARK: 缓存日历（避免 body 求值时反复构造）

    static let gregorianCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        return c
    }()

    static let chineseCalendar: Calendar = {
        var c = Calendar(identifier: .chinese)
        c.locale = Locale(identifier: "zh_CN")
        return c
    }()

    // MARK: 下一次发生日期（带当日缓存）

    var nextDate: Date {
        let today = Self.gregorianCalendar.startOfDay(for: Date())
        if cachedNextDateAnchor == today, let cached = cachedNextDate {
            return cached
        }
        let value = isLunar && isYearly ? nextLunarDate : nextGregorianDate
        cachedNextDate = value
        cachedNextDateAnchor = today
        return value
    }

    /// 编辑保存后手动失效缓存（模型内容变了，但日期锚点没变）
    func invalidateNextDateCache() {
        cachedNextDate = nil
        cachedNextDateAnchor = nil
    }

    private var nextGregorianDate: Date {
        let cal = Self.gregorianCalendar
        guard isYearly else { return date }

        let today = cal.startOfDay(for: Date())
        let y = cal.component(.year, from: today)
        let comps = cal.dateComponents([.month, .day], from: date)

        var dc = DateComponents()
        dc.year = y
        dc.month = comps.month
        dc.day = comps.day

        guard var candidate = cal.date(from: dc) else { return date }
        if cal.startOfDay(for: candidate) < today {
            dc.year = y + 1
            candidate = cal.date(from: dc) ?? candidate
        }
        return candidate
    }

    /// 农历下一次：优先精确匹配闰月；若当年无闰月则回退到非闰月；日不存在则回退到当月最后一天
    private var nextLunarDate: Date {
        let lunar = Self.chineseCalendar
        let gregorian = Self.gregorianCalendar
        let today = gregorian.startOfDay(for: Date())

        let target = lunar.dateComponents([.month, .day], from: date)
        guard let tm = target.month, let td = target.day else { return date }

        let currentLunarYear = lunar.component(.year, from: Date())
        let wantLeap = lunarIsLeapMonth

        for offset in 0...4 {
            let year = currentLunarYear + offset

            if let d = Self.lunarDate(year: year, month: tm, day: td, leap: wantLeap),
               gregorian.startOfDay(for: d) >= today {
                return d
            }

            if wantLeap,
               let d = Self.lunarDate(year: year, month: tm, day: td, leap: false),
               gregorian.startOfDay(for: d) >= today {
                return d
            }
        }
        return date
    }

    private static func lunarDate(year: Int, month: Int, day: Int, leap: Bool) -> Date? {
        let lunar = Self.chineseCalendar
        var dc = DateComponents()
        dc.year = year
        dc.month = month
        dc.day = day
        dc.isLeapMonth = leap

        if let d = lunar.date(from: dc) { return d }

        for fallback in stride(from: day - 1, through: 28, by: -1) {
            dc.day = fallback
            if let d = lunar.date(from: dc) { return d }
        }
        return nil
    }

    // MARK: 倒计时

    var daysUntil: Int {
        let cal = Self.gregorianCalendar
        let from = cal.startOfDay(for: Date())
        let to = cal.startOfDay(for: nextDate)
        return cal.dateComponents([.day], from: from, to: to).day ?? 0
    }

    var isToday: Bool { daysUntil == 0 }

    var lastDate: Date? {
        let cal = Self.gregorianCalendar
        if !isYearly {
            let d = cal.startOfDay(for: date)
            return d <= cal.startOfDay(for: Date()) ? d : nil
        }
        return cal.date(byAdding: .year, value: -1, to: nextDate)
    }

    var daysSinceLast: Int? {
        guard let last = lastDate else { return nil }
        let cal = Self.gregorianCalendar
        return cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: last),
            to: cal.startOfDay(for: Date())
        ).day
    }

    var yearsCount: Int {
        guard isYearly else { return 0 }
        let cal = Self.gregorianCalendar
        let y1 = cal.component(.year, from: date)
        let y2 = cal.component(.year, from: nextDate)
        return max(0, y2 - y1)
    }

    var countdownText: String {
        switch daysUntil {
        case 0:  return "就是今天"
        case 1:  return "明天"
        default: return "\(daysUntil) 天后"
        }
    }

    // MARK: 农历文本

    var lunarDateText: String? {
        guard isLunar else { return nil }
        let lunar = Self.chineseCalendar
        let comps = lunar.dateComponents([.month, .day], from: date)
        guard let m = comps.month, let d = comps.day else { return nil }
        let leap = lunarIsLeapMonth ? "闰" : ""
        return "\(leap)\(Self.lunarMonthName(m))\(Self.lunarDayName(d))"
    }

    var gregorianDateText: String {
        let c = Self.gregorianCalendar
        let m = c.component(.month, from: nextDate)
        let d = c.component(.day, from: nextDate)
        return "\(m)月\(d)日"
    }

    private static func lunarMonthName(_ m: Int) -> String {
        let names = ["正月", "二月", "三月", "四月", "五月", "六月",
                     "七月", "八月", "九月", "十月", "冬月", "腊月"]
        guard m >= 1 && m <= 12 else { return "" }
        return names[m - 1]
    }

    private static func lunarDayName(_ d: Int) -> String {
        let names = ["初一","初二","初三","初四","初五","初六","初七","初八","初九","初十",
                     "十一","十二","十三","十四","十五","十六","十七","十八","十九","二十",
                     "廿一","廿二","廿三","廿四","廿五","廿六","廿七","廿八","廿九","三十"]
        guard d >= 1 && d <= 30 else { return "" }
        return names[d - 1]
    }
}

// MARK: - 排序

enum AnniversarySortOrder: String, CaseIterable, Identifiable {
    case nextDate
    case created
    case title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nextDate: return "按日期"
        case .created:  return "按创建"
        case .title:    return "按名称"
        }
    }

    var symbol: String {
        switch self {
        case .nextDate: return "calendar"
        case .created:  return "clock"
        case .title:    return "textformat"
        }
    }

    /// 预计算排序 key，避免 n log n 次调用 `nextDate`
    func sorted(_ items: [Anniversary]) -> [Anniversary] {
        let base: [Anniversary]
        switch self {
        case .nextDate:
            base = items
                .map { (item: $0, key: $0.nextDate) }
                .sorted { $0.key < $1.key }
                .map(\.item)
        case .created:
            base = items.sorted { $0.createdAt > $1.createdAt }
        case .title:
            base = items.sorted {
                $0.title.localizedCompare($1.title) == .orderedAscending
            }
        }

        let pinned = base.filter { $0.isPinned }
        let normal = base.filter { !$0.isPinned }
        return pinned + normal
    }
}

// MARK: - 数组扩展

extension Array where Element == Anniversary {
    func inCategory(_ category: AnniversaryCategory) -> [Anniversary] {
        self
            .filter { $0.category == category }
            .map { (item: $0, key: $0.nextDate) }
            .sorted { $0.key < $1.key }
            .map(\.item)
    }

    func count(in category: AnniversaryCategory) -> Int {
        self.filter { $0.category == category }.count
    }
}

// MARK: - Schema 版本化

enum AnniversarySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Anniversary.self]
    }
}

enum AnniversaryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AnniversarySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
