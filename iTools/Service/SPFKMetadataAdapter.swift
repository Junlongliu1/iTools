// SPFKMetadataAdapter.swift
import Foundation
import UIKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import SPFKMetadata
import SPFKMetadataBase
import SPFKMetadataC

/// spfk-metadata 的封装层
enum SPFKMetadataAdapter {

    // MARK: - 错误

    enum AdapterError: LocalizedError {
        case loadFailed(String)
        case saveFailed(String)
        case coverDecodeFailed
        case coverWriteFailed

        var errorDescription: String? {
            switch self {
            case .loadFailed(let path):
                return "TagFile 加载失败：\(path)"
            case .saveFailed(let path):
                return "TagFile 保存失败：\(path)"
            case .coverDecodeFailed:
                return "封面数据无法解码为 CGImage"
            case .coverWriteFailed:
                return "封面写入失败"
            }
        }
    }

    // MARK: - 读取

    static func readMetadata(at url: URL) async -> AudioEmbeddedMetadata {
        let path = url.path

        var title: String?
        var artist: String?
        var album: String?
        var lyrics: String?

        let tagFile = TagFile(path: path)
        if tagFile.load(), let raw = tagFile.dictionary {
            let dict = stringDictionary(from: raw)
            title  = clean(dict["TITLE"])
            artist = clean(dict["ARTIST"])
            album  = clean(dict["ALBUM"])
            lyrics = clean(dict["LYRICS"]) ?? clean(dict["UNSYNCEDLYRICS"])
        }

        var coverData: Data?
        if let ref = try? TagPictureRef.parsing(url: url),
           let data = cgImageToJPEGData(ref.cgImage) {
            coverData = data
        }

        return AudioEmbeddedMetadata(
            title: title,
            artist: artist,
            album: album,
            coverData: coverData,
            lyrics: lyrics
        )
    }

    // MARK: - 写入

    static func writeMetadata(
        to url: URL,
        track: MusicTrack,
        coverData: Data?,
        lyricText: String?
    ) async throws {
        let path = url.path

        // 1. 文字标签：读-改-写，保留其他已有字段
        let tagFile = TagFile(path: path)
        var dict: [String: String] = [:]

        if tagFile.load(), let raw = tagFile.dictionary {
            dict = stringDictionary(from: raw)
        }

        dict["TITLE"]  = track.name
        dict["ARTIST"] = track.artist
        if !track.album.isEmpty { dict["ALBUM"] = track.album }
        if let lyricText, !lyricText.isEmpty { dict["LYRICS"] = lyricText }

        // TagFile.dictionary 在 Swift 里是 [AnyHashable: Any]，直接赋 Swift 字典
        tagFile.dictionary = dict

        guard tagFile.save() else {
            throw AdapterError.saveFailed(path)
        }

        // 2. 封面
        if let coverData, !coverData.isEmpty {
            guard let cgImage = jpegDataToCGImage(coverData) else {
                throw AdapterError.coverDecodeFailed
            }

            let ref = TagPictureRef(
                image: cgImage,
                utType: .jpeg,
                pictureDescription: "Front Cover",
                pictureType: "Front Cover"
            )

            guard TagPicture.write(ref, path: path) else {
                throw AdapterError.coverWriteFailed
            }
        }
    }

    // MARK: - 私有辅助

    private static func stringDictionary(from raw: [AnyHashable: Any]) -> [String: String] {
        var out = [String: String]()
        for (key, value) in raw {
            guard let k = key as? String, let v = value as? String else { continue }
            out[k] = v
        }
        return out
    }

    private static func clean(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func cgImageToJPEGData(_ cgImage: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData, "public.jpeg" as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }

    private static func jpegDataToCGImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return cgImage
    }
}
