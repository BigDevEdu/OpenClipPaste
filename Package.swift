// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClipPaste",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ClipPaste"),
        .testTarget(name: "ClipPasteTests", dependencies: ["ClipPaste"]),
    ]
)
