// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InsightApp",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "InsightApp",
            targets: ["InsightApp"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "InsightApp",
            dependencies: [],
            path: "Sources/InsightApp",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "InsightAppTests",
            dependencies: ["InsightApp"],
            path: "Tests"
        ),
    ]
)
