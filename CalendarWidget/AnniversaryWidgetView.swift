// AnniversaryWidgetView.swift
import SwiftUI
import WidgetKit

struct AnniversaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AnniversaryEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumLayout(items: entry.items)
            default:
                SmallLayout(items: entry.items)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - 工具

private func countdownDays(_ item: WidgetAnniversaryItem) -> Int {
    WidgetAnniversaryCalculator.daysUntil(item)
}

private func shortDate(_ item: WidgetAnniversaryItem) -> String {
    let next = WidgetAnniversaryCalculator.nextDate(for: item)
    let c = WidgetAnniversaryCalculator.gregorian
    let m = c.component(.month, from: next)
    let d = c.component(.day, from: next)
    return "\(m)月\(d)日"
}

// MARK: - 头部

private struct WidgetHeader: View {
    let count: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text("itools")
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if count > 0 {
                Text("\(count) 条")
                    .font(.system(size: compact ? 9 : 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - 空状态

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
            Text("还没有纪念日")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 倒计时标签

private struct CountdownLabel: View {
    let days: Int
    let tint: Color
    var compact: Bool

    @Environment(\.widgetRenderingMode) private var mode

    /// 天数颜色分级（仅用于数字）
    private var dayColor: Color {
        guard mode == .fullColor else { return .primary }
        switch days {
        case 2...3:   return Color(red: 1.00, green: 0.23, blue: 0.19)  // 红
        case 4...7:   return Color(red: 1.00, green: 0.58, blue: 0.00)  // 橙
        case 8...30:  return Color(red: 0.00, green: 0.48, blue: 1.00)  // 蓝
        default:      return Color.secondary                            // >30 天
        }
    }

    var body: some View {
        if days == 0 {
            Text("今天")
                .font(.system(size: compact ? 10 : 11, weight: .bold))
                .foregroundStyle(mode == .fullColor ? Color.white : Color.primary)
                .padding(.horizontal, compact ? 6 : 8)
                .padding(.vertical, compact ? 2 : 3)
                .background {
                    if mode == .fullColor {
                        Capsule().fill(tint)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
                .widgetAccentable()

        } else if days == 1 {
            Text("明天")
                .font(.system(size: compact ? 11 : 13, weight: .bold))
                .foregroundStyle(mode == .fullColor ? tint : Color.primary)
                .widgetAccentable()

        } else {
            HStack(alignment: .firstTextBaseline, spacing: compact ? 1 : 2) {
                Text("\(days)")
                    .font(.system(size: compact ? 12 : 18,
                                  weight: .bold,
                                  design: .rounded))
                    .foregroundStyle(dayColor)
                    .monospacedDigit()
                    .widgetAccentable()

                Text("天")
                    .font(.system(size: compact ? 9 : 10, weight: .medium))
                    .foregroundStyle(dayColor)
            }
        }
    }
}

// MARK: - 小尺寸

private struct SmallLayout: View {
    let items: [WidgetAnniversaryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(count: min(items.count, 3), compact: true)
                .padding(.bottom, 8)

            if items.isEmpty {
                EmptyState()
            } else {
                VStack(spacing: 7) {
                    ForEach(items.prefix(3)) { item in
                        SmallRow(item: item)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct SmallRow: View {
    let item: WidgetAnniversaryItem

    var body: some View {
        let days = countdownDays(item)

        HStack(spacing: 0) {
            Text(item.title)
                .font(.system(size: 12, weight: days == 0 ? .semibold : .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 6)

            CountdownLabel(days: days, tint: item.category.topColor, compact: true)
        }
    }
}

// MARK: - 中尺寸

private struct MediumLayout: View {
    let items: [WidgetAnniversaryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(count: min(items.count, 3))

            if items.isEmpty {
                EmptyState()
            } else {
                Spacer(minLength: 6)
                VStack(spacing: 0) {
                    ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { idx, item in
                        MediumRow(item: item)
                        if idx < min(items.count, 3) - 1 {
                            Divider()
                                .opacity(0.35)
                                .padding(.leading, 0)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct MediumRow: View {
    let item: WidgetAnniversaryItem
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let days = countdownDays(item)

        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(mode == .fullColor ? Color.orange : Color.primary)
                            .rotationEffect(.degrees(45))
                            .widgetAccentable()
                    }
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Text(shortDate(item))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 6)

            CountdownLabel(days: days, tint: item.category.topColor, compact: false)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - 预览

#Preview(as: .systemMedium) {
    AnniversaryWidget()
} timeline: {
    AnniversaryEntry(
        date: .now,
        items: [
            WidgetAnniversaryItem(
                id: "p1", title: "小美生日",
                originalDate: .now,
                isYearly: true, isLunar: false, lunarIsLeapMonth: false,
                categoryRaw: "birthday", isPinned: true
            ),
            WidgetAnniversaryItem(
                id: "p2", title: "结婚纪念日",
                originalDate: Calendar.current.date(byAdding: .day, value: 12, to: .now)!,
                isYearly: true, isLunar: false, lunarIsLeapMonth: false,
                categoryRaw: "anniversary", isPinned: false
            ),
            WidgetAnniversaryItem(
                id: "p3", title: "中秋节",
                originalDate: Calendar.current.date(byAdding: .day, value: 30, to: .now)!,
                isYearly: true, isLunar: true, lunarIsLeapMonth: false,
                categoryRaw: "festival", isPinned: false
            )
        ]
    )
}

#Preview(as: .systemSmall) {
    AnniversaryWidget()
} timeline: {
    AnniversaryEntry(
        date: .now,
        items: [
            WidgetAnniversaryItem(
                id: "p1", title: "小美生日",
                originalDate: .now,
                isYearly: true, isLunar: false, lunarIsLeapMonth: false,
                categoryRaw: "birthday", isPinned: true
            ),
            WidgetAnniversaryItem(
                id: "p2", title: "结婚纪念日",
                originalDate: Calendar.current.date(byAdding: .day, value: 12, to: .now)!,
                isYearly: true, isLunar: false, lunarIsLeapMonth: false,
                categoryRaw: "anniversary", isPinned: false
            ),
            WidgetAnniversaryItem(
                id: "p3", title: "中秋节",
                originalDate: Calendar.current.date(byAdding: .day, value: 30, to: .now)!,
                isYearly: true, isLunar: true, lunarIsLeapMonth: false,
                categoryRaw: "festival", isPinned: false
            )
        ]
    )
}
