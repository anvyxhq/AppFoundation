//
//  Lock.swift
//  AppFoundation
//
//  Created by AnhPT on 09/07/2026.
//

import Foundation
import os

/// A lightweight non-recursive lock backed by `OSAllocatedUnfairLock`.
///
/// Prefer isolating state in an `actor` for async code. Reach for `Lock` only
/// for fast, synchronous critical sections in non-async contexts.
///
/// `Sendable` (not `@unchecked`): all synchronization lives inside the
/// `OSAllocatedUnfairLock` value, which Apple already audits as `Sendable`, so
/// this wrapper is safe by construction.
public final class Lock: Sendable {
    private let unfairLock = OSAllocatedUnfairLock()

    public init() {}

    public func lock() {
        unfairLock.lock()
    }

    public func unlock() {
        unfairLock.unlock()
    }

    /// Run `body` while holding the lock.
    @discardableResult
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        unfairLock.lock()
        defer { unfairLock.unlock() }
        return try body()
    }
}

/// A thread-safe box around a value, guarded by a `Lock`.
///
/// The synchronous counterpart to isolating state in an `actor`, for use in
/// non-async code. Comparable to `NIOLockedValueBox` or Point-Free's
/// `LockIsolated`.
///
/// `Sendable` (not `@unchecked`): the protected `Value` is stored inside an
/// `OSAllocatedUnfairLock`, which is unconditionally `Sendable`. Access goes
/// through `withLockUnchecked` so a non-`Sendable` `Value` is still supported —
/// the lock guarantees exclusive access.
public final class LockedValue<Value>: Sendable {
    private let storage: OSAllocatedUnfairLock<Value>

    public init(_ value: Value) {
        storage = OSAllocatedUnfairLock(uncheckedState: value)
    }

    /// Access — and optionally mutate — the protected value while holding the lock.
    @discardableResult
    public func withLock<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        try storage.withLockUnchecked { try body(&$0) }
    }

    /// A snapshot of the current value.
    public var current: Value {
        storage.withLockUnchecked { $0 }
    }

    /// Replace the protected value.
    public func set(_ newValue: Value) {
        storage.withLockUnchecked { $0 = newValue }
    }
}
