// MusicModels.swift
import Foundation

// MARK: - 音乐源

enum MusicSource: String, CaseIterable, Identifiable, Codable {
    case netease
    case joox
    case bilibili
    case tencent
    case kuwo
    case tidal
    case qobuz
    case apple
    case ytmusic
    case spotify

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .netease:  return "网易云"
        case .joox:     return "JOOX"
        case .bilibili: return "B站"
        case .tencent:  return "QQ音乐"
        case .kuwo:     return "酷我"
        case .tidal:    return "Tidal"
        case .qobuz:    return "Qobuz"
        case .apple:    return "Apple Music"
        case .ytmusic:  return "YouTube"
        case .spotify:  return "Spotify"
        }
    }

    /// GDStudio 声明的当前稳定源
    var isStable: Bool {
        switch self {
        case .netease, .joox, .bilibili: return true
        default: return false
        }
    }

    /// 稳定源优先排序
    static var ordered: [MusicSource] {
        allCases.sorted { a, b in
            if a.isStable != b.isStable { return a.isStable }
            return false
        }
    }

    static var stable: [MusicSource] { allCases.filter(\.isStable) }
}

// MARK: - 音质

enum AudioQuality: Int, CaseIterable, Identifiable {
    case low      = 128
    case medium   = 192
    case high     = 320
    case lossless = 740
    case hiRes    = 999

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .low:      return "128 kbps"
        case .medium:   return "192 kbps"
        case .high:     return "320 kbps"
        case .lossless: return "无损 16bit"
        case .hiRes:    return "无损 24bit"
        }
    }

    var shortName: String {
        switch self {
        case .low:      return "128"
        case .medium:   return "192"
        case .high:     return "320"
        case .lossless: return "无损"
        case .hiRes:    return "Hi-Res"
        }
    }
}

// MARK: - 搜索响应

struct MusicSearchItem: Decodable {
    let id: String
    let name: String
    let artist: [String]
    let album: String
    let picId: String
    let lyricId: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case id, name, artist, album, source
        case picId   = "pic_id"
        case lyricId = "lyric_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id     = (try? c.decode(String.self, forKey: .id)) ?? ""
        name   = (try? c.decode(String.self, forKey: .name)) ?? "未知曲目"
        album  = (try? c.decode(String.self, forKey: .album)) ?? ""
        picId  = (try? c.decode(String.self, forKey: .picId)) ?? ""
        lyricId = (try? c.decode(String.self, forKey: .lyricId)) ?? ""
        source = (try? c.decode(String.self, forKey: .source)) ?? ""

        // artist 在不同源下可能返回数组或字符串
        if let arr = try? c.decode([String].self, forKey: .artist) {
            artist = arr
        } else if let single = try? c.decode(String.self, forKey: .artist) {
            artist = [single]
        } else {
            artist = []
        }
    }

    var artistText: String {
        artist.isEmpty ? "未知歌手" : artist.joined(separator: " / ")
    }
}

// MARK: - 歌曲 URL 响应

struct MusicURLResponse: Decodable {
    let url: String
    let br: Int?
    let size: Int?   // KB
}

// MARK: - 歌词响应

struct MusicLyricResponse: Decodable {
    let lyric: String
    let tlyric: String?
}

// MARK: - 统一展示模型

struct MusicTrack: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let picId: String
    let lyricId: String
    let source: MusicSource
    var displayKey: String { "\(source.rawValue)_\(id)" }
}

// MARK: - 错误

// MusicModels.swift
enum MusicAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed(String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .invalidResponse:
            return "服务器返回数据异常"
        case .httpStatus(let code):
            return Self.friendlyMessage(for: code)
        case .decodingFailed(let m):
            return "解析失败：\(m)"
        case .noResult:
            return "未找到结果"
        }
    }

    /// ★ 把 HTTP 状态码翻译成人话
    private static func friendlyMessage(for code: Int) -> String {
        switch code {
        case 400:  return "请求参数错误"
        case 401, 403: return "访问被拒绝，请稍后重试"
        case 404:  return "接口不存在或资源已下架"
        case 429:  return "请求过于频繁，请稍后再试"
        case 500:  return "服务器内部错误"
        case 502:  return "网关错误，服务器可能正在维护"
        case 503:  return "服务暂时不可用（可能触发限流）"
        case 521, 522, 523, 524:
            return "音乐源服务器暂时无法访问，请稍后再试"
        default:
            return "网络错误（\(code)）"
        }
    }
}
