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
    dependencies: [
        .package(url: "https://github.com/objectbox/objectbox-swift.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "InsightApp",
            dependencies: [
                .product(name: "ObjectBox", package: "objectbox-swift"),
            ],
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
