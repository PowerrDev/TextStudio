// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownNotes",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MarkdownNotes",
            path: "Sources/MarkdownNotes"
        )
    ]
)
