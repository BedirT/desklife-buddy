#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import Domain
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import SettingsFeature

    @Suite("Settings information routes", .serialized)
    struct SettingsInformationRoutesSnapshotTests {
        private func screen(
            _ state: SettingsFeatureModel.PreviewState,
            runtime: SettingsIntegrationsRuntime = .unavailable,
            evidenceTopic: SettingsEvidenceTopic = .visualResets,
            colorScheme: ColorScheme = .light,
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
                integrationsRuntime: runtime,
                evidenceTopic: evidenceTopic,
            )
            .frame(width: width, height: height)
            .environment(\._colorSchemeContrast, increaseContrast ? .increased : .standard)
            .environment(\.colorScheme, colorScheme)
            .environment(\.dsTextScale, textScale)
        }

        private func approvalRequiredScreen(textScale: DSTextScale = .standard) -> some View {
            SettingsFeatureView(
                model: .preview(.integrationsApprovalRequired),
                loadsAutomatically: false,
                deterministicSplitLayout: true,
                integrationsRuntime: SettingsIntegrationsRuntime(
                    notifications: .available(authorization: .authorized),
                    launchAtLogin: .requiresApproval,
                ),
            )
            .frame(width: 1000, height: 700)
            .environment(\.dsTextScale, textScale)
        }

        @Test func integrationsAuthorizedLight() {
            assertScreenSnapshot(of: screen(
                .integrationsAvailable,
                runtime: SettingsIntegrationsRuntime(
                    notifications: .available(authorization: .authorized),
                    launchAtLogin: .enabled,
                ),
            ))
        }

        @Test func integrationsDeniedDark() {
            assertScreenSnapshot(of: screen(
                .integrationsUnavailable,
                runtime: SettingsIntegrationsRuntime(
                    notifications: .available(authorization: .denied),
                    launchAtLogin: .notRegistered,
                ),
                colorScheme: .dark,
            ))
        }

        @Test func integrationsNotDetermined() {
            assertScreenSnapshot(of: screen(
                .integrationsUnavailable,
                runtime: SettingsIntegrationsRuntime(
                    notifications: .available(authorization: .notDetermined),
                    launchAtLogin: .notRegistered,
                ),
            ))
        }

        @Test func integrationsLaunchAtLoginApprovalRequired() {
            assertScreenSnapshot(of: approvalRequiredScreen())
        }

        @Test func integrationsLaunchAtLoginApprovalRequiredLargestText() {
            assertScreenSnapshot(of: approvalRequiredScreen(textScale: .largest))
        }

        @Test func integrationsUnavailableLargestText() {
            assertScreenSnapshot(of: screen(
                .integrationsUnavailable,
                textScale: .largest,
            ))
        }

        @Test func evidenceVisualResetsLight() {
            assertScreenSnapshot(of: screen(.evidenceVisualResets))
        }

        @Test func evidenceCompactWindow() {
            assertScreenSnapshot(of: screen(
                .evidenceVisualResets,
                width: 780,
                height: 592,
            ))
        }

        @Test func evidenceStandingAndMovingDark() {
            assertScreenSnapshot(of: screen(
                .evidenceStandingAndMoving,
                evidenceTopic: .standingAndMoving,
                colorScheme: .dark,
            ))
        }

        @Test func evidenceLargestTextIncreaseContrast() {
            assertScreenSnapshot(of: screen(
                .evidenceVisualResets,
                increaseContrast: true,
                textScale: .largest,
            ))
        }

        @Test func safetyLight() {
            assertScreenSnapshot(of: screen(.safetyAndSupport))
        }

        @Test func safetyDark() {
            assertScreenSnapshot(of: screen(.safetyAndSupport, colorScheme: .dark))
        }

        @Test func safetyLargestTextIncreaseContrast() {
            assertScreenSnapshot(of: screen(
                .safetyAndSupport,
                increaseContrast: true,
                textScale: .largest,
            ))
        }
    }
#endif
