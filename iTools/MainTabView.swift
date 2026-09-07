// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AlarmListView()
                .tabItem {
                    Label("闹钟", systemImage: "alarm.fill")
                }
            
            ChineseCalendarView()
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }
            
            SchedulePlaceholderView()
                .tabItem {
                    Label("日程", systemImage: "list.bullet.clipboard")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
    }
}

// 占位视图 - 日程
struct SchedulePlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
                Text("日程功能开发中")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("日程")
        }
    }
}
