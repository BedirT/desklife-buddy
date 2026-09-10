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
            width: CGFloat = 1000,
            height: CGFloat = 700,
            focusedSidebarSectionOverride: SettingsSection? = nil,
        ) -> some View {
            SettingsFeatureView(
                model: .preview(state),
                loadsAutomatically: false,
                increaseContrastOverride: increaseContrast,
                deterministicSplitLayout: true,
                focusedSidebarSectionOverride: focusedSidebarSectionOverride,
            )
            .frame(width: width, height: height)
            .environment(\._colorSchemeContrast, increaseContrast ? .increased : .standard)
            .environment(\.dsTextScale, textScale)
        }

        private func scheduleComponent(
            _ state: SettingsFeatureModel.PreviewState,
            textScale: DSTextScale = .standard,
            height: CGFloat,
        ) -> some View {
            ScheduleSettingsView(
                model: .preview(state),
                increaseContrast: false,
            )
            .padding(DSSpacing.lg)
            .frame(width: 460, height: height, alignment: .top)
            .background(Color.dsContentCanvas)
            .environment(\.dsTextScale, textScale)
        }

        @Test func balancedLight() {
            assertScreenSnapshot(of: screen())
        }

        @Test func compactWindow() {
            assertScreenSnapshot(of: screen(width: 780, height: 592))
        }

        @Test func compactWindowLargestText() {
            assertScreenSnapshot(of: screen(textScale: .largest, width: 780, height: 592))
        }

        @Test func compactWindowCustomValid() {
            assertScreenSnapshot(of: screen(.customValid, width: 780, height: 592))
        }

        @Test func compactExpandedCustomContent() {
            assertScreenSnapshot(
                of: scheduleComponent(.customValid, height: 1800),
                layout: .fixed(width: 460, height: 1800),
            )
        }

        @Test func compactLargestTextContent() {
            assertScreenSnapshot(
                of: scheduleComponent(.balanced, textScale: .largest, height: 1260),
                layout: .fixed(width: 460, height: 1260),
            )
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

        @Test func focusedSidebar() {
            assertScreenSnapshot(of: screen(focusedSidebarSectionOverride: .schedule))
        }

        @Test func focusedSidebarIncreaseContrast() {
            assertScreenSnapshot(
                of: screen(
                    increaseContrast: true,
                    focusedSidebarSectionOverride: .schedule,
                ),
            )
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
