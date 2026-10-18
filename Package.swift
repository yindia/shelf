// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shelf",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "Packages/Core"),
        .package(path: "Packages/UI"),
        .package(path: "Packages/Platform"),
    ],
    targets: [
        .executableTarget(
            name: "ShelfApp",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "UI", package: "UI"),
                .product(name: "Platform", package: "Platform"),
            ],
            path: "App",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "Snapshot",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "UI", package: "UI"),
                .product(name: "Platform", package: "Platform"),
            ],
            path: "Tools/Snapshot",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
