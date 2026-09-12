// swift-tools-version: 6.2
import PackageDescription

// NON-SHIPPING SPIKE — Epic 5 story S2 (issue #6).
// This package is intentionally standalone: it is NOT referenced by
// App.xcodeproj, Packages/Domain, Packages/Features, or any product test
// suite. It exists only to establish the public-API ceiling for each
// context source and to prove (via boundary tests) that the sanitized
// shapes retain no titles, attendees, content, URLs, window titles,
// device identity, or history. Delete or archive after the S3 adapter
// decision; never wire into production targets.
let package = Package(
    name: "Epic5ContextSense",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Epic5ContextSpikes", targets: ["Epic5ContextSpikes"]),
    ],
    targets: [
        .target(name: "Epic5ContextSpikes"),
        .testTarget(
            name: "Epic5ContextSpikeTests",
            dependencies: ["Epic5ContextSpikes"]
        ),
    ],
)
