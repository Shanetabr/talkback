// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Talkback",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "Talkback",
            path: "Sources/Talkback",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
