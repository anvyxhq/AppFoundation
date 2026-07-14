//
//  AsyncEventBus.swift
//  AppFoundation
//
//  Created by AnhPT on 10/07/2026.
//

import Foundation

/// A typed event bus built on `AsyncStream` — the `async/await` counterpart to the
/// Combine-based ``EventBus``. Each subscriber gets its own stream and consumes
/// events with `for await`; dropping the stream unsubscribes automatically.
///
/// ```swift
/// enum AppEvent: Sendable { case loggedOut, purchased }
/// let bus = AsyncEventBus<AppEvent>()
///
/// Task {
///     for await event in await bus.events() where event == .loggedOut {
///         router.popToRoot()
///     }
/// }
///
/// await bus.send(.loggedOut)
/// ```
public actor AsyncEventBus<Event: Sendable> {
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    public init() {}

    /// Broadcast `event` to every current subscriber.
    public func send(_ event: Event) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    /// A new stream of events. Finishes (and unsubscribes) when the consumer stops
    /// iterating and the stream is deallocated.
    public func events() -> AsyncStream<Event> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    guard let self else { return }
                    await self.unsubscribe(id)
                }
            }
        }
    }

    /// Current subscriber count (useful in tests / diagnostics).
    public var subscriberCount: Int { continuations.count }

    private func unsubscribe(_ id: UUID) {
        continuations[id] = nil
    }
}
