// iToolsApp.swift
import SwiftUI
import SwiftData
import UserNotifications

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
            AppLogError("创建 ModelContainer 失败: \(error)")
            fatalError("❌ 创建 ModelContainer 失败: \(error)")
        }

        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
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
    @Environment(\.modelContext) private var context
    @State private var didBootstrap = false

    var body: some View {
        MainTabView()
            .preferredColorScheme(appColorScheme.colorScheme)
            .toastOverlay()
            .task {
                guard !didBootstrap else { return }
                didBootstrap = true
                await bootstrap()
            }
    }

    /// 启动：请求通知权限 + 修复旧数据 UUID + 全量重排提醒
    @MainActor
    private func bootstrap() async {
        _ = await ReminderScheduler.requestAuthorization()

        let descriptor = FetchDescriptor<Anniversary>()
        let items: [Anniversary]
        do {
            items = try context.fetch(descriptor)
        } catch {
            AppLogError("启动时拉取纪念日失败: \(error.localizedDescription)")
            return
        }

        var seen = Set<UUID>()
        var needsSave = false
        for item in items {
            if seen.contains(item.uuid) {
                AppLogWarn("检测到重复 UUID，已重新分配 [title=\(item.title)]")
                item.uuid = UUID()
                needsSave = true
            } else {
                seen.insert(item.uuid)
            }
        }
        if needsSave {
            do {
                try context.save()
            } catch {
                AppLogError("UUID 去重保存失败: \(error.localizedDescription)")
            }
        }

        await ReminderScheduler.rescheduleAll(items)
    }
}

// MARK: - 通知前台展示

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
