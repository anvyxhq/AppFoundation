//
//  Device.swift
//  DeviceKit
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

/// A modern, value-type description of the running device — a `Sendable`
/// replacement for `UIDevice` with hardware identification baked in.
///
/// ```swift
/// let device = Device.current
/// print(device.name)          // "iPhone 15 Pro"
/// print(device.family)        // .iPhone
/// if device.hasDynamicIsland { ... }
/// ```
public struct Device: Sendable, Equatable, Identifiable {
    /// Raw hardware identifier, e.g. `"iPhone16,1"`.
    public let identifier: String

    public var id: String { identifier }

    public init(identifier: String) {
        self.identifier = identifier
    }

    /// The device the app is currently running on (resolved once).
    public static let current = Device(identifier: Self.machineIdentifier)

    /// Marketing name, e.g. `"iPhone 15 Pro"`. Falls back to the raw identifier
    /// for hardware released after this package was built.
    public var name: String {
        DeviceModel.marketingName(for: identifier)
    }

    public enum Family: String, Sendable {
        case iPhone, iPad, iPod, mac, vision, unknown
    }

    public var family: Family {
        switch identifier {
        case let id where id.hasPrefix("iPhone"):     return .iPhone
        case let id where id.hasPrefix("iPad"):       return .iPad
        case let id where id.hasPrefix("iPod"):       return .iPod
        case let id where id.hasPrefix("Mac"),
             let id where id.hasPrefix("arm64"):      return .mac
        case let id where id.hasPrefix("RealityDevice"): return .vision
        default:                                       return .unknown
        }
    }

    public var isPhone: Bool { family == .iPhone }
    public var isPad: Bool   { family == .iPad }
    public var isPod: Bool   { family == .iPod }

    public var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    /// `true` when this device has a Dynamic Island.
    public var hasDynamicIsland: Bool {
        DeviceModel.dynamicIslandIdentifiers.contains(identifier)
    }

    /// `true` for notch devices (Face ID, no Dynamic Island).
    public var hasNotch: Bool {
        DeviceModel.notchIdentifiers.contains(identifier)
    }

    /// Membership test against a group of devices.
    public func isOneOf(_ devices: [Device]) -> Bool {
        devices.contains(self)
    }

    // MARK: - Hardware identifier

    private static var machineIdentifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafeBytes(of: &systemInfo.machine) { raw -> String in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
        return machine
        #endif
    }
}
