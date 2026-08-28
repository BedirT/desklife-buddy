#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import SettingsFeature

    @Suite("Settings context and exclusions screens", .serialized)
    struct SettingsContextSnapshotTests {
        private func screen(
            _ state: SettingsFeatureModel.PreviewState,
            colorScheme: ColorScheme = .light,
            increaseContrast: Bool = false,
            textScale: DSTextScale = .standard,
        ) -> some View {
            SettingsFeatureView(
                model: .preview(state),
                loadsAutomatically: false,
                increaseContrastOverride: increaseContrast,
                deterministicSplitLayout: true,
                excludedApplicationPresentations: applicationPresentations,
                excludedApplicationPicker: { nil },
            )
            .frame(width: 1000, height: 700)
            .environment(\._colorSchemeContrast, increaseContrast ? .increased : .standard)
            .environment(\.colorScheme, colorScheme)
            .environment(\.dsTextScale, textScale)
        }

        @Test func emptyLight() {
            assertScreenSnapshot(of: screen(.contextEmpty))
        }

        @Test func populatedLight() {
            assertScreenSnapshot(of: screen(.contextPopulated))
        }

        @Test func populatedDark() {
            assertScreenSnapshot(of: screen(.contextPopulated, colorScheme: .dark))
        }

        @Test func emptyIncreaseContrast() {
            assertScreenSnapshot(of: screen(.contextEmpty, increaseContrast: true))
        }

        @Test func populatedLargestText() {
            assertScreenSnapshot(of: screen(.contextPopulated, textScale: .largest))
        }

        private var applicationPresentations: [SettingsExcludedApplicationPresentation] {
            [
                SettingsExcludedApplicationPresentation(
                    bundleID: "com.apple.dt.Xcode",
                    displayName: "Xcode",
                    icon: Image(systemName: "hammer"),
                ),
                SettingsExcludedApplicationPresentation(
                    bundleID: "us.zoom.xos",
                    displayName: "Zoom",
                    icon: Image(systemName: "video"),
                ),
            ]
        }
    }
#endif
