//
//  TaskQueueTests.swift
//  AppFoundation
//
//  Created by AnhPT on 10/07/2026.
//

import XCTest
@testable import AnvyxFoundation

private actor Peak {
    private(set) var current = 0
    private(set) var peak = 0
    func enter() { current += 1; peak = max(peak, current) }
    func leave() { current -= 1 }
}

final class TaskQueueTests: XCTestCase {

    func testRunReturnsResult() async throws {
        let queue = TaskQueue(maxConcurrent: 2)
        let value = try await queue.run { 21 * 2 }
        XCTAssertEqual(value, 42)
    }

    func testBoundsConcurrency() async {
        let queue = TaskQueue(maxConcurrent: 2)
        let peak = Peak()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<12 {
                group.addTask {
                    try? await queue.run {
                        await peak.enter()
                        await Task.yield()
                        try? await Task.sleep(nanoseconds: 2_000_000)
                        await peak.leave()
                    }
                }
            }
        }

        let observed = await peak.peak
        XCTAssertGreaterThan(observed, 0)
        XCTAssertLessThanOrEqual(observed, 2)
    }
}
