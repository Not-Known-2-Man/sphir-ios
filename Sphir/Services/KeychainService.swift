//
//  KeychainService.swift
//  Sphir
//
//  Secure storage for auth credentials (access_token + uid).
//  Tokens live only in the Keychain (App Group access group, shared with the
//  SphirShare extension), never in UserDefaults. Compiled into both targets.
//

import Foundation
import Security

enum KeychainService {
    enum Key: String, CaseIterable {
        case accessToken = "access_token"
        case uid
        case client
    }

    /// Keychain service name. Internal + mutable so tests can use an isolated one.
    static let service = "com.Sphir.auth"

    /// App Group shared by the app and SphirShare. App Groups are valid keychain
    /// access groups, so both targets read the same items. Tests set this to nil
    /// to exercise the default-group fallback.
    static let sharedAccessGroup: String? = "group.com.sphir.shared"

    // MARK: - CRUD

    static func save(_ value: String, for key: Key) {
        guard let data = value.data(using: .utf8) else { return }
        if writeShared(data, key: key) {
            // Drop any legacy copy so there is a single source of truth.
            SecItemDelete(baseQuery(for: key, group: nil) as CFDictionary)
            return
        }
        var query = baseQuery(for: key, group: nil)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    // `service`/`group` default to the statics above; tests pass their own so
    // they never mutate shared global state.
    static func load(_ key: Key, service: String = KeychainService.service,
                     group sharedGroup: String? = KeychainService.sharedAccessGroup) -> String? {
        if let group = sharedGroup,
           let value = read(baseQuery(for: key, group: group, service: service)) {
            return value
        }
        // Legacy / fallback location (default access group).
        guard let legacy = read(baseQuery(for: key, group: nil, service: service)) else { return nil }
        migrateToShared(legacy, key: key, service: service, group: sharedGroup)
        return legacy
    }

    static func delete(_ key: Key, service: String = KeychainService.service,
                       group sharedGroup: String? = KeychainService.sharedAccessGroup) {
        if let group = sharedGroup {
            SecItemDelete(baseQuery(for: key, group: group, service: service) as CFDictionary)
        }
        SecItemDelete(baseQuery(for: key, group: nil, service: service) as CFDictionary)
    }

    // MARK: - Convenience

    static func saveCredentials(accessToken: String, uid: String, client: String? = nil) {
        save(accessToken, for: .accessToken)
        save(uid, for: .uid)
        if let client { save(client, for: .client) }
    }

    static func clear() {
        Key.allCases.forEach { delete($0) }
    }

    static var hasCredentials: Bool {
        // Mock UI-test runs share the simulator Keychain with real sessions;
        // without this guard they synced mock data into the real account.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("UITEST") || args.contains("LOGGED_OUT") { return false }
        return load(.accessToken) != nil && load(.uid) != nil
    }

    /// Auth headers to attach to protected requests.
    static var authHeaders: [String: String] {
        guard let token = load(.accessToken),
              let uid = load(.uid) else { return [:] }
        var headers = [
            "Authorization": "Bearer \(token)",
            "uid": uid
        ]
        if let client = load(.client) { headers["client"] = client }
        return headers
    }

    // MARK: - Private

    /// Moves a legacy item into the shared group; the legacy item is deleted
    /// only after the shared write succeeded.
    private static func migrateToShared(_ value: String, key: Key, service: String, group: String?) {
        guard let data = value.data(using: .utf8) else { return }
        if writeShared(data, key: key, service: service, group: group) {
            SecItemDelete(baseQuery(for: key, group: nil, service: service) as CFDictionary)
        }
    }

    /// Writes to the shared group and verifies by reading back (some unsigned
    /// simulator builds accept the add but never return the item).
    private static func writeShared(_ data: Data, key: Key,
                                    service: String = KeychainService.service,
                                    group sharedGroup: String? = KeychainService.sharedAccessGroup) -> Bool {
        guard let group = sharedGroup else { return false }
        var query = baseQuery(for: key, group: group, service: service)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            log("shared keychain group unavailable (OSStatus \(status)); using default group")
            return false
        }
        guard read(baseQuery(for: key, group: group, service: service)) != nil else {
            log("shared keychain group accepted the write but cannot read it back; using default group")
            SecItemDelete(baseQuery(for: key, group: group, service: service) as CFDictionary)
            return false
        }
        return true
    }

    private static func read(_ base: [String: Any]) -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private static func baseQuery(for key: Key, group: String?, service: String = KeychainService.service) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            // A query without an access group matches items in every group the
            // process can see, so shared items use a distinct service name; otherwise
            // deleting the legacy item would also delete the shared one.
            kSecAttrService as String: group == nil ? service : service + ".shared",
            kSecAttrAccount as String: key.rawValue
        ]
        if let group { query[kSecAttrAccessGroup as String] = group }
        return query
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("[Keychain] \(message)")
        #endif
    }
}
