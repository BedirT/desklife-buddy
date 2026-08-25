#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import Domain
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import ItemList

    // Renders the same states the previews declare. Run via scripts/snapshot.sh.
    // First run records missing baselines; after that, agents inspect the colored
    // diff and accept exact reviewed bytes. Bulk re-recording remains human-only.
//
    // The .tint mirrors RootView's composition so snapshots see real app chrome.

    @Suite("ItemList screens", .serialized)
    struct ItemListSnapshotTests {
        private func screen(_ state: ItemListModel.PreviewState) -> some View {
            DesktopSnapshotShell {
                ItemListView(model: .preview(state), selection: .constant(nil), loadsAutomatically: false)
            } detail: {
                ItemDetailPlaceholder()
            }
        }

        @Test func loaded() {
            assertScreenSnapshot(of: screen(.loaded))
        }

        @Test func loading() {
            assertScreenSnapshot(of: screen(.loading))
        }

        @Test func empty() {
            assertScreenSnapshot(of: screen(.empty))
        }

        @Test func failed() {
            assertScreenSnapshot(of: screen(.failed))
        }

        @Test func loadedAtAccessibilitySize() {
            assertDynamicTypeSnapshot(of: screen(.loaded))
        }
    }

    @Suite("ItemDetail screens", .serialized)
    struct ItemDetailSnapshotTests {
        private func screen(_ item: Item) -> some View {
            DesktopSnapshotShell {
                ItemListView(model: .preview(.loaded), selection: .constant(item.id), loadsAutomatically: false)
            } detail: {
                ItemDetailView(item: item)
            }
        }

        @Test func openItem() {
            assertScreenSnapshot(of: screen(SampleData.items(now: SampleData.referenceDate)[1]))
        }

        @Test func doneItem() {
            assertScreenSnapshot(of: screen(SampleData.items(now: SampleData.referenceDate)[0]))
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
