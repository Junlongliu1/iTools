// MainTabView.swift
import SwiftUI

enum AppTab: Hashable {
    case music, files, reminders, alarm, settings
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
            Tab("提醒", systemImage: "checklist", value: AppTab.reminders) {
                RemindersPlaceholderView()
            }
            Tab("闹钟", systemImage: "alarm.fill", value: AppTab.alarm) {
                AlarmPlaceholderView()
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

private struct RemindersPlaceholderView: View {
    var body: some View {
        PlaceholderScreen(title: "提醒", icon: "checklist", message: "提醒功能开发中")
    }
}

private struct AlarmPlaceholderView: View {
    var body: some View {
        PlaceholderScreen(title: "闹钟", icon: "alarm.fill", message: "闹钟功能开发中")
    }
}
