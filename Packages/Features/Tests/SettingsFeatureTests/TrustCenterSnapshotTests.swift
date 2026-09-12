#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import SettingsFeature

    @Suite("Trust center screens", .serialized)
    struct TrustCenterSnapshotTests {
        private func screen(
            _ modelState: SettingsFeatureModel.PreviewState,
            _ trustState: TrustCenterPreviewState,
            increaseContrast: Bool = false,
            textScale: DSTextScale = .standard,
            width: CGFloat = 1000,
            height: CGFloat = 700,
            rules: TrustCenterRulesSnapshot? = nil,
        ) -> some View {
            SettingsFeatureView(
                model: .preview(modelState),
                loadsAutomatically: false,
                increaseContrastOverride: increaseContrast,
                deterministicSplitLayout: true,
                trustCenterSnapshot: .preview(trustState),
                trustCenterRulesSnapshot: rules,
            )
            .frame(width: width, height: height)
            .environment(\._colorSchemeContrast, increaseContrast ? .increased : .standard)
            .environment(\.dsTextScale, textScale)
        }

        @Test func grantedLight() {
            assertScreenSnapshot(of: screen(.trustCenterGranted, .granted))
        }

        @Test func grantedDark() {
            assertScreenSnapshot(of: screen(.trustCenterGranted, .granted), appearances: [.dark])
        }

        @Test func denied() {
            assertScreenSnapshot(of: screen(.trustCenterDenied, .denied))
        }

        @Test func educating() {
            assertScreenSnapshot(of: screen(.trustCenterEducating, .educating))
        }

        @Test func killSwitchEngaged() {
            assertScreenSnapshot(of: screen(.trustCenterKillSwitch, .killSwitchEngaged))
        }

        @Test func resumeVisible() {
            // Taller exact-size render: the Resume control sits below the
            // 700pt window fold, so the window-layout kill-switch case
            // cannot prove it. Baselines: resumeVisible.light/dark.png.
            assertScreenSnapshot(
                of: screen(.trustCenterKillSwitch, .killSwitchEngaged, height: 1300),
                layout: .fixed(width: 1000, height: 1300),
            )
        }

        @Test func inspectorActive() {
            assertScreenSnapshot(of: screen(.trustCenterInspector, .inspectorActive))
        }

        @Test func receipts() {
            assertScreenSnapshot(of: screen(.trustCenterReceipts, .receipts))
        }

        @Test func proposedRules() {
            // Taller exact-size render: four rule rows sit below the
            // receipts list. Baselines: proposedRules.light/dark.png.
            assertScreenSnapshot(
                of: screen(
                    .trustCenterReceipts,
                    .receipts,
                    height: 2300,
                    rules: .previewMixed(),
                ),
                layout: .fixed(width: 1000, height: 2300),
            )
        }

        @Test func proposedRulesEmpty() {
            assertScreenSnapshot(
                of: screen(.trustCenterReceipts, .receipts, rules: .empty),
            )
        }

        @Test func empty() {
            assertScreenSnapshot(of: screen(.trustCenterEmpty, .empty))
        }

        @Test func receiptsLargestText() {
            assertScreenSnapshot(of: screen(.trustCenterReceipts, .receipts, textScale: .largest))
        }

        @Test func grantedIncreaseContrast() {
            assertScreenSnapshot(of: screen(.trustCenterGranted, .granted, increaseContrast: true))
        }
    }
#endif
