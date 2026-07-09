//
//  Lock.swift
//  AppFoundation
//
//  Created by AnhPT on 09/07/2026.
//

import Foundation
import os

/// A lightweight non-recursive lock backed by `os_unfair_lock`.
///
/// Prefer isolating state in an `actor` for async code. Reach for `Lock` only
/// for fast, synchronous critical sections in non-async contexts.
public final class Lock: @unchecked Sendable {
    private let unfairLock: os_unfair_lock_t

    public init() {
        unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    public func lock() {
        os_unfair_lock_lock(unfairLock)
    }

    public func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }

    /// Run `body` while holding the lock.
    @discardableResult
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(unfairLock)
        defer { os_unfair_lock_unlock(unfairLock) }
        return try body()
    }
}

/// A thread-safe box around a value, guarded by a `Lock`.
///
/// The synchronous counterpart to isolating state in an `actor`, for use in
/// non-async code. Comparable to `NIOLockedValueBox` or Point-Free's
/// `LockIsolated`.
public final class LockedValue<Value>: @unchecked Sendable {
    private let lock = Lock()
    private var value: Value

    public init(_ value: Value) {
        self.value = value
    }

    /// Access — and optionally mutate — the protected value while holding the lock.
    @discardableResult
    public func withLock<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        try lock.withLock { try body(&value) }
    }

    /// A snapshot of the current value.
    public var current: Value {
        lock.withLock { value }
    }

    /// Replace the protected value.
    public func set(_ newValue: Value) {
        lock.withLock { value = newValue }
    }
}
