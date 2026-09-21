//
//  CloudBackupManager.swift
//  纪念日云盘备份：上传 / 列目录 / 恢复 / 清理
//

import Foundation
import CryptoKit
import SwiftData
import Combine
import UIKit

@MainActor
final class CloudBackupManager: ObservableObject {

    static let shared = CloudBackupManager()

    // MARK: - 状态

    enum State: Equatable {
        case idle, listing, uploading, downloading
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastError: String?
    @Published private(set) var remoteFiles: [NutstoreWebDAVClient.RemoteFile] = []

    private var client: NutstoreWebDAVClient?
    private let auth     = NutstoreAuth.shared
    private let settings = CloudBackupSettings.shared

    /// 由 App 启动时注入，避免依赖全局单例
    private var modelContext: ModelContext?

    private init() {}

    // MARK: - 配置

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private func requireContext() throws -> ModelContext {
        guard let ctx = modelContext else {
            throw NutstoreError.invalidResponse
        }
        return ctx
    }

    // MARK: - 客户端

    private func ensureClient() throws -> NutstoreWebDAVClient {
        if let client { return client }
        guard let root = auth.webdavRoot else {
            throw NutstoreError.invalidResponse
        }
        let new = NutstoreWebDAVClient(auth: auth, baseURL: root)
        client = new
        return new
    }

    func resetClient() {
        client = nil
        remoteFiles = []
    }

    // MARK: - 结果类型

    enum BackupOutcome {
        case uploaded(fileName: String)
        case skippedNoChange
    }

    // MARK: - 手动 / 自动备份

    func performManualBackup() async throws -> BackupOutcome {
        try await uploadCurrentData(force: true)
    }

    func performAutoBackup() async throws -> BackupOutcome {
        try await uploadCurrentData(force: false)
    }

    // MARK: - 核心上传

    private func uploadCurrentData(force: Bool) async throws -> BackupOutcome {
        guard auth.isLoggedIn else { throw NutstoreError.notAuthenticated }
        guard state == .idle else { throw NutstoreError.invalidResponse }

        state = .uploading
        defer { state = .idle }

        let (data, hash) = try await generateBackupData()

        if !force, settings.lastBackupHash == hash {
            return .skippedNoChange
        }

        let folder = settings.folderPath
        let client = try ensureClient()
        try await client.createDirectory(at: folder)

        let fileName   = Self.makeFileName()
        let remotePath = "\(folder)/\(fileName)"
        try await client.upload(data: data, to: remotePath)

        settings.markBackupSucceeded(hash: hash)

        try? await trimOldBackups(keeping: 3)

        AppLogInfo("[AnniversaryBackup] 上传成功 file=\(fileName) size=\(data.count)")
        return .uploaded(fileName: fileName)
    }

    // MARK: - 生成备份数据

    private func generateBackupData() async throws -> (Data, String) {
        let ctx = try requireContext()

        let items = try ctx.fetch(FetchDescriptor<Anniversary>())

        let payload = AnniversaryBackup(
            version:    AnniversaryBackup.currentVersion,
            exportDate: Date(),
            deviceName: UIDevice.current.name,
            items:      items.map(AnniversaryDTO.init)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let digest = SHA256.hash(data: data)
        let hash   = digest.map { String(format: "%02x", $0) }.joined()

        return (data, hash)
    }

    // MARK: - 文件名

    private static func makeFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return "Anniversary_\(formatter.string(from: Date())).json"
    }

    // MARK: - 列出远端

    func refreshRemoteFiles() async throws {
        guard auth.isLoggedIn else { throw NutstoreError.notAuthenticated }

        state = .listing
        defer { state = .idle }

        let client = try ensureClient()
        let folder = settings.folderPath

        try await client.createDirectory(at: folder)

        let all = try await client.listDirectory(at: folder)

        let filtered = all
            .filter { !$0.isDirectory && $0.displayName.hasSuffix(".json") }
            .sorted { ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast) }

        remoteFiles = filtered
        AppLogInfo("[AnniversaryBackup] 远端文件 count=\(filtered.count)")
    }

    // MARK: - 清理旧备份

    private func trimOldBackups(keeping limit: Int) async throws {
        let client = try ensureClient()
        let folder = settings.folderPath
        let all    = try await client.listDirectory(at: folder)

        let jsonFiles = all
            .filter { !$0.isDirectory && $0.displayName.hasSuffix(".json") }
            .sorted { ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast) }

        guard jsonFiles.count > limit else { return }

        for file in jsonFiles.dropFirst(limit) {
            do {
                try await client.delete(at: file.path)
                AppLogInfo("[AnniversaryBackup] 删除旧备份 file=\(file.displayName)")
            } catch {
                AppLogWarn("[AnniversaryBackup] 删除失败 file=\(file.displayName) error=\(error.localizedDescription)")
            }
        }
    }

    // MARK: - 从云端恢复

    /// 下载备份文件，按 uuid 合并到本地（不覆盖已存在数据），失败自动回滚
    func restore(from file: NutstoreWebDAVClient.RemoteFile)
        async throws -> AnniversaryRestoreResult
    {
        guard auth.isLoggedIn else { throw NutstoreError.notAuthenticated }
        guard state == .idle else { throw NutstoreError.invalidResponse }

        state = .downloading
        defer { state = .idle }

        // 1. 下载
        let client = try ensureClient()
        let data   = try await client.download(from: file.path)

        // 2. 解析
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup: AnniversaryBackup
        do {
            backup = try decoder.decode(AnniversaryBackup.self, from: data)
        } catch {
            AppLogError("[AnniversaryBackup] 备份解析失败: \(error.localizedDescription)")
            throw NutstoreError.invalidBackupFormat
        }

        // 3. 版本检查
        guard backup.version <= AnniversaryBackup.currentVersion else {
            throw NutstoreError.unsupportedBackupVersion(backup.version)
        }

        // 4. 拉取现有数据，建立 uuid 索引
        let ctx = try requireContext()

        let existing: [Anniversary]
        do {
            existing = try ctx.fetch(FetchDescriptor<Anniversary>())
        } catch {
            throw NutstoreError.invalidResponse
        }

        var existingUUIDs = Set(existing.map(\.uuid))

        var added: Int = 0
        var skipped: Int = 0
        var inserted: [Anniversary] = []

        for dto in backup.items {
            if existingUUIDs.contains(dto.uuid) {
                skipped += 1
                continue
            }
            let model = dto.makeModel()
            ctx.insert(model)
            inserted.append(model)
            existingUUIDs.insert(dto.uuid)
            added += 1
        }

        // 5. 事务式保存 + 失败回滚
        if added > 0 {
            do {
                try ctx.save()
            } catch {
                AppLogError("[AnniversaryBackup] 保存失败，回滚: \(error.localizedDescription)")
                for m in inserted { ctx.delete(m) }
                try? ctx.save()
                throw error
            }
        }

        // 6. 重建所有通知
        let all: [Anniversary]
        do {
            all = try ctx.fetch(FetchDescriptor<Anniversary>())
        } catch {
            all = existing + inserted
        }
        await ReminderScheduler.rescheduleAll(all)

        let result = AnniversaryRestoreResult(
            added: added,
            skipped: skipped,
            total: backup.items.count
        )
        AppLogInfo("[AnniversaryBackup] 恢复完成 \(result.logLine) file=\(file.displayName)")
        return result
    }
}
