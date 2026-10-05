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

    private init() {}

    // MARK: - 注册（App 启动时调用）

    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(task: refreshTask)
        }
        AppLogInfo("[BGTask] 已注册 \(Self.taskIdentifier)")
    }

    // MARK: - 调度

    func reschedule(policy: CloudBackupSettings.BackupPolicy) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: policy.interval)

        do {
            try BGTaskScheduler.shared.submit(request)
            let hours = Int(policy.interval / 3600)
            AppLogInfo("[BGTask] 已调度下一次备份 policy=\(policy.displayName) 约 \(hours) 小时后")
        } catch {
            AppLogError("[BGTask] 调度失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 处理

    private func handle(task: BGAppRefreshTask) {
        AppLogInfo("[BGTask] 开始执行后台备份任务")

        reschedule(policy: CloudBackupSettings.shared.policy)

        let workTask = Task {
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
