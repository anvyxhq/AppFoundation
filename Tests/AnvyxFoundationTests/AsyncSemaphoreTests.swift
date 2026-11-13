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

    // MARK: Cancellation

    /// Polls until `count` callers are suspended in the semaphore's queue.
    private func waitForWaiters(_ count: Int, in semaphore: AsyncSemaphore,
                                file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<2_000 {
            if await semaphore.waiterCount == count { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("expected \(count) waiter(s)", file: file, line: line)
    }

    func testCancelledWaiterThrowsAndLeavesQueue() async {
        let semaphore = AsyncSemaphore(value: 0)
        let cancelled = Task { try await semaphore.waitUnlessCancelled() }
        await waitForWaiters(1, in: semaphore)

        cancelled.cancel()
        do {
            try await cancelled.value
            XCTFail("expected CancellationError")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }

        let waiters = await semaphore.waiterCount
        XCTAssertEqual(waiters, 0, "a cancelled waiter must not stay queued")
    }

    func testCancelledWaiterDoesNotConsumePermit() async throws {
        let semaphore = AsyncSemaphore(value: 0)
        let cancelled = Task { try await semaphore.waitUnlessCancelled() }
        await waitForWaiters(1, in: semaphore)
        let later = Task { try await semaphore.waitUnlessCancelled() }
        await waitForWaiters(2, in: semaphore)

        cancelled.cancel()
        _ = await cancelled.result
        await waitForWaiters(1, in: semaphore)

        // One signal: it must reach the later waiter, not the cancelled one ahead of it.
        await semaphore.signal()
        try await later.value

        // And a further signal is banked as a free permit.
        await semaphore.signal()
        let permits = await semaphore.availablePermits
        XCTAssertEqual(permits, 1)
    }

    func testAlreadyCancelledTaskThrowsWithoutTakingPermit() async {
        let semaphore = AsyncSemaphore(value: 1)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await semaphore.waitUnlessCancelled()
        }
        let result = await task.result
        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError) }
        let permits = await semaphore.availablePermits
        XCTAssertEqual(permits, 1)
    }

    func testWithPermitUnlessCancelledSkipsBodyAndKeepsPermits() async {
        let semaphore = AsyncSemaphore(value: 1)
        await semaphore.wait()   // hold the only permit
        let ran = LockedValue(false)

        let blocked = Task {
            try await semaphore.withPermitUnlessCancelled { ran.set(true) }
        }
        await waitForWaiters(1, in: semaphore)
        blocked.cancel()
        let result = await blocked.result
        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertFalse(ran.current)

        await semaphore.signal()
        let permits = await semaphore.availablePermits
        XCTAssertEqual(permits, 1, "the cancelled caller must not have released a permit it never held")
    }

    func testMixedWaitersStayFIFO() async throws {
        let semaphore = AsyncSemaphore(value: 0)
        let order = LockedValue<[Int]>([])
        let first = Task { await semaphore.wait(); order.withLock { $0.append(1) } }
        await waitForWaiters(1, in: semaphore)
        let second = Task { try await semaphore.waitUnlessCancelled(); order.withLock { $0.append(2) } }
        await waitForWaiters(2, in: semaphore)

        await semaphore.signal()
        await first.value
        await semaphore.signal()
        try await second.value
        XCTAssertEqual(order.current, [1, 2])
    }
}
