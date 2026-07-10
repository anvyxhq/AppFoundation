//
//  Logger+Anvyx.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import OSLog

/// Lightweight, category-based logging on top of `os.Logger`.
///
/// ```swift
/// let log = AppLog.network
/// log.debug("Fetching \(url)")
/// ```
public enum AppLog {
    // Thread-safe backing store so `subsystem` is not nonisolated global mutable
    // state under strict concurrency. Loggers are computed (not stored) so a
    // launch-time override actually applies to every logger created afterwards.
    private static let _subsystem = LockedValue(Bundle.main.bundleIdentifier ?? "AnvyxKit")

    /// Override once at launch to group all logs under your app's bundle id.
    public static var subsystem: String {
        get { _subsystem.current }
        set { _subsystem.set(newValue) }
    }

    public static var app: Logger      { Logger(subsystem: subsystem, category: "app") }
    public static var network: Logger  { Logger(subsystem: subsystem, category: "network") }
    public static var purchase: Logger { Logger(subsystem: subsystem, category: "purchase") }
    public static var ads: Logger      { Logger(subsystem: subsystem, category: "ads") }
    public static var ui: Logger       { Logger(subsystem: subsystem, category: "ui") }

    /// Make a logger for a custom category.
    public static func category(_ name: String) -> Logger {
        Logger(subsystem: subsystem, category: name)
    }
}
