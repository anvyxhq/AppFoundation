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

    private enum TestError: Error { case fail }
    private actor Counter {
        private(set) var count = 0
        func increment() -> Int { count += 1; return count }
    }
}
