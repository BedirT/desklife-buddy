// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TestSupport",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SnapshotSupport", targets: ["SnapshotSupport"]),
    ],
    targets: [
        .target(
            name: "SnapshotSupport",
            swiftSettings: [.defaultIsolation(MainActor.self)],
        ),
    ],
)
