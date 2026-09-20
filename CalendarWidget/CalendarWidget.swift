// CalendarWidget.swift
import WidgetKit
import SwiftUI

struct CalendarWidget: Widget {
    let kind: String = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            CalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("日历")
        .description("在锁屏上快速查看今天的日期与本周日历。")
        .supportedFamilies([
            .accessoryRectangular
        ])
    }
}
