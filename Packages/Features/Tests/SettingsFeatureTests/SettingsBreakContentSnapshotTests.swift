#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import SettingsFeature

    @Suite("Settings break-content screens", .serialized)
    struct SettingsBreakContentSnapshotTests {
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
            )
            .frame(width: 1000, height: 700)
            .environment(\._colorSchemeContrast, increaseContrast ? .increased : .standard)
            .environment(\.colorScheme, colorScheme)
            .environment(\.dsTextScale, textScale)
        }

        @Test func defaultLight() {
            assertScreenSnapshot(of: screen(.breakContentDefault))
        }

        @Test func customizedDark() {
            assertScreenSnapshot(of: screen(.breakContentCustomized, colorScheme: .dark))
        }

        @Test func defaultIncreaseContrast() {
            assertScreenSnapshot(of: screen(.breakContentDefault, increaseContrast: true))
        }

        @Test func defaultLargestText() {
            assertScreenSnapshot(of: screen(.breakContentDefault, textScale: .largest))
        }

        @Test func libraryList() {
            assertScreenSnapshot(of: screen(.contentLibrary))
        }

        @Test func visualDetail() {
            assertScreenSnapshot(of: screen(.contentLibraryVisualDetail))
        }

        @Test func movementDetailDark() {
            assertScreenSnapshot(of: screen(.contentLibraryMovementDetail, colorScheme: .dark))
        }

        @Test func positionDetail() {
            assertScreenSnapshot(of: screen(.contentLibraryPositionDetail))
        }

        @Test func breathingDetail() {
            assertScreenSnapshot(of: screen(.contentLibraryBreathingDetail))
        }

        @Test func detailLargestTextIncreaseContrast() {
            assertScreenSnapshot(of: screen(
                .contentLibraryMovementDetail,
                increaseContrast: true,
                textScale: .largest,
            ))
        }
    }
#endif
