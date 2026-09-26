// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RillRichSample",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../../Packages/RillExtensionKit")
    ],
    targets: [
        .executableTarget(
            name: "RillRichSample",
            dependencies: [.product(name: "RillExtensionKit", package: "RillExtensionKit")]
        )
    ]
)
