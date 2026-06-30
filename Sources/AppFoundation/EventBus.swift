//
//  EventBus.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Combine
import Foundation

/// A typed, Combine-based event bus — a clean replacement for closure/observer
/// lists. Producers `send`, consumers subscribe to `publisher`.
///
/// ```swift
/// enum AppEvent { case loggedOut, purchased }
/// let bus = EventBus<AppEvent>()
///
/// bus.publisher
///     .filter { $0 == .loggedOut }
///     .sink { _ in router.popToRoot() }
///     .store(in: &cancellables)
///
/// bus.send(.loggedOut)
/// ```
@MainActor
public final class EventBus<Event: Sendable> {
    private let subject = PassthroughSubject<Event, Never>()

    public init() {}

    /// Stream of all events. Use Combine operators (`filter`, `debounce`, …) downstream.
    public var publisher: AnyPublisher<Event, Never> {
        subject.eraseToAnyPublisher()
    }

    public func send(_ event: Event) {
        subject.send(event)
    }
}
