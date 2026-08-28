// swift-tools-version: 6.2
import PackageDescription

let featureSettings: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

// One module per feature. App links the stable AppFeatures product once;
// scripts/new-feature.sh adds modules and targets at the markers below.

let package = Package(
    name: "Features",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ItemList", targets: ["ItemList"]),
        .library(
            name: "AppFeatures",
            targets: [
                "FeatureLocalization",
                "ItemList",
                "StatusMenu",
                "BreakPresentation",
                "VisualReset",
                "Movement",
                "BreakFlow",
                "HeadsUp",
                "SettingsFeature",
                "Onboarding",
                "PreferencePresentation",
                "WeeklyRhythm",
                // agent:app-feature-targets
            ],
        ),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
        .package(path: "../TestSupport"),
    ],
    targets: [
        .target(
            name: "FeatureLocalization",
            resources: [.process("Resources")],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "ItemList",
            dependencies: [
                "FeatureLocalization",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "ItemListTests",
            dependencies: [
                "ItemList",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "StatusMenu",
            dependencies: [
                "FeatureLocalization",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "StatusMenuTests",
            dependencies: [
                "StatusMenu",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "BreakPresentation",
            dependencies: [
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            resources: [.process("Resources")],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "BreakPresentationTests",
            dependencies: [
                "BreakPresentation",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "VisualReset",
            dependencies: [
                "BreakPresentation",
                "FeatureLocalization",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "VisualResetTests",
            dependencies: [
                "VisualReset",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "Movement",
            dependencies: [
                "BreakPresentation",
                "FeatureLocalization",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "MovementTests",
            dependencies: [
                "Movement",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "BreakFlow",
            dependencies: [
                "BreakPresentation",
                "FeatureLocalization",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "BreakFlowTests",
            dependencies: [
                "BreakFlow",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "HeadsUp",
            dependencies: [
                "FeatureLocalization",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "HeadsUpTests",
            dependencies: [
                "HeadsUp",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "SettingsFeature",
            dependencies: [
                "FeatureLocalization",
                "PreferencePresentation",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            resources: [.process("Resources")],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: [
                "SettingsFeature",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "Onboarding",
            dependencies: [
                "FeatureLocalization",
                "PreferencePresentation",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "OnboardingTests",
            dependencies: [
                "Onboarding",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "PreferencePresentation",
            dependencies: [
                "FeatureLocalization",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            resources: [.process("Resources")],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "PreferencePresentationTests",
            dependencies: [
                "PreferencePresentation",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        .target(
            name: "WeeklyRhythm",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            resources: [.process("Resources")],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "WeeklyRhythmTests",
            dependencies: [
                "WeeklyRhythm",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
        // agent:feature-targets
    ],
)
