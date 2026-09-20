// iToolsApp.swift
import SwiftUI
import UIKit

@main
struct iToolsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// 在 View 层观察 @AppStorage，确保主题变化能触发 SwiftUI 更新
private struct RootView: View {
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system

    var body: some View {
        MainTabView()
            .preferredColorScheme(appColorScheme.colorScheme)
            .onAppear { applyWindowStyle(appColorScheme) }
            .onChange(of: appColorScheme) { _, newValue in
                applyWindowStyle(newValue)
            }
    }

    private func applyWindowStyle(_ scheme: AppColorScheme) {
        let style: UIUserInterfaceStyle
        switch scheme {
        case .system: style = .unspecified
        case .light:  style = .light
        case .dark:   style = .dark
        }

        // 等下一个 runloop，确保窗口已挂载
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                for window in ws.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
}
