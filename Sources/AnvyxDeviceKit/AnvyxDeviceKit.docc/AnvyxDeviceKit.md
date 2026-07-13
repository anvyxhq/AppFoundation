# ``AnvyxDeviceKit``

A modern, value-type view of the running device: hardware identity, screen, storage,
battery/thermal state, biometrics, and window access.

## Overview

AnvyxDeviceKit replaces scattered `UIDevice`/`UIScreen` calls with `Sendable`
value types and an `@Observable` live monitor, so device state is easy to read and
reacts to change.

```swift
let device = Device.current
print(device.name, device.family)          // "iPhone 15 Pro", .iPhone
if device.hasDynamicIsland { … }

let monitor = DeviceMonitor.shared          // @Observable
if monitor.isLowPowerMode || monitor.thermalState == .serious { throttleWork() }
```

## Topics

### Device Identity
- ``Device``
- ``DeviceClass``

### Live State
- ``DeviceMonitor``

### Capabilities
- ``DeviceScreen``
- ``DeviceStorage``
- ``DeviceBiometrics``
- ``AppWindow``
