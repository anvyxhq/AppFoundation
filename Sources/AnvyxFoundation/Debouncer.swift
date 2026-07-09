//
//  Debouncer.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

/// Coalesces rapid calls, running the latest work only after a quiet interval.
/// Backed by Swift Concurrency — cancel-safe and actor-isolated.
///
/// ```swift
/// let debouncer = Debouncer(delay: .milliseconds(300))
/// func searchChanged(_ q: String) {
///     Task { await debouncer.run { await viewModel.search(q) } }
/// }
/// ```
public actor Debouncer {
    private let delay: Duration
    private var task: Task<Void, Never>?

    public init(delay: Duration) {
        self.delay = delay
    }

    public func run(_ operation: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}

/// Ensures work runs at most once per interval, ignoring calls in between.
public actor Throttler {
    private let interval: Duration
    private var lastRun: ContinuousClock.Instant?
    private let clock = ContinuousClock()

    public init(interval: Duration) {
        self.interval = interval
    }

    @discardableResult
    public func run(_ operation: @Sendable () async -> Void) async -> Bool {
        let now = clock.now
        if let lastRun, now - lastRun < interval { return false }
        lastRun = now
        await operation()
        return true
    }
}
