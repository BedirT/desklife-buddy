// swift-tools-version: 6.2
import PackageDescription

let settings: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Domain",
    platforms: [.macOS(.v26), .iOS(.v18)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
    ],
    targets: [
        .target(name: "Domain", swiftSettings: settings),
        .testTarget(name: "DomainTests", dependencies: ["Domain"], swiftSettings: settings),
    ],
)
