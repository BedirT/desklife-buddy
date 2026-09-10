#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import SettingsFeature

    @Suite("Settings privacy and data screens", .serialized)
    struct SettingsPrivacySnapshotTests {
        private struct PrivacyDetailScreen: View {
            @FocusState private var focusedControl: SettingsPrivacyFocusTarget?
            let storedDetailsExpanded: Bool
            let dataControlsExpanded: Bool
            let textScale: DSTextScale

            var body: some View {
                PrivacyAndDataSettingsView(
                    model: .preview(.privacyDefault),
                    increaseContrast: false,
                    focusedControl: $focusedControl,
                    initiallyShowsStoredDetails: storedDetailsExpanded,
                    initiallyShowsDataControls: dataControlsExpanded,
                )
                .frame(width: 740, height: 700)
                .environment(\.dsTextScale, textScale)
            }
        }

        private func screen(
            _ state: SettingsFeatureModel.PreviewState,
            increaseContrast: Bool = false,
            textScale: DSTextScale = .standard,
            width: CGFloat = 1000,
            height: CGFloat = 700,
        ) -> some View {
            SettingsFeatureView(
                model: .preview(state),
                loadsAutomatically: false,
                increaseContrastOverride: increaseContrast,
                deterministicSplitLayout: true,
            )
            .frame(width: width, height: height)
            .environment(\._colorSchemeContrast, increaseContrast ? .increased : .standard)
            .environment(\.dsTextScale, textScale)
        }

        @Test func defaultLight() {
            assertScreenSnapshot(of: screen(.privacyDefault))
        }

        @Test func defaultDark() {
            assertScreenSnapshot(of: screen(.privacyDefault), appearances: [.dark])
        }

        @Test func noRetainedHistory() {
            assertScreenSnapshot(of: screen(.privacyNoHistory))
        }

        @Test func noRetainedHistoryCompactWindow() {
            assertScreenSnapshot(of: screen(
                .privacyNoHistory,
                width: 780,
                height: 592,
            ))
        }

        @Test func applyingRetention() {
            assertScreenSnapshot(of: screen(.privacyApplyingRetention))
        }

        @Test func exportReview() {
            assertScreenSnapshot(of: screen(.privacyExportReview))
        }

        @Test func exportColumnsExpanded() {
            assertScreenSnapshot(of: screen(.privacyExportColumnsExpanded))
        }

        @Test func exportColumnsExpandedLargestText() {
            assertScreenSnapshot(of: screen(
                .privacyExportColumnsExpanded,
                textScale: .largest,
            ))
        }

        @Test func exportColumnsExpandedCombinedAccessibility() {
            assertScreenSnapshot(of: screen(
                .privacyExportColumnsExpanded,
                increaseContrast: true,
                textScale: .largest,
            ))
        }

        @Test func exportNoColumns() {
            assertScreenSnapshot(of: screen(.privacyExportNoColumns))
        }

        @Test func exportCancelledReview() {
            assertScreenSnapshot(of: screen(.privacyExportCancelled))
        }

        @Test func exportSuccess() {
            assertScreenSnapshot(of: screen(.privacyExportSuccess))
        }

        @Test func exportFailure() {
            assertScreenSnapshot(of: screen(.privacyExportFailure))
        }

        @Test func deleteConfirmation() {
            assertScreenSnapshot(of: screen(.privacyDeleteConfirmation))
        }

        @Test func deleteSuccess() {
            assertScreenSnapshot(of: screen(.privacyDeleteSuccess))
        }

        @Test func deleteFailure() {
            assertScreenSnapshot(of: screen(.privacyDeleteFailure))
        }

        @Test func resetConfirmation() {
            assertScreenSnapshot(of: screen(.privacyResetConfirmation))
        }

        @Test func resetSuccess() {
            assertScreenSnapshot(of: screen(.privacyResetSuccess))
        }

        @Test func resetTemporarilyBusy() {
            assertScreenSnapshot(of: screen(.privacyResetTemporarilyBusy))
        }

        @Test func resetFailure() {
            assertScreenSnapshot(of: screen(.privacyResetFailure))
        }

        @Test func largestText() {
            assertScreenSnapshot(of: screen(.privacyDefault, textScale: .largest))
        }

        @Test func increaseContrast() {
            assertScreenSnapshot(of: screen(.privacyDefault, increaseContrast: true))
        }

        @Test func storedDetailsExpanded() {
            assertScreenSnapshot(of: PrivacyDetailScreen(
                storedDetailsExpanded: true,
                dataControlsExpanded: false,
                textScale: .standard,
            ))
        }

        @Test func storedDetailsExpandedLargestText() {
            assertScreenSnapshot(of: PrivacyDetailScreen(
                storedDetailsExpanded: true,
                dataControlsExpanded: false,
                textScale: .largest,
            ))
        }

        @Test func dataControlsExpanded() {
            assertScreenSnapshot(of: PrivacyDetailScreen(
                storedDetailsExpanded: false,
                dataControlsExpanded: true,
                textScale: .standard,
            ))
        }

        @Test func reduceTransparency() {
            assertScreenSnapshot(of: screen(.privacyDefault))
        }
    }
#endif
