//
//  OneShotContinuation.swift
//  AppFoundation
//
//  Created by AnhPT on 13/11/2026.
//

/// A `CheckedContinuation` that can be resumed from several places but only ever
/// resumes once — the first `resume` wins, every later one is ignored.
///
/// Bridging a callback API that may report more than once (a success *and* a
/// timeout, a delegate plus a completion handler, callbacks arriving on
/// different queues) would otherwise trap on the second resume. A captured
/// `var didResume` flag is not an option either: it is a data race and is
/// rejected inside `@Sendable` closures.
///
/// ```swift
/// let image = try await withCheckedThrowingContinuation { continuation in
///     let once = OneShotContinuation(continuation)
///     camera.capture(
///         onPhoto: { once.resume(returning: $0) },
///         onError: { once.resume(throwing: $0) }
///     )
///     timeout.schedule { once.resume(throwing: CaptureError.timedOut) }
/// }
/// ```
///
/// `Sendable`: the continuation lives in a ``LockedValue``, and is taken out
/// under the lock before being resumed outside of it.
public final class OneShotContinuation<T, E: Error>: Sendable {
    private let continuation: LockedValue<CheckedContinuation<T, E>?>

    public init(_ continuation: CheckedContinuation<T, E>) {
        self.continuation = LockedValue(continuation)
    }

    /// `true` once the continuation has been resumed.
    public var isResumed: Bool {
        continuation.withLock { $0 == nil }
    }

    /// Resume with a value.
    /// - Returns: `true` if this call resumed the continuation, `false` if it had
    ///   already been resumed (the value is then dropped).
    @discardableResult
    public func resume(returning value: sending T) -> Bool {
        guard let continuation = take() else { return false }
        continuation.resume(returning: value)
        return true
    }

    /// Resume by throwing `error`.
    /// - Returns: `true` if this call resumed the continuation, `false` if it had
    ///   already been resumed.
    @discardableResult
    public func resume(throwing error: E) -> Bool {
        guard let continuation = take() else { return false }
        continuation.resume(throwing: error)
        return true
    }

    /// Resume with a `Result`.
    /// - Returns: `true` if this call resumed the continuation, `false` if it had
    ///   already been resumed.
    @discardableResult
    public func resume(with result: sending Result<T, E>) -> Bool {
        guard let continuation = take() else { return false }
        continuation.resume(with: result)
        return true
    }

    private func take() -> CheckedContinuation<T, E>? {
        continuation.withLock { stored in
            defer { stored = nil }
            return stored
        }
    }
}

public extension OneShotContinuation where T == Void {
    /// Resume a `Void` continuation.
    @discardableResult
    func resume() -> Bool {
        resume(returning: ())
    }
}
