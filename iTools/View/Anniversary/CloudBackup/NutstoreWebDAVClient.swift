//
//  NutstoreWebDAVClient.swift
//  坚果云 WebDAV API 封装
//
//  支持操作：
//  - PROPFIND  列目录
//  - MKCOL     创建文件夹
//  - PUT       上传文件
//  - GET       下载文件
//  - DELETE    删除文件
//

import Foundation

// MARK: - WebDAV 客户端

actor NutstoreWebDAVClient {

    private let baseURL: URL
    private let auth: NutstoreAuth
    private let session: URLSession

    init(auth: NutstoreAuth, baseURL: URL) {
        self.auth = auth
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 60
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity       = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - 远端文件模型

    struct RemoteFile: Identifiable, Hashable {
        let id: String          // 完整相对路径（用于 Identifiable）
        let href: String        // WebDAV 返回的原始 href
        let displayName: String
        let isDirectory: Bool
        let size: Int64
        let modifiedDate: Date?
        let path: String        // 相对 baseURL 的路径

        var displaySize: String { formatByteCount(size) }
    }

    // MARK: - 列目录

    /// 列出指定路径下的文件和文件夹
    /// - Parameter path: 相对 baseURL 的路径，如 `AnniversaryBackup` 或空字符串表示根目录
    func listDirectory(at path: String) async throws -> [RemoteFile] {
        guard let authHeader = await auth.authorizationHeader else {
            throw NutstoreError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <d:propfind xmlns:d="DAV:">
          <d:prop>
            <d:displayname/>
            <d:getcontentlength/>
            <d:getlastmodified/>
            <d:resourcetype/>
          </d:prop>
        </d:propfind>
        """
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NutstoreError.invalidResponse
        }
        guard http.statusCode == 207 else {
            throw NutstoreError.httpStatus(http.statusCode)
        }

        return try parseMultiStatus(data: data, basePath: path)
    }

    // MARK: - 创建文件夹

    /// 创建文件夹（已存在时不报错）
    func createDirectory(at path: String) async throws {
        guard let authHeader = await auth.authorizationHeader else {
            throw NutstoreError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "MKCOL"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NutstoreError.invalidResponse
        }

        // 201 Created = 新建成功
        // 405 Method Not Allowed = 已存在（WebDAV 规范）
        guard http.statusCode == 201 || http.statusCode == 405 else {
            throw NutstoreError.httpStatus(http.statusCode)
        }
    }

    // MARK: - 上传

    /// 上传数据到指定路径
    func upload(data: Data, to path: String) async throws {
        guard let authHeader = await auth.authorizationHeader else {
            throw NutstoreError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

        let (_, response) = try await session.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse else {
            throw NutstoreError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw NutstoreError.httpStatus(http.statusCode)
        }
    }

    // MARK: - 下载

    /// 从指定路径下载文件数据
    func download(from path: String) async throws -> Data {
        guard let authHeader = await auth.authorizationHeader else {
            throw NutstoreError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NutstoreError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw NutstoreError.httpStatus(http.statusCode)
        }
        return data
    }

    // MARK: - 删除

    func delete(at path: String) async throws {
        guard let authHeader = await auth.authorizationHeader else {
            throw NutstoreError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NutstoreError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) || http.statusCode == 404 else {
            throw NutstoreError.httpStatus(http.statusCode)
        }
    }

    // MARK: - XML 解析

    private func parseMultiStatus(data: Data, basePath: String) throws -> [RemoteFile] {
        let parser = XMLParser(data: data)
        let delegate = PropfindParser()
        parser.delegate = delegate

        guard parser.parse() else {
            throw NutstoreError.xmlParseFailed
        }

        // WebDAV 的 href 通常是完整路径，需要去掉 baseURL 前缀
        let basePrefix = baseURL.absoluteString

        return delegate.entries.compactMap { entry -> RemoteFile? in
            var relativePath = entry.href

            // 去掉完整 URL 前缀
            if relativePath.hasPrefix(basePrefix) {
                relativePath = String(relativePath.dropFirst(basePrefix.count))
            }
            // 去掉开头的 /
            if relativePath.hasPrefix("/") {
                relativePath = String(relativePath.dropFirst())
            }
            // 去掉尾部的 /
            if relativePath.hasSuffix("/") {
                relativePath = String(relativePath.dropLast())
            }

            // 跳过自身（根目录条目）
            if relativePath.isEmpty
                || relativePath == basePath.trimmingCharacters(
                    in: CharacterSet(charactersIn: "/")) {
                return nil
            }

            let name = (relativePath as NSString).lastPathComponent
            guard !name.isEmpty else { return nil }

            return RemoteFile(
                id: relativePath,
                href: entry.href,
                displayName: entry.displayName ?? name,
                isDirectory: entry.isDirectory,
                size: entry.size ?? 0,
                modifiedDate: entry.modifiedDate,
                path: relativePath
            )
        }
    }
}

// MARK: - PROPFIND 解析器（nonisolated：脱离 MainActor 隔离）

/// 用 `nonisolated` 显式声明，否则在 SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
/// 的工程里会被推断为 @MainActor，导致无法在 actor 内使用。
nonisolated final class PropfindParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    struct Entry {
        var href: String = ""
        var displayName: String?
        var size: Int64?
        var modifiedDate: Date?
        var isDirectory: Bool = false
    }

    var entries: [Entry] = []

    private var currentEntry: Entry?
    private var currentText = ""

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        currentText = ""

        let local = elementName.split(separator: ":").last.map(String.init) ?? elementName

        if local == "response" {
            currentEntry = Entry()
        } else if local == "collection" {
            currentEntry?.isDirectory = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        let local = elementName.split(separator: ":").last.map(String.init) ?? elementName
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch local {
        case "href":
            currentEntry?.href = text
        case "displayname":
            currentEntry?.displayName = text
        case "getcontentlength":
            currentEntry?.size = Int64(text)
        case "getlastmodified":
            currentEntry?.modifiedDate = Self.dateFormatter.date(from: text)
        case "response":
            if let entry = currentEntry, !entry.href.isEmpty {
                entries.append(entry)
            }
            currentEntry = nil
        default:
            break
        }

        currentText = ""
    }
}

// MARK: - 错误

enum NutstoreError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpStatus(Int)
    case xmlParseFailed
    case fileNotFound
    case invalidBackupFormat
    case unsupportedBackupVersion(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "未登录坚果云"
        case .invalidResponse:
            return "服务器响应无效"
        case .httpStatus(let code):
            switch code {
            case 401: return "认证失败，请重新登录"
            case 403: return "无权限访问该文件夹"
            case 404: return "文件不存在"
            case 507: return "坚果云存储空间不足"
            default:  return "服务器错误（\(code)）"
            }
        case .xmlParseFailed:
            return "文件列表解析失败"
        case .fileNotFound:
            return "文件不存在"
        case .invalidBackupFormat:
            return "备份文件格式不正确"
        case .unsupportedBackupVersion(let v):
            return "备份版本（v\(v)）过高，请升级 App"
        }
    }
}

// MARK: - 工具函数

/// 将字节数格式化为可读字符串
/// - 例：`0 B` / `512 B` / `1.5 KB` / `3.4 MB` / `1.5 GB`
///
/// 用 `nonisolated` 显式声明，脱离 MainActor 默认隔离。
nonisolated func formatByteCount(_ bytes: Int64) -> String {
    guard bytes > 0 else { return "0 B" }

    let units: [(threshold: Int64, divisor: Double, suffix: String)] = [
        (1_073_741_824, 1_073_741_824, "GB"),
        (1_048_576,     1_048_576,     "MB"),
        (1_024,         1_024,         "KB"),
    ]

    for unit in units where bytes >= unit.threshold {
        let value = Double(bytes) / unit.divisor
        // KB 保留 1 位小数，MB / GB 保留 2 位
        let decimals = unit.suffix == "KB" ? 1 : 2
        return String(format: "%.\(decimals)f %@", value, unit.suffix)
    }

    return "\(bytes) B"
}
