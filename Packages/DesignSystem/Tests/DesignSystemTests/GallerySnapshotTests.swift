#if os(macOS) && SNAPSHOT_TESTS
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import DesignSystem

    // The design system's visual contract. A failing test here means a token or
    // component changed appearance. Agents may accept exact bytes from the
    // colored review; bulk scripts/record-snapshots.sh remains human-run.

    @Suite("Design system gallery", .serialized)
    struct GallerySnapshotTests {
        @Test func tokens() {
            assertScreenSnapshot(
                of: DSGallery.TokensSection()
                    .padding(DSSpacing.lg)
                    .background(Color.dsBackground)
                    .frame(width: 520),
                layout: .sizeThatFits,
            )
        }

        @Test func components() {
            assertScreenSnapshot(
                of: DSGallery.ComponentsSection()
                    .padding(DSSpacing.lg)
                    .background(Color.dsBackground)
                    .frame(width: 520),
                layout: .sizeThatFits,
            )
        }

        @Test func movementControls() {
            assertScreenSnapshot(
                of: DSGallery.MovementControlsSection()
                    .padding(DSSpacing.lg)
                    .background(Color.dsBackground)
                    .frame(width: 1120),
                layout: .sizeThatFits,
            )
        }
    }
#endif
