//
//  CacheRetryTests.swift
//  AppFoundation
//
//  Created by AnhPT on 14/07/2026.
//

import XCTest
@testable import AnvyxFoundation

final class CacheRetryTests: XCTestCase {
    func testCacheStoresAndReads() {
        let cache = MemoryCache<String, Int>()
        cache.insert(42, for: "a")
        XCTAssertEqual(cache.value(for: "a"), 42)
    }

    func testCacheTTLExpires() {
        let cache = MemoryCache<String, Int>()
        cache.insert(1, for: "a", ttl: -1)   // already past
        XCTAssertNil(cache.value(for: "a"))
    }

    func testCacheTTLStillValid() {
        let cache = MemoryCache<String, Int>()
        cache.insert(7, for: "a", ttl: 60)
        XCTAssertEqual(cache.value(for: "a"), 7)
    }

    func testRetrySucceedsAfterFailures() async throws {
        let counter = Counter()
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0)
        let result = try await withRetry(policy) { () async throws -> Int in
            if await counter.increment() < 3 { throw TestError.fail }
            return 99
        }
        XCTAssertEqual(result, 99)
        let attempts = await counter.count
        XCTAssertEqual(attempts, 3)
    }

    func testRetryThrowsAfterMaxAttempts() async {
        let counter = Counter()
        let policy = RetryPolicy(maxAttempts: 2, baseDelay: 0)
        do {
            _ = try await withRetry(policy) { () async throws -> Int in
                _ = await counter.increment(); throw TestError.fail
            }
            XCTFail("expected throw")
        } catch { /* expected */ }
        let attempts = await counter.count
        XCTAssertEqual(attempts, 2)
    }

    func testCancelDuringBackoffStopsPromptly() async {
        let counter = Counter()
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 30, jitter: 0)
        let task = Task {
            try await withRetry(policy) { () async throws -> Int in
                _ = await counter.increment(); throw TestError.fail
            }
        }
        // Let the first attempt fail so the task is sleeping in its backoff.
        while await counter.count < 1 { try? await Task.sleep(nanoseconds: 1_000_000) }
        try? await Task.sleep(nanoseconds: 50_000_000)

        let start = ContinuousClock.now
        task.cancel()
        let result = await task.result
        let elapsed = ContinuousClock.now - start

        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError, "got \($0)") }
        XCTAssertLessThan(elapsed, .seconds(5))
        let attempts = await counter.count
        XCTAssertEqual(attempts, 1, "a cancelled task must not run further attempts")
    }

    func testCancelledTaskDoesNotStartAnAttempt() async {
        let counter = Counter()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await withRetry(RetryPolicy(maxAttempts: 3, baseDelay: 0)) { () async throws -> Int in
                await counter.increment()
            }
        }
        let result = await task.result
        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError) }
        let attempts = await counter.count
        XCTAssertEqual(attempts, 0)
    }

    func testCancellationErrorIsNeverRetried() async {
        let counter = Counter()
        do {
            _ = try await withRetry(RetryPolicy(maxAttempts: 3, baseDelay: 0)) { () async throws -> Int in
                _ = await counter.increment(); throw CancellationError()
            }
            XCTFail("expected throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let attempts = await counter.count
        XCTAssertEqual(attempts, 1)
    }

    private enum TestError: Error { case fail }
    private actor Counter {
        private(set) var count = 0
        func increment() -> Int { count += 1; return count }
    }
}
