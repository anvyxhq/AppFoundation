//
//  DeviceLayout.swift
//  DeviceKit
//
//  Created by AnhPT on 03/07/2026.
//

import UIKit

public extension DeviceScreen {
    /// Logical screen width / height (points). Main-actor because it reads
    /// `UIScreen.main`, which is main-actor isolated.
    @MainActor static var width: CGFloat { UIScreen.main.bounds.width }
    @MainActor static var height: CGFloat { UIScreen.main.bounds.height }
}

/// Coarse device size class based on the screen's short edge.
public enum DeviceClass: Sendable {
    case compact   // small phones (SE)
    case regular   // standard phones
    case large     // Max phones / iPad

    @MainActor
    public static var current: DeviceClass {
        let shortEdge = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        switch shortEdge {
        case ..<375: return .compact
        case ..<430: return .regular
        default: return .large
        }
    }
}

/// Runtime window/layout metrics read from the active window scene (avoids the
/// deprecated `UIApplication.keyWindow`). Main-actor because it touches UIKit.
@MainActor
public enum AppWindow {

    /// The active foreground key window (falls back to any scene's key window).
    public static var key: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let active = scenes.first(where: { $0.activationState == .foregroundActive }),
           let window = active.windows.first(where: \.isKeyWindow) ?? active.keyWindow {
            return window
        }
        return scenes.compactMap { $0.keyWindow }.first
    }

    /// The current status-bar height from the active scene.
    public static var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.statusBarManager?.statusBarFrame.height }
            .first ?? 0
    }

    /// Safe-area insets of the key window.
    public static var safeAreaInsets: UIEdgeInsets { key?.safeAreaInsets ?? .zero }

    /// The visible top-most view controller (walks presented / nav / tab).
    public static var topViewController: UIViewController? {
        guard var top = key?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        if let nav = top as? UINavigationController, let visible = nav.visibleViewController { return visible }
        if let tab = top as? UITabBarController, let selected = tab.selectedViewController { return selected }
        return top
    }

    /// Height of the top-most navigation bar (or the standard 44pt fallback).
    public static var navigationBarHeight: CGFloat {
        topViewController?.navigationController?.navigationBar.frame.height ?? 44
    }
}

public extension Comparable {
    /// Constrain a value to a closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
