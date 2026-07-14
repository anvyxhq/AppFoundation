//
//  Keychain.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation
import Security

/// Errors from the throwing Keychain API.
public enum KeychainError: Error, Equatable {
    case notFound
    case invalidData
    case accessControlFailed
    case unexpectedStatus(OSStatus)
}

/// A type-safe wrapper around the Keychain for storing secrets (tokens,
/// credentials) as generic passwords — with an access group, accessibility
/// class, optional biometric gating, and a throwing API that surfaces the real
/// `OSStatus`. The `Bool`-returning methods are kept for simple call sites.
public struct Keychain: Sendable {
    private let service: String
    private let accessGroup: String?

    /// When an item is readable, mapping to `kSecAttrAccessible*`.
    public enum Accessibility: Sendable {
        case whenUnlocked
        case afterFirstUnlock
        case whenUnlockedThisDeviceOnly
        case afterFirstUnlockThisDeviceOnly
        case whenPasscodeSetThisDeviceOnly

        var rawValue: CFString {
            switch self {
            case .whenUnlocked:                    kSecAttrAccessibleWhenUnlocked
            case .afterFirstUnlock:                kSecAttrAccessibleAfterFirstUnlock
            case .whenUnlockedThisDeviceOnly:      kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            case .afterFirstUnlockThisDeviceOnly:  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .whenPasscodeSetThisDeviceOnly:   kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            }
        }
    }

    public init(service: String = Bundle.main.bundleIdentifier ?? "AnvyxKit", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    // MARK: - Throwing API

    /// Store `data`, replacing any existing item. When `biometric` is `true` the
    /// item is protected by an access-control requiring Face ID / Touch ID (the
    /// current enrolled set), so reading it prompts for biometrics.
    public func store(_ data: Data, for key: String,
                      accessibility: Accessibility = .whenUnlocked,
                      biometric: Bool = false) throws {
        try? delete(key)
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        if biometric {
            guard let access = SecAccessControlCreateWithFlags(
                nil, accessibility.rawValue, .biometryCurrentSet, nil) else {
                throw KeychainError.accessControlFailed
            }
            query[kSecAttrAccessControl as String] = access
        } else {
            query[kSecAttrAccessible as String] = accessibility.rawValue
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    public func store(_ string: String, for key: String,
                      accessibility: Accessibility = .whenUnlocked,
                      biometric: Bool = false) throws {
        try store(Data(string.utf8), for: key, accessibility: accessibility, biometric: biometric)
    }

    /// Read raw data, or throw ``KeychainError/notFound``.
    public func retrieveData(for key: String) throws -> Data {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = result as? Data else { throw KeychainError.invalidData }
        return data
    }

    public func retrieveString(for key: String) throws -> String {
        guard let string = String(data: try retrieveData(for: key), encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    /// Delete an item (a missing item is not an error).
    public func delete(_ key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Bool convenience (unchanged surface)

    @discardableResult
    public func set(_ data: Data, for key: String) -> Bool { (try? store(data, for: key)) != nil }

    @discardableResult
    public func set(_ string: String, for key: String) -> Bool { set(Data(string.utf8), for: key) }

    public func data(for key: String) -> Data? { try? retrieveData(for: key) }

    public func string(for key: String) -> String? { try? retrieveString(for: key) }

    @discardableResult
    public func remove(_ key: String) -> Bool { (try? delete(key)) != nil }

    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }
}
