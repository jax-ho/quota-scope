// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexWatcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CodexWatcherCore", targets: ["CodexWatcherCore"])
    ],
    targets: [
        .target(name: "CodexWatcherCore"),
        .testTarget(
            name: "CodexWatcherCoreTests",
            dependencies: ["CodexWatcherCore"]
        )
    ]
)
