#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import StatusMenu

    @Suite("Status menu states", .serialized)
    struct StatusMenuSnapshotTests {
        private func menu(_ state: StatusMenuModel.PreviewState) -> some View {
            StatusMenuView(model: .preview(state))
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

        @Test func paused() {
            assertScreenSnapshot(of: menu(.paused), layout: .sizeThatFits)
        }

        @Test func calendarBusy() {
            assertScreenSnapshot(of: menu(.calendarBusy), layout: .sizeThatFits)
        }

        @Test func headsUp() {
            assertScreenSnapshot(of: menu(.headsUp), layout: .sizeThatFits)
        }
    }
#endif
