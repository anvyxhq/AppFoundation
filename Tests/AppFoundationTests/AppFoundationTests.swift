//
//  AppFoundationTests.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import XCTest
@testable import AppFoundation

final class AppFoundationTests: XCTestCase {
    func testSafeSubscript() {
        let array = [1, 2, 3]
        XCTAssertEqual(array[safe: 1], 2)
        XCTAssertNil(array[safe: 5])
    }

    func testStringHelpers() {
        XCTAssertTrue("   ".isBlank)
        XCTAssertEqual("  hi ".trimmed, "hi")
        XCTAssertTrue("a@b.com".isValidEmail)
        XCTAssertFalse("nope".isValidEmail)
    }

    func testUserDefaultRoundTrip() {
        let suite = UserDefaults(suiteName: #function)!
        suite.removePersistentDomain(forName: #function)

        struct Box { @UserDefault("flag", default: false, store: .standard) var flag: Bool }
        var box = Box()
        box.flag = true
        XCTAssertTrue(box.flag)
    }
}
