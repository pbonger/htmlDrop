// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "html-drop",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "html-drop", path: "Sources")
    ]
)
