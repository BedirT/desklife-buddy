#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import VisualReset

    @Suite("VisualReset screens", .serialized)
    struct VisualResetSnapshotTests {
        private func screen(_ state: VisualResetModel.Phase = .ready) -> some View {
            DesktopSnapshotShell {
                List(selection: .constant(0)) {
                    Text(VisualResetL10n.navigationTitle).tag(0)
                }
                .listStyle(.sidebar)
            } detail: {
                VisualResetView(model: .preview(state), loadsAutomatically: false)
            }
        }

        @Test func loading() {
            assertScreenSnapshot(of: screen(.loading))
        }

        @Test func ready() {
            assertScreenSnapshot(of: screen())
        }

        @Test func failed() {
            assertScreenSnapshot(of: screen(.failed(message: VisualResetL10n.previewError)))
        }
    }

    private struct DesktopSnapshotShell<Sidebar: View, Detail: View>: View {
        let sidebar: Sidebar
        let detail: Detail

        init(
            @ViewBuilder sidebar: () -> Sidebar,
            @ViewBuilder detail: () -> Detail,
        ) {
            self.sidebar = sidebar()
            self.detail = detail()
        }

        var body: some View {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 280)
                    .background(.regularMaterial)

                Divider()

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.dsBackground)
            }
            .frame(width: 1000, height: 700)
            .tint(.dsAccent)
        }
    }
#endif
