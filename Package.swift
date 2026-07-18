// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopAvatar",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/tattn/VRMKit.git", from: "0.8.0")
    ],
    targets: [
        .executableTarget(
            name: "DesktopAvatar",
            dependencies: [
                .product(name: "VRMKit", package: "VRMKit"),
                .product(name: "VRMRealityKit", package: "VRMKit"),
            ],
            path: "Sources/DesktopAvatar",
            resources: [
                .copy("Resources/Elmer.vrm"),
                .copy("Resources/idle-maid.vrma")
            ]
        )
    ]
)
