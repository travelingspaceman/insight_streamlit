// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmbeddingGenerator",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "EmbeddingGenerator",
            path: "Sources"
        )
    ]
)
