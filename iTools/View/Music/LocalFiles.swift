// LocalFiles.swift
import Foundation
import UIKit
import SwiftUI

/// 本地文件系统工具
enum LocalFiles {

    // MARK: - 目录

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var musicURL: URL {
        let url = documentsURL.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    // MARK: - 列表

    static func listDownloadedMusic() -> [URL] {
        let keys: [URLResourceKey] = [.fileSizeKey, .creationDateKey, .contentModificationDateKey]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: musicURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let audioExtensions: Set<String> = [
            "mp3", "m4a", "aac", "flac", "wav", "ogg", "opus"
        ]

        return urls
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            }
    }

    static func fileSize(_ url: URL) -> Int64 {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return Int64(size)
    }

    static func totalMusicSize() -> Int64 {
        listDownloadedMusic().reduce(Int64(0)) { $0 + fileSize($1) }
    }

    // MARK: - Sidecar 文件

    static func metaURL(for audioURL: URL) -> URL {
        audioURL.deletingPathExtension().appendingPathExtension("json")
    }

    static func coverURL(for audioURL: URL) -> URL? {
        let cover = audioURL.deletingPathExtension().appendingPathExtension("jpg")
        return FileManager.default.fileExists(atPath: cover.path) ? cover : nil
    }

    static func loadTrack(for audioURL: URL) -> MusicTrack? {
        let meta = metaURL(for: audioURL)
        guard FileManager.default.fileExists(atPath: meta.path) else { return nil }
        guard let data = try? Data(contentsOf: meta) else { return nil }
        return try? JSONDecoder().decode(MusicTrack.self, from: data)
    }

    @discardableResult
    static func saveTrack(_ track: MusicTrack, for audioURL: URL) -> Bool {
        let meta = metaURL(for: audioURL)
        guard let data = try? JSONEncoder().encode(track) else {
            AppLogError("[LocalFiles] 编码 MusicTrack 失败")
            return false
        }
        do {
            try data.write(to: meta, options: .atomic)
            TrackMetaCache.shared.invalidate(audioURL)
            return true
        } catch {
            AppLogError("[LocalFiles] 保存元数据失败: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    static func saveCover(_ imageData: Data, for audioURL: URL) -> Bool {
        let cover = audioURL.deletingPathExtension().appendingPathExtension("jpg")
        do {
            try imageData.write(to: cover, options: .atomic)
            return true
        } catch {
            AppLogError("[LocalFiles] 保存封面失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 格式化

    static func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }

    static func formattedDate(_ url: URL) -> String {
        let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - 操作

    static func openInFilesApp() {
        let path = documentsURL.path
        guard let url = URL(string: "shareddocuments://\(path)") else { return }
        UIApplication.shared.open(url)
    }

    @discardableResult
    static func delete(_ url: URL) -> Bool {
        let fm = FileManager.default
        var ok = false
        do {
            try fm.removeItem(at: url)
            ok = true
        } catch {
            AppLogError("[LocalFiles] 删除失败: \(error.localizedDescription)")
        }

        try? fm.removeItem(at: metaURL(for: url))
        if let cover = coverURL(for: url) {
            try? fm.removeItem(at: cover)
        }

        TrackMetaCache.shared.invalidate(url)
        return ok
    }

    @discardableResult
    static func deleteAll() -> Int {
        var count = 0
        for url in listDownloadedMusic() {
            if delete(url) { count += 1 }
        }
        return count
    }

    @MainActor
    static func share(_ urls: [URL], from view: UIView? = nil) {
        guard !urls.isEmpty else { return }

        guard let presenter = topViewController() else {
            AppLogError("[LocalFiles] 分享失败：找不到 presenter")
            ToastCenter.shared.show("分享失败，请重试", icon: "xmark.circle.fill", tint: .red)
            return
        }

        let activity = UIActivityViewController(
            activityItems: urls,
            applicationActivities: nil
        )

        if let popover = activity.popoverPresentationController {
            if let view {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            } else {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 1,
                    height: 1
                )
            }
            popover.permittedArrowDirections = []
        }

        presenter.present(activity, animated: true)
        AppLogInfo("[LocalFiles] 分享 \(urls.count) 个文件")
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let scene = scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first(where: { $0.windows.contains(where: \.isKeyWindow) })
            ?? scenes.first

        guard let scene else { return nil }

        guard let window = scene.windows.first(where: \.isKeyWindow)
            ?? scene.windows.first else { return nil }

        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
