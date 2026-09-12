import Domain
import SwiftUI

#Preview("WK-01 · Populated") {
    WeeklyRhythmView(
        model: .preview(WeeklyRhythmFixtures.populated),
        calendar: WeeklyRhythmFixtures.populated.calendar,
        arrivalPresentation: .settled,
    )
    .frame(width: 1000, height: 700)
}

#Preview("WK-02 · First week") {
    WeeklyRhythmView(
        model: .preview(WeeklyRhythmFixtures.sparse),
        calendar: WeeklyRhythmFixtures.sparse.calendar,
        arrivalPresentation: .settled,
    )
    .frame(width: 1000, height: 700)
}

#Preview("WK-01 · Recorded facts") {
    WeeklyRhythmView(
        model: .preview(WeeklyRhythmFixtures.populated),
        calendar: WeeklyRhythmFixtures.populated.calendar,
        arrivalPresentation: .settled,
        factsExpanded: true,
    )
    .frame(width: 1000, height: 700)
}

#Preview("WK-03 · History disabled") {
    WeeklyRhythmView(
        model: .preview(WeeklyRhythmFixtures.historyDisabled),
        calendar: WeeklyRhythmFixtures.historyDisabled.calendar,
        arrivalPresentation: .settled,
    )
    .frame(width: 1000, height: 700)
}

#Preview("WK-04 · Adjusted schedule") {
    WeeklyRhythmView(
        model: .preview(WeeklyRhythmFixtures.adjustedSchedule),
        calendar: WeeklyRhythmFixtures.adjustedSchedule.calendar,
        arrivalPresentation: .settled,
    )
    .frame(width: 1000, height: 700)
}

#Preview("Loading") {
    WeeklyRhythmView(
        model: .preview(state: .loading),
        arrivalPresentation: .settled,
    )
    .frame(width: 1000, height: 700)
}

#Preview("WK-05 · Assistant audit") {
    WeeklyRhythmView(
        model: .preview(
            WeeklyRhythmFixtures.populated,
            audit: WeeklyAssistantAudit(
                proposedRuleCount: 4,
                addedRuleCount: 1,
                pendingRuleCount: 1,
                snoozedRuleCount: 1,
                declinedRuleCount: 1,
                preventedRedundantPromptCount: 3,
                supportingEvidenceCount: 8,
                rulesWithoutRecordedTriggers: 2,
                recordedRowCount: 4,
            ),
        ),
        calendar: WeeklyRhythmFixtures.populated.calendar,
        arrivalPresentation: .settled,
    )
    .frame(width: 1000, height: 1000)
}
