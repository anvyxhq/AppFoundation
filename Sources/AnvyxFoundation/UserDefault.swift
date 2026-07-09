//
//  UserDefault.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

/// A property wrapper for plain values stored in `UserDefaults`.
///
/// ```swift
/// enum Settings {
///     @UserDefault("hasOnboarded", default: false) static var hasOnboarded: Bool
/// }
/// ```
@propertyWrapper
public struct UserDefault<Value> {
    private let key: String
    private let defaultValue: Value
    private let store: UserDefaults

    public init(_ key: String, default defaultValue: Value, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    public var wrappedValue: Value {
        get { store.object(forKey: key) as? Value ?? defaultValue }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                store.removeObject(forKey: key)
            } else {
                store.set(newValue, forKey: key)
            }
        }
    }
}

/// A property wrapper that persists any `Codable` value as JSON in `UserDefaults`.
@propertyWrapper
public struct CodableUserDefault<Value: Codable> {
    private let key: String
    private let defaultValue: Value
    private let store: UserDefaults

    public init(_ key: String, default defaultValue: Value, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    public var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return defaultValue }
            return value
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            store.set(data, forKey: key)
        }
    }
}

/// Lets the wrapper detect `nil` so it can clear the key instead of storing NSNull.
public protocol AnyOptional {
    var isNil: Bool { get }
}

extension Optional: AnyOptional {
    public var isNil: Bool { self == nil }
}
