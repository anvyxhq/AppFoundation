//
//  Logger+Anvora.swift
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
    /// Override once at launch to group all logs under your app's bundle id.
    public static var subsystem: String = Bundle.main.bundleIdentifier ?? "AnvoraKit"

    public static let app      = Logger(subsystem: subsystem, category: "app")
    public static let network  = Logger(subsystem: subsystem, category: "network")
    public static let purchase = Logger(subsystem: subsystem, category: "purchase")
    public static let ads      = Logger(subsystem: subsystem, category: "ads")
    public static let ui       = Logger(subsystem: subsystem, category: "ui")

    /// Make a logger for a custom category.
    public static func category(_ name: String) -> Logger {
        Logger(subsystem: subsystem, category: name)
    }
}
