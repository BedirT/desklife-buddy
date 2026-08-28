#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import HeadsUp

    @Suite("Heads-up authored motion", .serialized)
    struct HeadsUpMotionSnapshotTests {
        private let layout = SnapshotLayout.fixed(width: 760, height: 150)

        @Test(
            "Reactive glint has bounded left and right endpoints",
            arguments: [-1.0, 1.0],
        )
        func reactiveGlintEndpoint(_ normalizedGlint: Double) {
            assertScreenSnapshot(
                of: capsule(.preview(
                    scope: .visual,
                    phase: .approaching(.seconds15),
                    normalizedGlint: normalizedGlint,
                )),
                named: normalizedGlint < 0 ? "left" : "right",
                layout: layout,
                appearances: [.light],
            )
        }

        @Test(
            "Restrained entrance has explicit start and settled endpoints",
            arguments: [HeadsUpEntranceEndpoint.before, .after],
        )
        func entranceEndpoint(_ endpoint: HeadsUpEntranceEndpoint) {
            assertScreenSnapshot(
                of: capsule(
                    .preview(scope: .visual),
                    entranceEndpoint: endpoint,
                ),
                named: endpoint.snapshotName,
                layout: layout,
                appearances: [.light],
            )
        }

        @Test("Static presentation renders settled without authored motion")
        func staticPresentation() {
            assertScreenSnapshot(
                of: capsule(.preview(
                    scope: .visual,
                    accessibility: .init(staticPresentation: true),
                )),
                layout: layout,
                appearances: [.light],
            )
        }

        private func capsule(
            _ model: HeadsUpModel,
            entranceEndpoint: HeadsUpEntranceEndpoint = .after,
        ) -> some View {
            HeadsUpView(model: model, entranceEndpoint: entranceEndpoint)
                .padding(DSSpacing.xxl)
                .frame(width: 760, height: 150, alignment: .top)
                .background(Color.dsBackground)
        }
    }

    private extension HeadsUpEntranceEndpoint {
        var snapshotName: String {
            switch self {
            case .automatic: "automatic"
            case .before: "before"
            case .after: "after"
            }
        }
    }
#endif
