# ``AnvyxFoundation``

Foundational utilities for Anvyx apps: storage, concurrency primitives, caching,
logging, and small building blocks — all `Sendable` and Swift-6-ready.

## Overview

AnvyxFoundation is the dependency-free base layer every other Anvyx package builds
on. It gathers the small, reusable pieces an app needs before any feature code:
type-safe defaults, async primitives, a keychain wrapper, an event bus, and more.

```swift
@UserDefault("hasOnboarded", default: false) var hasOnboarded: Bool

let limit = AsyncSemaphore(value: 4)
await limit.withPermit { try await upload(file) }

let result = try await withRetry(.default) { try await api.fetch() }
```

## Topics

### Storage
- ``UserDefault``
- ``CodableUserDefault``
- ``Keychain``
- ``MemoryCache``

### Concurrency
- ``AsyncSemaphore``
- ``TaskQueue``
- ``Debouncer``
- ``Throttler``
- ``Lock``
- ``LockedValue``
- ``RetryPolicy``

### Events & State
- ``EventBus``
- ``AsyncEventBus``
- ``NetworkMonitor``
- ``Loadable``

### Diagnostics & Feedback
- ``AppLog``
- ``PerfTrace``
- ``Haptics``
