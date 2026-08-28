#if os(macOS) && SNAPSHOT_TESTS
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import SettingsFeature

    @Suite("Settings schedule redesign explorations", .serialized)
    struct SettingsRedesignSnapshotTests {
        private func screen(
            _ variant: SettingsScheduleRedesignVariant,
            colorScheme: ColorScheme,
        ) -> some View {
            SettingsScheduleRedesignExploration(
                model: .preview(.balanced),
                variant: variant,
            )
            .frame(width: 1000, height: 700)
            .environment(\.colorScheme, colorScheme)
        }

        @Test func floatingRailLight() {
            assertScreenSnapshot(of: screen(.floatingRail, colorScheme: .light))
        }

        @Test func refinedRailLight() {
            assertScreenSnapshot(of: screen(.refinedRail, colorScheme: .light))
        }

        @Test func refinedRailDark() {
            assertScreenSnapshot(of: screen(.refinedRail, colorScheme: .dark))
        }

        @Test func refinedMarkRailLight() {
            assertScreenSnapshot(of: screen(.refinedMarkRail, colorScheme: .light))
        }

        @Test func refinedMarkRailDark() {
            assertScreenSnapshot(of: screen(.refinedMarkRail, colorScheme: .dark))
        }

        @Test func floatingRailDark() {
            assertScreenSnapshot(of: screen(.floatingRail, colorScheme: .dark))
        }

        @Test func calmWorkspaceLight() {
            assertScreenSnapshot(of: screen(.calmWorkspace, colorScheme: .light))
        }

        @Test func calmWorkspaceDark() {
            assertScreenSnapshot(of: screen(.calmWorkspace, colorScheme: .dark))
        }

        @Test func artCanvasLight() {
            assertScreenSnapshot(of: screen(.artCanvas, colorScheme: .light))
        }

        @Test func artCanvasDark() {
            assertScreenSnapshot(of: screen(.artCanvas, colorScheme: .dark))
        }
    }
#endif
