//
//  ScreenBrightness.swift
//  DeviceKit
//
//  Created by AnhPT on 13/11/2026.
//

#if canImport(UIKit)
import UIKit

/// Temporarily raises the screen brightness — for capture and scanning screens
/// that need a bright display — and puts the previous level back afterwards.
///
/// Boosts are counted per holder: each ``boost(to:)`` call returns a ``Token``,
/// the screen stays boosted while at least one token is held, and the level from
/// before the first boost is restored when the last one is released. Nested or
/// overlapping screens therefore never restore too early or to a wrong level.
///
/// While a boost is held the level is applied again whenever the system reports
/// a brightness change or the app becomes active again.
///
/// ```swift
/// final class ScanViewController: UIViewController {
///     private var brightness: ScreenBrightness.Token?
///
///     override func viewDidAppear(_ animated: Bool) {
///         super.viewDidAppear(animated)
///         brightness = ScreenBrightness.shared.boost()
///     }
///
///     override func viewWillDisappear(_ animated: Bool) {
///         super.viewWillDisappear(animated)
///         brightness?.release()
///         brightness = nil
///     }
/// }
/// ```
@MainActor
public final class ScreenBrightness {
    /// The controller for the app's active screen.
    public static let shared = ScreenBrightness()

    /// One holder of a brightness boost. Keep it for as long as the boost is
    /// needed; call ``release()`` when done. A token that is deallocated without
    /// being released gives up its boost shortly afterwards.
    public final class Token: Sendable {
        private let id: UInt64
        private let owner: ScreenBrightness

        fileprivate init(id: UInt64, owner: ScreenBrightness) {
            self.id = id
            self.owner = owner
        }

        /// Give up this holder's boost. Releasing more than once has no effect.
        @MainActor
        public func release() {
            owner.release(id)
        }

        deinit {
            Task { @MainActor [owner, id] in owner.release(id) }
        }
    }

    private let readLevel: @MainActor () -> Double
    private let writeLevel: @MainActor (Double) -> Void
    private let observesSystemEvents: Bool

    private var holders: [UInt64: Double] = [:]
    private var nextID: UInt64 = 0
    private var originalLevel: Double?
    private var observers: [Task<Void, Never>] = []

    /// Readings closer than this to the target are treated as "already applied",
    /// so a rounded value reported by the system does not trigger another write.
    private static let tolerance = 0.01

    /// A controller for the app's active screen. Prefer ``shared`` so that every
    /// caller is counted together.
    public convenience init() {
        self.init(
            readLevel: { Double(DeviceScreen.current?.brightness ?? 0) },
            writeLevel: { DeviceScreen.current?.brightness = CGFloat($0) },
            observesSystemEvents: true
        )
    }

    /// Designated initializer with an injected brightness getter/setter, so the
    /// counting logic can run without a real screen.
    init(
        readLevel: @escaping @MainActor () -> Double,
        writeLevel: @escaping @MainActor (Double) -> Void,
        observesSystemEvents: Bool = false
    ) {
        self.readLevel = readLevel
        self.writeLevel = writeLevel
        self.observesSystemEvents = observesSystemEvents
    }

    deinit {
        observers.forEach { $0.cancel() }
    }

    /// `true` while at least one token is held.
    public var isBoosting: Bool { !holders.isEmpty }

    /// Number of tokens currently held.
    public var holderCount: Int { holders.count }

    /// Raise the screen brightness until the returned token is released.
    ///
    /// When several holders ask for different levels the highest one is applied.
    ///
    /// - Parameter level: the wanted brightness in `0...1` (clamped). Defaults to
    ///   full brightness.
    /// - Returns: the token that keeps the boost alive — store it; dropping it
    ///   ends the boost.
    public func boost(to level: Double = 1) -> Token {
        if holders.isEmpty {
            originalLevel = readLevel()
            startObserving()
        }
        let id = nextID
        nextID &+= 1
        holders[id] = min(max(level, 0), 1)
        reapply()
        return Token(id: id, owner: self)
    }

    /// Write the boosted level again if the screen has drifted away from it.
    /// Called on brightness-change and did-become-active; a no-op when nothing
    /// is held.
    func reapply() {
        guard let target = holders.values.max() else { return }
        guard abs(readLevel() - target) > Self.tolerance else { return }
        writeLevel(target)
    }

    private func release(_ id: UInt64) {
        guard holders.removeValue(forKey: id) != nil else { return }
        guard holders.isEmpty else {
            reapply()   // the remaining holders may want a lower level
            return
        }
        stopObserving()
        if let originalLevel {
            writeLevel(originalLevel)
        }
        originalLevel = nil
    }

    private func startObserving() {
        guard observesSystemEvents, observers.isEmpty else { return }
        for name in [UIScreen.brightnessDidChangeNotification, UIApplication.didBecomeActiveNotification] {
            observers.append(Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    guard let self else { break }
                    self.reapply()
                }
            })
        }
    }

    private func stopObserving() {
        observers.forEach { $0.cancel() }
        observers.removeAll()
    }
}
#endif
