// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Duplix",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DuplixCore",
            targets: ["DuplixCore"]
        ),
        .executable(
            name: "duplix",
            targets: ["duplix"]
        ),
        .executable(
            name: "DuplixApp",
            targets: ["DuplixApp"]
        ),
        .executable(
            name: "DuplixTests",
            targets: ["DuplixTests"]
        )
    ],
    targets: [
        .target(
            name: "DuplixCore",
            dependencies: [],
            path: "Sources/DuplixCore"
        ),
        .executableTarget(
            name: "duplix",
            dependencies: ["DuplixCore"],
            path: "Sources/duplix"
        ),
        .executableTarget(
            name: "DuplixApp",
            dependencies: ["DuplixCore"],
            path: "Sources/DuplixApp"
        ),
        .executableTarget(
            name: "DuplixTests",
            dependencies: ["DuplixCore"],
            path: "Tests/DuplixTests"
        )
    ]
)
