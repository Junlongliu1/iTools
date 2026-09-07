// iToolsApp.swift
import SwiftUI

@main
struct iToolsApp: App {
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(appColorScheme.colorScheme)
        }
    }
}
