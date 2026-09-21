// MainTabView.swift
import SwiftUI

enum AppTab: Hashable {
    case music, files, anniversary, widget, settings
}

struct MainTabView: View {
    @State private var selection: AppTab = .music

    var body: some View {
        TabView(selection: $selection) {
            Tab("音乐", systemImage: "music.note.list", value: AppTab.music) {
                MusicSearchView()
            }

            Tab("文件", systemImage: "folder.fill", value: AppTab.files) {
                NavigationStack {
                    DownloadedMusicView()
                }
            }

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

// MARK: - 通用占位

private struct PlaceholderScreen: View {
    let title: String
    let icon: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.secondary)

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
        }
    }
}

private struct AlarmPlaceholderView: View {
    var body: some View {
        PlaceholderScreen(
            title: "闹钟",
            icon: "alarm.fill",
            message: "闹钟功能开发中"
        )
    }
}
