// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LuminaBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "LuminaBar",
            path: "Sources/LuminaBar"
        )
    ]
)
