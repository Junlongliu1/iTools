// AnniversaryWidget.swift
import WidgetKit
import SwiftUI

struct AnniversaryWidget: Widget {
    let kind: String = "AnniversaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnniversaryProvider()) { entry in
            AnniversaryWidgetView(entry: entry)
        }
        .configurationDisplayName("近期纪念日")
        .description("在主屏幕或负一屏查看最近的 3 个纪念日。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}
