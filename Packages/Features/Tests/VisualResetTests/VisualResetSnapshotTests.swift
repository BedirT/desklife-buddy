#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import VisualReset

    @Suite("VisualReset screens", .serialized)
    struct VisualResetSnapshotTests {
        private let referenceLayout = SnapshotLayout.fixed(width: 1440, height: 900)

        private func screen(
            _ phase: VisualResetModel.Phase = .running,
            accessibility: VisualResetAccessibility = .init(),
            standardField: AnyView? = nil,
            staticField: AnyView? = nil,
        ) -> some View {
            VisualResetView(
                model: .preview(phase, accessibility: accessibility),
                standardField: standardField,
                staticField: staticField,
                accessibilityOverride: accessibility,
            )
            .frame(width: 1440, height: 900)
        }

        @Test func workingReference() {
            assertScreenSnapshot(of: screen(), layout: referenceLayout)
        }

        @Test func finalSeconds() {
            assertScreenSnapshot(of: screen(.finalSeconds), layout: referenceLayout)
        }

        @Test func increasedContrast() {
            assertScreenSnapshot(
                of: screen(accessibility: .init(increaseContrast: true)),
                layout: referenceLayout,
            )
        }

        @Test func reducedTransparency() {
            assertScreenSnapshot(
                of: screen(accessibility: .init(reduceTransparency: true)),
                layout: referenceLayout,
            )
        }

        @Test func reducedMotion() {
            let accessibility = VisualResetAccessibility(reduceMotion: true)
            assertScreenSnapshot(
                of: screen(accessibility: accessibility),
                layout: referenceLayout,
            )
        }

        @Test func plusThirtyFivePercentText() {
            assertDynamicTypeSnapshot(
                of: screen(),
                sizes: [.xxxLarge],
                layout: referenceLayout,
            )
        }

        @Test func largestText() {
            assertDynamicTypeSnapshot(
                of: screen(),
                sizes: [.accessibility3],
                layout: referenceLayout,
            )
        }

        @Test func largestTextDark() {
            assertScreenSnapshot(
                of: screen().environment(\.dynamicTypeSize, .accessibility3),
                layout: referenceLayout,
                appearances: [.dark],
            )
        }

        @Test func largestTextCombinedAccessibility() {
            let accessibility = VisualResetAccessibility(
                reduceTransparency: true,
                increaseContrast: true,
            )
            assertScreenSnapshot(
                of: screen(accessibility: accessibility)
                    .environment(\.dynamicTypeSize, .accessibility3),
                layout: referenceLayout,
                appearances: [.dark],
            )
        }

        @Test func brightBackdrop() {
            assertScreenSnapshot(
                of: screen(standardField: AnyView(Color.dsBreakSkyTop)),
                layout: referenceLayout,
                appearances: [.light],
            )
        }

        @Test func darkBackdrop() {
            assertScreenSnapshot(
                of: screen(standardField: AnyView(Color.dsBreakGroundBottom)),
                layout: referenceLayout,
                appearances: [.dark],
            )
        }

        @Test func injectedStaticPresentation() {
            let accessibility = VisualResetAccessibility(staticPresentation: true)
            assertScreenSnapshot(
                of: screen(
                    accessibility: accessibility,
                    staticField: AnyView(Color.dsBreakControlSolid),
                ),
                layout: referenceLayout,
                appearances: [.light],
            )
        }
    }
#endif
