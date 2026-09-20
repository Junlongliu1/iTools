// TrackMetaCache.swift
import Foundation

/// 已下载文件元数据的内存缓存。
/// - 通过 mtime 校验自动失效
/// - 线程安全
/// - 由 LocalFiles.saveTrack / delete 主动 invalidate
final class TrackMetaCache: @unchecked Sendable {
    static let shared = TrackMetaCache()

    private let lock = NSLock()
    private var cache: [URL: (mtime: Date, track: MusicTrack?)] = [:]

    private init() {}

    func track(for url: URL) -> MusicTrack? {
        let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .distantPast

        lock.lock()
        if let entry = cache[url], entry.mtime == mtime {
            let track = entry.track
            lock.unlock()
            return track
        }
        lock.unlock()

        // 缓存未命中/过期，锁外解码
        let loaded = LocalFiles.loadTrack(for: url)

        lock.lock()
        cache[url] = (mtime, loaded)
        lock.unlock()
        return loaded
    }

    func invalidate(_ url: URL) {
        lock.lock()
        cache.removeValue(forKey: url)
        lock.unlock()
    }

    func invalidateAll() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}
