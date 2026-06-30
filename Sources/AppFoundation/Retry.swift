//
//  Retry.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

/// Controls how `withRetry` re-attempts a failing operation.
public struct RetryPolicy: Sendable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var multiplier: Double
    public var maxDelay: TimeInterval
    public var jitter: Double

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5,
        multiplier: Double = 2.0,
        maxDelay: TimeInterval = 10,
        jitter: Double = 0.2
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = baseDelay
        self.multiplier = multiplier
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    public static let `default` = RetryPolicy()

    /// Delay before the attempt at `attemptIndex` (0-based), with exponential
    /// backoff and randomized jitter.
    func delay(forAttempt attemptIndex: Int) -> TimeInterval {
        let exponential = baseDelay * pow(multiplier, Double(attemptIndex))
        let capped = min(exponential, maxDelay)
        let spread = capped * jitter
        return capped + Double.random(in: -spread...spread)
    }
}

/// Runs `operation`, retrying on thrown errors per `policy`. `shouldRetry` lets
/// you skip retries for non-transient errors (e.g. 4xx).
public func withRetry<T: Sendable>(
    _ policy: RetryPolicy = .default,
    shouldRetry: @Sendable (Error) -> Bool = { _ in true },
    operation: @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error?
    for attempt in 0..<policy.maxAttempts {
        do {
            return try await operation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            lastError = error
            let isLast = attempt == policy.maxAttempts - 1
            guard !isLast, shouldRetry(error) else { break }
            let delay = max(0, policy.delay(forAttempt: attempt))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
    throw lastError ?? CancellationError()
}
