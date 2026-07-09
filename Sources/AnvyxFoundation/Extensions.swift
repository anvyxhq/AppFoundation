//
//  Extensions.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

// MARK: - Collection

public extension Collection {
    /// Returns the element at `index` when it is within bounds, otherwise `nil`.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - String

public extension String {
    /// Trimmed of leading/trailing whitespace and newlines.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `true` when the string is empty after trimming.
    var isBlank: Bool { trimmed.isEmpty }

    /// Naive but practical email validation.
    var isValidEmail: Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Optional String

public extension Optional where Wrapped == String {
    /// `true` when the optional is nil or blank.
    var isNilOrBlank: Bool {
        self?.isBlank ?? true
    }
}

// MARK: - Bundle

public extension Bundle {
    /// Marketing version, e.g. "1.2.0".
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Build number, e.g. "42".
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// Display name shown under the icon.
    var displayName: String {
        infoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleName"] as? String
            ?? "App"
    }
}
