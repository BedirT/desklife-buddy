import Domain
import Foundation

/// Descriptive assistant audit for the Weekly surface (Epic 13 R2).
///
/// Counts only, projected from R1 engine facts: rule counts by owner
/// status, redundant prompts held back by caps and cooldowns, supporting
/// evidence records, rules with no recorded triggers, and recorded rows.
/// Carries no scores, streaks, praise, shame, grades, comparisons, or
/// causal claims about the person.
public struct WeeklyAssistantAudit: Equatable, Sendable {
    public var proposedRuleCount: Int
    public var addedRuleCount: Int
    public var pendingRuleCount: Int
    public var snoozedRuleCount: Int
    public var declinedRuleCount: Int
    public var preventedRedundantPromptCount: Int
    public var supportingEvidenceCount: Int
    public var rulesWithoutRecordedTriggers: Int
    public var recordedRowCount: Int

    public init(
        proposedRuleCount: Int = 0,
        addedRuleCount: Int = 0,
        pendingRuleCount: Int = 0,
        snoozedRuleCount: Int = 0,
        declinedRuleCount: Int = 0,
        preventedRedundantPromptCount: Int = 0,
        supportingEvidenceCount: Int = 0,
        rulesWithoutRecordedTriggers: Int = RuleProposal.rules.count,
        recordedRowCount: Int = 0,
    ) {
        self.proposedRuleCount = proposedRuleCount
        self.addedRuleCount = addedRuleCount
        self.pendingRuleCount = pendingRuleCount
        self.snoozedRuleCount = snoozedRuleCount
        self.declinedRuleCount = declinedRuleCount
        self.preventedRedundantPromptCount = preventedRedundantPromptCount
        self.supportingEvidenceCount = supportingEvidenceCount
        self.rulesWithoutRecordedTriggers = rulesWithoutRecordedTriggers
        self.recordedRowCount = recordedRowCount
    }

    /// Aggregates R1 facts into descriptive counts. Triggers counted past
    /// the throttle minus fires are the redundant prompts held back;
    /// the difference clamps at zero so inconsistent inputs stay honest.
    /// Unused rows count closed-table rules with no recorded triggers.
    public static func aggregate(
        proposals: [RuleProposal],
        triggerCounts: [String: Int],
        fireCounts: [String: Int],
    ) -> WeeklyAssistantAudit {
        var added = 0
        var pending = 0
        var snoozed = 0
        var declined = 0
        var evidence = 0
        for proposal in proposals {
            switch proposal.status {
            case .added: added += 1
            case .pending: pending += 1
            case .notNow: snoozed += 1
            case .never: declined += 1
            }
            evidence += proposal.supportingEvidenceCount
        }
        let triggers = triggerCounts.values.reduce(0, +)
        let fires = fireCounts.values.reduce(0, +)
        let unused = RuleProposal.rules.keys.filter { triggerCounts[$0, default: 0] == 0 }.count
        return WeeklyAssistantAudit(
            proposedRuleCount: proposals.count,
            addedRuleCount: added,
            pendingRuleCount: pending,
            snoozedRuleCount: snoozed,
            declinedRuleCount: declined,
            preventedRedundantPromptCount: max(0, triggers - fires),
            supportingEvidenceCount: evidence,
            rulesWithoutRecordedTriggers: unused,
            recordedRowCount: proposals.count,
        )
    }
}
