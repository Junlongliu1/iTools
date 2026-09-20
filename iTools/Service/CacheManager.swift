// CacheManager.swift
import Foundation
import UIKit
import Observation

/// 应用缓存管理：封面图片内存、封面 URL、URLSession 响应缓存、临时文件
@MainActor
@Observable
final class CacheManager {
    static let shared = CacheManager()

    // MARK: - 状态

    private(set) var imageMemoryBytes: Int = 0
    private(set) var coverURLCacheCount: Int = 0
    private(set) var urlCacheBytes: Int = 0
    private(set) var tempFileBytes: Int = 0

    private(set) var isRefreshing = false

    var totalBytes: Int {
        imageMemoryBytes + urlCacheBytes + tempFileBytes
    }

    var hasAnyCache: Bool {
        totalBytes > 0 || coverURLCacheCount > 0
    }

    private init() {}

    // MARK: - 刷新

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        imageMemoryBytes = CoverImageCache.shared.approximateSize
        coverURLCacheCount = await AlbumArtURLCache.shared.count

        let urlCache = URLCache.shared
        urlCacheBytes = urlCache.currentDiskUsage + urlCache.currentMemoryUsage

        tempFileBytes = Self.tempFilesSize()
    }

    // MARK: - 清理

    /// 清理图片相关：内存图片 + 封面 URL 缓存 + 503 负缓存
    func clearImageCaches() async {
        CoverImageCache.shared.clear()
        await AlbumArtURLCache.shared.clear()
        await CoverRequestCoordinator.shared.clearNegativeCache()

        imageMemoryBytes = 0
        coverURLCacheCount = 0
    }

    /// 清理 URLSession 磁盘/内存响应缓存
    func clearURLCache() {
        URLCache.shared.removeAllCachedResponses()
        urlCacheBytes = 0
    }

    /// 清理临时目录残留文件（进行中的下载不受影响，其临时文件在写入完成后才落盘）
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
        for url in files {
            try? FileManager.default.removeItem(at: url)
        }
        tempFileBytes = 0
        AppLogInfo("[Cache] 清理临时文件 \(files.count) 个")
    }

    /// 全部清理
    func clearAll() async {
        await clearImageCaches()
        clearURLCache()
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
