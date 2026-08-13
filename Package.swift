// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DockGesture",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DockGestureCore", targets: ["DockGestureCore"]),
        .executable(name: "DockGesture", targets: ["DockGesture"])
    ],
    targets: [
        .target(name: "DockGestureCore"),
        .executableTarget(
            name: "DockGesture",
            dependencies: ["DockGestureCore"]
        ),
        .testTarget(
            name: "DockGestureCoreTests",
            dependencies: ["DockGestureCore"]
        )
    ]
)
