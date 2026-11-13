//
//  ScreenBrightnessTests.swift
//  DeviceKit
//
//  Created by AnhPT on 13/11/2026.
//

#if canImport(UIKit)
import XCTest
@testable import AnvyxDeviceKit

@MainActor
private final class FakeScreen {
    var level: Double
    private(set) var writes: [Double] = []

    init(level: Double) { self.level = level }

    func write(_ newLevel: Double) {
        level = newLevel
        writes.append(newLevel)
    }
}

@MainActor
final class ScreenBrightnessTests: XCTestCase {
    private func make(level: Double = 0.4) -> (ScreenBrightness, FakeScreen) {
        let screen = FakeScreen(level: level)
        let brightness = ScreenBrightness(readLevel: { screen.level }, writeLevel: { screen.write($0) })
        return (brightness, screen)
    }

    func testBoostRaisesAndReleaseRestores() {
        let (brightness, screen) = make(level: 0.4)

        let token = brightness.boost()
        XCTAssertEqual(screen.level, 1)
        XCTAssertTrue(brightness.isBoosting)

        token.release()
        XCTAssertEqual(screen.level, 0.4)
        XCTAssertFalse(brightness.isBoosting)
    }

    func testRestoresOnlyWhenLastHolderReleases() {
        let (brightness, screen) = make(level: 0.3)

        let first = brightness.boost()
        let second = brightness.boost()
        XCTAssertEqual(brightness.holderCount, 2)

        first.release()
        XCTAssertEqual(screen.level, 1, "still held by the second token")

        second.release()
        XCTAssertEqual(screen.level, 0.3)
        XCTAssertEqual(brightness.holderCount, 0)
    }

    func testReleasingTwiceCountsOnce() {
        let (brightness, screen) = make(level: 0.3)
        let first = brightness.boost()
        let second = brightness.boost()

        first.release()
        first.release()
        XCTAssertEqual(brightness.holderCount, 1)
        XCTAssertEqual(screen.level, 1)

        second.release()
        XCTAssertEqual(screen.level, 0.3)
    }

    func testOriginalIsCapturedOnceNotFromBoostedLevel() {
        let (brightness, screen) = make(level: 0.2)
        let first = brightness.boost()
        let second = brightness.boost()   // screen already at 1 here
        second.release()
        first.release()
        XCTAssertEqual(screen.level, 0.2)
    }

    func testHighestRequestedLevelWins() {
        let (brightness, screen) = make(level: 0.1)
        let low = brightness.boost(to: 0.6)
        XCTAssertEqual(screen.level, 0.6)
        let high = brightness.boost(to: 0.9)
        XCTAssertEqual(screen.level, 0.9)

        high.release()
        XCTAssertEqual(screen.level, 0.6)
        low.release()
        XCTAssertEqual(screen.level, 0.1)
    }

    func testLevelIsClamped() {
        let (brightness, screen) = make(level: 0.5)
        let token = brightness.boost(to: 3)
        XCTAssertEqual(screen.level, 1)
        token.release()
    }

    func testReapplyWhileHeldThenRestoresPreBoostLevel() {
        let (brightness, screen) = make(level: 0.4)
        let token = brightness.boost()

        screen.level = 0.5      // changed behind our back (system / user)
        brightness.reapply()    // what brightness-change / did-become-active trigger
        XCTAssertEqual(screen.level, 1)

        token.release()
        XCTAssertEqual(screen.level, 0.4)
    }

    func testReapplyDoesNotRewriteAnAppliedLevel() {
        let (brightness, screen) = make(level: 0.4)
        let token = brightness.boost()
        XCTAssertEqual(screen.writes, [1])

        screen.level = 0.996    // rounded reading reported by the system
        brightness.reapply()
        brightness.reapply()
        XCTAssertEqual(screen.writes, [1], "must not loop on its own change notification")
        token.release()
    }

    func testReapplyWithoutHolderDoesNothing() {
        let (brightness, screen) = make(level: 0.4)
        brightness.reapply()
        let token = brightness.boost()
        token.release()
        screen.level = 0.7
        brightness.reapply()
        XCTAssertEqual(screen.level, 0.7)
    }

    func testBoostAgainAfterFullReleaseCapturesNewOriginal() {
        let (brightness, screen) = make(level: 0.4)
        brightness.boost().release()
        screen.level = 0.8
        let token = brightness.boost()
        token.release()
        XCTAssertEqual(screen.level, 0.8)
    }

    func testDroppedTokenReleasesItsBoost() async {
        let (brightness, screen) = make(level: 0.4)
        do {
            let token = brightness.boost()
            XCTAssertEqual(screen.level, 1)
            _ = token
        }
        for _ in 0..<1_000 where brightness.isBoosting {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertFalse(brightness.isBoosting)
        XCTAssertEqual(screen.level, 0.4)
    }
}
#endif
