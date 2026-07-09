# AppFoundation

Foundational utilities shared across iOS apps — logging, reachability, persistence, and everyday extensions. Zero third-party dependencies.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/iOS-17%2B-blue.svg)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

## Features

- **`AppLog`** — category-based logging on top of `os.Logger`.
- **`NetworkMonitor`** — observable reachability (`NWPathMonitor`) for SwiftUI.
- **`@UserDefault` / `@CodableUserDefault`** — property wrappers for `UserDefaults`.
- **`Keychain`** — a minimal, type-safe generic-password store.
- **Extensions** — safe collection subscript, `String` helpers, `Bundle` version info.

## Installation

```swift
.package(url: "https://github.com/anvyxhq/AppFoundation.git", branch: "main")
```

## Usage

```swift
import AnvyxFoundation

// Logging
AppLog.app.debug("Launched")

// Persistence
enum Settings {
    @UserDefault("hasOnboarded", default: false) static var hasOnboarded: Bool
}

// Keychain
let keychain = Keychain()
keychain.set("secret-token", for: "authToken")
let token = keychain.string(for: "authToken")

// Reachability (SwiftUI, Observation framework)
@State private var monitor = NetworkMonitor.shared

// Retry with exponential backoff
let data = try await withRetry { try await fetch() }

// Combine event bus
let bus = EventBus<AppEvent>()
bus.publisher.sink { handle($0) }.store(in: &cancellables)
```

## Requirements

- iOS 17+ · Swift 5.9+

## License

MIT
