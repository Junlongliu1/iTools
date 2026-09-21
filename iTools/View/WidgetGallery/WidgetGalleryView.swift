// WidgetGalleryView.swift
import SwiftUI

struct WidgetGalleryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: DSLayout.cardSpacing) {
                    LazyVStack(spacing: DSLayout.cardSpacing) {
                        lockScreenWidgetCard
                        infoCard
                    }
                }
                .padding(.horizontal, DSLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("小组件")
        }
    }

    // MARK: - 锁屏小组件预览

    private var lockScreenWidgetCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "square.grid.2x2.fill",
                iconColor: .blue,
                title: "锁屏小组件"
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("日历 · 矩形")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                LockScreenCalendarPreview()
            }
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    // MARK: - 说明

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "info.circle.fill",
                iconColor: .blue,
                title: "说明"
            )

            Text("这里展示的是现有锁屏矩形小组件的页面预览。实际使用时，可在系统锁屏编辑中添加「日历」小组件。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DSLayout.rowHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }
}

// MARK: - 模拟锁屏背景 + 小组件

private struct LockScreenCalendarPreview: View {
    private let entry = PreviewCalendarEntryBuilder.make(for: .now)

    private var lockScreenDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.07, blue: 0.13),
                            Color(red: 0.12, green: 0.10, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("09:41")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))

                    Text(lockScreenDateText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)

                PreviewCalendarWidgetStyle(entry: entry)
                    .frame(width: 160, height: 72)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .environment(\.colorScheme, .dark)
            }
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

// MARK: - 小组件样式复刻

private struct PreviewCalendarWidgetStyle: View {
    let entry: PreviewCalendarEntry

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
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.year)
                .font(.system(size: Metrics.metaFontSize, weight: .bold))
                .foregroundStyle(.secondary)

            Text(entry.monthText)
                .font(.system(size: Metrics.metaFontSize, weight: .bold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text("\(entry.dayNumber)")
                .font(.system(size: Metrics.bigDayFontSize,
                              weight: .bold,
                              design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(Color.red)
        }
        .frame(maxHeight: .infinity, alignment: .leading)
    }

    private var rightCalendar: some View {
        VStack(spacing: Metrics.verticalSpacing) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: Metrics.headerFontSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 1)

            ForEach(Array(entry.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        dayCell(day)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func dayCell(_ day: PreviewCalendarDay) -> some View {
        if day.isToday {
            Text("\(day.day)")
                .font(.system(size: Metrics.dayFontSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Metrics.cellSize, height: Metrics.cellSize)
                .background(
                    Circle().fill(.ultraThinMaterial)
                )
        } else {
            Text("\(day.day)")
                .font(.system(size: Metrics.dayFontSize, weight: .regular))
                .foregroundStyle(
                    day.isCurrentMonth
                    ? Color.primary
                    : Color.secondary.opacity(0.6)
                )
                .frame(width: Metrics.cellSize, height: Metrics.cellSize)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}

// MARK: - 预览用数据模型

private struct PreviewCalendarEntry {
    let year: String
    let monthText: String
    let dayNumber: Int
    let weeks: [[PreviewCalendarDay]]
}

private struct PreviewCalendarDay: Identifiable, Hashable {
    let id: String
    let day: Int
    let isToday: Bool
    let isCurrentMonth: Bool
}

private enum PreviewCalendarEntryBuilder {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 周一
        return cal
    }()

    private static let idFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月"
        return f
    }()

    static func make(for date: Date, today: Date = .now) -> PreviewCalendarEntry {
        let cal = calendar
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        let monthText = monthFormatter.string(from: date)

        let dateStart = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: dateStart)
        let offsetToMonday = (weekday + 5) % 7

        guard let thisMonday = cal.date(
            byAdding: .day,
            value: -offsetToMonday,
            to: dateStart
        ) else {
            return PreviewCalendarEntry(
                year: "\(year)",
                monthText: monthText,
                dayNumber: day,
                weeks: []
            )
        }

        var weeks: [[PreviewCalendarDay]] = []

        for weekOffset in [-1, 0, 1] {
            guard let weekStart = cal.date(
                byAdding: .weekOfYear,
                value: weekOffset,
                to: thisMonday
            ) else { continue }

            var week: [PreviewCalendarDay] = []

            for i in 0..<7 {
                guard let d = cal.date(byAdding: .day, value: i, to: weekStart) else {
                    continue
                }

                let dMonth = cal.component(.month, from: d)

                week.append(
                    PreviewCalendarDay(
                        id: idFormatter.string(from: d),
                        day: cal.component(.day, from: d),
                        isToday: cal.isDate(d, inSameDayAs: today),
                        isCurrentMonth: dMonth == month
                    )
                )
            }

            weeks.append(week)
        }

        return PreviewCalendarEntry(
            year: "\(year)",
            monthText: monthText,
            dayNumber: day,
            weeks: weeks
        )
    }
}

#Preview {
    WidgetGalleryView()
}
