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

        // 注入 ModelContext 给 CloudBackupManager
        CloudBackupManager.shared.configure(modelContext: container.mainContext)

        // 注册后台备份任务（每次冷启动注册一次，系统要求）
        BackgroundBackupScheduler.shared.register()

        // 首次或冷启动重排：基于 lastBackupDate 计算，不会推迟原定时间
        BackgroundBackupScheduler.shared.reschedule(
            policy: CloudBackupSettings.shared.policy
        )
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
    @Environment(\.scenePhase) private var scenePhase
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
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhase(newPhase)
            }
    }

    /// 启动：请求通知权限 + 修复旧数据 UUID + 全量重排提醒 + 兜底备份
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

        // 前台兜底：若已超过备份周期，立即补一次
        await CloudBackupManager.shared.performForegroundAutoBackupIfNeeded()
    }

    // MARK: - 场景切换

    @MainActor
    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // 回到前台：检查是否需要补一次备份
            Task { @MainActor in
                await CloudBackupManager.shared.performForegroundAutoBackupIfNeeded()
            }
        case .background:
            // 进入后台：刷新调度，保证队列里始终有任务
            // reschedule 基于 lastBackupDate，不会推迟原定时间
            BackgroundBackupScheduler.shared.reschedule(
                policy: CloudBackupSettings.shared.policy
            )
        default:
            break
        }
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
