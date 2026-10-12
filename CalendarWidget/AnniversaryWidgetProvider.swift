// AnniversaryWidgetProvider.swift
import WidgetKit
import SwiftUI

struct AnniversaryEntry: TimelineEntry {
    let date: Date
    let items: [WidgetAnniversaryItem]
}

struct AnniversaryProvider: TimelineProvider {

    func placeholder(in context: Context) -> AnniversaryEntry {
        AnniversaryEntry(date: .now, items: Self.placeholderItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (AnniversaryEntry) -> Void) {
        let items = Self.upcoming(limit: 3)
        completion(
            AnniversaryEntry(
                date: .now,
                items: items.isEmpty ? Self.placeholderItems : items
            )
        )
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<AnniversaryEntry>) -> Void) {
        let now = Date()
        let entry = AnniversaryEntry(date: now, items: Self.upcoming(limit: 3, now: now))

        let cal = WidgetAnniversaryCalculator.gregorian
        let nextMidnight = cal.date(
            byAdding: .day, value: 1,
            to: cal.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)

        completion(
            Timeline(
                entries: [entry],
                policy: .after(nextMidnight.addingTimeInterval(60))
            )
        )
    }

    // MARK: - Private

    private static func upcoming(limit: Int, now: Date = .now) -> [WidgetAnniversaryItem] {
        WidgetAnniversaryStore.load()
            .map { item -> (item: WidgetAnniversaryItem, days: Int, next: Date) in
                let days = WidgetAnniversaryCalculator.daysUntil(item, now: now)
                let next = WidgetAnniversaryCalculator.nextDate(for: item, now: now)
                return (item, days, next)
            }
            .filter { $0.days >= 0 }
            .sorted { a, b in
                if a.item.isPinned != b.item.isPinned { return a.item.isPinned }
                if a.days != b.days { return a.days < b.days }
                return a.next < b.next
            }
            .prefix(limit)
            .map(\.item)
    }

    private static var placeholderItems: [WidgetAnniversaryItem] {
        let cal = WidgetAnniversaryCalculator.gregorian
        func d(_ days: Int) -> Date {
            cal.date(byAdding: .day, value: days, to: .now) ?? .now
        }
        return [
            WidgetAnniversaryItem(
                id: "p1", title: "小美生日",
                originalDate: d(0),
                isYearly: true, isLunar: false, lunarIsLeapMonth: false,
                categoryRaw: "birthday", isPinned: true
            ),
            WidgetAnniversaryItem(
                id: "p2", title: "结婚纪念日",
                originalDate: d(12),
                isYearly: true, isLunar: false, lunarIsLeapMonth: false,
                categoryRaw: "anniversary", isPinned: false
            ),
            WidgetAnniversaryItem(
                id: "p3", title: "中秋节",
                originalDate: d(30),
                isYearly: true, isLunar: true, lunarIsLeapMonth: false,
                categoryRaw: "festival", isPinned: false
            )
        ]
    }
}
