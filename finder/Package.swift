// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "netlify-share",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "netlify-share", path: "Sources")
    ]
)
