//
//  DeviceMonitor.swift
//  DeviceKit
//
//  Created by AnhPT on 02/07/2026.
//

#if canImport(UIKit)
import UIKit
import Observation

/// Live device state — battery, power, thermal, and orientation — exposed through
/// the Observation framework (iOS 17+). Updates are driven by structured-
/// concurrency `NotificationCenter` async sequences rather than selectors/KVO.
@MainActor
@Observable
public final class DeviceMonitor {
    public static let shared = DeviceMonitor()

    public enum BatteryState: Sendable {
        case unknown, unplugged, charging, full
    }

    /// Battery charge in the range `0...1` (`0` when unknown).
    public private(set) var batteryLevel: Double = 0
    public private(set) var batteryState: BatteryState = .unknown
    public private(set) var isLowPowerMode: Bool = false
    public private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    public private(set) var orientation: UIDeviceOrientation = .unknown

    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    public init() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        device.beginGeneratingDeviceOrientationNotifications()
        refresh()
        observe()
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }

    /// Battery charge as a 0–100 integer.
    public var batteryPercentage: Int {
        max(0, Int((batteryLevel * 100).rounded()))
    }

    public var isCharging: Bool {
        batteryState == .charging || batteryState == .full
    }

    private func refresh() {
        let device = UIDevice.current
        batteryLevel = max(0, Double(device.batteryLevel))
        batteryState = Self.map(device.batteryState)
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
        orientation = device.orientation
    }

    private func observe() {
        stream(UIDevice.batteryLevelDidChangeNotification) { [weak self] in
            self?.batteryLevel = max(0, Double(UIDevice.current.batteryLevel))
        }
        stream(UIDevice.batteryStateDidChangeNotification) { [weak self] in
            self?.batteryState = Self.map(UIDevice.current.batteryState)
        }
        stream(.NSProcessInfoPowerStateDidChange) { [weak self] in
            self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        stream(ProcessInfo.thermalStateDidChangeNotification) { [weak self] in
            self?.thermalState = ProcessInfo.processInfo.thermalState
        }
        stream(UIDevice.orientationDidChangeNotification) { [weak self] in
            self?.orientation = UIDevice.current.orientation
        }
    }

    private func stream(_ name: Notification.Name, _ handler: @escaping @MainActor () -> Void) {
        let task = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: name) {
                guard self != nil else { break }
                handler()
            }
        }
        tasks.append(task)
    }

    private static func map(_ state: UIDevice.BatteryState) -> BatteryState {
        switch state {
        case .charging:  return .charging
        case .full:      return .full
        case .unplugged: return .unplugged
        case .unknown:   return .unknown
        @unknown default: return .unknown
        }
    }
}
#endif
