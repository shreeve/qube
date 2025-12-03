// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Qube",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Qube",
            path: "Sources/Qube"
        )
    ]
)
