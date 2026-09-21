// EmbeddedMetadataReader.swift
import Foundation
import SwiftUI
import UIKit

// MARK: - 嵌入元数据

struct AudioEmbeddedMetadata: Sendable {
    let title: String?
    let artist: String?
    let album: String?
    let coverData: Data?
    let lyrics: String?

    static let empty = AudioEmbeddedMetadata(
        title: nil, artist: nil, album: nil,
        coverData: nil, lyrics: nil
    )

    var hasCover: Bool { coverData != nil }
    var hasLyrics: Bool { !(lyrics?.isEmpty ?? true) }
}

// MARK: - 读取器

final class EmbeddedMetadataReader: @unchecked Sendable {
    static let shared = EmbeddedMetadataReader()

    private let cache = NSCache<NSString, Box>()
    private let sizeLock = NSLock()
    private var _approximateSize: Int = 0

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 24 * 1024 * 1024   // 24 MB 硬上限
    }

    /// 粗略估算的内存占用（封面 Data + 歌词 + 文本标签）
    var approximateSize: Int {
        sizeLock.lock(); defer { sizeLock.unlock() }
        return _approximateSize
    }

    func metadata(for url: URL) async -> AudioEmbeddedMetadata {
        let key = url.path as NSString
        let mtime = Self.modificationTime(of: url)

        // 命中且文件未变更才复用；mtime 变了说明内容已换，重新解析
        if let boxed = cache.object(forKey: key), boxed.mtime == mtime {
            return boxed.value
        }

        let result = await SPFKMetadataAdapter.readMetadata(at: url)
        let cost = Self.estimatedCost(of: result)

        cache.setObject(Box(result, mtime: mtime), forKey: key, cost: cost)
        addSize(cost)

        return result
    }

    /// 按路径失效：即使文件已被删除也能正确移除条目
    func invalidate(_ url: URL) {
        let key = url.path as NSString

        if let boxed = cache.object(forKey: key) {
            let cost = Self.estimatedCost(of: boxed.value)
            subtractSize(cost)
        }
        cache.removeObject(forKey: key)
    }

    func clearCache() {
        cache.removeAllObjects()
        resetSize()
    }

    // MARK: - 同步临界区

    private func addSize(_ delta: Int) {
        sizeLock.lock()
        defer { sizeLock.unlock() }
        _approximateSize = min(_approximateSize + delta, cache.totalCostLimit)
    }

    private func subtractSize(_ delta: Int) {
        sizeLock.lock()
        defer { sizeLock.unlock() }
        _approximateSize = max(_approximateSize - delta, 0)
    }

    private func resetSize() {
        sizeLock.lock()
        defer { sizeLock.unlock() }
        _approximateSize = 0
    }

    // MARK: - 私有

    private static func modificationTime(of url: URL) -> TimeInterval {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate)?.timeIntervalSince1970 ?? 0
    }

    private static func estimatedCost(of meta: AudioEmbeddedMetadata) -> Int {
        let cover  = meta.coverData?.count ?? 0
        let lyrics = meta.lyrics?.utf8.count ?? 0
        let title  = meta.title?.utf8.count ?? 0
        let artist = meta.artist?.utf8.count ?? 0
        let album  = meta.album?.utf8.count ?? 0
        return max(cover + lyrics + title + artist + album, 1)
    }

    private final class Box {
        let value: AudioEmbeddedMetadata
        let mtime: TimeInterval

        init(_ value: AudioEmbeddedMetadata, mtime: TimeInterval) {
            self.value = value
            self.mtime = mtime
        }
    }
}

// MARK: - 封面视图（保持不变）

struct EmbeddedCoverImage<Placeholder: View>: View {
    let audioURL: URL
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: audioURL) {
            let meta = await EmbeddedMetadataReader.shared.metadata(for: audioURL)
            guard let data = meta.coverData, let img = UIImage(data: data) else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.15)) {
                    self.image = img
                }
            }
        }
    }
}
