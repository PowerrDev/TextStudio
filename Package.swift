// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TextStudio",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TextStudio",
            path: "Sources/TextStudio"
        )
    ]
)
