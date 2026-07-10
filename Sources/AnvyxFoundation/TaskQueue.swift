//
//  TaskQueue.swift
//  AppFoundation
//
//  Created by AnhPT on 10/07/2026.
//

/// Runs async operations with a bounded number in flight — a small ergonomic
/// layer over ``AsyncSemaphore``. Use `maxConcurrent: 1` for a serial queue that
/// preserves submission order.
///
/// ```swift
/// let queue = TaskQueue(maxConcurrent: 4)
/// let results = try await withThrowingTaskGroup(of: Data.self) { group in
///     for url in urls {
///         group.addTask { try await queue.run { try await fetch(url) } }
///     }
///     return try await group.reduce(into: []) { $0.append($1) }
/// }
/// ```
public struct TaskQueue: Sendable {
    private let semaphore: AsyncSemaphore

    /// - Parameter maxConcurrent: the most operations allowed to run at once (`>= 1`).
    public init(maxConcurrent: Int) {
        precondition(maxConcurrent >= 1, "TaskQueue needs at least one concurrent slot")
        semaphore = AsyncSemaphore(value: maxConcurrent)
    }

    /// Run `operation` once a slot is free, returning its result. The slot is
    /// released even if `operation` throws or is cancelled.
    public func run<T>(_ operation: () async throws -> T) async rethrows -> T {
        try await semaphore.withPermit(operation)
    }
}
