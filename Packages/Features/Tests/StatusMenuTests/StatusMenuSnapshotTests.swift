#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import StatusMenu

    @Suite("Status menu states", .serialized)
    struct StatusMenuSnapshotTests {
        private func menu(
            _ state: StatusMenuModel.PreviewState,
            width: CGFloat = 312,
            menuTextPointSize: CGFloat? = nil,
        ) -> some View {
            StatusMenuView(
                model: .preview(state),
                width: width,
                menuTextPointSize: menuTextPointSize,
                increasedContrastOverride: nil,
            )
            .padding(24)
            .background(Color.dsBackground)
        }

        @Test func normal() {
            assertScreenSnapshot(of: menu(.normal), layout: .sizeThatFits)
        }

        @Test func visualDue() {
            assertScreenSnapshot(of: menu(.visualDue), layout: .sizeThatFits)
        }

        @Test func movementDue() {
            assertScreenSnapshot(of: menu(.movementDue), layout: .sizeThatFits)
        }

        @Test func bothDue() {
            assertScreenSnapshot(of: menu(.bothDue), layout: .sizeThatFits)
        }

        @Test func paused() {
            assertScreenSnapshot(of: menu(.paused), layout: .sizeThatFits)
        }

        @Test func timedPause() {
            assertScreenSnapshot(of: menu(.timedPause), layout: .sizeThatFits)
        }

        @Test func calendarBusy() {
            assertScreenSnapshot(of: menu(.calendarBusy), layout: .sizeThatFits)
        }

        @Test func headsUp() {
            assertScreenSnapshot(of: menu(.headsUp), layout: .sizeThatFits)
        }

        @Test func held() {
            assertScreenSnapshot(of: menu(.held), layout: .sizeThatFits)
        }

        @Test func protected() {
            assertScreenSnapshot(of: menu(.protected), layout: .sizeThatFits)
        }

        @Test func acceptedRitual() {
            assertScreenSnapshot(of: menu(.acceptedRitual), layout: .sizeThatFits)
        }

        @Test func headsUpOff() {
            assertScreenSnapshot(of: menu(.headsUpOff), layout: .sizeThatFits)
        }

        @Test func normalAtAccessibilitySize() {
            assertDynamicTypeSnapshot(
                of: menu(.normal, width: 421.2, menuTextPointSize: 17.55),
                sizes: [.accessibility1],
                layout: .sizeThatFits,
            )
        }

        @Test func normalAtIncreasedContrast() {
            assertScreenSnapshot(
                of: StatusMenuView(
                    model: .preview(.normal),
                    width: 312,
                    increasedContrastOverride: true,
                )
                .padding(24)
                .background(Color.dsBackground),
                layout: .sizeThatFits,
            )
        }
    }
#endif
