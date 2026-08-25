// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TestSupport",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SnapshotSupport", targets: ["SnapshotSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0"),
    ],
    targets: [
        .target(
            name: "SnapshotSupport",
            dependencies: [
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)],
        ),
    ],
)
