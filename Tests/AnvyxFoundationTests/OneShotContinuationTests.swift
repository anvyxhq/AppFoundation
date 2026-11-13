//
//  OneShotContinuationTests.swift
//  AppFoundation
//
//  Created by AnhPT on 13/11/2026.
//

import XCTest
@testable import AnvyxFoundation

final class OneShotContinuationTests: XCTestCase {
    private enum TestError: Error { case fail }

    func testDoubleResumeKeepsFirstValue() async {
        let results = LockedValue<[Bool]>([])
        let value = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            let once = OneShotContinuation(continuation)
            XCTAssertFalse(once.isResumed)
            results.withLock { $0.append(once.resume(returning: 1)) }
            results.withLock { $0.append(once.resume(returning: 2)) }   // would trap on a bare continuation
            XCTAssertTrue(once.isResumed)
        }
        XCTAssertEqual(value, 1)
        XCTAssertEqual(results.current, [true, false])
    }

    func testThrowAfterReturnIsIgnored() async throws {
        let value = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, any Error>) in
            let once = OneShotContinuation(continuation)
            once.resume(returning: "ok")
            XCTAssertFalse(once.resume(throwing: TestError.fail))
            XCTAssertFalse(once.resume(with: .success("late")))
        }
        XCTAssertEqual(value, "ok")
    }

    func testReturnAfterThrowIsIgnored() async {
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, any Error>) in
                let once = OneShotContinuation(continuation)
                once.resume(throwing: TestError.fail)
                once.resume(returning: 1)
            }
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? TestError, .fail)
        }
    }

    func testVoidResume() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = OneShotContinuation(continuation)
            XCTAssertTrue(once.resume())
            XCTAssertFalse(once.resume())
        }
    }

    func testResumeFromTwoThreadsResumesOnce() async {
        for _ in 0..<200 {
            let winners = LockedValue(0)
            let value = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
                let once = OneShotContinuation(continuation)
                for thread in 0..<2 {
                    Thread.detachNewThread {
                        if once.resume(returning: thread) { winners.withLock { $0 += 1 } }
                    }
                }
            }
            XCTAssertTrue((0..<2).contains(value))
            // Give the losing thread time to report; it must never count as a winner.
            try? await Task.sleep(nanoseconds: 200_000)
            XCTAssertEqual(winners.current, 1)
        }
    }

    func testManyConcurrentResumesHaveOneWinner() async {
        let winners = LockedValue(0)
        _ = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            let once = OneShotContinuation(continuation)
            DispatchQueue.concurrentPerform(iterations: 64) { index in
                if once.resume(returning: index) { winners.withLock { $0 += 1 } }
            }
        }
        XCTAssertEqual(winners.current, 1)
    }
}
