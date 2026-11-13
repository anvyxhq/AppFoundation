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
    /// The item exists but cannot be used right now (`errSecInteractionNotAllowed`)
    /// — typically the device is locked and the item's ``Keychain/Accessibility``
    /// does not allow access in that state. Nothing was changed; try again once
    /// the device is unlocked.
    case interactionNotAllowed
    case unexpectedStatus(OSStatus)
}

/// The `SecItem*` calls ``Keychain`` goes through, as a seam for tests.
struct KeychainBackend: Sendable {
    var add: @Sendable (_ attributes: [String: Any]) -> OSStatus
    var update: @Sendable (_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus
    var copy: @Sendable (_ query: [String: Any]) -> (status: OSStatus, data: Data?)
    var delete: @Sendable (_ query: [String: Any]) -> OSStatus

    static let system = KeychainBackend(
        add: { SecItemAdd($0 as CFDictionary, nil) },
        update: { SecItemUpdate($0 as CFDictionary, $1 as CFDictionary) },
        copy: { query in
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return (status, result as? Data)
        },
        delete: { SecItemDelete($0 as CFDictionary) }
    )
}

/// A type-safe wrapper around the Keychain for storing secrets (tokens,
/// credentials) as generic passwords — with an access group, accessibility
/// class, optional biometric gating, and a throwing API that surfaces the real
/// `OSStatus`. The `Bool`-returning methods are kept for simple call sites.
///
/// Pick the ``Accessibility`` once per instance; the `ThisDeviceOnly` classes
/// keep items out of backups and device transfers, and the `afterFirstUnlock`
/// classes stay readable while the device is locked (background work):
///
/// ```swift
/// let keychain = Keychain(accessibility: .afterFirstUnlockThisDeviceOnly)
/// try keychain.resetOnReinstall()                 // once, at launch
/// try keychain.migrate(fromDefaultsKey: "token")  // move a legacy value over
/// try keychain.store(token, for: "token")
/// ```
public struct Keychain: Sendable {
    private let service: String
    private let accessGroup: String?
    private let defaultAccessibility: Accessibility
    private let backend: KeychainBackend

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

    /// - Parameters:
    ///   - service: groups this instance's items (`kSecAttrService`).
    ///   - accessGroup: a shared keychain access group, if any.
    ///   - accessibility: the class used by `store` calls that do not pass their
    ///     own. Defaults to ``Accessibility/whenUnlocked``.
    public init(service: String = Bundle.main.bundleIdentifier ?? "AnvyxKit",
                accessGroup: String? = nil,
                accessibility: Accessibility = .whenUnlocked) {
        self.init(service: service, accessGroup: accessGroup, accessibility: accessibility, backend: .system)
    }

    init(service: String, accessGroup: String? = nil,
         accessibility: Accessibility = .whenUnlocked, backend: KeychainBackend) {
        self.service = service
        self.accessGroup = accessGroup
        self.defaultAccessibility = accessibility
        self.backend = backend
    }

    // MARK: - Throwing API

    /// Store `data`, replacing any existing item. When `biometric` is `true` the
    /// item is protected by an access-control requiring Face ID / Touch ID (the
    /// current enrolled set), so reading it prompts for biometrics.
    ///
    /// An existing item is updated in place, so when the write fails the previous
    /// value is still there. (Biometric items cannot be updated without a prompt;
    /// for those an existing item is removed and added again.)
    ///
    /// - Parameter accessibility: overrides the instance's accessibility for this
    ///   item; also applied when the item already exists.
    /// - Throws: ``KeychainError/interactionNotAllowed`` when the device is locked
    ///   and the item is not accessible in that state.
    public func store(_ data: Data, for key: String,
                      accessibility: Accessibility? = nil,
                      biometric: Bool = false) throws {
        let accessibility = accessibility ?? defaultAccessibility
        let query = baseQuery(for: key)
        var attributes: [String: Any] = [kSecValueData as String: data]

        if biometric {
            guard let access = SecAccessControlCreateWithFlags(
                nil, accessibility.rawValue, .biometryCurrentSet, nil) else {
                throw KeychainError.accessControlFailed
            }
            attributes[kSecAttrAccessControl as String] = access
            let item = query.merging(attributes) { _, new in new }
            var status = backend.add(item)
            if status == errSecDuplicateItem {
                try delete(key)
                status = backend.add(item)
            }
            try Self.check(status)
            return
        }

        attributes[kSecAttrAccessible as String] = accessibility.rawValue
        var status = backend.update(query, attributes)
        if status == errSecItemNotFound {
            status = backend.add(query.merging(attributes) { _, new in new })
        }
        try Self.check(status)
    }

    public func store(_ string: String, for key: String,
                      accessibility: Accessibility? = nil,
                      biometric: Bool = false) throws {
        try store(Data(string.utf8), for: key, accessibility: accessibility, biometric: biometric)
    }

    /// Read raw data, or throw ``KeychainError/notFound``.
    public func retrieveData(for key: String) throws -> Data {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let (status, data) = backend.copy(query)
        try Self.check(status)
        guard let data else { throw KeychainError.invalidData }
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
        let status = backend.delete(baseQuery(for: key))
        guard status != errSecItemNotFound else { return }
        try Self.check(status)
    }

    /// Delete every item stored under this instance's service (and access group,
    /// when one was given). Having nothing to delete is not an error.
    public func deleteAll() throws {
        let status = backend.delete(serviceQuery())
        guard status != errSecItemNotFound else { return }
        try Self.check(status)
    }

    // MARK: - Install lifecycle

    /// Clear items left over from a previous installation — once per install.
    ///
    /// Keychain items outlive the app: after delete-and-reinstall the old items
    /// are still there, while everything else the app stored is gone. This keeps
    /// a marker in `defaults` (which *is* removed with the app); when the marker
    /// is missing, ``deleteAll()`` runs and the marker is written.
    ///
    /// Call it once at launch, before the first read. If clearing fails the
    /// marker is not written, so the next launch tries again.
    ///
    /// - Important: Adopt this in the same release that first stores items. An
    ///   update from a version that stored items but never wrote the marker looks
    ///   like a fresh install and is cleared once.
    /// - Parameters:
    ///   - defaults: where the marker lives. Must not be an app-group suite that
    ///     outlives the app.
    ///   - markerKey: the marker's key; defaults to one derived from the service.
    /// - Returns: `true` when this call cleared the items, `false` when the marker
    ///   was already present.
    @discardableResult
    public func resetOnReinstall(defaults: UserDefaults = .standard, markerKey: String? = nil) throws -> Bool {
        let markerKey = markerKey ?? "anvyx.keychain.installed.\(service)"
        guard !defaults.bool(forKey: markerKey) else { return false }
        try deleteAll()
        defaults.set(true, forKey: markerKey)
        return true
    }

    /// Move a value that an earlier version kept in `UserDefaults` into the
    /// Keychain, then remove it from `defaults`.
    ///
    /// The legacy entry is removed only after the Keychain write succeeded, so a
    /// failure loses nothing and the next call retries. An item already present
    /// in the Keychain is kept as is (it is the newer value) and the legacy entry
    /// is dropped. Only `String` and `Data` values are migrated.
    ///
    /// When used together with ``resetOnReinstall(defaults:markerKey:)``, call
    /// that first.
    ///
    /// - Parameters:
    ///   - defaultsKey: the legacy `UserDefaults` key.
    ///   - key: the Keychain key to store under; defaults to `defaultsKey`.
    ///   - defaults: the store holding the legacy value.
    ///   - accessibility: overrides the instance's accessibility for this item.
    /// - Returns: `true` when a value was written to the Keychain.
    @discardableResult
    public func migrate(fromDefaultsKey defaultsKey: String, to key: String? = nil,
                        defaults: UserDefaults = .standard,
                        accessibility: Accessibility? = nil) throws -> Bool {
        let legacy: Data
        switch defaults.object(forKey: defaultsKey) {
        case let string as String: legacy = Data(string.utf8)
        case let data as Data:     legacy = data
        default:                   return false
        }
        let key = key ?? defaultsKey
        let migrated: Bool
        do {
            _ = try retrieveData(for: key)
            migrated = false
        } catch KeychainError.notFound {
            try store(legacy, for: key, accessibility: accessibility)
            migrated = true
        }
        defaults.removeObject(forKey: defaultsKey)
        return migrated
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

    private func serviceQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    private func baseQuery(for key: String) -> [String: Any] {
        var query = serviceQuery()
        query[kSecAttrAccount as String] = key
        return query
    }

    private static func check(_ status: OSStatus) throws {
        switch status {
        case errSecSuccess:               return
        case errSecItemNotFound:          throw KeychainError.notFound
        case errSecInteractionNotAllowed: throw KeychainError.interactionNotAllowed
        default:                          throw KeychainError.unexpectedStatus(status)
        }
    }
}
