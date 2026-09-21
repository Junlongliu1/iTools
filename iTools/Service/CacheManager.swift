// CacheManager.swift
import Foundation
import UIKit
import Observation

/// 应用缓存管理：封面图片内存、嵌入元数据、封面 URL、URLSession 响应缓存、日志归档、临时文件
@MainActor
@Observable
final class CacheManager {
    static let shared = CacheManager()

    // MARK: - 状态

    private(set) var imageMemoryBytes: Int = 0
    private(set) var metadataBytes: Int = 0
    private(set) var coverURLCacheCount: Int = 0
    private(set) var urlCacheBytes: Int = 0
    private(set) var logBytes: Int = 0
    private(set) var tempFileBytes: Int = 0

    /// 只读展示：已下载音乐属于用户数据，不计入缓存总量
    private(set) var musicBytes: Int = 0
    private(set) var musicFileCount: Int = 0

    private(set) var isRefreshing = false

    /// 缓存总量（不含已下载音乐）
    var totalBytes: Int {
        imageMemoryBytes + metadataBytes + urlCacheBytes + logBytes + tempFileBytes
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
        metadataBytes = EmbeddedMetadataReader.shared.approximateSize
        coverURLCacheCount = await AlbumArtURLCache.shared.count

        let urlCache = URLCache.shared
        urlCacheBytes = urlCache.currentDiskUsage + urlCache.currentMemoryUsage

        logBytes = await LogManager.shared.totalLogBytes()
        tempFileBytes = Self.tempFilesSize()

        let musicFiles = LocalFiles.listDownloadedMusic()
        musicFileCount = musicFiles.count
        musicBytes = Int(LocalFiles.totalMusicSize())
    }

    // MARK: - 清理

    /// 清理图片相关：封面内存图 + 封面 URL 缓存 + 503 负缓存
    func clearImageCaches() async {
        CoverImageCache.shared.clear()
        await AlbumArtURLCache.shared.clear()
        await CoverRequestCoordinator.shared.clearNegativeCache()

        imageMemoryBytes = 0
        coverURLCacheCount = 0
    }

    /// 清理音频嵌入元数据缓存
    func clearMetadataCache() {
        EmbeddedMetadataReader.shared.clearCache()
        metadataBytes = 0
    }

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

    /// 全部清理（不含已下载音乐）
    func clearAll() async {
        await clearImageCaches()
        clearMetadataCache()
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
