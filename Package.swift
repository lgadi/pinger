// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pinger",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Pinger",
            path: "Sources/Pinger"
        )
    ]
)
