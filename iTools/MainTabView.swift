// MainTabView.swift
import SwiftUI

enum AppTab: Hashable {
    case anniversary, widget, settings
}

struct MainTabView: View {
    @State private var selection: AppTab = .anniversary

    var body: some View {
        TabView(selection: $selection) {
            Tab("纪念日", systemImage: "heart.text.square.fill", value: AppTab.anniversary) {
                AnniversaryView()
            }

            Tab("小组件", systemImage: "square.grid.2x2.fill", value: AppTab.widget) {
                WidgetGalleryView()
            }

            Tab("设置", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
