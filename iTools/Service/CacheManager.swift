// CacheManager.swift
import Foundation
import UIKit
import Observation

/// 应用缓存管理：URLSession 响应缓存、日志归档、临时文件
@MainActor
@Observable
final class CacheManager {
    static let shared = CacheManager()

    // MARK: - 状态

    private(set) var urlCacheBytes: Int = 0
    private(set) var logBytes: Int = 0
    private(set) var tempFileBytes: Int = 0

    private(set) var isRefreshing = false

    /// 缓存总量
    var totalBytes: Int {
        urlCacheBytes + logBytes + tempFileBytes
    }

    var hasAnyCache: Bool {
        totalBytes > 0
    }

    private init() {}

    // MARK: - 刷新

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let urlCache = URLCache.shared
        urlCacheBytes = urlCache.currentDiskUsage + urlCache.currentMemoryUsage

        logBytes = await LogManager.shared.totalLogBytes()
        tempFileBytes = Self.tempFilesSize()
    }

    // MARK: - 清理

    /// 清理 URLSession 磁盘/内存响应缓存
    func clearURLCache() {
        URLCache.shared.removeAllCachedResponses()
        urlCacheBytes = 0
    }

    /// 清理日志归档（保留当前正在写入的当日文件）
    @discardableResult
    func clearLogArchives() async -> Int {
        let removed = await LogManager.shared.clearArchives()
        logBytes = await LogManager.shared.totalLogBytes()
        return removed
    }

    /// 清理临时目录残留文件（进行中的下载不受影响）
    func clearTempFiles() {
        let tmp = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            tempFileBytes = 0
            return
        }
        var failed = 0
        for url in files {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                failed += 1
            }
        }

        if failed > 0 {
            AppLogWarn("[Cache] 有 \(failed) 个临时文件删除失败")
        }
        tempFileBytes = 0
    }

    /// 全部清理
    func clearAll() async {
        clearURLCache()
        await clearLogArchives()
        clearTempFiles()
        await refresh()
    }

    // MARK: - 私有

    private static func tempFilesSize() -> Int {
        let tmp = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total = 0
        for url in files {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += size
            }
        }
        return total
    }
}
