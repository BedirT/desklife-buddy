// swift-tools-version: 6.2
import PackageDescription

let settings: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "DesignSystem",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    dependencies: [
        .package(path: "../TestSupport"),
    ],
    targets: [
        .target(name: "DesignSystem", resources: [.process("Resources")], swiftSettings: settings),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: [
                "DesignSystem",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: settings,
        ),
    ],
)
