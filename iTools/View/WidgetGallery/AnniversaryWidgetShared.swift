// AnniversaryWidgetShared.swift
//
// 此文件需同时加入 App Target 与 Widget Target。
// 两个 Target 都要在 Signing & Capabilities 里添加同一 App Group。

import Foundation
import SwiftUI

// MARK: - 分类

enum WidgetAnniversaryCategory: String, Codable, Hashable {
    case birthday, anniversary, festival, other

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
}

// MARK: - 传输模型

struct WidgetAnniversaryItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let originalDate: Date
    let isYearly: Bool
    let isLunar: Bool
    let lunarIsLeapMonth: Bool
    let categoryRaw: String
    let isPinned: Bool

    var category: WidgetAnniversaryCategory {
        WidgetAnniversaryCategory(rawValue: categoryRaw) ?? .other
    }
}

// MARK: - 日期计算

enum WidgetAnniversaryCalculator {

    static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        return c
    }()

    static let chinese: Calendar = {
        var c = Calendar(identifier: .chinese)
        c.locale = Locale(identifier: "zh_CN")
        return c
    }()

    static func nextDate(for item: WidgetAnniversaryItem, now: Date = .now) -> Date {
        if item.isYearly && item.isLunar {
            return nextLunarDate(from: item.originalDate,
                                 leap: item.lunarIsLeapMonth,
                                 now: now)
        }
        if item.isYearly {
            return nextGregorianDate(from: item.originalDate, now: now)
        }
        return item.originalDate
    }

    static func daysUntil(_ item: WidgetAnniversaryItem, now: Date = .now) -> Int {
        let cal = gregorian
        let next = nextDate(for: item, now: now)
        return cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: now),
            to: cal.startOfDay(for: next)
        ).day ?? 0
    }

    private static func nextGregorianDate(from date: Date, now: Date) -> Date {
        let cal = gregorian
        let today = cal.startOfDay(for: now)
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

    private static func nextLunarDate(from date: Date, leap: Bool, now: Date) -> Date {
        let lunar = chinese
        let greg = gregorian
        let today = greg.startOfDay(for: now)

        let target = lunar.dateComponents([.month, .day], from: date)
        guard let tm = target.month, let td = target.day else { return date }

        let currentLunarYear = lunar.component(.year, from: now)

        for offset in 0...4 {
            let year = currentLunarYear + offset

            if let d = lunarDate(year: year, month: tm, day: td, leap: leap),
               greg.startOfDay(for: d) >= today {
                return d
            }
            if leap,
               let d = lunarDate(year: year, month: tm, day: td, leap: false),
               greg.startOfDay(for: d) >= today {
                return d
            }
        }
        return date
    }

    private static func lunarDate(year: Int, month: Int, day: Int, leap: Bool) -> Date? {
        let lunar = chinese
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
}

// MARK: - App Group 存储

enum WidgetAnniversaryStore {
    static let appGroupID = "group.com.iTools.calendarwidget"
    static let itemsKey   = "widget.anniversaries.upcoming"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ items: [WidgetAnniversaryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults?.set(data, forKey: itemsKey)
    }

    static func load() -> [WidgetAnniversaryItem] {
        guard let data = defaults?.data(forKey: itemsKey),
              let items = try? JSONDecoder().decode([WidgetAnniversaryItem].self, from: data)
        else { return [] }
        return items
    }
}
