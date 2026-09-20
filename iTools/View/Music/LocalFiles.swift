// LocalFiles.swift
import Foundation
import UIKit

/// 本地文件系统工具
enum LocalFiles {

    // MARK: - 目录

    /// App 沙盒的 Documents 目录
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Documents/Music 目录（自动创建）
    static var musicURL: URL {
        let url = documentsURL.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    // MARK: - 列表

    /// 列出所有已下载的音频文件，按创建时间倒序（最新在前）
    static func listDownloadedMusic() -> [URL] {
        let keys: [URLResourceKey] = [.fileSizeKey, .creationDateKey, .contentModificationDateKey]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: musicURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "flac", "wav"]

        return urls
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            }
    }

    /// 单个文件大小（字节）
    static func fileSize(_ url: URL) -> Int64 {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return Int64(size)
    }

    /// 总占用空间（字节）
    static func totalMusicSize() -> Int64 {
        listDownloadedMusic().reduce(Int64(0)) { $0 + fileSize($1) }
    }

    // MARK: - ★ Sidecar 文件（新增）

    /// 音频对应的元数据文件（.json）
    static func metaURL(for audioURL: URL) -> URL {
        audioURL.deletingPathExtension().appendingPathExtension("json")
    }

    /// 音频对应的封面文件（.jpg）—— 存在则返回，否则 nil
    static func coverURL(for audioURL: URL) -> URL? {
        let cover = audioURL.deletingPathExtension().appendingPathExtension("jpg")
        return FileManager.default.fileExists(atPath: cover.path) ? cover : nil
    }

    /// 读取音频对应的 MusicTrack 元数据（若不存在返回 nil）
    static func loadTrack(for audioURL: URL) -> MusicTrack? {
        let meta = metaURL(for: audioURL)
        guard FileManager.default.fileExists(atPath: meta.path) else { return nil }
        guard let data = try? Data(contentsOf: meta) else { return nil }
        return try? JSONDecoder().decode(MusicTrack.self, from: data)
    }

    /// 保存 MusicTrack 元数据到音频同名的 .json 文件
    @discardableResult
    static func saveTrack(_ track: MusicTrack, for audioURL: URL) -> Bool {
        let meta = metaURL(for: audioURL)
        guard let data = try? JSONEncoder().encode(track) else {
            AppLogError("[LocalFiles] 编码 MusicTrack 失败")
            return false
        }
        do {
            try data.write(to: meta, options: .atomic)
            return true
        } catch {
            AppLogError("[LocalFiles] 保存元数据失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 保存封面图片到音频同名的 .jpg 文件
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

    /// 人类可读的字节数
    static func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }

    /// 人类可读的日期
    static func formattedDate(_ url: URL) -> String {
        let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - 操作

    /// 打开系统「文件」App 并定位到 Documents
    static func openInFilesApp() {
        let path = documentsURL.path
        guard let url = URL(string: "shareddocuments://\(path)") else { return }
        UIApplication.shared.open(url)
    }

    /// 删除音频及其 sidecar（.json / .jpg）
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

        // 清理 sidecar
        try? fm.removeItem(at: metaURL(for: url))
        if let cover = coverURL(for: url) {
            try? fm.removeItem(at: cover)
        }

        return ok
    }

    /// 清空 Music 目录
    @discardableResult
    static func deleteAll() -> Int {
        var count = 0
        for url in listDownloadedMusic() {
            if delete(url) { count += 1 }
        }
        return count
    }

    /// 弹出系统分享面板
    static func share(_ urls: [URL], from view: UIView? = nil) {
        guard !urls.isEmpty else { return }
        let activity = UIActivityViewController(
            activityItems: urls,
            applicationActivities: nil
        )

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        if let popover = activity.popoverPresentationController {
            popover.sourceView = view ?? root.view
            popover.sourceRect = view?.bounds ?? CGRect(
                x: root.view.bounds.midX,
                y: root.view.bounds.midY,
                width: 1, height: 1
            )
            popover.permittedArrowDirections = []
        }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(activity, animated: true)
    }
}
