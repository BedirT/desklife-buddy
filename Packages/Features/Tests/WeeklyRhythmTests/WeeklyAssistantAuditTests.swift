import Domain
import Foundation
import Testing
@testable import WeeklyRhythm

/// Epic 13 R2 RED-first: the Weekly descriptive assistant audit.
///
/// The audit aggregates R1 engine facts (rule counts by status,
/// prevented-redundant-prompt counts, evidence counts, unused-rule and
/// recorded-row counts) into counts only. Copy stays descriptive: no
/// scores, streaks, praise, shame, grades, or causal health claims.
///
/// Fails before implementation: `WeeklyAssistantAudit` does not exist.
@Suite("Weekly assistant audit")
struct WeeklyAssistantAuditTests {
    private func proposal(
        ruleKey: String,
        kindCode: String,
        effectCode: String,
        status: RuleProposalStatus,
        evidence: Int = 2,
        required: Int = 2,
    ) throws -> RuleProposal {
        try RuleProposal(
            id: UUID(),
            recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
            ruleKey: ruleKey,
            kindCode: kindCode,
            effectCode: effectCode,
            supportingEvidenceCount: evidence,
            requiredEvidenceCount: required,
            status: status,
            statusUpdatedTicks: 10_000,
        )
    }

    @Test("Empty engine facts aggregate to zero counts")
    func emptyAggregatesToZero() {
        let audit = WeeklyAssistantAudit.aggregate(proposals: [], triggerCounts: [:], fireCounts: [:])
        #expect(audit.proposedRuleCount == 0)
        #expect(audit.addedRuleCount == 0)
        #expect(audit.pendingRuleCount == 0)
        #expect(audit.snoozedRuleCount == 0)
        #expect(audit.declinedRuleCount == 0)
        #expect(audit.preventedRedundantPromptCount == 0)
        #expect(audit.supportingEvidenceCount == 0)
        #expect(audit.recordedRowCount == 0)
        #expect(audit.rulesWithoutRecordedTriggers == RuleProposal.rules.count)
    }

    @Test("Rule counts follow owner status, not suggestion order")
    func countsFollowStatus() throws {
        let proposals = try [
            proposal(ruleKey: "quiet-when-weak", kindCode: "holdBegin", effectCode: "quiet", status: .added),
            proposal(
                ruleKey: "shift-within-window",
                kindCode: "holdBegin",
                effectCode: "shift",
                status: .notNow,
            ),
            proposal(
                ruleKey: "restart-on-strong-motion",
                kindCode: "sensorStrongMovementRestart",
                effectCode: "restart",
                status: .never,
            ),
            proposal(
                ruleKey: "release-on-strong-absence",
                kindCode: "holdRelease",
                effectCode: "resume",
                status: .pending,
            ),
        ]
        let audit = WeeklyAssistantAudit.aggregate(proposals: proposals, triggerCounts: [:], fireCounts: [:])
        #expect(audit.proposedRuleCount == 4)
        #expect(audit.addedRuleCount == 1)
        #expect(audit.pendingRuleCount == 1)
        #expect(audit.snoozedRuleCount == 1)
        #expect(audit.declinedRuleCount == 1)
        #expect(audit.recordedRowCount == 4)
    }

    @Test("Prevented prompts are triggers minus fires, never negative")
    func preventedPromptsAreTriggersMinusFires() throws {
        let proposals = try [
            proposal(ruleKey: "quiet-when-weak", kindCode: "holdBegin", effectCode: "quiet", status: .added),
        ]
        let audit = WeeklyAssistantAudit.aggregate(
            proposals: proposals,
            triggerCounts: ["quiet-when-weak": 5],
            fireCounts: ["quiet-when-weak": 2],
        )
        #expect(audit.preventedRedundantPromptCount == 3)
    }

    @Test("Fires without recorded triggers clamp prevented prompts at zero")
    func preventedPromptsClampAtZero() throws {
        let proposals = try [
            proposal(ruleKey: "quiet-when-weak", kindCode: "holdBegin", effectCode: "quiet", status: .added),
        ]
        let audit = WeeklyAssistantAudit.aggregate(
            proposals: proposals,
            triggerCounts: [:],
            fireCounts: ["quiet-when-weak": 2],
        )
        #expect(audit.preventedRedundantPromptCount == 0)
    }

    @Test("Evidence counts sum supporting records across proposals")
    func evidenceCountsSum() throws {
        let proposals = try [
            proposal(
                ruleKey: "quiet-when-weak",
                kindCode: "holdBegin",
                effectCode: "quiet",
                status: .added,
                evidence: 3,
            ),
            proposal(
                ruleKey: "shift-within-window",
                kindCode: "holdBegin",
                effectCode: "shift",
                status: .pending,
                evidence: 1,
            ),
        ]
        let audit = WeeklyAssistantAudit.aggregate(proposals: proposals, triggerCounts: [:], fireCounts: [:])
        #expect(audit.supportingEvidenceCount == 4)
    }

    @Test("Unused rows count closed-table rules with no recorded triggers")
    func unusedRowsCountTriggerlessRules() throws {
        let proposals = try [
            proposal(ruleKey: "quiet-when-weak", kindCode: "holdBegin", effectCode: "quiet", status: .added),
        ]
        let audit = WeeklyAssistantAudit.aggregate(
            proposals: proposals,
            triggerCounts: ["quiet-when-weak": 2],
            fireCounts: ["quiet-when-weak": 1],
        )
        #expect(audit.rulesWithoutRecordedTriggers == RuleProposal.rules.count - 1)
    }

    @Test("Audit copy stays descriptive: no scores, streaks, praise, shame, grades, or health claims")
    func auditCopyStaysDescriptive() {
        let copy = [
            WeeklyRhythmL10n.auditTitle,
            WeeklyRhythmL10n.auditDetail,
            WeeklyRhythmL10n.auditProposedRules,
            WeeklyRhythmL10n.auditPendingRules,
            WeeklyRhythmL10n.auditAddedRules,
            WeeklyRhythmL10n.auditSnoozedRules,
            WeeklyRhythmL10n.auditDeclinedRules,
            WeeklyRhythmL10n.auditPreventedPrompts,
            WeeklyRhythmL10n.auditSupportingEvidence,
            WeeklyRhythmL10n.auditUnusedRules,
            WeeklyRhythmL10n.auditRecordedRows,
            WeeklyRhythmL10n.auditReviewRules,
        ]
        let banned = [
            "score", "streak", "praise", "shame", "grade",
            "compliance", "compliant", "improv", "health",
            "better", "worse", "goal", "target", "achiev",
            "cause", "because", "should",
        ]
        for text in copy {
            #expect(!text.isEmpty, "audit copy must not be empty")
            for word in banned {
                #expect(
                    !text.localizedCaseInsensitiveContains(word),
                    "audit copy must stay descriptive: '\(text)' contains '\(word)'",
                )
            }
        }
    }
}
