//
//  AnniversaryBackup.swift
//  纪念日备份文件结构 + 恢复结果
//

import Foundation

struct AnniversaryBackup: Codable {
    let version: Int
    let exportDate: Date
    let deviceName: String
    let items: [AnniversaryDTO]

    static let currentVersion = 1
}

struct AnniversaryDTO: Codable {
    let uuid: UUID
    let title: String
    let date: Date
    let isYearly: Bool
    let isLunar: Bool
    let lunarIsLeapMonth: Bool
    let notes: String
    let categoryRaw: String
    let createdAt: Date
    let isPinned: Bool
    let reminderAdvanceDays: Int

    init(from model: Anniversary) {
        self.uuid                = model.uuid
        self.title               = model.title
        self.date                = model.date
        self.isYearly            = model.isYearly
        self.isLunar             = model.isLunar
        self.lunarIsLeapMonth    = model.lunarIsLeapMonth
        self.notes               = model.notes
        self.categoryRaw         = model.categoryRaw
        self.createdAt           = model.createdAt
        self.isPinned            = model.isPinned
        self.reminderAdvanceDays = model.reminderAdvanceDays
    }

    /// 生成新模型实例，保留原始 uuid / createdAt 以便跨设备去重
    func makeModel() -> Anniversary {
        let model = Anniversary(
            title: title,
            date: date,
            isYearly: isYearly,
            isLunar: isLunar,
            lunarIsLeapMonth: lunarIsLeapMonth,
            notes: notes,
            category: AnniversaryCategory(rawValue: categoryRaw) ?? .other,
            isPinned: isPinned,
            reminderAdvanceDays: reminderAdvanceDays
        )
        model.uuid      = uuid
        model.createdAt = createdAt
        return model
    }
}

// MARK: - 恢复结果

struct AnniversaryRestoreResult {
    let added: Int
    let skipped: Int
    let total: Int

    var summary: String {
        if total == 0 { return "备份为空，未恢复任何数据" }
        if added == 0 { return "已是最新，未新增任何纪念日" }
        if skipped == 0 { return "恢复完成，新增 \(added) 条" }
        return "恢复完成，新增 \(added) 条，跳过 \(skipped) 条重复"
    }

    var logLine: String {
        "added=\(added) skipped=\(skipped) total=\(total)"
    }
}
