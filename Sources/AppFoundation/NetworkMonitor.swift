//
//  NetworkMonitor.swift
//  AppFoundation
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation
import Network
import Combine

/// Observable reachability monitor backed by `NWPathMonitor`.
///
/// ```swift
/// @StateObject private var monitor = NetworkMonitor.shared
/// if !monitor.isConnected { showOfflineBanner() }
/// ```
@MainActor
public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()

    public enum Connection: Sendable {
        case wifi, cellular, wired, other, none
    }

    @Published public private(set) var isConnected: Bool = true
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var connection: Connection = .other

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.anvora.networkmonitor")

    public init() {
        start()
    }

    private func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func apply(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        if path.usesInterfaceType(.wifi) {
            connection = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connection = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connection = .wired
        } else {
            connection = isConnected ? .other : .none
        }
    }

    deinit {
        monitor.cancel()
    }
}
