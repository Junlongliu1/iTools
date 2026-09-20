// CalendarModels.swift
import Foundation
import WidgetKit

// MARK: - Timeline Entry

struct CalendarEntry: TimelineEntry {
    let date: Date
    let year: String             // "2026"
    let monthText: String        // "9月"
    let dayNumber: Int           // 20
    let weeks: [[CalendarDay]]   // 固定 3 周：[上周, 本周, 下周]
}

struct CalendarDay: Identifiable, Hashable {
    let id: String               // "yyyy-MM-dd"
    let day: Int
    let isToday: Bool
    let isCurrentMonth: Bool
}

// MARK: - 构建 Entry

enum CalendarEntryBuilder {

    /// 统一使用的日历（周一为一周起始）
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2   // 周一
        return cal
    }()

    private static let idFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 中文月份格式：9月 / 10月
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月"
        return f
    }()

    /// - Parameters:
    ///   - date: entry 对应的日期（用于显示 year / month / day）
    ///   - today: 用于判定 isToday 的参考日期；默认当前
    static func make(for date: Date, today: Date = .now) -> CalendarEntry {
        let cal = calendar
        let year  = cal.component(.year,  from: date)
        let month = cal.component(.month, from: date)
        let day   = cal.component(.day,   from: date)

        let monthText = monthFormatter.string(from: date)

        // 找到 date 所在周的周一
        let dateStart = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: dateStart)   // 1=日, 2=一, ..., 7=六
        let offsetToMonday = (weekday + 5) % 7                    // 一→0, 二→1, ..., 日→6

        guard let thisMonday = cal.date(byAdding: .day, value: -offsetToMonday, to: dateStart) else {
            return CalendarEntry(date: date, year: "\(year)", monthText: monthText,
                                 dayNumber: day, weeks: [])
        }

        // 三周：上周 / 本周 / 下周
        var weeks: [[CalendarDay]] = []
        for weekOffset in [-1, 0, 1] {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: thisMonday) else { continue }
            var week: [CalendarDay] = []
            for i in 0..<7 {
                guard let d = cal.date(byAdding: .day, value: i, to: weekStart) else { continue }
                let dMonth = cal.component(.month, from: d)
                week.append(CalendarDay(
                    id: idFormatter.string(from: d),
                    day: cal.component(.day, from: d),
                    isToday: cal.isDate(d, inSameDayAs: today),
                    isCurrentMonth: dMonth == month
                ))
            }
            weeks.append(week)
        }

        return CalendarEntry(
            date: date,
            year: "\(year)",
            monthText: monthText,
            dayNumber: day,
            weeks: weeks
        )
    }
}
