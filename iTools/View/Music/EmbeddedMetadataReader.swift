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

    private init() {
        cache.countLimit = 100
    }

    func metadata(for url: URL) async -> AudioEmbeddedMetadata {
        let key = cacheKey(url)
        if let boxed = cache.object(forKey: key) { return boxed.value }

        let result = await SPFKMetadataAdapter.readMetadata(at: url)
        cache.setObject(Box(result), forKey: key)
        return result
    }

    func invalidate(_ url: URL) {
        cache.removeObject(forKey: cacheKey(url))
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    private func cacheKey(_ url: URL) -> NSString {
        let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate)?.timeIntervalSince1970 ?? 0
        return "\(url.path)|\(mtime)" as NSString
    }

    private final class Box {
        let value: AudioEmbeddedMetadata
        init(_ value: AudioEmbeddedMetadata) { self.value = value }
    }
}

// MARK: - 封面视图

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
