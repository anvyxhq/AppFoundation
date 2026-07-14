//
//  KeychainTests.swift
//  AppFoundation
//
//  Created by AnhPT on 14/07/2026.
//

import XCTest
@testable import AnvyxFoundation

final class KeychainTests: XCTestCase {
    private let keychain = Keychain(service: "com.anvyx.tests.keychain")

    override func setUpWithError() throws {
        // A headless test bundle has no keychain-access-groups entitlement, so the
        // Keychain is unreachable there — skip rather than fail (runs on a host/device).
        do {
            try keychain.store("probe", for: "__probe__")
            try keychain.delete("__probe__")
        } catch KeychainError.unexpectedStatus(errSecMissingEntitlement) {
            throw XCTSkip("Keychain unavailable in this test host (missing entitlement)")
        }
    }

    override func tearDown() { try? keychain.delete("token"); super.tearDown() }

    func testStoreAndRetrieveRoundTrip() throws {
        try keychain.store("secret-123", for: "token")
        XCTAssertEqual(try keychain.retrieveString(for: "token"), "secret-123")
    }

    func testRetrieveMissingThrowsNotFound() {
        try? keychain.delete("token")
        XCTAssertThrowsError(try keychain.retrieveData(for: "token")) { error in
            XCTAssertEqual(error as? KeychainError, .notFound)
        }
    }

    func testStoreReplacesExisting() throws {
        try keychain.store("first", for: "token")
        try keychain.store("second", for: "token", accessibility: .afterFirstUnlock)
        XCTAssertEqual(try keychain.retrieveString(for: "token"), "second")
    }

    func testDeleteIsIdempotent() throws {
        try keychain.store("x", for: "token")
        try keychain.delete("token")
        XCTAssertNoThrow(try keychain.delete("token"))   // missing item is not an error
    }

    func testBoolAPIStillWorks() {
        XCTAssertTrue(keychain.set("v", for: "token"))
        XCTAssertEqual(keychain.string(for: "token"), "v")
        XCTAssertTrue(keychain.remove("token"))
        XCTAssertNil(keychain.string(for: "token"))
    }
}
