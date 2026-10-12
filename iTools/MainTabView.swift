// MainTabView.swift
import SwiftUI

// MARK: - Tab 定义

enum MainTab: String, Hashable, CaseIterable, Identifiable {
    case anniversary
    case widget
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anniversary: return "纪念日"
        case .widget:      return "小组件"
        case .settings:    return "设置"
        }
    }

    var symbol: String {
        switch self {
        case .anniversary: return "heart.text.square.fill"
        case .widget:      return "square.grid.2x2.fill"
        case .settings:    return "gearshape.fill"
        }
    }
}

// MARK: - 主视图

struct MainTabView: View {

    @State private var selection: MainTab = .anniversary

    var body: some View {
        TabView(selection: $selection) {

            Tab(MainTab.anniversary.title,
                systemImage: MainTab.anniversary.symbol,
                value: MainTab.anniversary) {
                AnniversaryView()
            }

            Tab(MainTab.widget.title,
                systemImage: MainTab.widget.symbol,
                value: MainTab.widget) {
                WidgetGalleryView()
            }

            Tab(MainTab.settings.title,
                systemImage: MainTab.settings.symbol,
                value: MainTab.settings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
