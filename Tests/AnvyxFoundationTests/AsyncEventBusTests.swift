//
//  AsyncEventBusTests.swift
//  AppFoundation
//
//  Created by AnhPT on 10/07/2026.
//

import XCTest
@testable import AnvyxFoundation

final class AsyncEventBusTests: XCTestCase {

    enum Event: Sendable, Equatable { case a, b }

    func testDeliversEventsToSubscriber() async {
        let bus = AsyncEventBus<Event>()
        let stream = await bus.events()

        let received = Task { await stream.prefix(2).reduce(into: []) { $0.append($1) } }
        // Let the consumer start iterating before sending.
        await Task.yield()
        await bus.send(.a)
        await bus.send(.b)

        let events = await received.value
        XCTAssertEqual(events, [.a, .b])
    }

    func testBroadcastsToMultipleSubscribers() async {
        let bus = AsyncEventBus<Event>()
        let s1 = await bus.events()
        let s2 = await bus.events()

        let first = Task { await s1.first { _ in true } }
        let second = Task { await s2.first { _ in true } }
        await Task.yield()
        await bus.send(.a)

        let r1 = await first.value
        let r2 = await second.value
        XCTAssertEqual(r1, .a)
        XCTAssertEqual(r2, .a)
    }
}
