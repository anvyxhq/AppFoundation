// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppFoundation",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "AppFoundation", targets: ["AppFoundation"]),
    ],
    targets: [
        .target(name: "AppFoundation"),
        .testTarget(name: "AppFoundationTests", dependencies: ["AppFoundation"]),
    ]
)
