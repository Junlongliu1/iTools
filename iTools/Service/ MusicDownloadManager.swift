// MusicDownloadManager.swift
import Foundation
import SwiftUI
import ID3TagEditor

// MARK: - 下载状态

enum DownloadState: Equatable {
    case idle
    case fetchingURL
    case downloading(progress: Double)
    case completed(fileName: String)
    case failed(message: String)

    var isActive: Bool {
        switch self {
        case .fetchingURL, .downloading: return true
        default: return false
        }
    }
}

// MARK: - 下载管理器

@MainActor
@Observable
final class MusicDownloadManager {
    static let shared = MusicDownloadManager()

    private(set) var states: [String: DownloadState] = [:]

    @ObservationIgnored private var tasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let musicDirectory: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        musicDirectory = docs.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: musicDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - 查询

    func state(for track: MusicTrack) -> DownloadState {
        states[track.displayKey] ?? .idle
    }

    func isDownloaded(_ track: MusicTrack) -> Bool {
        if case .completed = state(for: track) { return true }
        return false
    }

    // MARK: - 下载入口

    func download(track: MusicTrack, quality: AudioQuality = .high) {
        let key = track.displayKey
        guard !(states[key]?.isActive ?? false) else { return }

        states[key] = .fetchingURL
        AppLogInfo("[MusicDownload] 开始下载：\(track.name) - \(track.artist) [\(quality.shortName)]")

        let task = Task { [weak self] in
            guard let self else { return }

            let maxAttempts = 3
            var lastErrorMessage = "未知错误"

            for attempt in 1...maxAttempts {
                if Task.isCancelled {
                    self.states[key] = .idle
                    self.tasks.removeValue(forKey: key)
                    return
                }

                do {
                    try await self.performDownload(
                        track: track,
                        quality: quality,
                        key: key,
                        attempt: attempt
                    )
                    return

                } catch is CancellationError {
                    self.states[key] = .idle
                    self.tasks.removeValue(forKey: key)
                    AppLogInfo("[MusicDownload] 已取消：\(track.name)")
                    return

                } catch {
                    lastErrorMessage = error.localizedDescription
                    let retryable = (error as NSError).isRetryableNetworkError

                    AppLogWarn("[MusicDownload] 第 \(attempt) 次失败：\(lastErrorMessage)"
                               + "（可重试: \(retryable)）")

                    if !retryable || attempt == maxAttempts {
                        self.states[key] = .failed(message: lastErrorMessage)
                        self.tasks.removeValue(forKey: key)
                        ToastCenter.shared.show(
                            "下载失败：\(lastErrorMessage)",
                            icon: "xmark.circle.fill",
                            tint: .red
                        )
                        AppLogError("[MusicDownload] 最终失败：\(lastErrorMessage)")
                        return
                    }

                    let backoff = Double(attempt) * 1.2
                    AppLogInfo("[MusicDownload] \(String(format: "%.1f", backoff))s 后重试"
                               + "（尝试 \(attempt + 1)/\(maxAttempts)）")

                    self.states[key] = .fetchingURL
                    try? await Task.sleep(for: .seconds(backoff))
                }
            }

            _ = lastErrorMessage
        }

        tasks[key] = task
    }

    // MARK: - 单次下载尝试

    private func performDownload(
        track: MusicTrack,
        quality: AudioQuality,
        key: String,
        attempt: Int
    ) async throws {

        // 1. 获取播放地址
        let urlResp = try await MusicAPIService.shared.fetchSongURL(
            trackId: track.id,
            source: track.source,
            bitrate: quality.rawValue
        )
        guard let remoteURL = URL(string: urlResp.url) else {
            throw MusicAPIError.invalidURL
        }

        // 2. 构造带防盗链头的请求
        let request = MusicAPIService.shared.makeAudioRequest(
            for: remoteURL,
            source: track.source
        )

        // 3. 流式下载到临时文件
        let tempURL = try await AudioDownloadSession.shared.download(
            request: request,
            key: key
        ) { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch self.states[key] {
                case .downloading, .fetchingURL, .none:
                    self.states[key] = .downloading(progress: progress)
                default:
                    break
                }
            }
        }

        // 4. 检测真实容器格式，按真实格式命名并落盘
        let format = AudioFormat.detect(at: tempURL)
        AppLogInfo("[MusicDownload] 容器格式：\(format.displayName)（.\(format.fileExtension)）")

        let fileName = uniqueFileName(for: track, format: format)
        let dest = musicDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)

        // 5. 封面（尺寸与搜索页保持一致 → 复用缓存）
        var coverData: Data?
        if !track.picId.isEmpty {
            do {
                let realURL = try await AlbumArtURLCache.shared.url(
                    picId: track.picId,
                    source: track.source,
                    size: 300
                )
                let (data, _) = try await URLSession.shared.data(from: realURL)
                coverData = data
                LocalFiles.saveCover(data, for: dest)
                AppLogInfo("[MusicDownload] 封面已下载 (\(data.count) bytes)")
            } catch {
                AppLogWarn("[MusicDownload] 封面下载失败（不影响音频）：\(error.localizedDescription)")
            }
        }

        // 6. 歌词
        var lyricText: String?
        var lyricLang: ID3FrameContentLanguage = .chi
        if !track.lyricId.isEmpty {
            do {
                let lyricResp = try await MusicAPIService.shared.fetchLyric(
                    lyricId: track.lyricId,
                    source: track.source
                )

                if let t = lyricResp.tlyric, !t.isEmpty {
                    lyricText = t
                    lyricLang = .chi
                } else if !lyricResp.lyric.isEmpty {
                    lyricText = lyricResp.lyric
                    lyricLang = lyricResp.lyric.containsCJK ? .chi : .eng
                }

                if let text = lyricText {
                    AppLogInfo("[MusicDownload] 歌词已获取 (\(text.count) 字符, lang=\(lyricLang.rawValue))")
                }
            } catch {
                AppLogWarn("[MusicDownload] 歌词获取失败：\(error.localizedDescription)")
            }
        }

        // 7. ID3 标签（仅 MP3 支持 ID3v2 写入）
        if format.supportsID3 {
            do {
                try writeID3Tags(
                    to: dest,
                    track: track,
                    coverData: coverData,
                    lyricText: lyricText,
                    lyricLanguage: lyricLang
                )
                AppLogInfo("[MusicDownload] ID3 标签写入成功")
            } catch {
                AppLogError("[MusicDownload] ID3 标签写入失败：\(error.localizedDescription)")
            }
        } else {
            AppLogInfo("[MusicDownload] 跳过 ID3 写入（容器为 \(format.displayName)）")

            // 非 MP3 容器无法嵌歌词，额外写出 .lrc sidecar 以便播放器识别
            if let text = lyricText, !text.isEmpty {
                let lrcURL = dest.deletingPathExtension().appendingPathExtension("lrc")
                do {
                    try text.write(to: lrcURL, atomically: true, encoding: .utf8)
                    AppLogInfo("[MusicDownload] 已写出 .lrc 歌词")
                } catch {
                    AppLogWarn("[MusicDownload] .lrc 写出失败：\(error.localizedDescription)")
                }
            }
        }

        // 8. 元数据 sidecar（会自动 invalidate TrackMetaCache）
        LocalFiles.saveTrack(track, for: dest)

        // 9. 成功
        let sizeBytes = (try? FileManager.default
            .attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0

        states[key] = .completed(fileName: fileName)
        tasks.removeValue(forKey: key)

        ToastCenter.shared.show(
            "已下载：\(track.name)",
            icon: "arrow.down.circle.fill",
            tint: .green
        )
        AppLogInfo("[MusicDownload] 完成：\(fileName) "
                   + "(\(sizeBytes) bytes, \(format.displayName), 第 \(attempt) 次尝试)")
    }

    // MARK: - ID3 标签写入（仅 MP3）

    private func writeID3Tags(
        to mp3URL: URL,
        track: MusicTrack,
        coverData: Data?,
        lyricText: String?,
        lyricLanguage: ID3FrameContentLanguage
    ) throws {
        let builder = ID32v3TagBuilder()

        _ = builder
            .title(frame: ID3FrameWithStringContent(content: track.name))
            .artist(frame: ID3FrameWithStringContent(content: track.artist))

        if !track.album.isEmpty {
            _ = builder.album(frame: ID3FrameWithStringContent(content: track.album))
        }

        if let coverData, !coverData.isEmpty {
            let picture = ID3FrameAttachedPicture(
                picture: coverData,
                type: .frontCover,
                format: .jpeg
            )
            _ = builder.attachedPicture(pictureType: .frontCover, frame: picture)
        }

        if let lyricText, !lyricText.isEmpty {
            let lyricsFrame = ID3FrameWithLocalizedContent(
                language: lyricLanguage,
                contentDescription: "Lyrics",
                content: lyricText
            )
            _ = builder.unsynchronisedLyrics(
                language: lyricLanguage,
                frame: lyricsFrame
            )
        }

        let id3Tag = builder.build()
        let editor = ID3TagEditor()
        try editor.write(tag: id3Tag, to: mp3URL.path)
    }

    // MARK: - 取消 / 删除 / 重置

    func cancel(track: MusicTrack) {
        let key = track.displayKey
        tasks[key]?.cancel()
        tasks.removeValue(forKey: key)
        AudioDownloadSession.shared.cancelAll(forKey: key)
        if !(states[key]?.isActive ?? false) {
            states[key] = .idle
        }
    }

    func delete(track: MusicTrack) {
        let key = track.displayKey
        if case .completed(let fileName) = state(for: track) {
            let url = musicDirectory.appendingPathComponent(fileName)
            LocalFiles.delete(url)
        }
        states[key] = .idle
        ToastCenter.shared.show("已删除本地文件", icon: "trash.fill", tint: .red)
    }

    func resetFailure(track: MusicTrack) {
        let key = track.displayKey
        if case .failed = state(for: track) {
            states[key] = .idle
        }
    }

    // MARK: - 文件名

    private func uniqueFileName(for track: MusicTrack, format: AudioFormat) -> String {
        let raw = "\(track.artist) - \(track.name)"
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")
        var cleaned = raw.components(separatedBy: illegal).joined()
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { cleaned = track.id }
        let base = String(cleaned.prefix(80))

        let ext = format.fileExtension
        var name = "\(base).\(ext)"
        var index = 1
        while FileManager.default.fileExists(
            atPath: musicDirectory.appendingPathComponent(name).path
        ) {
            name = "\(base) (\(index)).\(ext)"
            index += 1
        }
        return name
    }
}

// MARK: - 可重试网络错误

private extension NSError {
    var isRetryableNetworkError: Bool {
        guard domain == NSURLErrorDomain else { return false }
        switch code {
        case NSURLErrorNetworkConnectionLost,
             NSURLErrorTimedOut,
             NSURLErrorCannotConnectToHost,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorBadServerResponse,
             NSURLErrorHTTPTooManyRedirects,
             -1100,
             -11800:
            return true
        default:
            return false
        }
    }
}

// MARK: - String 辅助

extension String {
    var containsCJK: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value) ||
            (0x3040...0x309F).contains(scalar.value) ||
            (0x30A0...0x30FF).contains(scalar.value) ||
            (0xAC00...0xD7AF).contains(scalar.value)
        }
    }
}

// MARK: - 音频下载会话

private final class AudioDownloadSession: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    static let shared = AudioDownloadSession()

    nonisolated(unsafe) private var observers: [Int: DownloadObserver] = [:]
    private let lock = NSLock()

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 60
        cfg.timeoutIntervalForResource = 600
        cfg.waitsForConnectivity       = true
        cfg.requestCachePolicy         = .reloadIgnoringLocalCacheData
        cfg.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    nonisolated override private init() {
        super.init()
        _ = session
    }

    nonisolated func download(
        request: URLRequest,
        key: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let observer = DownloadObserver(
                key: key,
                continuation: continuation,
                onProgress: onProgress
            )
            let task = session.downloadTask(with: request)

            lock.lock()
            observers[task.taskIdentifier] = observer
            lock.unlock()

            task.resume()
        }
    }

    /// ★ 只取消指定 key 对应的任务，不影响其他下载
    nonisolated func cancelAll(forKey key: String) {
        lock.lock()
        let victims = observers.values.filter { $0.key == key }
        lock.unlock()
        for observer in victims { observer.cancel() }
    }

    // MARK: URLSessionDownloadDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        lock.lock()
        let observer = observers[downloadTask.taskIdentifier]
        lock.unlock()

        guard totalBytesExpectedToWrite > 0 else { return }
        let p = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        observer?.emitProgress(p)
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("iTools_audio_\(UUID().uuidString).tmp")

        lock.lock()
        let observer = observers.removeValue(forKey: downloadTask.taskIdentifier)
        lock.unlock()

        if let http = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            observer?.finishFailure(
                error: MusicAPIError.httpStatus(http.statusCode)
            )
            return
        }

        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            observer?.finishSuccess(url: dest)
        } catch {
            observer?.finishFailure(error: error)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }

        lock.lock()
        let observer = observers.removeValue(forKey: task.taskIdentifier)
        lock.unlock()

        observer?.finishFailure(error: error)
    }
}

// MARK: - 下载观察者

private final class DownloadObserver: @unchecked Sendable {

    let key: String
    private let onProgress: @Sendable (Double) -> Void
    private let lock = NSLock()
    nonisolated(unsafe) private var continuation: CheckedContinuation<URL, Error>?

    nonisolated init(
        key: String,
        continuation: CheckedContinuation<URL, Error>,
        onProgress: @escaping @Sendable (Double) -> Void
    ) {
        self.key = key
        self.continuation = continuation
        self.onProgress = onProgress
    }

    nonisolated func emitProgress(_ value: Double) {
        onProgress(value)
    }

    nonisolated func finishSuccess(url: URL) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(returning: url)
    }

    nonisolated func finishFailure(error: Error) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(throwing: error)
    }

    nonisolated func cancel() {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(throwing: CancellationError())
    }
}
