// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RillExtensionKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RillExtensionKit", targets: ["RillExtensionKit"])
    ],
    targets: [
        .target(name: "RillExtensionKit", path: "Packages/RillExtensionKit/Sources/RillExtensionKit"),
        .testTarget(name: "RillExtensionKitTests", dependencies: ["RillExtensionKit"], path: "Packages/RillExtensionKit/Tests/RillExtensionKitTests")
    ]
)
