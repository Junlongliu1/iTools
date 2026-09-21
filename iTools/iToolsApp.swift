// iToolsApp.swift
import SwiftUI
import SwiftData

@main
struct iToolsApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Anniversary.self,
                migrationPlan: AnniversaryMigrationPlan.self
            )
        } catch {
            // 开发期直接崩，让你第一时间看到真实错误；
            // 上线时建议改成降级：用 inMemory 兜底 + 上报。
            fatalError("❌ 创建 ModelContainer 失败: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

private struct RootView: View {
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system

    var body: some View {
        MainTabView()
            .preferredColorScheme(appColorScheme.colorScheme)
            .toastOverlay()
    }
}
