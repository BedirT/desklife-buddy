import Foundation

/// One rule-proposal lifecycle state (Epic 13 R1, engine core).
///
/// Proposed rules surface an owner decision — Add, Not now, or Never — and
/// activate only via Add. Not now re-arms to pending at the re-arm horizon;
/// Never is a permanent decline that only an explicit reset escapes.
public enum RuleProposalStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case pending
    case added
    case notNow
    case never
}

/// The owner decision applied to one proposed rule.
public enum RuleDecision: String, Hashable, Sendable {
    case add
    case notNow
    case never
}

/// One per-rule throttle: at most `weeklyMax` fires per rolling seven-day
/// tick window, spaced at least `cooldownTicks` apart. Tick-injected like
/// `GovernorBudget`: the engine never reads a clock.
public struct RuleCap: Equatable, Hashable, Sendable {
    public let weeklyMax: Int
    public let cooldownTicks: TimeInterval

    public init(weeklyMax: Int, cooldownTicks: TimeInterval) {
        precondition(weeklyMax > 0, "RuleCap weeklyMax must be positive")
        precondition(cooldownTicks > 0, "RuleCap cooldownTicks must be positive")
        self.weeklyMax = weeklyMax
        self.cooldownTicks = cooldownTicks
    }
}

/// One deterministic rule proposal (Epic 13 R1, engine core).
///
/// A rule is data in a closed table, never code: each `ruleKey` maps to
/// exactly one firewall-emittable kind plus one existing effect class
/// (quiet/shift/restart/resume — never a payload, never a new vocabulary).
/// Inputs exclude app identity, protected traits, OCR/raw timelines, raw
/// sensors, and semantic location by construction: the row carries counts
/// and codes only. Grades no person and states no health outcome.
public struct RuleProposal: Equatable, Hashable, Sendable, Codable {
    /// Closed rule table: rule key to its (kind, effect) mapping. The kinds
    /// are the firewall-emittable family; the effects are the existing
    /// policy-decision effect classes.
    public static let rules: [String: (kind: String, effect: String)] = [
        "quiet-when-weak": (kind: "holdBegin", effect: "quiet"),
        "shift-within-window": (kind: "holdBegin", effect: "shift"),
        "restart-on-strong-motion": (kind: "sensorStrongMovementRestart", effect: "restart"),
        "release-on-strong-absence": (kind: "holdRelease", effect: "resume"),
    ]

    public let id: UUID
    public let recordedAt: Date
    public let ruleKey: String
    public let kindCode: String
    public let effectCode: String
    public let supportingEvidenceCount: Int
    public let requiredEvidenceCount: Int
    public let status: RuleProposalStatus
    public let statusUpdatedTicks: TimeInterval

    public init(
        id: UUID,
        recordedAt: Date,
        ruleKey: String,
        kindCode: String,
        effectCode: String,
        supportingEvidenceCount: Int,
        requiredEvidenceCount: Int,
        status: RuleProposalStatus,
        statusUpdatedTicks: TimeInterval,
    ) throws {
        guard let mapping = Self.rules[ruleKey] else {
            throw LedgerStoreError.invalidRecord("rule-proposal key \(ruleKey)")
        }
        guard mapping.kind == kindCode, mapping.effect == effectCode else {
            throw LedgerStoreError.invalidRecord("rule-proposal pair \(kindCode)/\(effectCode)")
        }
        guard RuleProposalEngine.isFirewallCompatible(kindCode: kindCode, effectCode: effectCode) else {
            throw LedgerStoreError.invalidRecord("rule-proposal outside firewall bounds")
        }
        guard supportingEvidenceCount >= 0 else {
            throw LedgerStoreError.invalidRecord("rule-proposal evidence")
        }
        guard requiredEvidenceCount > 0 else {
            throw LedgerStoreError.invalidRecord("rule-proposal required evidence")
        }
        guard statusUpdatedTicks.isFinite else {
            throw LedgerStoreError.invalidRecord("rule-proposal ticks")
        }
        self.id = id
        self.recordedAt = recordedAt
        self.ruleKey = ruleKey
        self.kindCode = kindCode
        self.effectCode = effectCode
        self.supportingEvidenceCount = supportingEvidenceCount
        self.requiredEvidenceCount = requiredEvidenceCount
        self.status = status
        self.statusUpdatedTicks = statusUpdatedTicks
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case recordedAt
        case ruleKey
        case kindCode
        case effectCode
        case supportingEvidenceCount
        case requiredEvidenceCount
        case status
        case statusUpdatedTicks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            recordedAt: container.decode(Date.self, forKey: .recordedAt),
            ruleKey: container.decode(String.self, forKey: .ruleKey),
            kindCode: container.decode(String.self, forKey: .kindCode),
            effectCode: container.decode(String.self, forKey: .effectCode),
            supportingEvidenceCount: container.decode(Int.self, forKey: .supportingEvidenceCount),
            requiredEvidenceCount: container.decode(Int.self, forKey: .requiredEvidenceCount),
            status: container.decode(RuleProposalStatus.self, forKey: .status),
            statusUpdatedTicks: container.decode(TimeInterval.self, forKey: .statusUpdatedTicks),
        )
    }
    /// Returns a copy moved to a new lifecycle state. The closed-table and
    /// firewall checks re-run, so a status move can never widen the pair.
    func withStatus(_ status: RuleProposalStatus, atTicks ticks: TimeInterval) throws -> RuleProposal {
        try RuleProposal(
            id: id,
            recordedAt: recordedAt,
            ruleKey: ruleKey,
            kindCode: kindCode,
            effectCode: effectCode,
            supportingEvidenceCount: supportingEvidenceCount,
            requiredEvidenceCount: requiredEvidenceCount,
            status: status,
            statusUpdatedTicks: ticks,
        )
    }

    /// Returns a copy carrying refreshed evidence with the owner status
    /// preserved, so re-suggestion never reactivates a decision.
    func withEvidence(_ proposal: RuleProposal) throws -> RuleProposal {
        try RuleProposal(
            id: proposal.id,
            recordedAt: proposal.recordedAt,
            ruleKey: proposal.ruleKey,
            kindCode: proposal.kindCode,
            effectCode: proposal.effectCode,
            supportingEvidenceCount: proposal.supportingEvidenceCount,
            requiredEvidenceCount: proposal.requiredEvidenceCount,
            status: status,
            statusUpdatedTicks: statusUpdatedTicks,
        )
    }

    /// Full export row; the exporter keeps selected keys only.
    public func exportRow() -> [String: String] {
        [
            "id": id.uuidString.lowercased(),
            "recordedAt": String(recordedAt.timeIntervalSince1970),
            "ruleKey": ruleKey,
            "kind": kindCode,
            "effect": effectCode,
            "status": status.rawValue,
            "evidence": String(supportingEvidenceCount),
            "requiredEvidence": String(requiredEvidenceCount),
            "statusTicks": String(statusUpdatedTicks),
        ]
    }
}

/// One evaluation verdict for an added rule.
public enum RuleEvaluation: Equatable, Sendable {
    /// No proposal is known under this key.
    case unknown
    /// The rule is known but not added: pending, snoozed, or declined.
    case inactive(RuleProposalStatus)
    /// Evidence is below the rule's required count.
    case insufficientEvidence(have: Int, required: Int)
    /// The rolling weekly cap is exhausted.
    case capped
    /// A previous fire is still inside the cooldown window.
    case coolingDown(remainingTicks: TimeInterval)
    /// The rule fires: a (kind, effect) pair inside firewall bounds.
    case fire(kindCode: String, effectCode: String)

    public var isFire: Bool {
        if case .fire = self { return true }
        return false
    }
}

/// Tick-injected rule-proposal engine beside `ResourceGovernor` (Epic 13 R1).
///
/// Value semantics: `suggest` records evidence, `decide` applies the owner
/// Add/Not-now/Never choice, `evaluate` fires added rules inside their caps
/// and cooldowns, `advance` re-arms snoozes and rolls the weekly window,
/// `undo` reverts one non-permanent transition, and `reset` explicitly
/// clears one rule back to pending. Backward ticks change nothing, so
/// identical tick sequences decide identically. No Date, Task, sleep, or
/// UUID in logic: identities arrive injected, time arrives as ticks.
public struct RuleProposalEngine: Sendable {
    /// Rolling window for weekly caps, in ticks.
    public static let weekTicks: TimeInterval = 7 * 24 * 60 * 60
    /// Ticks a Not-now snooze waits before re-arming to pending.
    public static let notNowRearmTicks: TimeInterval = 7 * 24 * 60 * 60

    /// Shipped per-rule throttle table.
    public static let defaultCaps: [String: RuleCap] = [
        "quiet-when-weak": RuleCap(weeklyMax: 3, cooldownTicks: 24 * 60 * 60),
        "shift-within-window": RuleCap(weeklyMax: 3, cooldownTicks: 60 * 60),
        "restart-on-strong-motion": RuleCap(weeklyMax: 2, cooldownTicks: 24 * 60 * 60),
        "release-on-strong-absence": RuleCap(weeklyMax: 7, cooldownTicks: 5 * 60),
    ]

    private let caps: [String: RuleCap]
    private var proposals: [String: RuleProposal] = [:]
    private var previousStatuses: [String: RuleProposalStatus] = [:]
    private var fireTicks: [String: [TimeInterval]] = [:]
    private var triggerCounts: [String: Int] = [:]
    private var fireCounts: [String: Int] = [:]
    private var lastAdvanceTicks: TimeInterval

    public init(caps: [String: RuleCap]? = nil, startedAtTicks: TimeInterval = 0) {
        var merged = Self.defaultCaps
        for (key, cap) in caps ?? [:] {
            merged[key] = cap
        }
        self.caps = merged
        lastAdvanceTicks = startedAtTicks
    }

    /// Whether a (kind, effect) pair stays inside the live firewall bounds:
    /// a firewall-emittable kind, a known effect class, and the pair the
    /// firewall itself routes. The rule proposes; the firewall still
    /// qualifies — this clamp is checked against the current firewall, so a
    /// firewall change fails loudly here instead of widening silently.
    public static func isFirewallCompatible(kindCode: String, effectCode: String) -> Bool {
        guard LedgerPolicyDecisionRecord.effects.contains(effectCode),
            let kind = OpportunityActionKind(rawValue: kindCode),
            ClosedPolicyFirewall.isEmittable(kind)
        else {
            return false
        }
        switch (kindCode, effectCode) {
        case ("holdBegin", "quiet"),
            ("holdBegin", "shift"),
            ("sensorStrongMovementRestart", "restart"),
            ("holdRelease", "resume"):
            return true
        default:
            return false
        }
    }

    /// The recorded proposal for one rule, if suggested.
    public func proposal(for ruleKey: String) -> RuleProposal? {
        proposals[ruleKey]
    }

    /// Qualified evaluations (evidence-sufficient, added rule) for one rule,
    /// including capped and cooling-down triggers: over-throttle volume is
    /// counted, never silently dropped.
    public func triggerCount(for ruleKey: String) -> Int {
        triggerCounts[ruleKey, default: 0]
    }

    /// Cumulative fires for one rule across every window.
    public func fireCount(for ruleKey: String) -> Int {
        fireCounts[ruleKey, default: 0]
    }

    /// Records a proposal's latest evidence. Owner status survives
    /// re-suggestion: a repeated suggestion never reactivates a decision,
    /// so Never stays permanent until an explicit reset.
    @discardableResult
    public mutating func suggest(_ proposal: RuleProposal, atTicks _: TimeInterval) -> RuleProposal {
        if let existing = proposals[proposal.ruleKey] {
            let merged = (try? existing.withEvidence(proposal)) ?? existing
            proposals[proposal.ruleKey] = merged
            return merged
        }
        proposals[proposal.ruleKey] = proposal
        return proposal
    }

    /// Applies the owner decision. Transitions out of Never are refused:
    /// permanent decline escapes only through an explicit reset.
    @discardableResult
    public mutating func decide(ruleKey: String, decision: RuleDecision, atTicks ticks: TimeInterval) -> Bool {
        guard let current = proposals[ruleKey] else { return false }
        guard current.status != .never else { return false }
        let next: RuleProposalStatus
        switch decision {
        case .add: next = .added
        case .notNow: next = .notNow
        case .never: next = .never
        }
        guard next != current.status else { return true }
        previousStatuses[ruleKey] = current.status
        proposals[ruleKey] = (try? current.withStatus(next, atTicks: ticks)) ?? current
        return true
    }
    /// Evaluates one rule at the presented ticks. Only added rules fire, and
    /// only inside their evidence threshold, weekly cap, and cooldown.
    public mutating func evaluate(
        ruleKey: String,
        evidenceCount: Int,
        atTicks ticks: TimeInterval,
    ) -> RuleEvaluation {
        guard let proposal = proposals[ruleKey] else { return .unknown }
        guard proposal.status == .added else { return .inactive(proposal.status) }
        guard evidenceCount >= proposal.requiredEvidenceCount else {
            return .insufficientEvidence(have: evidenceCount, required: proposal.requiredEvidenceCount)
        }
        triggerCounts[ruleKey, default: 0] += 1
        guard let cap = caps[ruleKey] else { return .capped }
        let recent = fireTicks[ruleKey, default: []].filter { $0 <= ticks && $0 > ticks - Self.weekTicks }
        guard recent.count < cap.weeklyMax else { return .capped }
        if let last = recent.max(), ticks - last < cap.cooldownTicks {
            return .coolingDown(remainingTicks: cap.cooldownTicks - (ticks - last))
        }
        fireTicks[ruleKey, default: []].append(ticks)
        fireCounts[ruleKey, default: 0] += 1
        return .fire(kindCode: proposal.kindCode, effectCode: proposal.effectCode)
    }

    /// Rolls the engine forward: re-arms elapsed Not-now snoozes to pending
    /// and drops fire history older than the weekly window. Backward ticks
    /// change nothing.
    public mutating func advance(atTicks ticks: TimeInterval) {
        guard ticks >= lastAdvanceTicks else { return }
        lastAdvanceTicks = ticks
        for (key, proposal) in proposals where proposal.status == .notNow
            && ticks >= proposal.statusUpdatedTicks + Self.notNowRearmTicks
        {
            proposals[key] = (try? proposal.withStatus(.pending, atTicks: ticks)) ?? proposal
            previousStatuses.removeValue(forKey: key)
        }
        for key in fireTicks.keys {
            fireTicks[key] = fireTicks[key]?.filter { $0 >= ticks - Self.weekTicks }
        }
    }

    /// Reverts the last non-permanent transition. Refuses Never: a permanent
    /// decline is not undoable, only resettable.
    @discardableResult
    public mutating func undo(ruleKey: String, atTicks ticks: TimeInterval) -> Bool {
        guard let current = proposals[ruleKey],
            let previous = previousStatuses[ruleKey],
            current.status != .never,
            previous != current.status
        else {
            return false
        }
        proposals[ruleKey] = (try? current.withStatus(previous, atTicks: ticks)) ?? current
        previousStatuses.removeValue(forKey: ruleKey)
        return true
    }

    /// Explicitly clears one rule to pending with empty counts and no
    /// cooldown memory. The only path out of Never.
    public mutating func reset(ruleKey: String, atTicks ticks: TimeInterval) {
        guard let current = proposals[ruleKey] else { return }
        proposals[ruleKey] = (try? current.withStatus(.pending, atTicks: ticks)) ?? current
        previousStatuses.removeValue(forKey: ruleKey)
        fireTicks.removeValue(forKey: ruleKey)
        triggerCounts.removeValue(forKey: ruleKey)
        fireCounts.removeValue(forKey: ruleKey)
    }
}
