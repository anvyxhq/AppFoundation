//
//  Loadable.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

/// The lifecycle of an async value — the state primitive a SwiftUI ViewModel
/// exposes so the View can render idle / spinner / content / error uniformly.
///
/// ```swift
/// @Observable final class FeedModel {
///     private(set) var posts: Loadable<[Post]> = .idle
///     func load() async { posts = await Loadable { try await repo.posts() } }
/// }
/// ```
public enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(Error)

    public var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    public var error: Error? {
        if case .failed(let error) = self { return error }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var isLoaded: Bool { value != nil }

    /// Transform the loaded value, preserving the surrounding state.
    public func map<T>(_ transform: (Value) -> T) -> Loadable<T> {
        switch self {
        case .idle:                return .idle
        case .loading:             return .loading
        case .loaded(let value):   return .loaded(transform(value))
        case .failed(let error):   return .failed(error)
        }
    }
}

public extension Loadable {
    /// Run async work and capture the result as `.loaded` / `.failed`.
    init(_ operation: () async throws -> Value) async {
        do {
            self = .loaded(try await operation())
        } catch {
            self = .failed(error)
        }
    }
}

extension Loadable: Equatable where Value: Equatable {
    public static func == (lhs: Loadable, rhs: Loadable) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case let (.loaded(a), .loaded(b)):
            return a == b
        case let (.failed(a), .failed(b)):
            return String(describing: a) == String(describing: b)
        default:
            return false
        }
    }
}
