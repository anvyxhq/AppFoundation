// swift-tools-version: 6.2
import PackageDescription

// Anvyx concurrency baseline (roadmap 0.1):
// - Swift 6 language mode → strict concurrency checking = complete.
// - Approachable Concurrency upcoming features (matches Xcode's
//   SWIFT_APPROACHABLE_CONCURRENCY toggle).
// - Default actor isolation = nonisolated (SE-0466: MainActor-default is wrong
//   for libraries). This is already SwiftPM's default; declared explicitly so
//   intent is visible and survives future default changes.
let concurrencyBaseline: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(nil),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "AppFoundation",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "AnvyxFoundation", targets: ["AnvyxFoundation"]),
        .library(name: "AnvyxDeviceKit", targets: ["AnvyxDeviceKit"]),
    ],
    targets: [
        .target(name: "AnvyxFoundation", swiftSettings: concurrencyBaseline),
        .target(name: "AnvyxDeviceKit", swiftSettings: concurrencyBaseline),
        .testTarget(name: "AnvyxFoundationTests", dependencies: ["AnvyxFoundation"], swiftSettings: concurrencyBaseline),
        .testTarget(name: "AnvyxDeviceKitTests", dependencies: ["AnvyxDeviceKit"], swiftSettings: concurrencyBaseline),
    ]
)
