//
//  AppTheme.swift
//  AnvyxFoundation
//
//  A minimal design-token base for an app's fonts and colours. It ships sensible system defaults
//  so any view works out of the box; each app *redefines* its own `AppTheme` and injects it with
//  `.appTheme(_:)`, then views read `@Environment(\.appTheme)`.
//

import SwiftUI
import UIKit

public struct AppFonts: Sendable {
    public var largeTitle: Font
    public var title: Font
    public var headline: Font
    public var body: Font
    public var callout: Font
    public var caption: Font

    public init(
        largeTitle: Font = .largeTitle.weight(.bold),
        title: Font = .title3.weight(.semibold),
        headline: Font = .headline,
        body: Font = .body,
        callout: Font = .callout,
        caption: Font = .caption
    ) {
        self.largeTitle = largeTitle
        self.title = title
        self.headline = headline
        self.body = body
        self.callout = callout
        self.caption = caption
    }
}

public struct AppColors: Sendable {
    public var accent: Color
    public var background: Color
    public var surface: Color
    public var primaryText: Color
    public var secondaryText: Color
    public var separator: Color

    public init(
        accent: Color = .accentColor,
        background: Color = Color(uiColor: .systemGroupedBackground),
        surface: Color = Color(uiColor: .secondarySystemGroupedBackground),
        primaryText: Color = .primary,
        secondaryText: Color = .secondary,
        separator: Color = Color(uiColor: .separator)
    ) {
        self.accent = accent
        self.background = background
        self.surface = surface
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.separator = separator
    }
}

public struct AppTheme: Sendable {
    public var fonts: AppFonts
    public var colors: AppColors

    public init(fonts: AppFonts = AppFonts(), colors: AppColors = AppColors()) {
        self.fonts = fonts
        self.colors = colors
    }

    /// System defaults — apps override this with their own brand theme.
    public static let `default` = AppTheme()
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.default
}

public extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

public extension View {
    /// Inject an app-wide theme; descendants read it via `@Environment(\.appTheme)`.
    func appTheme(_ theme: AppTheme) -> some View { environment(\.appTheme, theme) }
}
