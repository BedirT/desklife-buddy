import Foundation
import Testing

@testable import Domain

/// Epic 13 R1 RED: deterministic rule-proposal engine core (no UI).
///
/// Rules propose adaptive-quiet behavior inside owner-approved bounds:
/// evidence counts gate firing, per-rule trigger counts are observable,
/// weekly caps bound volume, cooldown timers bound cadence — all
/// tick-injected value semantics (no Date, Task, sleep, or UUID in logic).
/// Statuses run pending → added (Add) / notNow (re-arming snooze) / never
/// (permanent decline), with undo (never permanent) and explicit reset.
/// Proposed rules activate only via Add. Every fired pair stays inside the
/// live firewall bounds (rule proposes, firewall still qualifies).
///
/// Fails before implementation: `RuleProposal`, `RuleProposalStatus`,
/// `RuleCap`, `RuleProposalEngine`, `RuleSuggestion`, and `RuleEvaluation`
/// do not exist.

private let ruleT0: TimeInterval = 10_000
private let ruleSeed = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

private func quietRule(counter: UInt64 = 1) throws -> RuleProposal {
    try RuleProposal(
        id: LedgerIdentity.derive(ledger: .policyDecision, seed: ruleSeed, counter: counter),
        recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
        ruleKey: "quiet-when-weak",
        kindCode: "holdBegin",
        effectCode: "quiet",
        supportingEvidenceCount: 2,
        requiredEvidenceCount: 2,
        status: .pending,
        statusUpdatedTicks: ruleT0,
    )
}

private func smallEngine() -> RuleProposalEngine {
    RuleProposalEngine(
        caps: [
            "quiet-when-weak": RuleCap(weeklyMax: 2, cooldownTicks: 60),
            "shift-within-window": RuleCap(weeklyMax: 2, cooldownTicks: 60),
            "restart-on-strong-motion": RuleCap(weeklyMax: 1, cooldownTicks: 300),
            "release-on-strong-absence": RuleCap(weeklyMax: 2, cooldownTicks: 60),
        ],
        startedAtTicks: ruleT0,
    )
}

// MARK: - Proposal lifecycle

@Test func ruleProposalClosedTableMapsToExistingEffectsOnly() throws {
    for (key, mapping) in RuleProposal.rules {
        #expect(LedgerPolicyDecisionRecord.effects.contains(mapping.effect))
        #expect(LedgerPolicyDecisionRecord.kinds.contains(mapping.kind))
    }
    #expect(Set(RuleProposal.rules.keys) == Set([
        "quiet-when-weak", "shift-within-window",
        "restart-on-strong-motion", "release-on-strong-absence",
    ]))
}

@Test func ruleProposalRejectsUnknownRuleKey() {
    #expect(throws: LedgerStoreError.self) {
        try RuleProposal(
            id: ruleSeed,
            recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
            ruleKey: "grade-the-person",
            kindCode: "holdBegin",
            effectCode: "quiet",
            supportingEvidenceCount: 1,
            requiredEvidenceCount: 1,
            status: .pending,
            statusUpdatedTicks: ruleT0,
        )
    }
}

@Test func ruleProposalRejectsMismatchedKindEffectPair() {
    #expect(throws: LedgerStoreError.self) {
        try RuleProposal(
            id: ruleSeed,
            recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
            ruleKey: "quiet-when-weak",
            kindCode: "sensorStrongMovementRestart",
            effectCode: "restart",
            supportingEvidenceCount: 2,
            requiredEvidenceCount: 2,
            status: .pending,
            statusUpdatedTicks: ruleT0,
        )
    }
}

@Test func pendingRuleNeverFiresBeforeAdd() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let verdict = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 9, atTicks: ruleT0 + 10)
    guard case .inactive(let status) = verdict else {
        Issue.record("pending rule must not fire, got \(verdict)")
        return
    }
    #expect(status == .pending)
}

// MARK: - Add / Not-now / Never transitions

@Test func addActivatesPendingRule() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let added = engine.decide(ruleKey: "quiet-when-weak", decision: .add, atTicks: ruleT0 + 1)
    #expect(added)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .added)
}

@Test func notNowSnoozesUntilRearm() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let snoozed = engine.decide(ruleKey: "quiet-when-weak", decision: .notNow, atTicks: ruleT0 + 1)
    #expect(snoozed)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .notNow)
    // Still snoozed just before the re-arm horizon.
    engine.advance(atTicks: ruleT0 + 1 + RuleProposalEngine.notNowRearmTicks - 1)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .notNow)
    // Re-armed back to pending at the horizon.
    engine.advance(atTicks: ruleT0 + 1 + RuleProposalEngine.notNowRearmTicks)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .pending)
}

@Test func neverIsPermanentDecline() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let declined = engine.decide(ruleKey: "quiet-when-weak", decision: .never, atTicks: ruleT0 + 1)
    #expect(declined)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .never)
    // Re-arm never revives a permanent decline.
    engine.advance(atTicks: ruleT0 + 1 + RuleProposalEngine.notNowRearmTicks + 1)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .never)
    // A declined rule never fires, however strong the evidence.
    let verdict = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 99, atTicks: ruleT0 + 1_000_000)
    guard case .inactive(let status) = verdict else {
        Issue.record("declined rule must not fire, got \(verdict)")
        return
    }
    #expect(status == .never)
}

@Test func resuggestionNeverReactivatesDecline() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let declined = engine.decide(ruleKey: "quiet-when-weak", decision: .never, atTicks: ruleT0 + 1)
    #expect(declined)
    let resuggested = try engine.suggest(quietRule(), atTicks: ruleT0 + 2)
    #expect(resuggested.status == .never)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .never)
}

// MARK: - Caps / cooldown enforcement

@Test func weeklyCapBoundsFires() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let added = engine.decide(ruleKey: "quiet-when-weak", decision: .add, atTicks: ruleT0 + 1)
    #expect(added)
    let firedAtT0Plus10 = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 2, atTicks: ruleT0 + 10)
    #expect(firedAtT0Plus10.isFire)
    let firedAtT0Plus100 = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 2, atTicks: ruleT0 + 100)
    #expect(firedAtT0Plus100.isFire)
    let third = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 2, atTicks: ruleT0 + 200)
    guard case .capped = third else {
        Issue.record("third fire inside one week must cap, got \(third)")
        return
    }
    // Triggers still count while capped: nothing disappears silently.
    #expect(engine.triggerCount(for: "quiet-when-weak") == 3)
    #expect(engine.fireCount(for: "quiet-when-weak") == 2)
}

@Test func cooldownBoundsCadence() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let added = engine.decide(ruleKey: "quiet-when-weak", decision: .add, atTicks: ruleT0 + 1)
    #expect(added)
    let firedAtT0Plus10 = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 2, atTicks: ruleT0 + 10)
    #expect(firedAtT0Plus10.isFire)
    let early = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 2, atTicks: ruleT0 + 11)
    guard case .coolingDown(let remaining) = early else {
        Issue.record("immediate re-fire must cool down, got \(early)")
        return
    }
    #expect(remaining == 59)
    let firedAtT0Plus70 = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 2, atTicks: ruleT0 + 70)
    #expect(firedAtT0Plus70.isFire)
}

@Test func insufficientEvidenceNeverFires() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let added = engine.decide(ruleKey: "quiet-when-weak", decision: .add, atTicks: ruleT0 + 1)
    #expect(added)
    let verdict = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 1, atTicks: ruleT0 + 100)
    guard case .insufficientEvidence(let have, let required) = verdict else {
        Issue.record("weak evidence must not fire, got \(verdict)")
        return
    }
    #expect(have == 1)
    #expect(required == 2)
    #expect(engine.fireCount(for: "quiet-when-weak") == 0)
}

@Test func backwardTicksChangeNothing() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let added = engine.decide(ruleKey: "quiet-when-weak", decision: .add, atTicks: ruleT0 + 1)
    #expect(added)
    let firedAtT0Plus10 = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 2, atTicks: ruleT0 + 10)
    #expect(firedAtT0Plus10.isFire)
    engine.advance(atTicks: ruleT0 - 500)
    #expect(engine.fireCount(for: "quiet-when-weak") == 1)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .added)
}

// MARK: - Undo / reset semantics

@Test func undoRevertsAddToPending() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let added = engine.decide(ruleKey: "quiet-when-weak", decision: .add, atTicks: ruleT0 + 1)
    #expect(added)
    let undone = engine.undo(ruleKey: "quiet-when-weak", atTicks: ruleT0 + 2)
    #expect(undone)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .pending)
    // Nothing left to undo.
    let redundant = engine.undo(ruleKey: "quiet-when-weak", atTicks: ruleT0 + 3)
    #expect(!redundant)
}

@Test func undoRefusesPermanentDecline() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let declined = engine.decide(ruleKey: "quiet-when-weak", decision: .never, atTicks: ruleT0 + 1)
    #expect(declined)
    let refused = engine.undo(ruleKey: "quiet-when-weak", atTicks: ruleT0 + 2)
    #expect(!refused)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .never)
}

@Test func resetClearsStatusCountsAndCooldown() throws {
    var engine = smallEngine()
    try engine.suggest(quietRule(), atTicks: ruleT0)
    let declined = engine.decide(ruleKey: "quiet-when-weak", decision: .never, atTicks: ruleT0 + 1)
    #expect(declined)
    engine.reset(ruleKey: "quiet-when-weak", atTicks: ruleT0 + 2)
    #expect(engine.proposal(for: "quiet-when-weak")?.status == .pending)
    #expect(engine.triggerCount(for: "quiet-when-weak") == 0)
    #expect(engine.fireCount(for: "quiet-when-weak") == 0)
    // Reset re-arms the full path: Add then fire works at once.
    let readded = engine.decide(ruleKey: "quiet-when-weak", decision: .add, atTicks: ruleT0 + 3)
    #expect(readded)
    let firedAtT0Plus4 = engine.evaluate(ruleKey: "quiet-when-weak", evidenceCount: 2, atTicks: ruleT0 + 4)
    #expect(firedAtT0Plus4.isFire)
}

// MARK: - Firewall-clamp compatibility (rule proposes, firewall qualifies)

@Test func everyRuleStaysInsideLiveFirewallBounds() {
    for (key, mapping) in RuleProposal.rules {
        guard let kind = OpportunityActionKind(rawValue: mapping.kind) else {
            Issue.record("rule \(key) names an unregistered kind \(mapping.kind)")
            continue
        }
        #expect(ClosedPolicyFirewall.isEmittable(kind), "rule \(key) must propose a firewall-emittable kind")
    }
    #expect(
        Set(RuleProposal.rules.values.map(\.effect)) == Set(["quiet", "shift", "restart", "resume"]),
        "rules must map onto exactly the existing effect classes",
    )
}

@Test func firedPairsAlwaysSurviveFirewallClamp() throws {
    var engine = smallEngine()
    for key in RuleProposal.rules.keys.sorted() {
        let mapping = RuleProposal.rules[key]!
        let proposal = try RuleProposal(
            id: LedgerIdentity.derive(ledger: .policyDecision, seed: ruleSeed, counter: UInt64(abs(key.hashValue) % 1000 + 10)),
            recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
            ruleKey: key,
            kindCode: mapping.kind,
            effectCode: mapping.effect,
            supportingEvidenceCount: 1,
            requiredEvidenceCount: 1,
            status: .pending,
            statusUpdatedTicks: ruleT0,
        )
        try engine.suggest(proposal, atTicks: ruleT0)
        let loopAdded = engine.decide(ruleKey: key, decision: .add, atTicks: ruleT0 + 1)
        #expect(loopAdded)
        let verdict = engine.evaluate(ruleKey: key, evidenceCount: 1, atTicks: ruleT0 + 10)
        guard case .fire(let kindCode, let effectCode) = verdict else {
            Issue.record("added rule \(key) with sufficient evidence must fire, got \(verdict)")
            continue
        }
        #expect(RuleProposalEngine.isFirewallCompatible(kindCode: kindCode, effectCode: effectCode))
        #expect(LedgerPolicyDecisionRecord.effects.contains(effectCode))
    }
}

@Test func firewallIncompatiblePairNeverValidates() {
    #expect(!RuleProposalEngine.isFirewallCompatible(kindCode: "visualTimerFinished", effectCode: "quiet"))
    #expect(!RuleProposalEngine.isFirewallCompatible(kindCode: "holdBegin", effectCode: "nudge"))
    #expect(!RuleProposalEngine.isFirewallCompatible(kindCode: "holdBegin", effectCode: "restart"))
    #expect(RuleProposalEngine.isFirewallCompatible(kindCode: "holdBegin", effectCode: "quiet"))
    #expect(RuleProposalEngine.isFirewallCompatible(kindCode: "holdBegin", effectCode: "shift"))
    #expect(RuleProposalEngine.isFirewallCompatible(kindCode: "sensorStrongMovementRestart", effectCode: "restart"))
    #expect(RuleProposalEngine.isFirewallCompatible(kindCode: "holdRelease", effectCode: "resume"))
}
