// swift-tools-version: 5.9
import PackageDescription

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
        .target(name: "AnvyxFoundation"),
        .target(name: "AnvyxDeviceKit"),
        .testTarget(name: "AnvyxFoundationTests", dependencies: ["AnvyxFoundation"]),
        .testTarget(name: "AnvyxDeviceKitTests", dependencies: ["AnvyxDeviceKit"]),
    ]
)
