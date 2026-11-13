//
//  KeychainStoreTests.swift
//  AppFoundation
//
//  Created by AnhPT on 13/11/2026.
//

import XCTest
import Security
@testable import AnvyxFoundation

/// An in-memory stand-in for the `SecItem*` calls, so the store/replace/migrate
/// logic runs without a real Keychain (unavailable in a hostless test bundle).
private final class FakeKeychain: Sendable {
    struct Item { var data: Data; var accessible: String? }

    let items = LockedValue<[String: Item]>([:])
    /// When set, the matching call fails with this status and changes nothing.
    let addFailure = LockedValue<OSStatus?>(nil)
    let updateFailure = LockedValue<OSStatus?>(nil)
    let copyFailure = LockedValue<OSStatus?>(nil)
    let deleteFailure = LockedValue<OSStatus?>(nil)

    private static func id(_ query: [String: Any]) -> String {
        let service = query[kSecAttrService as String] as? String ?? ""
        let account = query[kSecAttrAccount as String] as? String ?? ""
        return service + "|" + account
    }

    var backend: KeychainBackend {
        KeychainBackend(
            add: { [self] attributes in
                if let status = addFailure.current { return status }
                return items.withLock { items in
                    let id = Self.id(attributes)
                    guard items[id] == nil else { return errSecDuplicateItem }
                    items[id] = Item(data: attributes[kSecValueData as String] as? Data ?? Data(),
                                     accessible: attributes[kSecAttrAccessible as String] as? String)
                    return errSecSuccess
                }
            },
            update: { [self] query, attributes in
                if let status = updateFailure.current { return status }
                return items.withLock { items in
                    let id = Self.id(query)
                    guard var item = items[id] else { return errSecItemNotFound }
                    if let data = attributes[kSecValueData as String] as? Data { item.data = data }
                    if let accessible = attributes[kSecAttrAccessible as String] as? String {
                        item.accessible = accessible
                    }
                    items[id] = item
                    return errSecSuccess
                }
            },
            copy: { [self] query in
                if let status = copyFailure.current { return (status, nil) }
                guard let item = items.current[Self.id(query)] else { return (errSecItemNotFound, nil) }
                return (errSecSuccess, item.data)
            },
            delete: { [self] query in
                if let status = deleteFailure.current { return status }
                return items.withLock { items in
                    let before = items.count
                    if query[kSecAttrAccount as String] == nil {
                        let prefix = (query[kSecAttrService as String] as? String ?? "") + "|"
                        items = items.filter { !$0.key.hasPrefix(prefix) }
                    } else {
                        items[Self.id(query)] = nil
                    }
                    return items.count == before ? errSecItemNotFound : errSecSuccess
                }
            }
        )
    }
}

final class KeychainStoreTests: XCTestCase {
    private var fake: FakeKeychain!
    private var keychain: Keychain!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        fake = FakeKeychain()
        keychain = Keychain(service: "svc", backend: fake.backend)
        suiteName = "KeychainStoreTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: store

    func testStoreAddsThenReplaces() throws {
        try keychain.store("first", for: "token")
        try keychain.store("second", for: "token")
        XCTAssertEqual(try keychain.retrieveString(for: "token"), "second")
    }

    /// Replacing must not go through delete-then-add: with the add path broken, an
    /// existing item is still replaced in place.
    func testReplaceUpdatesInPlace() throws {
        try keychain.store("old", for: "token")
        fake.addFailure.set(errSecParam)
        fake.deleteFailure.set(errSecParam)

        try keychain.store("new", for: "token")
        XCTAssertEqual(try keychain.retrieveString(for: "token"), "new")
    }

    /// The bug: delete-then-add dropped the existing secret when the write failed.
    func testFailedUpdateKeepsExistingSecret() throws {
        try keychain.store("old", for: "token")
        fake.updateFailure.set(errSecInteractionNotAllowed)

        XCTAssertThrowsError(try keychain.store("new", for: "token")) { error in
            XCTAssertEqual(error as? KeychainError, .interactionNotAllowed)
        }
        fake.updateFailure.set(nil)
        XCTAssertEqual(try keychain.retrieveString(for: "token"), "old")
    }

    func testLockedDeviceMapsToInteractionNotAllowed() throws {
        fake.copyFailure.set(errSecInteractionNotAllowed)
        XCTAssertThrowsError(try keychain.retrieveData(for: "token")) { error in
            XCTAssertEqual(error as? KeychainError, .interactionNotAllowed)
        }
        fake.copyFailure.set(nil)

        fake.addFailure.set(errSecInteractionNotAllowed)
        XCTAssertThrowsError(try keychain.store("v", for: "token")) { error in
            XCTAssertEqual(error as? KeychainError, .interactionNotAllowed)
        }
    }

    func testOtherStatusStaysUnexpected() {
        fake.addFailure.set(errSecParam)
        XCTAssertThrowsError(try keychain.store("v", for: "token")) { error in
            XCTAssertEqual(error as? KeychainError, .unexpectedStatus(errSecParam))
        }
    }

    func testAccessibilityDefaultAndOverride() throws {
        let deviceOnly = Keychain(service: "svc", accessibility: .afterFirstUnlockThisDeviceOnly,
                                  backend: fake.backend)
        try deviceOnly.store("a", for: "k")
        XCTAssertEqual(fake.items.current["svc|k"]?.accessible,
                       kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)

        // Per-call override, applied to an existing item too.
        try deviceOnly.store("b", for: "k", accessibility: .whenUnlockedThisDeviceOnly)
        XCTAssertEqual(fake.items.current["svc|k"]?.accessible,
                       kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)

        try keychain.store("c", for: "plain")
        XCTAssertEqual(fake.items.current["svc|plain"]?.accessible, kSecAttrAccessibleWhenUnlocked as String)
    }

    func testDeleteAllOnlyTouchesOwnService() throws {
        let other = Keychain(service: "other", backend: fake.backend)
        try keychain.store("a", for: "one")
        try keychain.store("b", for: "two")
        try other.store("c", for: "one")

        try keychain.deleteAll()
        XCTAssertNoThrow(try keychain.deleteAll())   // nothing left is not an error

        XCTAssertThrowsError(try keychain.retrieveData(for: "one"))
        XCTAssertThrowsError(try keychain.retrieveData(for: "two"))
        XCTAssertEqual(try other.retrieveString(for: "one"), "c")
    }

    // MARK: resetOnReinstall

    func testResetOnReinstallClearsOnceThenKeeps() throws {
        try keychain.store("leftover", for: "token")   // survived an uninstall

        XCTAssertTrue(try keychain.resetOnReinstall(defaults: defaults))
        XCTAssertThrowsError(try keychain.retrieveData(for: "token"))

        try keychain.store("fresh", for: "token")
        XCTAssertFalse(try keychain.resetOnReinstall(defaults: defaults))   // marker present
        XCTAssertEqual(try keychain.retrieveString(for: "token"), "fresh")
    }

    func testResetOnReinstallRetriesAfterFailure() throws {
        try keychain.store("leftover", for: "token")
        fake.deleteFailure.set(errSecInteractionNotAllowed)
        XCTAssertThrowsError(try keychain.resetOnReinstall(defaults: defaults))

        fake.deleteFailure.set(nil)
        XCTAssertTrue(try keychain.resetOnReinstall(defaults: defaults), "marker must not be set by a failed reset")
        XCTAssertThrowsError(try keychain.retrieveData(for: "token"))
    }

    // MARK: migrate

    func testMigrateMovesStringAndRemovesLegacy() throws {
        defaults.set("legacy-token", forKey: "token")

        XCTAssertTrue(try keychain.migrate(fromDefaultsKey: "token", defaults: defaults))
        XCTAssertEqual(try keychain.retrieveString(for: "token"), "legacy-token")
        XCTAssertNil(defaults.object(forKey: "token"))
        XCTAssertFalse(try keychain.migrate(fromDefaultsKey: "token", defaults: defaults))   // nothing left
    }

    func testMigrateMovesDataUnderNewKey() throws {
        defaults.set(Data([1, 2, 3]), forKey: "old.blob")

        XCTAssertTrue(try keychain.migrate(fromDefaultsKey: "old.blob", to: "blob", defaults: defaults))
        XCTAssertEqual(try keychain.retrieveData(for: "blob"), Data([1, 2, 3]))
        XCTAssertNil(defaults.object(forKey: "old.blob"))
    }

    func testMigrateKeepsExistingKeychainValue() throws {
        try keychain.store("current", for: "token")
        defaults.set("stale", forKey: "token")

        XCTAssertFalse(try keychain.migrate(fromDefaultsKey: "token", defaults: defaults))
        XCTAssertEqual(try keychain.retrieveString(for: "token"), "current")
        XCTAssertNil(defaults.object(forKey: "token"))
    }

    func testMigrateKeepsLegacyWhenStoreFails() {
        defaults.set("legacy-token", forKey: "token")
        fake.addFailure.set(errSecInteractionNotAllowed)

        XCTAssertThrowsError(try keychain.migrate(fromDefaultsKey: "token", defaults: defaults))
        XCTAssertEqual(defaults.string(forKey: "token"), "legacy-token")
    }
}
