// ReminderScheduler.swift
import Foundation
import UserNotifications
import SwiftData

/// 本地通知调度：为每个纪念日安排下一次提醒
@MainActor
enum ReminderScheduler {

    private static let defaultHour = 9
    private static let defaultMinute = 0

    // MARK: 权限

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            AppLogWarn("通知权限已被拒绝，用户需前往系统设置开启")
            return false
        default:
            do {
                let granted = try await center.requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
                if !granted {
                    AppLogWarn("用户拒绝了通知授权")
                }
                return granted
            } catch {
                AppLogError("请求通知授权失败: \(error.localizedDescription)")
                return false
            }
        }
    }

    // MARK: 排程

    /// 为单个纪念日重排下一次提醒
    static func reschedule(_ item: Anniversary) async {
        let id = identifier(for: item)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard let request = makeRequest(for: item) else { return }
        do {
            try await center.add(request)
        } catch {
            AppLogError("添加通知请求失败 [id=\(id)]: \(error.localizedDescription)")
        }
    }

    static func cancel(_ item: Anniversary) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: item)])
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func rescheduleAll(_ items: [Anniversary]) async {
        let center = UNUserNotificationCenter.current()

        // 1. 构造不可变请求
        var pairs: [(id: String, request: UNNotificationRequest)] = []
        pairs.reserveCapacity(items.count)
        for item in items {
            let id = identifier(for: item)
            if let req = makeRequest(for: item) {
                pairs.append((id, req))
            } else {
                // 不提醒 / 已过期：至少清掉旧的
                center.removePendingNotificationRequests(withIdentifiers: [id])
            }
        }

        // 2. 清掉旧排程（仍有效的通过 identifier 覆盖）
        center.removePendingNotificationRequests(withIdentifiers: pairs.map(\.id))

        // 3. 并发提交
        await withTaskGroup(of: Void.self) { group in
            for pair in pairs {
                group.addTask {
                    do {
                        try await center.add(pair.request)
                    } catch {
                        AppLogError("批量排程通知失败 [id=\(pair.id)]: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: 内部

    private static func identifier(for item: Anniversary) -> String {
        "anniversary-\(item.uuid.uuidString)"
    }

    /// 构造请求（无副作用，可在并发提交前完成）
    private static func makeRequest(for item: Anniversary) -> UNNotificationRequest? {
        let advance = item.reminderAdvanceDays
        guard advance >= 0 else { return nil }
        guard let fire = fireDate(for: item, advanceDays: advance) else { return nil }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = bodyText(for: item, advanceDays: advance)
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["anniversaryUUID": item.uuid.uuidString]

        var comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fire
        )
        comps.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(
            identifier: identifier(for: item),
            content: content,
            trigger: trigger
        )
    }

    /// 触发时间：nextDate 提前 advanceDays 天的 09:00；已过去则 nil
    private static func fireDate(for item: Anniversary, advanceDays: Int) -> Date? {
        let cal = Anniversary.gregorianCalendar
        guard let day = cal.date(byAdding: .day, value: -advanceDays, to: item.nextDate),
              let fire = cal.date(bySettingHour: defaultHour,
                                  minute: defaultMinute,
                                  second: 0,
                                  of: day),
              fire > Date()
        else { return nil }
        return fire
    }

    private static func bodyText(for item: Anniversary, advanceDays: Int) -> String {
        switch advanceDays {
        case 0:  return "就是今天！"
        case 1:  return "明天"
        default: return "还有 \(advanceDays) 天"
        }
    }
}
