// swift-tools-version: 6.2
import PackageDescription

// Host-only developer tool: it never links into the app, so it is free to take
// a parser dependency the shipping targets must not. The version is pinned
// `exact` because swift-syntax releases track the compiler - 603.x is what the
// app's own resolved graph already carries for Xcode 26.5. Bump it only
// alongside a toolchain bump, and re-run the rehearsal on that bump.
let package = Package(
    name: "ObservablePreviewWiring",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "observable-preview-wiring", targets: ["observable-preview-wiring"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", exact: "603.0.2"),
    ],
    targets: [
        .target(
            name: "ObservablePreviewWiring",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
        ),
        .executableTarget(
            name: "observable-preview-wiring",
            dependencies: ["ObservablePreviewWiring"],
        ),
        .testTarget(
            name: "ObservablePreviewWiringTests",
            dependencies: ["ObservablePreviewWiring"],
        ),
    ],
)
