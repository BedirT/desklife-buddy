#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import SettingsFeature

    @Suite("Settings accessibility screens", .serialized)
    struct SettingsAccessibilitySnapshotTests {
        private func screen(
            _ state: SettingsFeatureModel.PreviewState,
            colorScheme: ColorScheme = .light,
            increaseContrast: Bool = false,
            textScale: DSTextScale = .standard,
        ) -> some View {
            baseScreen(state, increaseContrast: increaseContrast)
                .environment(\.colorScheme, colorScheme)
                .environment(\.dsTextScale, textScale)
        }

        private func baseScreen(
            _ state: SettingsFeatureModel.PreviewState,
            increaseContrast: Bool = false,
        ) -> some View {
            SettingsFeatureView(
                model: .preview(state),
                loadsAutomatically: false,
                increaseContrastOverride: increaseContrast,
                deterministicSplitLayout: true,
            )
            .frame(width: 1000, height: 700)
            .environment(\._colorSchemeContrast, increaseContrast ? .increased : .standard)
        }

        @Test func standardLight() {
            assertScreenSnapshot(of: screen(.accessibilityStandard))
        }

        @Test func staticLight() {
            assertScreenSnapshot(of: screen(.accessibilityStatic))
        }

        @Test func textOnlyLight() {
            assertScreenSnapshot(of: screen(.accessibilityTextOnly))
        }

        @Test func staticMinimumBrightness() {
            assertScreenSnapshot(of: screen(.accessibilityStaticMinimumBrightness))
        }

        @Test func staticMaximumBrightnessDark() {
            assertScreenSnapshot(
                of: baseScreen(.accessibilityStaticMaximumBrightness)
                    .environment(\.dsTextScale, DSTextScale.standard),
                appearances: [.dark],
            )
        }

        @Test func textOnlyDark() {
            assertScreenSnapshot(of: screen(.accessibilityTextOnly, colorScheme: .dark))
        }

        @Test func standardLargestText() {
            assertScreenSnapshot(of: screen(.accessibilityStandard, textScale: .largest))
        }

        @Test func staticIncreaseContrast() {
            assertScreenSnapshot(of: screen(.accessibilityStatic, increaseContrast: true))
        }
    }
#endif
