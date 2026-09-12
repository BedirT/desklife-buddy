#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import Domain
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import WeeklyRhythm

    @Suite("Weekly rhythm screen", .serialized)
    struct WeeklyRhythmSnapshotTests {
        @Test(arguments: [
            WeeklySnapshotState.populated,
            .sparse,
            .historyDisabled,
        ])
        func primaryStates(_ state: WeeklySnapshotState) {
            assertScreenSnapshot(
                of: screen(state),
                named: state.rawValue,
            )
        }

        @Test func largestText() {
            assertScreenSnapshot(
                of: screen(.populated, textScale: .largest),
                named: "populated-largest-text",
                appearances: [.light],
            )
        }

        @Test func recordedFactsExpanded() {
            assertScreenSnapshot(
                of: screen(.populated, factsExpanded: true),
                named: "populated-recorded-facts",
            )
        }

        @Test func assistantAudit() {
            assertScreenSnapshot(
                of: screen(.populated, audit: snapshotAudit, height: 1100),
                named: "populated-assistant-audit",
                layout: .fixed(width: 1000, height: 1100),
            )
        }

        @Test func increasedContrast() {
            assertScreenSnapshot(
                of: screen(.populated, increaseContrast: true),
                named: "populated-increased-contrast",
                appearances: [.light],
            )
        }

        @Test func reducedMotionEndpoint() {
            assertScreenSnapshot(
                of: screen(.populated, reduceMotion: true),
                named: "populated-reduced-motion",
                appearances: [.light],
            )
        }

        private func screen(
            _ state: WeeklySnapshotState,
            textScale: DSTextScale = .standard,
            increaseContrast: Bool = false,
            reduceMotion: Bool = false,
            factsExpanded: Bool = false,
            audit: WeeklyAssistantAudit? = nil,
            height: CGFloat = 700,
        ) -> some View {
            WeeklyRhythmView(
                model: .preview(state.input, audit: audit),
                calendar: state.input.calendar,
                increaseContrastOverride: increaseContrast,
                reduceMotionOverride: reduceMotion,
                arrivalPresentation: .settled,
                factsExpanded: factsExpanded,
            )
            .environment(\.dsTextScale, textScale)
            .environment(\._colorSchemeContrast, increaseContrast ? .increased : .standard)
            .frame(width: 1000, height: height)
        }

        private var snapshotAudit: WeeklyAssistantAudit {
            WeeklyAssistantAudit(
                proposedRuleCount: 4,
                addedRuleCount: 1,
                pendingRuleCount: 1,
                snoozedRuleCount: 1,
                declinedRuleCount: 1,
                preventedRedundantPromptCount: 3,
                supportingEvidenceCount: 8,
                rulesWithoutRecordedTriggers: 2,
                recordedRowCount: 4,
            )
        }
    }

    enum WeeklySnapshotState: String {
        case populated
        case sparse
        case historyDisabled = "history-disabled"

        var input: WeeklyRhythmProjectionInput {
            switch self {
            case .populated: WeeklyRhythmFixtures.populated
            case .sparse: WeeklyRhythmFixtures.sparse
            case .historyDisabled: WeeklyRhythmFixtures.historyDisabled
            }
        }
    }
#endif
