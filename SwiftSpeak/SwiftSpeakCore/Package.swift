// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSpeakCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftSpeakCore",
            targets: ["SwiftSpeakCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftSpeakCore",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftSpeakCoreTests",
            dependencies: ["SwiftSpeakCore"]
        ),
    ]
)
