#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import SettingsFeature

    @Suite("Settings schedule screens", .serialized)
    struct SettingsSnapshotTests {
        private func screen(
            _ state: SettingsFeatureModel.PreviewState = .balanced,
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
            .environment(\.dsTextScale, textScale)
        }

        @Test func balancedLight() {
            assertScreenSnapshot(of: screen())
        }

        @Test func loading() {
            assertScreenSnapshot(of: screen(.loading))
        }

        @Test func loadFailure() {
            assertScreenSnapshot(of: screen(.loadFailed))
        }

        @Test func gentle() {
            assertScreenSnapshot(of: screen(.gentle))
        }

        @Test func frequentMovement() {
            assertScreenSnapshot(of: screen(.frequentMovement))
        }

        @Test func highFrequency() {
            assertScreenSnapshot(of: screen(.highFrequency))
        }

        @Test func customInvalid() {
            assertScreenSnapshot(of: screen(.customInvalid))
        }

        @Test func customUnparseable() {
            assertScreenSnapshot(of: screen(.customUnparseable))
        }

        @Test func customValid() {
            assertScreenSnapshot(of: screen(.customValid))
        }

        @Test func customVeryFrequent() {
            assertScreenSnapshot(of: screen(.customVeryFrequent))
        }

        @Test func customEffectivelyDisabled() {
            assertScreenSnapshot(of: screen(.customEffectivelyDisabled))
        }

        @Test func temporarilyBusy() {
            assertScreenSnapshot(of: screen(.temporarilyBusy))
        }

        @Test func applying() {
            assertScreenSnapshot(of: screen(.applying))
        }

        @Test func applyFailed() {
            assertScreenSnapshot(of: screen(.applyFailed))
        }

        @Test func increaseContrast() {
            assertScreenSnapshot(of: screen(increaseContrast: true))
        }

        @Test func largestText() {
            assertScreenSnapshot(of: screen(textScale: .largest))
        }

        @Test func largestTextLoading() {
            assertScreenSnapshot(of: screen(.loading, textScale: .largest))
        }

        @Test func largestTextLoadFailure() {
            assertScreenSnapshot(of: screen(.loadFailed, textScale: .largest))
        }

        @Test func largestTextCustomInvalid() {
            assertScreenSnapshot(of: screen(.customInvalid, textScale: .largest))
        }

        @Test func largestTextCustomAdvisory() {
            assertScreenSnapshot(of: screen(.customVeryFrequent, textScale: .largest))
        }

        @Test func largestTextTemporarilyBusy() {
            assertScreenSnapshot(of: screen(.temporarilyBusy, textScale: .largest))
        }

        @Test func largestTextApplyFailure() {
            assertScreenSnapshot(of: screen(.applyFailed, textScale: .largest))
        }
    }
#endif
