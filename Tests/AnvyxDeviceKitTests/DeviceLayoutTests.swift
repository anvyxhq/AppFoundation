//
//  DeviceLayoutTests.swift
//  DeviceKit
//
//  Created by AnhPT on 03/07/2026.
//

import XCTest
import UIKit
@testable import AnvyxDeviceKit

final class DeviceLayoutTests: XCTestCase {

    func testClampedConstrainsValue() {
        XCTAssertEqual(5.clamped(to: 0...3), 3)
        XCTAssertEqual((-1).clamped(to: 0...3), 0)
        XCTAssertEqual(2.clamped(to: 0...3), 2)
    }

    @MainActor
    func testDeviceClassIsResolved() {
        let known: [DeviceClass] = [.compact, .regular, .large]
        XCTAssertTrue(known.contains(DeviceClass.current))
    }

    @MainActor
    func testScreenDimensionsPositive() {
        XCTAssertGreaterThan(DeviceScreen.width, 0)
        XCTAssertGreaterThan(DeviceScreen.height, 0)
    }

    @MainActor
    func testAppWindowFallbacksWithoutWindow() {
        // In a unit-test host there is no key window.
        XCTAssertEqual(AppWindow.navigationBarHeight, 44)
        XCTAssertNil(AppWindow.topViewController)
    }
}
