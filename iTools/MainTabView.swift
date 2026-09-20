// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MusicSearchView()
                .tabItem { Label("音乐", systemImage: "music.note.list") }

            FilesPlaceholderView()
                .tabItem { Label("文件", systemImage: "folder.fill") }

            RemindersPlaceholderView()
                .tabItem { Label("提醒", systemImage: "checklist") }

            AlarmPlaceholderView()
                .tabItem { Label("闹钟", systemImage: "alarm.fill") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
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
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct FilesPlaceholderView: View {
    var body: some View {
        PlaceholderScreen(title: "文件", icon: "folder.fill", message: "文件功能开发中")
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
