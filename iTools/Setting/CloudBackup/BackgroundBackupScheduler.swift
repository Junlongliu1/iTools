//
//  BackgroundBackupScheduler.swift
//  使用 BGTaskScheduler 实现后台自动备份
//

import Foundation
import BackgroundTasks
import UIKit

@MainActor
final class BackgroundBackupScheduler {

    static let shared = BackgroundBackupScheduler()

    /// 需与 Info.plist 中 BGTaskSchedulerPermittedIdentifiers 保持一致
    static let taskIdentifier = "com.iTools.cloudBackup.refresh"

    /// 失败后最短重试间隔（防止 lastBackupDate 未更新时被反复调度）
    private static let minimumRetryInterval: TimeInterval = 3600  // 1 小时

    private init() {}

    // MARK: - 注册（App 启动时调用）

    func register() {
        let ok = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(task: refreshTask)
        }
        AppLogInfo("[BGTask] register id=\(Self.taskIdentifier) ok=\(ok)")
    }

    // MARK: - 调度

    /// 按「上次成功备份时间 + interval」计算下次最早执行时间。
    /// - 未备份过：以当前时间为基准
    /// - 已备份过：以 lastBackupDate 为基准，冷启动重排不会推迟时间
    /// - 保底不早于 1 小时后，避免失败后立刻被系统再次唤起
    func reschedule(policy: CloudBackupSettings.BackupPolicy) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)

        let baseDate = CloudBackupSettings.shared.lastBackupDate ?? Date()
        let target   = baseDate.addingTimeInterval(policy.interval)
        let floor    = Date().addingTimeInterval(Self.minimumRetryInterval)
        let earliest = max(target, floor)

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = earliest

        do {
            try BGTaskScheduler.shared.submit(request)
            let fmt = DateFormatter()
            fmt.dateFormat = "MM-dd HH:mm"
            let baseDesc = CloudBackupSettings.shared.lastBackupDate == nil ? "首次" : fmt.string(from: baseDate)
            AppLogInfo("[BGTask] 已调度 policy=\(policy.displayName) base=\(baseDesc) next=\(fmt.string(from: earliest))")
        } catch {
            AppLogError("[BGTask] 调度失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 处理

    private func handle(task: BGAppRefreshTask) {
        AppLogInfo("[BGTask] 开始执行后台备份任务")

        let workTask = Task { @MainActor in
            defer {
                // 无论成功失败，都要重新调度，否则 BGTask 不会再有下一次
                self.reschedule(policy: CloudBackupSettings.shared.policy)
            }

            do {
                let result = try await CloudBackupManager.shared.performAutoBackup()
                switch result {
                case .skippedNoChange:
                    AppLogInfo("[BGTask] 数据无变化，跳过上传")
                case .uploaded(let fileName):
                    AppLogInfo("[BGTask] 自动备份成功 file=\(fileName)")
                }
                task.setTaskCompleted(success: true)
            } catch {
                AppLogError("[BGTask] 后台备份失败: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            AppLogWarn("[BGTask] 任务超时，取消")
            workTask.cancel()
        }
    }
}
