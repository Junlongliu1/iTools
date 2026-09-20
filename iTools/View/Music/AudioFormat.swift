// AudioFormat.swift
import Foundation

/// 音频容器格式
/// - 通过文件头魔数检测，不依赖 URL 后缀或 Content-Type（服务器常返回错误 MIME）
enum AudioFormat: String, CaseIterable {
    case mp3
    case flac
    case m4a
    case aac
    case wav
    case ogg
    case opus
    case unknown

    var fileExtension: String {
        switch self {
        case .mp3:     return "mp3"
        case .flac:    return "flac"
        case .m4a:     return "m4a"
        case .aac:     return "aac"
        case .wav:     return "wav"
        case .ogg:     return "ogg"
        case .opus:    return "opus"
        case .unknown: return "mp3"   // 兜底，保持旧行为
        }
    }

    var displayName: String {
        switch self {
        case .mp3:     return "MP3"
        case .flac:    return "FLAC"
        case .m4a:     return "M4A"
        case .aac:     return "AAC"
        case .wav:     return "WAV"
        case .ogg:     return "OGG"
        case .opus:    return "Opus"
        case .unknown: return "未知"
        }
    }

    /// 当前只对 MP3 做 ID3v2 写入；其他容器若强行写 ID3 可能损坏文件
    var supportsID3: Bool { self == .mp3 }

    // MARK: - 检测

    /// 从磁盘文件读取头部魔数进行检测
    static func detect(at url: URL) -> AudioFormat {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? handle.close() }

        guard let head = try? handle.read(upToCount: 64),
              head.count >= 12 else {
            return .unknown
        }
        return detect(from: head)
    }

    /// 魔数识别
    static func detect(from data: Data) -> AudioFormat {
        let b = [UInt8](data)
        guard b.count >= 12 else { return .unknown }

        // ID3v2 标签头 → MP3
        if b[0] == 0x49, b[1] == 0x44, b[2] == 0x33 { return .mp3 }

        // fLaC
        if b[0] == 0x66, b[1] == 0x4C, b[2] == 0x61, b[3] == 0x43 { return .flac }

        // OggS → OGG 容器，进一步区分 Opus / Vorbis
        if b[0] == 0x4F, b[1] == 0x67, b[2] == 0x67, b[3] == 0x53 {
            if data.range(of: Data("OpusHead".utf8)) != nil { return .opus }
            return .ogg
        }

        // RIFF....WAVE
        if b[0] == 0x52, b[1] == 0x49, b[2] == 0x46, b[3] == 0x46,
           b[8] == 0x57, b[9] == 0x41, b[10] == 0x56, b[11] == 0x45 {
            return .wav
        }

        // ISO-BMFF（MP4 家族）：偏移 4 处为 "ftyp"
        if b[4] == 0x66, b[5] == 0x74, b[6] == 0x79, b[7] == 0x70 {
            return .m4a
        }

        // MPEG 帧同步：FF Ex / FF Fx / ADTS
        if b[0] == 0xFF {
            let b1 = b[1]
            // ADTS AAC：FF F1 / FF F9
            if b1 == 0xF1 || b1 == 0xF9 { return .aac }
            // MPEG 音频帧（MP3）
            if (b1 & 0xE0) == 0xE0 { return .mp3 }
        }

        return .unknown
    }
}
