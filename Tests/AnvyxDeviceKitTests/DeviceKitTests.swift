//
//  DeviceKitTests.swift
//  DeviceKit
//
//  Created by AnhPT on 02/07/2026.
//

import XCTest
@testable import AnvyxDeviceKit

final class DeviceKitTests: XCTestCase {
    func testCurrentDeviceResolves() {
        let device = Device.current
        XCTAssertFalse(device.identifier.isEmpty)
    }

    func testFamilyParsing() {
        XCTAssertEqual(Device(identifier: "iPhone16,1").family, .iPhone)
        XCTAssertEqual(Device(identifier: "iPad13,1").family, .iPad)
        XCTAssertEqual(Device(identifier: "iPod9,1").family, .iPod)
        XCTAssertEqual(Device(identifier: "Frobnicator9,9").family, .unknown)
    }

    func testMarketingNameWithFallback() {
        XCTAssertEqual(Device(identifier: "iPhone16,1").name, "iPhone 15 Pro")
        // Unknown identifier falls back to itself.
        XCTAssertEqual(Device(identifier: "iPhone99,9").name, "iPhone99,9")
    }

    func testDynamicIslandAndNotch() {
        XCTAssertTrue(Device(identifier: "iPhone16,1").hasDynamicIsland)
        XCTAssertFalse(Device(identifier: "iPhone16,1").hasNotch)
        XCTAssertTrue(Device(identifier: "iPhone12,1").hasNotch)
    }

    func testIsOneOf() {
        let phone = Device(identifier: "iPhone16,1")
        XCTAssertTrue(phone.isOneOf([Device(identifier: "iPhone16,1"), Device(identifier: "iPad13,1")]))
    }
}
