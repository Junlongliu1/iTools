// CalendarProvider.swift
import WidgetKit
import SwiftUI

struct CalendarProvider: TimelineProvider {

    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntryBuilder.make(for: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        completion(CalendarEntryBuilder.make(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let cal = CalendarEntryBuilder.calendar
        let now = Date()

        // 用日历运算得到明天 0 点，避免 DST 下 86400 秒的误差
        guard let startOfTomorrow = cal.date(byAdding: .day,
                                             value: 1,
                                             to: cal.startOfDay(for: now)) else {
            // 极端兜底：1 小时后重试
            let entry = CalendarEntryBuilder.make(for: now, today: now)
            completion(Timeline(entries: [entry],
                                policy: .after(now.addingTimeInterval(3600))))
            return
        }

        let nowEntry      = CalendarEntryBuilder.make(for: now,             today: now)
        let tomorrowEntry = CalendarEntryBuilder.make(for: startOfTomorrow, today: startOfTomorrow)

        // 午夜后一分钟再请求新时间线，确保跨天时 widget 已切换
        let refreshAfter = startOfTomorrow.addingTimeInterval(60)

        let timeline = Timeline(entries: [nowEntry, tomorrowEntry],
                                policy: .after(refreshAfter))
        completion(timeline)
    }
}
