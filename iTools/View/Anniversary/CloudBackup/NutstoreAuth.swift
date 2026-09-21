//
//  NutstoreAuth.swift
//  坚果云 WebDAV 认证管理
//

import Foundation
import Security
import Combine

@MainActor
final class NutstoreAuth: ObservableObject {

    static let shared = NutstoreAuth()

    private enum KeychainKey {
        static let service = "com.iTools.nutstore"
        static let account = "webdav_credentials"
    }

    private let webdavBaseURL = "https://dav.jianguoyun.com/dav/"

    @Published private(set) var isLoggedIn = false
    @Published private(set) var accountEmail: String?

    private var cachedCredential: Credential?

    private struct Credential: Codable {
        let email: String
        let appPassword: String
    }

    private init() {
        loadFromKeychain()
    }

    var authorizationHeader: String? {
        guard let cred = cachedCredential else { return nil }
        let raw = "\(cred.email):\(cred.appPassword)"
        guard let data = raw.data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }

    var webdavRoot: URL? {
        URL(string: webdavBaseURL)
    }

    // MARK: - 登录

    func login(email: String, appPassword: String) async throws {
        let trimmedEmail    = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = appPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty    else { throw NutstoreAuthError.emptyEmail }
        guard !trimmedPassword.isEmpty else { throw NutstoreAuthError.emptyPassword }
        guard trimmedEmail.contains("@") else { throw NutstoreAuthError.invalidEmail }

        let valid = await verifyCredential(email: trimmedEmail, password: trimmedPassword)
        guard valid else { throw NutstoreAuthError.invalidCredential }

        let cred = Credential(email: trimmedEmail, appPassword: trimmedPassword)
        cachedCredential = cred

        do {
            try saveToKeychain(cred)
        } catch {
            cachedCredential = nil
            AppLogError("[NutstoreAuth] 保存凭证到 Keychain 失败: \(error)")
            throw NutstoreAuthError.keychainSaveFailed
        }

        accountEmail = trimmedEmail
        isLoggedIn = true

        AppLogInfo("[NutstoreAuth] 登录成功 email=\(trimmedEmail)")
    }

    func logout() {
        cachedCredential = nil
        accountEmail = nil
        isLoggedIn = false
        deleteFromKeychain()
        AppLogInfo("[NutstoreAuth] 已登出")
    }

    // MARK: - 凭证验证

    private func verifyCredential(email: String, password: String) async -> Bool {
        guard let url = URL(string: webdavBaseURL) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let raw = "\(email):\(password)"
        guard let data = raw.data(using: .utf8) else { return false }
        request.setValue("Basic \(data.base64EncodedString())",
                         forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 207 || http.statusCode == 200
        } catch {
            AppLogWarn("[NutstoreAuth] 凭证验证请求失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Keychain

    private func saveToKeychain(_ cred: Credential) throws {
        let data = try JSONEncoder().encode(cred)

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: KeychainKey.service,
            kSecAttrAccount as String: KeychainKey.account,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String]    = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "NutstoreAuth",
                          code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Keychain 写入失败 status=\(status)"])
        }
    }

    private func loadFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: KeychainKey.service,
            kSecAttrAccount as String: KeychainKey.account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let cred = try? JSONDecoder().decode(Credential.self, from: data) else {
            isLoggedIn = false
            return
        }

        cachedCredential = cred
        accountEmail = cred.email
        isLoggedIn = true
        AppLogInfo("[NutstoreAuth] 从 Keychain 恢复登录状态 email=\(cred.email)")
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: KeychainKey.service,
            kSecAttrAccount as String: KeychainKey.account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - 错误

enum NutstoreAuthError: LocalizedError {
    case emptyEmail
    case emptyPassword
    case invalidEmail
    case invalidCredential
    case keychainSaveFailed

    var errorDescription: String? {
        switch self {
        case .emptyEmail:         return "请输入坚果云账号邮箱"
        case .emptyPassword:      return "请输入应用密码"
        case .invalidEmail:       return "邮箱格式不正确"
        case .invalidCredential:  return "账号或应用密码错误，请检查后重试"
        case .keychainSaveFailed: return "凭证保存失败"
        }
    }
}
