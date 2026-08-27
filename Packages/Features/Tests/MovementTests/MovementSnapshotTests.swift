#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import Movement

    @Suite("Movement screens", .serialized)
    struct MovementSnapshotTests {
        private let referenceLayout = SnapshotLayout.fixed(width: 1440, height: 900)

        private func screen(
            selectedChoice: MovementChoice = .walkOrWheel,
            selectedDurationSeconds: TimeInterval = 300,
            remainingSeconds: Int = 225,
            accessibility: MovementAccessibility = .init(),
            focusedControl: MovementControl? = nil,
            context: MovementContext = .standalone,
        ) -> some View {
            MovementView(
                model: .preview(
                    selectedChoice: selectedChoice,
                    selectedDurationSeconds: selectedDurationSeconds,
                    remainingSeconds: remainingSeconds,
                    accessibility: accessibility,
                    context: context,
                ),
                accessibilityOverride: accessibility,
                focusedControlOverride: focusedControl,
                opensAutomatically: false,
            )
            .frame(width: 1440, height: 900)
        }

        @Test func workingReference() {
            assertScreenSnapshot(of: screen(), layout: referenceLayout)
        }

        @Test func smallSpaceSelected() {
            assertScreenSnapshot(
                of: screen(selectedChoice: .smallSpace),
                layout: referenceLayout,
            )
        }

        @Test func seatedQuickOption() {
            assertScreenSnapshot(
                of: screen(
                    selectedChoice: .seated,
                    selectedDurationSeconds: 120,
                    remainingSeconds: 75,
                ),
                layout: referenceLayout,
            )
        }

        @Test func mergedMovementSegment() {
            assertScreenSnapshot(
                of: screen(context: .merged),
                layout: referenceLayout,
            )
        }

        @Test func mergedVisualOnlyFocusState() {
            assertScreenSnapshot(
                of: screen(focusedControl: .visualOnly, context: .merged),
                layout: referenceLayout,
                appearances: [.dark],
            )
        }

        @Test func mergedIncreasedContrast() {
            assertScreenSnapshot(
                of: screen(
                    accessibility: .init(increaseContrast: true),
                    context: .merged,
                ),
                layout: referenceLayout,
            )
        }

        @Test func mergedStaticPresentation() {
            let accessibility = MovementAccessibility(staticPresentation: true)
            assertScreenSnapshot(
                of: ZStack {
                    StaticDesktopReference()
                    screen(accessibility: accessibility, context: .merged)
                },
                layout: referenceLayout,
            )
        }

        @Test func mergedPlusThirtyFivePercentText() {
            assertScreenSnapshot(
                of: screen(context: .merged)
                    .environment(\.dynamicTypeSize, .xxxLarge)
                    .environment(\.dsTextScale, .plusThirtyFivePercent),
                named: "plus-35-percent",
                layout: referenceLayout,
                appearances: [.light],
            )
        }

        @Test func mergedLargestTextCombinedAccessibility() {
            let accessibility = MovementAccessibility(
                reduceMotion: true,
                reduceTransparency: true,
                increaseContrast: true,
            )
            assertScreenSnapshot(
                of: screen(accessibility: accessibility, context: .merged)
                    .environment(\.dynamicTypeSize, .accessibility3)
                    .environment(\.dsTextScale, .largest),
                layout: referenceLayout,
                appearances: [.dark],
            )
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
            assertScreenSnapshot(
                of: screen(accessibility: .init(reduceMotion: true)),
                layout: referenceLayout,
            )
        }

        @Test func staticPresentation() {
            let accessibility = MovementAccessibility(staticPresentation: true)
            assertScreenSnapshot(
                of: ZStack {
                    StaticDesktopReference()
                    screen(accessibility: accessibility)
                },
                layout: referenceLayout,
            )
        }

        @Test func plusThirtyFivePercentText() {
            assertScreenSnapshot(
                of: screen()
                    .environment(\.dynamicTypeSize, .xxxLarge)
                    .environment(\.dsTextScale, .plusThirtyFivePercent),
                named: "plus-35-percent",
                layout: referenceLayout,
                appearances: [.light],
            )
        }

        @Test func largestTextCombinedAccessibility() {
            let accessibility = MovementAccessibility(
                reduceMotion: true,
                reduceTransparency: true,
                increaseContrast: true,
            )
            assertScreenSnapshot(
                of: screen(accessibility: accessibility)
                    .environment(\.dynamicTypeSize, .accessibility3)
                    .environment(\.dsTextScale, .largest),
                layout: referenceLayout,
                appearances: [.dark],
            )
        }

        @Test(
            "Every control has a visible focus state",
            arguments: [
                MovementControl.walkOrWheel,
                .smallSpace,
                .seated,
                .quickDuration,
                .doneEarly,
                .alreadyMoved,
                .skip,
                .positionChange,
            ],
        )
        func focusState(_ control: MovementControl) {
            assertScreenSnapshot(
                of: screen(focusedControl: control),
                named: control.snapshotName,
                layout: referenceLayout,
                appearances: [.dark],
            )
        }
    }

    private struct StaticDesktopReference: View {
        var body: some View {
            LinearGradient(
                colors: [.dsBackground, .dsSurfaceSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.dsSurface)
                    .frame(height: 30)
            }
            .accessibilityHidden(true)
        }
    }

    private extension MovementControl {
        var snapshotName: String {
            switch self {
            case .walkOrWheel: "walk-or-wheel"
            case .smallSpace: "small-space"
            case .seated: "seated"
            case .quickDuration: "quick-duration"
            case .doneEarly: "done-early"
            case .alreadyMoved: "already-moved"
            case .skip: "skip"
            case .positionChange: "position-change"
            case .visualOnly: "visual-only"
            }
        }
    }
#endif
