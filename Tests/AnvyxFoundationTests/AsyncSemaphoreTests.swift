//
//  AsyncSemaphoreTests.swift
//  AppFoundation
//
//  Created by AnhPT on 10/07/2026.
//

import XCTest
@testable import AnvyxFoundation

/// Tracks how many tasks are inside a critical section at once.
private actor ConcurrencyTracker {
    private(set) var current = 0
    private(set) var peak = 0

    func enter() { current += 1; peak = max(peak, current) }
    func leave() { current -= 1 }
}

final class AsyncSemaphoreTests: XCTestCase {

    func testNeverExceedsPermitCount() async {
        let limit = 3
        let semaphore = AsyncSemaphore(value: limit)
        let tracker = ConcurrencyTracker()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await semaphore.withPermit {
                        await tracker.enter()
                        await Task.yield()
                        try? await Task.sleep(nanoseconds: 2_000_000)   // force overlap
                        await tracker.leave()
                    }
                }
            }
        }

        let peak = await tracker.peak
        XCTAssertGreaterThan(peak, 0)
        XCTAssertLessThanOrEqual(peak, limit, "concurrency must never exceed the permit count")
    }

    func testPermitReleasedAfterThrow() async {
        let semaphore = AsyncSemaphore(value: 1)
        struct Boom: Error {}

        // Consume-and-throw: the permit must come back so the next acquire succeeds.
        do {
            _ = try await semaphore.withPermit { throw Boom() }
            XCTFail("expected throw")
        } catch {
            XCTAssertTrue(error is Boom)
        }

        // If the permit leaked, this would deadlock; guard with a timeout task.
        let acquired = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await semaphore.wait(); return true }
            group.addTask { try? await Task.sleep(nanoseconds: 500_000_000); return false }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        XCTAssertTrue(acquired, "permit should be available again after a throwing body")
    }

    func testWaitSignalRoundTrip() async {
        let semaphore = AsyncSemaphore(value: 0)
        // No permits: a waiter suspends until signaled.
        let waiter = Task { await semaphore.wait() }
        await semaphore.signal()
        await waiter.value   // completes only if signal resumed the waiter
    }
}
