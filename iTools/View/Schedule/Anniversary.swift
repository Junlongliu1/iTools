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

// MARK: - 数据模型

@Model
final class Anniversary {
    // 每个属性都给显式默认值，SwiftData 迁移时更容易推断
    var title: String = ""
    var date: Date = Date()
    var isYearly: Bool = true
    var isLunar: Bool = false
    var notes: String = ""
    var categoryRaw: String = AnniversaryCategory.anniversary.rawValue
    var createdAt: Date = Date()

    init(
        title: String,
        date: Date,
        isYearly: Bool = true,
        isLunar: Bool = false,
        notes: String = "",
        category: AnniversaryCategory = .anniversary
    ) {
        self.title = title
        self.date = date
        self.isYearly = isYearly
        self.isLunar = isLunar
        self.notes = notes
        self.categoryRaw = category.rawValue
        self.createdAt = Date()
    }

    var category: AnniversaryCategory {
        get { AnniversaryCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    // MARK: 下一次发生日期

    var nextDate: Date {
        if isLunar && isYearly { return nextLunarDate }
        return nextGregorianDate
    }

    /// 公历
    private var nextGregorianDate: Date {
        let cal = Calendar.current
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

    /// 农历：取今年农历月/日，已过则顺延到下一农历年
    private var nextLunarDate: Date {
        let lunar = Calendar(identifier: .chinese)
        let gregorian = Calendar.current
        let today = gregorian.startOfDay(for: Date())

        let target = lunar.dateComponents([.month, .day], from: date)
        guard let tm = target.month, let td = target.day else { return date }

        let currentLunarYear = lunar.component(.year, from: Date())
        for offset in 0...3 {
            var dc = DateComponents()
            dc.year = currentLunarYear + offset
            dc.month = tm
            dc.day = td
            dc.isLeapMonth = false

            if let candidate = lunar.date(from: dc),
               gregorian.startOfDay(for: candidate) >= today {
                return candidate
            }
        }
        return date
    }

    // MARK: 倒计时

    var daysUntil: Int {
        let cal = Calendar.current
        let from = cal.startOfDay(for: Date())
        let to = cal.startOfDay(for: nextDate)
        return cal.dateComponents([.day], from: from, to: to).day ?? 0
    }

    var isToday: Bool { daysUntil == 0 }

    var yearsCount: Int {
        let cal = Calendar.current
        let y1 = cal.component(.year, from: date)
        let y2 = cal.component(.year, from: Date())
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

    /// 例如「腊月初八」，非农历返回 nil
    var lunarDateText: String? {
        guard isLunar else { return nil }
        let lunar = Calendar(identifier: .chinese)
        let comps = lunar.dateComponents([.month, .day], from: date)
        guard let m = comps.month, let d = comps.day else { return nil }
        return "\(Self.lunarMonthName(m))\(Self.lunarDayName(d))"
    }

    /// 公历文本：如「3月15日」
    var gregorianDateText: String {
        let c = Calendar.current
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

// MARK: - 数组扩展

extension Array where Element == Anniversary {
    func inCategory(_ category: AnniversaryCategory) -> [Anniversary] {
        self
            .filter { $0.category == category }
            .sorted { $0.nextDate < $1.nextDate }
    }

    func count(in category: AnniversaryCategory) -> Int {
        self.filter { $0.category == category }.count
    }
}

// MARK: - Schema 版本化（防止后续加字段再丢数据）

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
