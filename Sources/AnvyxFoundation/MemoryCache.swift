//
//  MemoryCache.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

/// A thread-safe in-memory cache with optional per-entry TTL, backed by `NSCache`
/// (so it evicts under memory pressure). Keys must be `Hashable`.
///
/// `@unchecked Sendable` is retained deliberately: the only stored property is an
/// `NSCache`, which Apple documents as thread-safe but does not (yet) declare
/// `Sendable`. All access goes through that internally-synchronized store, so
/// the wrapper is safe to share across actors.
public final class MemoryCache<Key: Hashable, Value>: @unchecked Sendable {
    private final class Entry {
        let value: Value
        let expiresAt: Date?
        init(value: Value, expiresAt: Date?) {
            self.value = value
            self.expiresAt = expiresAt
        }
        var isExpired: Bool {
            guard let expiresAt else { return false }
            return Date() > expiresAt
        }
    }

    private final class WrappedKey: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            (object as? WrappedKey)?.key == key
        }
    }

    private let storage = NSCache<WrappedKey, Entry>()

    public init(countLimit: Int = 0) {
        storage.countLimit = countLimit
    }

    public func value(for key: Key) -> Value? {
        guard let entry = storage.object(forKey: WrappedKey(key)) else { return nil }
        if entry.isExpired {
            remove(key)
            return nil
        }
        return entry.value
    }

    public func insert(_ value: Value, for key: Key, ttl: TimeInterval? = nil) {
        let expiresAt = ttl.map { Date().addingTimeInterval($0) }
        storage.setObject(Entry(value: value, expiresAt: expiresAt), forKey: WrappedKey(key))
    }

    public func remove(_ key: Key) {
        storage.removeObject(forKey: WrappedKey(key))
    }

    public func removeAll() {
        storage.removeAllObjects()
    }

    public subscript(key: Key) -> Value? {
        get { value(for: key) }
        set {
            if let newValue { insert(newValue, for: key) }
            else { remove(key) }
        }
    }
}
