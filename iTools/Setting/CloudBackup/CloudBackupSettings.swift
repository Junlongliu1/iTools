//
//  CloudBackupSettings.swift
//  云盘备份用户偏好
//

import Foundation
import Combine

@MainActor
final class CloudBackupSettings: ObservableObject {

    static let shared = CloudBackupSettings()

    // MARK: - 备份策略

    enum BackupPolicy: String, CaseIterable, Identifiable, Codable {
        case threeDays = "threeDays"
        case sevenDays = "sevenDays"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .threeDays: return "每 3 天"
            case .sevenDays: return "每 7 天"
            }
        }

        var detail: String {
            switch self {
            case .threeDays: return "每 3 天自动备份一次"
            case .sevenDays: return "每 7 天自动备份一次"
            }
        }

        var interval: TimeInterval {
            switch self {
            case .threeDays: return 3 * 24 * 60 * 60
            case .sevenDays: return 7 * 24 * 60 * 60
            }
        }
    }

    // MARK: - 持久化 Key

    private enum Key {
        static let policy         = "cloudBackup.policy"
        static let folderPath     = "cloudBackup.folderPath"
        static let lastBackupDate = "cloudBackup.lastBackupDate"
        static let lastBackupHash = "cloudBackup.lastBackupHash"
    }

    private let defaults = UserDefaults.standard

    // MARK: - Published

    @Published var policy: BackupPolicy {
        didSet {
            defaults.set(policy.rawValue, forKey: Key.policy)
            rescheduleIfNeeded()
        }
    }

    @Published var folderPath: String {
        didSet {
            let cleaned = folderPath.trimmingCharacters(
                in: CharacterSet(charactersIn: "/ "))
            if cleaned != folderPath {
                folderPath = cleaned
                return
            }
            defaults.set(folderPath, forKey: Key.folderPath)
        }
    }

    @Published private(set) var lastBackupDate: Date? {
        didSet { defaults.set(lastBackupDate, forKey: Key.lastBackupDate) }
    }

    var lastBackupHash: String? {
        get { defaults.string(forKey: Key.lastBackupHash) }
        set { defaults.set(newValue, forKey: Key.lastBackupHash) }
    }

    // MARK: - Init

    private init() {
        let rawPolicy = defaults.string(forKey: Key.policy)
            ?? BackupPolicy.threeDays.rawValue
        self.policy = BackupPolicy(rawValue: rawPolicy) ?? .threeDays

        // 纪念日的默认文件夹
        self.folderPath = defaults.string(forKey: Key.folderPath)
            ?? "AnniversaryBackup"

        self.lastBackupDate = defaults.object(forKey: Key.lastBackupDate) as? Date
    }

    // MARK: - 更新

    func markBackupSucceeded(hash: String) {
        lastBackupDate = Date()
        lastBackupHash = hash
    }

    private func rescheduleIfNeeded() {
        BackgroundBackupScheduler.shared.reschedule(policy: policy)
    }
}
