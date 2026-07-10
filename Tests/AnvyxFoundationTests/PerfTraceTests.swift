//
//  PerfTraceTests.swift
//  AppFoundation
//
//  Created by AnhPT on 10/07/2026.
//

import XCTest
@testable import AnvyxFoundation

struct PerfTraceError: Error {}

final class PerfTraceTests: XCTestCase {

    func testIntervalReturnsBodyValue() {
        let value = PerfTrace.interval("test.sync") { 6 * 7 }
        XCTAssertEqual(value, 42)
    }

    func testAsyncIntervalReturnsBodyValue() async {
        let value = await PerfTrace.interval("test.async") {
            await Task.yield()
            return "done"
        }
        XCTAssertEqual(value, "done")
    }

    func testIntervalRethrows() {
        XCTAssertThrowsError(try PerfTrace.interval("test.throwing") { throw PerfTraceError() }) { error in
            XCTAssertTrue(error is PerfTraceError)
        }
    }

    func testManualBeginEndDoesNotCrash() {
        let token = PerfTrace.begin("test.manual")
        PerfTrace.end("test.manual", token)
    }

    func testEventDoesNotCrash() {
        PerfTrace.event("test.event")
    }
}
