//
//  Keychain.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation
import Security

/// A minimal, type-safe wrapper around the Keychain for storing secrets
/// (tokens, credentials) as generic passwords.
public struct Keychain: Sendable {
    private let service: String

    public init(service: String = Bundle.main.bundleIdentifier ?? "AnvoraKit") {
        self.service = service
    }

    @discardableResult
    public func set(_ data: Data, for key: String) -> Bool {
        var query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    public func set(_ string: String, for key: String) -> Bool {
        set(Data(string.utf8), for: key)
    }

    public func data(for key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    public func string(for key: String) -> String? {
        data(for: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    @discardableResult
    public func remove(_ key: String) -> Bool {
        SecItemDelete(baseQuery(for: key) as CFDictionary) == errSecSuccess
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
