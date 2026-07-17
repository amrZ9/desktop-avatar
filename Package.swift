// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopAvatar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DesktopAvatar",
            path: "Sources/DesktopAvatar"
        )
    ]
)
