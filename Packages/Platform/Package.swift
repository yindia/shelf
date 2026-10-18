// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Platform",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Platform", targets: ["Platform"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "Platform",
            dependencies: [.product(name: "Core", package: "Core")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
