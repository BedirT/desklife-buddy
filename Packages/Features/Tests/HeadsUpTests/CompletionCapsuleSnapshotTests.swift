#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import HeadsUp

    @Suite("Completion capsule", .serialized)
    struct CompletionCapsuleSnapshotTests {
        private let layout = SnapshotLayout.fixed(width: 360, height: 140)

        @Test(
            "Wordless completion endpoints",
            arguments: [CompletionCapsuleEndpoint.before, .after],
        )
        func endpoint(_ endpoint: CompletionCapsuleEndpoint) {
            assertScreenSnapshot(
                of: CompletionCapsuleView(endpoint: endpoint)
                    .padding(DSSpacing.xxl)
                    .frame(width: 360, height: 140)
                    .background(Color.dsBackground),
                named: endpoint.snapshotName,
                layout: layout,
            )
        }

        @Test func fixedTopCenterContext() {
            assertScreenSnapshot(
                of: CompletionCapsulePlacementPreview(),
                layout: .fixed(width: 1000, height: 220),
            )
        }
    }

    private extension CompletionCapsuleEndpoint {
        var snapshotName: String {
            switch self {
            case .before: "before"
            case .after, .automatic: "after"
            }
        }
    }
#endif
