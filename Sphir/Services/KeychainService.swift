//
//  KeychainService.swift
//  Sphir
//
//  Secure storage for auth credentials (access_token + uid).
//  Tokens live only in the Keychain, never in UserDefaults.
//

import Foundation
import Security

enum KeychainService {
    enum Key: String, CaseIterable {
        case accessToken = "access_token"
        case uid
    }

    private static let service = "com.Sphir.auth"

    // MARK: - CRUD

    static func save(_ value: String, for key: Key) {
        guard let data = value.data(using: .utf8) else { return }
        var query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(_ key: Key) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    static func delete(_ key: Key) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    // MARK: - Convenience

    static func saveCredentials(accessToken: String, uid: String) {
        save(accessToken, for: .accessToken)
        save(uid, for: .uid)
    }

    static func clear() {
        Key.allCases.forEach { delete($0) }
    }

    static var hasCredentials: Bool {
        load(.accessToken) != nil && load(.uid) != nil
    }

    /// Auth headers to attach to protected requests.
    static var authHeaders: [String: String] {
        guard let token = load(.accessToken),
              let uid = load(.uid) else { return [:] }
        return [
            "Authorization": "Bearer \(token)",
            "uid": uid
        ]
    }

    // MARK: - Private

    private static func baseQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }
}
