#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import BreakFlow

    @Suite("Break flow screens", .serialized)
    struct BreakFlowSnapshotTests {
        private let fieldLayout = SnapshotLayout.fixed(width: 1440, height: 900)
        private let sheetLayout = SnapshotLayout.fixed(width: 1000, height: 700)

        private func field(
            _ surface: BreakFlowSurface,
            accessibility: BreakFlowAccessibility = .init(),
            focusedControl: BreakFlowControl? = nil,
        ) -> some View {
            BreakFlowView(
                model: .preview(surface),
                accessibilityOverride: accessibility,
                focusedControlOverride: focusedControl,
            )
            .frame(width: 1440, height: 900)
        }

        private func snooze(
            scope: BreakScope,
            calendarEnd: Date? = nil,
            focusedControl: BreakFlowControl? = nil,
            accessibility: BreakFlowAccessibility? = nil,
        ) -> some View {
            BreakFlowView(
                model: .preview(.snooze(scope: scope, calendarEnd: calendarEnd)),
                accessibilityOverride: accessibility,
                focusedControlOverride: focusedControl,
            )
            .frame(width: 1000, height: 700)
        }

        @Test func visualOnlyAcknowledgement() {
            assertScreenSnapshot(
                of: field(.visualOnlyAcknowledgement),
                layout: fieldLayout,
            )
        }

        @Test func visualOnlyStaticPresentation() {
            let accessibility = BreakFlowAccessibility(staticPresentation: true)
            assertScreenSnapshot(
                of: ZStack {
                    StaticDesktopReference()
                    field(.visualOnlyAcknowledgement, accessibility: accessibility)
                },
                layout: fieldLayout,
            )
        }

        @Test func visualOnlyIncreasedContrast() {
            assertScreenSnapshot(
                of: field(
                    .visualOnlyAcknowledgement,
                    accessibility: .init(increaseContrast: true),
                ),
                layout: fieldLayout,
            )
        }

        @Test func visualOnlyPlusThirtyFivePercentText() {
            assertScreenSnapshot(
                of: field(.visualOnlyAcknowledgement)
                    .environment(\.dsTextScale, .plusThirtyFivePercent),
                named: "plus-35-percent",
                layout: fieldLayout,
                appearances: [.light],
            )
        }

        @Test func visualOnlyLargestTextCombinedAccessibility() {
            let accessibility = BreakFlowAccessibility(
                reduceMotion: true,
                reduceTransparency: true,
                increaseContrast: true,
            )
            assertScreenSnapshot(
                of: field(.visualOnlyAcknowledgement, accessibility: accessibility)
                    .environment(\.dynamicTypeSize, .accessibility3)
                    .environment(\.dsTextScale, .largest),
                layout: fieldLayout,
                appearances: [.dark],
            )
        }

        @Test func recoveryOffer() {
            assertScreenSnapshot(of: field(.recoveryOffer), layout: fieldLayout)
        }

        @Test func recoveryIncreasedContrast() {
            assertScreenSnapshot(
                of: field(.recoveryOffer, accessibility: .init(increaseContrast: true)),
                layout: fieldLayout,
            )
        }

        @Test func recoveryReducedTransparency() {
            assertScreenSnapshot(
                of: field(.recoveryOffer, accessibility: .init(reduceTransparency: true)),
                layout: fieldLayout,
            )
        }

        @Test func recoveryStaticPresentation() {
            let accessibility = BreakFlowAccessibility(staticPresentation: true)
            assertScreenSnapshot(
                of: ZStack {
                    StaticDesktopReference()
                    field(.recoveryOffer, accessibility: accessibility)
                },
                layout: fieldLayout,
            )
        }

        @Test func recoveryPlusThirtyFivePercentText() {
            assertScreenSnapshot(
                of: field(.recoveryOffer)
                    .environment(\.dynamicTypeSize, .xxxLarge)
                    .environment(\.dsTextScale, .plusThirtyFivePercent),
                named: "plus-35-percent",
                layout: fieldLayout,
                appearances: [.light],
            )
        }

        @Test func recoveryLargestTextCombinedAccessibility() {
            let accessibility = BreakFlowAccessibility(
                reduceMotion: true,
                reduceTransparency: true,
                increaseContrast: true,
            )
            assertScreenSnapshot(
                of: field(.recoveryOffer, accessibility: accessibility)
                    .environment(\.dynamicTypeSize, .accessibility3)
                    .environment(\.dsTextScale, .largest),
                layout: fieldLayout,
                appearances: [.dark],
            )
        }

        @Test(
            "Every recovery action has a visible focus state",
            arguments: [
                BreakFlowControl.recoveryFive,
                .recoveryTen,
                .recoveryNotNow,
            ],
        )
        func recoveryFocusState(_ control: BreakFlowControl) {
            assertScreenSnapshot(
                of: field(.recoveryOffer, focusedControl: control),
                named: control.snapshotName,
                layout: fieldLayout,
                appearances: [.dark],
            )
        }

        @Test func recoveryInitialFocusLight() {
            assertScreenSnapshot(
                of: field(.recoveryOffer, focusedControl: .recoveryFive),
                layout: fieldLayout,
                appearances: [.light],
            )
        }

        @Test func recoveryInitialFocusIncreasedContrast() {
            assertScreenSnapshot(
                of: field(
                    .recoveryOffer,
                    accessibility: .init(increaseContrast: true),
                    focusedControl: .recoveryFive,
                ),
                layout: fieldLayout,
                appearances: [.light],
            )
        }

        @Test func snoozeWithoutCalendar() {
            assertScreenSnapshot(of: snooze(scope: .visual), layout: sheetLayout)
        }

        @Test func mergedSnoozeWithCalendar() {
            assertScreenSnapshot(
                of: snooze(scope: .merged, calendarEnd: meetingEnd),
                layout: sheetLayout,
            )
        }

        @Test func mergedSnoozeWithoutCalendar() {
            assertScreenSnapshot(of: snooze(scope: .merged), layout: sheetLayout)
        }

        @Test func snoozePlusThirtyFivePercentText() {
            assertScreenSnapshot(
                of: snooze(scope: .merged, calendarEnd: meetingEnd)
                    .environment(\.dynamicTypeSize, .xxxLarge)
                    .environment(\.dsTextScale, .plusThirtyFivePercent),
                named: "plus-35-percent",
                layout: sheetLayout,
                appearances: [.light],
            )
        }

        @Test func snoozeLargestText() {
            assertScreenSnapshot(
                of: snooze(scope: .merged, calendarEnd: meetingEnd)
                    .environment(\.dynamicTypeSize, .accessibility3)
                    .environment(\.dsTextScale, .largest),
                named: "largest",
                layout: sheetLayout,
                appearances: [.light],
            )
        }

        @Test(
            "Every snooze action has a visible focus state",
            arguments: [
                BreakFlowControl.snooze(300),
                .snooze(600),
                .snooze(900),
                .afterMeeting,
                .pauseOneHour,
                .notAppropriate,
                .skip,
            ],
        )
        func snoozeFocusState(_ control: BreakFlowControl) {
            assertScreenSnapshot(
                of: snooze(
                    scope: .merged,
                    calendarEnd: meetingEnd,
                    focusedControl: control,
                ),
                named: control.snapshotName,
                layout: sheetLayout,
                appearances: [.dark],
            )
        }

        @Test func snoozeInitialFocusLight() {
            assertScreenSnapshot(
                of: snooze(
                    scope: .merged,
                    calendarEnd: meetingEnd,
                    focusedControl: .snooze(300),
                ),
                layout: sheetLayout,
                appearances: [.light],
            )
        }

        @Test func snoozeInitialFocusIncreasedContrast() {
            assertScreenSnapshot(
                of: snooze(
                    scope: .merged,
                    calendarEnd: meetingEnd,
                    focusedControl: .snooze(300),
                    accessibility: .init(increaseContrast: true),
                ),
                layout: sheetLayout,
                appearances: [.light],
            )
        }

        private var meetingEnd: Date {
            Date(timeIntervalSinceReferenceDate: 1000)
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

    private extension BreakFlowControl {
        var snapshotName: String {
            switch self {
            case .recoveryFive: "recovery-five"
            case .recoveryTen: "recovery-ten"
            case .recoveryNotNow: "recovery-not-now"
            case let .snooze(duration): "snooze-\(Int(duration))"
            case .afterMeeting: "after-meeting"
            case .pauseOneHour: "pause-one-hour"
            case .notAppropriate: "not-appropriate"
            case .skip: "skip"
            }
        }
    }
#endif
