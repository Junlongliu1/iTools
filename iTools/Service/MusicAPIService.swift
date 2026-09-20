// MusicAPIService.swift
import Foundation

// MARK: - 限流器

actor RateLimiter {
    private let maxRequests: Int
    private let window: TimeInterval
    private var timestamps: [Date] = []

    init(maxRequests: Int, window: TimeInterval) {
        self.maxRequests = maxRequests
        self.window = window
    }

    func acquire() async {
        while true {
            let now = Date()
            let cutoff = now.addingTimeInterval(-window)
            timestamps.removeAll { $0 < cutoff }

            if timestamps.count < maxRequests {
                timestamps.append(now)
                return
            }

            let oldest = timestamps.first ?? now
            let wait = window - now.timeIntervalSince(oldest) + 0.2
            AppLogWarn("[RateLimiter] 达到限流阈值，等待 \(String(format: "%.1f", wait)) 秒")
            try? await Task.sleep(for: .seconds(max(0.5, wait)))
        }
    }
}

// MARK: - 音乐 API 服务

final class MusicAPIService: @unchecked Sendable {
    static let shared = MusicAPIService()

    private let baseURL = "https://music-api.gdstudio.xyz/api.php"

    /// 元数据（search / url / lyric）限流：5 分钟 45 次
    private let rateLimiter = RateLimiter(maxRequests: 45, window: 300)

    /// 封面（pic）限流：独立配额，避免与音频元数据抢位
    private let coverRateLimiter = RateLimiter(maxRequests: 30, window: 300)

    private let metadataSession: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 15
        cfg.timeoutIntervalForResource = 60
        cfg.waitsForConnectivity       = true
        cfg.requestCachePolicy         = .reloadIgnoringLocalCacheData
        metadataSession = URLSession(configuration: cfg)
    }

    // MARK: - 搜索

    func search(
        keyword: String,
        source: MusicSource = .netease,
        page: Int = 1,
        count: Int = 20
    ) async throws -> [MusicTrack] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [
            .init(name: "types",  value: "search"),
            .init(name: "source", value: source.rawValue),
            .init(name: "name",   value: trimmed),
            .init(name: "count",  value: "\(count)"),
            .init(name: "pages",  value: "\(page)")
        ]
        guard let url = comps.url else { throw MusicAPIError.invalidURL }

        await rateLimiter.acquire()

        let (data, response) = try await metadataSession.data(from: url)
        try validate(response: response)

        do {
            let items = try JSONDecoder().decode([MusicSearchItem].self, from: data)
            return items.map {
                MusicTrack(
                    id: $0.id,
                    name: $0.name,
                    artist: $0.artistText,
                    album: $0.album,
                    picId: $0.picId,
                    lyricId: $0.lyricId,
                    source: source
                )
            }
        } catch {
            AppLogError("[MusicAPI] 搜索解码失败: \(error)")
            throw MusicAPIError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - 获取歌曲播放地址

    func fetchSongURL(
        trackId: String,
        source: MusicSource,
        bitrate: Int = 320
    ) async throws -> MusicURLResponse {
        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [
            .init(name: "types",  value: "url"),
            .init(name: "source", value: source.rawValue),
            .init(name: "id",     value: trackId),
            .init(name: "br",     value: "\(bitrate)")
        ]
        guard let url = comps.url else { throw MusicAPIError.invalidURL }

        await rateLimiter.acquire()

        let (data, response) = try await metadataSession.data(from: url)
        try validate(response: response)

        do {
            let obj = try JSONDecoder().decode(MusicURLResponse.self, from: data)
            guard !obj.url.isEmpty else { throw MusicAPIError.noResult }
            return obj
        } catch let e as MusicAPIError {
            throw e
        } catch {
            throw MusicAPIError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - 专辑图 URL（直接用于 AsyncImage，注意返回的是 JSON 而非图片）

    func albumArtURL(
        picId: String,
        source: MusicSource,
        size: Int = 300
    ) -> URL? {
        guard !picId.isEmpty else { return nil }
        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [
            .init(name: "types",  value: "pic"),
            .init(name: "source", value: source.rawValue),
            .init(name: "id",     value: picId),
            .init(name: "size",   value: "\(size)")
        ]
        return comps.url
    }

    /// 请求 `types=pic` 拿到真正的图片 CDN 地址。使用独立限流器，避免占用音频元数据配额。
    func fetchAlbumArtURL(
        picId: String,
        source: MusicSource,
        size: Int = 300
    ) async throws -> URL {
        guard !picId.isEmpty else { throw MusicAPIError.noResult }

        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [
            .init(name: "types",  value: "pic"),
            .init(name: "source", value: source.rawValue),
            .init(name: "id",     value: picId),
            .init(name: "size",   value: "\(size)")
        ]
        guard let url = comps.url else { throw MusicAPIError.invalidURL }

        await coverRateLimiter.acquire()

        let (data, response) = try await metadataSession.data(from: url)
        try validate(response: response)

        struct PicResponse: Decodable { let url: String }
        do {
            let obj = try JSONDecoder().decode(PicResponse.self, from: data)
            guard let real = URL(string: obj.url), !obj.url.isEmpty else {
                throw MusicAPIError.noResult
            }
            return real
        } catch let e as MusicAPIError {
            throw e
        } catch {
            throw MusicAPIError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - 歌词

    func fetchLyric(
        lyricId: String,
        source: MusicSource
    ) async throws -> MusicLyricResponse {
        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [
            .init(name: "types",  value: "lyric"),
            .init(name: "source", value: source.rawValue),
            .init(name: "id",     value: lyricId)
        ]
        guard let url = comps.url else { throw MusicAPIError.invalidURL }

        await rateLimiter.acquire()

        let (data, response) = try await metadataSession.data(from: url)
        try validate(response: response)

        do {
            return try JSONDecoder().decode(MusicLyricResponse.self, from: data)
        } catch {
            throw MusicAPIError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - 音频 CDN 请求头

    func makeAudioRequest(for remoteURL: URL, source: MusicSource) -> URLRequest {
        var request = URLRequest(url: remoteURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.cachePolicy = .reloadIgnoringLocalCacheData

        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
            + "Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("*/*",            forHTTPHeaderField: "Accept")
        request.setValue("close",          forHTTPHeaderField: "Connection")

        switch source {
        case .netease:
            request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        case .bilibili:
            request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
            request.setValue("https://www.bilibili.com",  forHTTPHeaderField: "Origin")
        case .joox:
            request.setValue("https://www.joox.com/", forHTTPHeaderField: "Referer")
        case .tencent:
            request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        case .kuwo:
            request.setValue("https://www.kuwo.cn/", forHTTPHeaderField: "Referer")
        default:
            break
        }
        return request
    }

    // MARK: - 私有

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MusicAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MusicAPIError.httpStatus(http.statusCode)
        }
    }
}
