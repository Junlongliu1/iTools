// CalendarWidgetEntryView.swift
import SwiftUI
import WidgetKit

struct CalendarWidgetEntryView: View {
    var entry: CalendarEntry

    var body: some View {
        RectangularCalendarView(entry: entry)
    }
}

// MARK: - 锁屏矩形（唯一布局）

private struct RectangularCalendarView: View {
    let entry: CalendarEntry

    /// 用于区分全色 / 强调渲染模式
    @Environment(\.widgetRenderingMode) private var renderingMode

    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    private enum Metrics {
        static let horizontalSpacing: CGFloat = 10
        static let verticalSpacing: CGFloat   = 1
        static let cellSize: CGFloat          = 15
        static let dayFontSize: CGFloat       = 11
        static let headerFontSize: CGFloat    = 9
        static let metaFontSize: CGFloat      = 12
        static let bigDayFontSize: CGFloat    = 34
    }

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.horizontalSpacing) {
            leftColumn
            rightCalendar
        }
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - 左侧：年 / 月 / 今天日期

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.year)
                .font(.system(size: Metrics.metaFontSize, weight: .bold))
                .foregroundStyle(.secondary)

            Text(entry.monthText)
                .font(.system(size: Metrics.metaFontSize, weight: .bold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            bigDay
        }
        .frame(maxHeight: .infinity, alignment: .leading)
    }

    /// 左侧大数字：彩色模式显示红色，其他模式回退系统强调色
    @ViewBuilder
    private var bigDay: some View {
        if renderingMode == .fullColor {
            Text("\(entry.dayNumber)")
                .font(.system(size: Metrics.bigDayFontSize,
                              weight: .bold,
                              design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(Color.red)
        } else {
            Text("\(entry.dayNumber)")
                .font(.system(size: Metrics.bigDayFontSize,
                              weight: .bold,
                              design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .widgetAccentable()
        }
    }

    // MARK: - 右侧：3 周日历

    private var rightCalendar: some View {
        VStack(spacing: Metrics.verticalSpacing) {
            // 星期头
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s)
                        .font(.system(size: Metrics.headerFontSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 1)

            // 三行日期
            if entry.weeks.isEmpty {
                Color.clear.frame(height: Metrics.cellSize * 3)
            } else {
                ForEach(Array(entry.weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(week) { day in
                            dayCell(day)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 单元格

    @ViewBuilder
    private func dayCell(_ day: CalendarDay) -> some View {
        if day.isToday {
            todayCell(day)
        } else {
            Text("\(day.day)")
                .font(.system(size: Metrics.dayFontSize, weight: .regular))
                .foregroundStyle(day.isCurrentMonth
                                 ? Color.primary
                                 : Color.secondary.opacity(0.6))
                .frame(width: Metrics.cellSize, height: Metrics.cellSize)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    /// 今日高亮：圆形磨砂底座（无描边）
    @ViewBuilder
    private func todayCell(_ day: CalendarDay) -> some View {
        let shape = Circle()

        if renderingMode == .fullColor {
            Text("\(day.day)")
                .font(.system(size: Metrics.dayFontSize, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: Metrics.cellSize, height: Metrics.cellSize)
                .background(
                    shape.fill(.ultraThinMaterial)
                )
        } else {
            // 强调 / 单色模式下磨砂会被系统去饱和，
            // 用半透明 primary 兜底，保证"今天"仍然看得清
            Text("\(day.day)")
                .font(.system(size: Metrics.dayFontSize, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: Metrics.cellSize, height: Metrics.cellSize)
                .background(
                    shape.fill(Color.primary.opacity(0.18))
                )
                .widgetAccentable()
        }
    }

    // MARK: - 无障碍

    private var accessibilityLabel: String {
        "\(entry.year)年\(entry.monthText)\(entry.dayNumber)日，本周日历"
    }
}

// MARK: - 预览

#Preview(as: .accessoryRectangular) {
    CalendarWidget()
} timeline: {
    CalendarEntryBuilder.make(for: .now)
}
