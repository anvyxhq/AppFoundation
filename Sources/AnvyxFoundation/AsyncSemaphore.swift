//
//  AsyncSemaphore.swift
//  AppFoundation
//
//  Created by AnhPT on 10/07/2026.
//

/// An `async`/`await`-native counting semaphore — bound concurrency without ever
/// blocking a thread (unlike `DispatchSemaphore`, which must not be waited on from
/// Swift Concurrency).
///
/// ```swift
/// let limit = AsyncSemaphore(value: 4)   // at most 4 concurrent downloads
/// await withTaskGroup(of: Data.self) { group in
///     for url in urls {
///         group.addTask { await limit.withPermit { try await fetch(url) } }
///     }
/// }
/// ```
public actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// - Parameter value: the number of permits available (must be `>= 0`).
    public init(value: Int) {
        precondition(value >= 0, "AsyncSemaphore value must be non-negative")
        permits = value
    }

    /// Acquire a permit, suspending (FIFO) until one is available.
    public func wait() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Release a permit, resuming the longest-waiting caller if any.
    public func signal() {
        if waiters.isEmpty {
            permits += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

public extension AsyncSemaphore {
    /// Run `body` while holding one permit, releasing it afterward — even if `body`
    /// throws or is cancelled. Runs in the caller's context, not the actor's.
    nonisolated func withPermit<T>(_ body: () async throws -> T) async rethrows -> T {
        await wait()
        do {
            let value = try await body()
            await signal()
            return value
        } catch {
            await signal()
            throw error
        }
    }
}
