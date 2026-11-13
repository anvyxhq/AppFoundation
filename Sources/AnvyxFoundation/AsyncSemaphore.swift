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
    /// FIFO queue. A waiter is resumed with `true` once it owns a permit, or with
    /// `false` when it was cancelled before getting one.
    private var waiters: [(id: UInt64, continuation: CheckedContinuation<Bool, Never>)] = []
    private var nextWaiterID: UInt64 = 0

    /// - Parameter value: the number of permits available (must be `>= 0`).
    public init(value: Int) {
        precondition(value >= 0, "AsyncSemaphore value must be non-negative")
        permits = value
    }

    /// Permits that can be acquired right now without suspending.
    var availablePermits: Int { permits }

    /// Callers currently suspended in ``wait()`` or ``waitUnlessCancelled()``.
    var waiterCount: Int { waiters.count }

    /// Acquire a permit, suspending (FIFO) until one is available.
    ///
    /// This variant ignores task cancellation: a cancelled caller keeps waiting
    /// until it is signaled. Use ``waitUnlessCancelled()`` when the wait must end
    /// as soon as the task is cancelled.
    public func wait() async {
        if permits > 0 {
            permits -= 1
            return
        }
        _ = await withCheckedContinuation { enqueue($0) }
    }

    /// Acquire a permit, suspending (FIFO) until one is available or the current
    /// task is cancelled.
    ///
    /// A cancelled caller leaves the queue at once and takes no permit, so later
    /// waiters are not held up behind it.
    ///
    /// - Throws: `CancellationError` if the task is (or becomes) cancelled before
    ///   a permit is acquired. When this throws, do **not** call ``signal()``.
    public func waitUnlessCancelled() async throws {
        try Task.checkCancellation()
        if permits > 0 {
            permits -= 1
            return
        }
        let id = nextWaiterID
        nextWaiterID &+= 1
        let acquired = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                // Cancelled between the check above and here: never enter the queue.
                if Task.isCancelled {
                    continuation.resume(returning: false)
                } else {
                    enqueue(continuation, id: id)
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
        if !acquired { throw CancellationError() }
    }

    /// Release a permit, resuming the longest-waiting caller if any.
    public func signal() {
        if waiters.isEmpty {
            permits += 1
        } else {
            waiters.removeFirst().continuation.resume(returning: true)
        }
    }

    private func enqueue(_ continuation: CheckedContinuation<Bool, Never>, id: UInt64? = nil) {
        let waiterID: UInt64
        if let id {
            waiterID = id
        } else {
            waiterID = nextWaiterID
            nextWaiterID &+= 1
        }
        waiters.append((waiterID, continuation))
    }

    /// Drop a cancelled waiter. A no-op when it already got its permit.
    private func cancelWaiter(_ id: UInt64) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(returning: false)
    }
}

public extension AsyncSemaphore {
    /// Run `body` while holding one permit, releasing it afterward — even if `body`
    /// throws or is cancelled. Runs in the caller's context, not the actor's.
    ///
    /// Waiting for the permit ignores cancellation; see
    /// ``withPermitUnlessCancelled(_:)`` for the cancellation-aware form.
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

    /// Like ``withPermit(_:)``, but stops waiting when the task is cancelled:
    /// `body` is then never run and `CancellationError` is thrown.
    nonisolated func withPermitUnlessCancelled<T>(_ body: () async throws -> T) async throws -> T {
        try await waitUnlessCancelled()
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
