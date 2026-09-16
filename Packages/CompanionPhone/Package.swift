// swift-tools-version: 6.2
import PackageDescription

let settings: [SwiftSetting] = [.defaultIsolation(MainActor.self)]
let package = Package(
    name: "CompanionPhone",
    defaultLocalization: "en",
    // macOS rides along so host Swift Testing (`scripts/test.sh`) runs this
    // package on the build Mac; the shipped product links it from the iOS
    // target only. Sources stay UIKit/ActivityKit-free (ActivityKit conformance
    // is `canImport`-gated) so both closures compile.
    platforms: [.macOS(.v26), .iOS(.v18)],
    products: [
        .library(name: "CompanionPhone", targets: ["CompanionPhone"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
    ],
    targets: [
        .target(
            name: "CompanionPhone",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
            ],
            resources: [.process("Resources")],
            swiftSettings: settings,
        ),
        .testTarget(
            name: "CompanionPhoneTests",
            dependencies: ["CompanionPhone"],
            swiftSettings: settings,
        ),
    ],
)
