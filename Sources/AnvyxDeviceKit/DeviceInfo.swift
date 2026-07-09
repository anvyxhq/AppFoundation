//
//  DeviceInfo.swift
//  DeviceKit
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

/// Disk-space queries via modern `URLResourceValues` (the values Apple recommends
/// over the deprecated `NSFileSystem` attributes).
public enum DeviceStorage {
    private static var homeURL: URL { URL(fileURLWithPath: NSHomeDirectory()) }

    /// Total volume capacity in bytes.
    public static var totalCapacity: Int64? {
        value(for: .volumeTotalCapacityKey).map(Int64.init)
    }

    /// Space available for important resources (the user-facing "free space").
    public static var availableCapacityForImportantUsage: Int64? {
        try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }

    /// Space available for opportunistic, non-urgent resources.
    public static var availableCapacityForOpportunisticUsage: Int64? {
        try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey])
            .volumeAvailableCapacityForOpportunisticUsage
    }

    private static func value(for key: URLResourceKey) -> Int? {
        (try? homeURL.resourceValues(forKeys: [key]))?.allValues[key] as? Int
    }
}

#if canImport(UIKit)
import UIKit

/// Display metrics. `@MainActor` because `UIScreen` is main-actor isolated.
@MainActor
public enum DeviceScreen {
    public static var scale: CGFloat { UIScreen.main.scale }
    public static var nativeBounds: CGRect { UIScreen.main.nativeBounds }
    public static var bounds: CGRect { UIScreen.main.bounds }

    /// Screen brightness in `0...1`.
    public static var brightness: Double { Double(UIScreen.main.brightness) }
}
#endif

#if canImport(LocalAuthentication)
import LocalAuthentication

/// Which biometric sensor the device offers (if any).
public enum DeviceBiometrics {
    public enum Kind: String, Sendable {
        case none, touchID, faceID, opticID
    }

    public static var available: Kind {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .none
        }
        switch context.biometryType {
        case .touchID: return .touchID
        case .faceID:  return .faceID
        case .opticID: return .opticID
        case .none:    return .none
        @unknown default: return .none
        }
    }
}
#endif
