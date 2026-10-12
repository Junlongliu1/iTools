// AnniversaryWidgetSync.swift
import Foundation
import SwiftData
import WidgetKit

@MainActor
enum AnniversaryWidgetSync {

    static func sync(context: ModelContext) {
        let descriptor = FetchDescriptor<Anniversary>()
        guard let items = try? context.fetch(descriptor) else { return }

        let payload = items.map(\.widgetItem)
        WidgetAnniversaryStore.save(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private extension Anniversary {
    var widgetItem: WidgetAnniversaryItem {
        WidgetAnniversaryItem(
            id: uuid.uuidString,
            title: title,
            originalDate: date,
            isYearly: isYearly,
            isLunar: isLunar,
            lunarIsLeapMonth: lunarIsLeapMonth,
            categoryRaw: categoryRaw,
            isPinned: isPinned
        )
    }
}
