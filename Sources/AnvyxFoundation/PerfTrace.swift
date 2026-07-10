//
//  PerfTrace.swift
//  AppFoundation
//
//  Created by AnhPT on 10/07/2026.
//

import OSLog

/// Lightweight performance tracing via `OSSignposter`. Intervals and events show
/// up in Instruments' **Points of Interest** track and can be inspected on the
/// `os_signpost` timeline — effectively free when no tool is attached.
///
/// ```swift
/// // Measure a block (sync or async); the result flows through:
/// let image = PerfTrace.interval("downsample") { downsample(data) }
/// let page  = await PerfTrace.interval("render") { await render(pdf) }
///
/// // Or bracket manually across suspension points:
/// let token = PerfTrace.begin("upload")
/// defer { PerfTrace.end("upload", token) }
///
/// // One-shot marker:
/// PerfTrace.event("cache-miss")
/// ```
///
/// Names are `StaticString` (a signpost requirement) so they must be literals.
public enum PerfTrace {

    /// Computed so a launch-time ``AppLog/subsystem`` override is honored.
    private static var signposter: OSSignposter {
        OSSignposter(logHandle: OSLog(subsystem: AppLog.subsystem, category: .pointsOfInterest))
    }

    /// Measure a synchronous block as a signpost interval; returns its result.
    @discardableResult
    public static func interval<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let poster = signposter
        let state = poster.beginInterval(name)
        defer { poster.endInterval(name, state) }
        return try body()
    }

    /// Measure an asynchronous block as a signpost interval; returns its result.
    @discardableResult
    public static func interval<T>(_ name: StaticString, _ body: () async throws -> T) async rethrows -> T {
        let poster = signposter
        let state = poster.beginInterval(name)
        defer { poster.endInterval(name, state) }
        return try await body()
    }

    /// Opaque handle tying a ``begin(_:)`` to its ``end(_:_:)``.
    public struct Token {
        fileprivate let name: StaticString
        fileprivate let state: OSSignpostIntervalState
    }

    /// Start an interval that ends later (e.g. across `await` boundaries).
    public static func begin(_ name: StaticString) -> Token {
        Token(name: name, state: signposter.beginInterval(name))
    }

    /// End an interval opened with ``begin(_:)``.
    public static func end(_ name: StaticString, _ token: Token) {
        signposter.endInterval(name, token.state)
    }

    /// Emit a one-shot event marker (a point, not an interval).
    public static func event(_ name: StaticString) {
        signposter.emitEvent(name)
    }
}
