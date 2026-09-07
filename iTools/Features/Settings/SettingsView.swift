// SettingsView.swift
import SwiftUI

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light  = "浅色模式"
    case dark   = "深色模式"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
    
    var body: some View {
        NavigationStack {
            List {
                Section("外观") {
                    Picker("显示模式", selection: $appColorScheme) {
                        ForEach(AppColorScheme.allCases) { scheme in
                            Text(scheme.rawValue).tag(scheme)
                        }
                    }
                }
                
                Section("开发者工具") {
                    NavigationLink {
                        LogViewerView()
                    } label: {
                        Text("日志调试")
                    }
                    
                    NavigationLink {
                        CalendarDebugView()
                    } label: {
                        Text("节假日数据")
                    }
                }
                
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}
