# Changelog

All notable changes to this package are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking

- **Breaking:** Products and modules were renamed to `Anvyx*` (`AnvyxFoundation`, `AnvyxDeviceKit`) and the package now requires Swift 6.2 (Xcode 26). Update `.product(name:)` entries and `import` statements.
- **Breaking:** `AsyncSemaphore` waiters and `retry` now stop when their task is cancelled instead of continuing.

### Added

- Cover the iPhone 17 family and every iPadOS 17+ iPad
- Add AppTheme base tokens (fonts + colors) with environment injection
- AsyncEventBus and TaskQueue concurrency primitives
- AsyncSemaphore for bounded concurrency
- PerfTrace signpost helper for performance tracing
- Add Lock and LockedValue concurrency primitives

### Changed

- Update AppTheme.swift
- Update NetworkMonitor.swift
- UserDefault
- Keychain upgrade + cache/keychain/retry tests
- Rename module -> AnvyxFoundation; absorb DeviceKit as AnvyxDeviceKit

### Fixed

- Cancellation-safe semaphore and retry, safer keychain writes

## [2.1.0] - 2026-07-02

### Added

- Add Loadable<Value> async state primitive

## [2.0.2] - 2026-07-02

_No notable changes._

## [2.0.1] - 2026-07-02

_No notable changes._

## [2.0.0] - 2026-07-02

_No notable changes._

## [1.2.0] - 2026-07-01

### Added

- Adopt iOS 17 + Observation (@Observable); DesignSystem adds Typography/fonts

## [1.1.0] - 2026-07-01

### Added

- Add withRetry+backoff, Debouncer/Throttler, MemoryCache (TTL), Haptics, Combine EventBus

## [1.0.0] - 2026-07-01

### Changed

- Initial release (SwiftUI/async-await iOS base)
