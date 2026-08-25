// swift-tools-version: 6.2
import PackageDescription

let settings: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Factory",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "FactoryCore", targets: ["FactoryCore"]),
        .executable(name: "FactoryBroker", targets: ["FactoryBroker"]),
        .executable(name: "FactoryCLI", targets: ["FactoryCLI"]),
        .executable(name: "FactoryEvaluator", targets: ["FactoryEvaluator"]),
    ],
    targets: [
        .target(name: "FactoryCore", swiftSettings: settings),
        .executableTarget(
            name: "FactoryBroker",
            dependencies: ["FactoryCore"],
            swiftSettings: settings,
        ),
        .executableTarget(
            name: "FactoryCLI",
            dependencies: ["FactoryCore"],
            swiftSettings: settings,
        ),
        .executableTarget(
            name: "FactoryEvaluator",
            dependencies: ["FactoryCore"],
            swiftSettings: settings,
        ),
        .testTarget(
            name: "FactoryTests",
            dependencies: ["FactoryCore"],
            swiftSettings: settings,
        ),
    ],
)
