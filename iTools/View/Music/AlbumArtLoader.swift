// AlbumArtLoader.swift
import SwiftUI
import UIKit

// MARK: - 专辑图 URL 缓存

actor AlbumArtURLCache {
    static let shared = AlbumArtURLCache()

    private var cache: [String: URL] = [:]
    private var inflight: [String: Task<URL, Error>] = [:]
    
    var count: Int { cache.count }

    func clear() {
        cache.removeAll()
    }

    func url(picId: String, source: MusicSource, size: Int = 300) async throws -> URL {
        let key = "\(source.rawValue)_\(picId)_\(size)"

        if let cached = cache[key] { return cached }
        if let task = inflight[key] { return try await task.value }

        let task = Task<URL, Error> {
            let coordinator = CoverRequestCoordinator.shared

            guard await coordinator.shouldAttempt(key: key) else {
                throw MusicAPIError.httpStatus(503)
            }

            var lastError: Error?
            for attempt in 1...3 {
                await coordinator.waitForSlot()
                do {
                    let url = try await MusicAPIService.shared.fetchAlbumArtURL(
                        picId: picId,
                        source: source,
                        size: size
                    )
                    await coordinator.markSuccess(key: key)
                    return url
                } catch let e as MusicAPIError {
                    lastError = e
                    if case .httpStatus(503) = e {
                        AppLogInfo("[Cover] 第 \(attempt)/3 次 503，稍后重试 pic=\(picId)")
                        continue
                    }
                    throw e
                } catch {
                    lastError = error
                    throw error
                }
            }

            await coordinator.markFailed(key: key)
            throw lastError ?? MusicAPIError.noResult
        }

        inflight[key] = task
        defer { inflight.removeValue(forKey: key) }

        let url = try await task.value
        cache[key] = url
        return url
    }
}

// MARK: - 图片内存缓存

final class CoverImageCache: @unchecked Sendable {
    static let shared = CoverImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let sizeLock = NSLock()
    private var _approximateSize: Int = 0

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    /// 粗略估算的内存占用（NSCache 被系统回收时可能略高估，仅用于展示）
    var approximateSize: Int {
        sizeLock.lock(); defer { sizeLock.unlock() }
        return _approximateSize
    }

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ key: String, _ image: UIImage) {
        let cost = Self.estimateCost(for: image)
        cache.setObject(image, forKey: key as NSString, cost: cost)

        sizeLock.lock()
        _approximateSize = min(_approximateSize + cost, cache.totalCostLimit)
        sizeLock.unlock()
    }

    func clear() {
        cache.removeAllObjects()
        sizeLock.lock()
        _approximateSize = 0
        sizeLock.unlock()
    }

    private static func estimateCost(for image: UIImage) -> Int {
        let pixels = Int(image.size.width * image.scale * image.size.height * image.scale)
        return max(pixels * 4, 1)
    }
}

// MARK: - 统一封面视图

struct CoverImage<Placeholder: View>: View {
    let picId: String
    let source: MusicSource
    var localFile: URL? = nil
    var size: Int = 300
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var failed = false

    private var cacheKey: String {
        "\(source.rawValue)_\(picId)_\(size)"
    }

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
        .task(id: cacheKey) {
            await load()
        }
    }

    private func load() async {
        if let localFile, let img = UIImage(contentsOfFile: localFile.path) {
            self.image = img
            return
        }

        if let cached = CoverImageCache.shared.get(cacheKey) {
            self.image = cached
            return
        }

        guard !picId.isEmpty else {
            failed = true
            return
        }

        do {
            let realURL = try await AlbumArtURLCache.shared.url(
                picId: picId,
                source: source,
                size: size
            )
            let (data, _) = try await URLSession.shared.data(from: realURL)
            guard let img = UIImage(data: data) else {
                failed = true
                return
            }
            CoverImageCache.shared.set(cacheKey, img)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.15)) {
                    self.image = img
                }
            }
        } catch let e as MusicAPIError {
            if case .httpStatus(503) = e {
                AppLogDebug("[Cover] 跳过（负缓存）pic=\(picId)")
            } else {
                AppLogWarn("[Cover] 加载失败 pic=\(picId) src=\(source.rawValue): \(e.localizedDescription)")
            }
            failed = true
        } catch {
            AppLogWarn("[Cover] 加载失败 pic=\(picId) src=\(source.rawValue): \(error.localizedDescription)")
            failed = true
        }
    }
}
