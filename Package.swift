// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TimezoneBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "TimezoneBar",
            path: "Sources/TimezoneBar"
        ),
        .testTarget(
            name: "TimezoneBarTests",
            dependencies: ["TimezoneBar"],
            path: "Tests/TimezoneBarTests"
        )
    ]
)
