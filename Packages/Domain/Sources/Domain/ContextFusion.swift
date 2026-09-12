import Foundation

/// Epic 5 story S4 (issue #6, gate G1): layered context fusion in shadow +
/// suggest, over the Epic 3 fusion path.
///
/// This layer never re-fuses and never emits behavior. It reads the bus's
/// live, provenanced atoms (the same frontier the Epic 3 fusion core reads —
/// post-admit revocation, expiry, revision advance, and epoch fencing
/// un-vote here exactly as there), collapses correlated groups into
/// derivative families, and applies the declared layering rules:
///
/// 1. Explicit manual (`ManualContextHold`, story S1) always wins while
///    active — inference never outranks a user declaration.
/// 2. Exactly one effective family vote stays ambient/menu-only: a single
///    weak signal is never a hold and never a suggestion.
/// 3. Correlated signals cannot self-promote: the call-observation family
///    (frontmost-app, media-device, and their FaceTime derivative) fuses
///    as ONE vote no matter how many of its groups report.
/// 4. Shadow evaluates + audit-logs with zero emission influence;
///    suggest surfaces one bounded proposal with qualified copy. There is
///    no hold case in this story by construction — bounded auto-hold is
///    story S5 ownership and has no representation here.
///
/// Write-set: this file is additive only. It does not modify the fusion
/// core, the firewall, the ledgers, the bus, the S1 manual files, the S3
/// adapters, or any registry vocabulary.

/// Which graduated layer an evaluation runs in.
public enum ContextFusionMode: String, Sendable, Equatable, CaseIterable {
    /// Counterfactual only: evaluate and audit-log what WOULD have been
    /// suggested. Never surfaces, never influences emission.
    case shadow
    /// Surfaces one bounded suggestion when inference is eligible. Never
    /// holds anything automatically.
    case suggest
}

/// One bounded suggestion: qualified copy plus the closed, auditable
/// content behind it. No titles, guest lists, names, or history — family
/// codes and confidence only.
public struct ContextSuggestion: Sendable, Equatable {
    /// Qualified headline ("Likely …"), never a universal meeting fact.
    public let headline: String
    /// Canonical voting families behind the suggestion, sorted.
    public let familyCodes: [String]
    /// Weakest-link confidence across the voting families.
    public let confidence: EvidenceConfidence // RAWGUARD-ALLOW: S4 layered fusion reads the Class 0 frontier (never persists/exports it)
    /// Earliest lapse among the voting atoms: the suggestion is valid
    /// only while its evidence is live.
    public let validUntilTicks: TimeInterval

    public init(
        headline: String,
        familyCodes: [String],
        confidence: EvidenceConfidence, // RAWGUARD-ALLOW: S4 layered fusion reads the Class 0 frontier (never persists/exports it)
        validUntilTicks: TimeInterval,
    ) {
        self.headline = headline
        self.familyCodes = familyCodes
        self.confidence = confidence
        self.validUntilTicks = validUntilTicks
    }
}

/// The observable result of one layered evaluation. The effect vocabulary
/// has no hold case: S4 cannot hold by construction.
public struct ContextFusionDecision: Sendable, Equatable {
    public enum Effect: String, Sendable, Equatable {
        /// No votable context evidence at all.
        case none
        /// Menu-only awareness at most. Also the only shadow outcome:
        /// shadow never surfaces and never emits.
        case ambientMenuOnly
        /// One bounded suggestion surfaced (suggest mode only).
        case suggest
        /// An active manual hold outranks inference.
        case manualHold
    }

    public let effect: Effect
    /// The winning manual mode when `effect == .manualHold`, else nil.
    public let manualMode: ManualContextMode?
    /// Independent families voting present, after derivative collapse.
    public let effectiveVotes: Int
    /// The surfaced proposal when `effect == .suggest`, else nil. Nil in
    /// shadow always: shadow never surfaces.
    public let suggestion: ContextSuggestion?
    /// Whether inference alone is suggest-eligible, regardless of mode
    /// and manual override — the auditable counterfactual.
    public let wouldHaveSuggested: Bool

    public init(
        effect: Effect,
        manualMode: ManualContextMode? = nil,
        effectiveVotes: Int,
        suggestion: ContextSuggestion? = nil,
        wouldHaveSuggested: Bool,
    ) {
        self.effect = effect
        self.manualMode = manualMode
        self.effectiveVotes = effectiveVotes
        self.suggestion = suggestion
        self.wouldHaveSuggested = wouldHaveSuggested
    }
}

/// One audit entry for a shadow (or suggest) evaluation: what was seen,
/// what would have happened, and what was emitted (nothing, in shadow).
public struct ContextFusionAuditEntry: Sendable, Equatable {
    public let mode: ContextFusionMode
    public let effect: ContextFusionDecision.Effect
    public let effectiveVotes: Int
    public let wouldHaveSuggested: Bool
    public let evaluatedTicks: TimeInterval

    public init(
        mode: ContextFusionMode,
        effect: ContextFusionDecision.Effect,
        effectiveVotes: Int,
        wouldHaveSuggested: Bool,
        evaluatedTicks: TimeInterval,
    ) {
        self.mode = mode
        self.effect = effect
        self.effectiveVotes = effectiveVotes
        self.wouldHaveSuggested = wouldHaveSuggested
        self.evaluatedTicks = evaluatedTicks
    }
}

/// In-memory audit log for shadow-then-suggest graduation: evaluations are
/// recorded here, never routed toward behavior. Memory-only like the bus.
public struct ContextFusionShadowLog: Sendable {
    public private(set) var entries: [ContextFusionAuditEntry] = []

    public init() {}

    public mutating func record(
        decision: ContextFusionDecision,
        mode: ContextFusionMode,
        atTicks ticks: TimeInterval,
    ) {
        entries.append(ContextFusionAuditEntry(
            mode: mode,
            effect: decision.effect,
            effectiveVotes: decision.effectiveVotes,
            wouldHaveSuggested: decision.wouldHaveSuggested,
            evaluatedTicks: ticks,
        ))
    }
}

/// Layered fusion over already-admitted bus evidence.
public enum ContextFusion: Sendable {
    /// Sources admitted to this layer: the S3 sanitized-context booleans
    /// only. Anything else on the bus (fake, motion, ambient test feeds)
    /// is not context evidence and never votes here.
    public static let contextSources: Set<EvidenceSource> = [ // RAWGUARD-ALLOW: S4 layered fusion reads the Class 0 frontier (never persists/exports it)
        .frontmostApp, .mediaDevice, .focusFilter,
    ]

    /// Group codes that share the call-observation origin: the two S3
    /// parents plus the S2-dead FaceTime path, which survives ONLY as a
    /// derivative of those parents (spike verdict: no independent source
    /// on macOS). All collapse to family "call" — the derivative keeps
    /// its own group code but never casts its own vote.
    public static let callFamilyGroupCodes: Set<String> = [
        "bundle-app", "media-device",
        "facetime-derivative", "derivatives", "facetime",
    ]

    /// The Focus declaration is its own origin (S2 verdict).
    public static let focusFamilyGroupCode = "focus-filter"
    /// Reserved for the future owner-approved calendar adapter (S3 dock
    /// point): its own origin when it lands.
    public static let calendarFamilyGroupCode = "calendar"

    /// Canonical family for one normalized group code. Unknown codes are
    /// each their own family: unrecognized origins stay independent, so a
    /// novel group can never silently merge into — or split — a vote.
    public static func family(forGroupCode code: String) -> String {
        if callFamilyGroupCodes.contains(code) { return "call" }
        if code == focusFamilyGroupCode { return "focus" }
        if code == calendarFamilyGroupCode { return "calendar" }
        return "other:\(code)"
    }

    /// One layered evaluation over the bus at the presented ticks.
    ///
    /// Reads the same live, provenanced frontier the Epic 3 fusion core reads;
    /// routes nothing, persists nothing, holds nothing.
    public static func evaluate(
        _ bus: EvidenceBus, // RAWGUARD-ALLOW: S4 layered fusion reads the Class 0 frontier (never persists/exports it)
        atTicks ticks: TimeInterval,
        manualHold: ManualContextHold?,
        now: Date,
        mode: ContextFusionMode,
    ) -> ContextFusionDecision {
        var authorityCopy = bus.authority
        var bestConfidenceRankByFamily: [String: Int] = [:]
        var earliestExpiryByFamily: [String: TimeInterval] = [:]
        for atom in bus.live(atTicks: ticks) {
            guard contextSources.contains(atom.source) else { continue }
            guard atom.quality == .full, atom.reading == .present else { continue }
            guard isProvenanceLive(atom.provenance, authority: &authorityCopy, atTicks: ticks) else { continue }
            let family = family(forGroupCode: atom.independenceGroup.code)
            let rank = atom.confidence.rank
            if let held = bestConfidenceRankByFamily[family] {
                bestConfidenceRankByFamily[family] = min(held, rank)
                earliestExpiryByFamily[family] = min(earliestExpiryByFamily[family] ?? .infinity, atom.expiryTicks)
            } else {
                bestConfidenceRankByFamily[family] = rank
                earliestExpiryByFamily[family] = atom.expiryTicks
            }
        }
        let families = bestConfidenceRankByFamily.keys.sorted()
        let eligible = families.count >= 2
        let weakestRank = bestConfidenceRankByFamily.values.min() ?? EvidenceConfidence.low.rank // RAWGUARD-ALLOW: S4 layered fusion reads the Class 0 frontier (never persists/exports it)
        let validUntil = earliestExpiryByFamily.values.min() ?? ticks

        // Rule 1: active manual state outranks all inference. The
        // counterfactual still audits honestly underneath.
        if let hold = manualHold, hold.isActive(at: now) {
            return ContextFusionDecision(
                effect: .manualHold,
                manualMode: hold.mode,
                effectiveVotes: families.count,
                wouldHaveSuggested: eligible,
            )
        }

        // Rule 4 (shadow): counterfactual only — eligible or not, the
        // effect stays non-surfacing and the suggestion stays nil.
        if mode == .shadow {
            return ContextFusionDecision(
                effect: families.isEmpty ? .none : .ambientMenuOnly,
                effectiveVotes: families.count,
                wouldHaveSuggested: eligible,
            )
        }

        // Rules 2–3 (suggest): one collapsed vote stays ambient-only;
        // two independent families earn one bounded suggestion. Holds do
        // not exist at this layer.
        guard eligible else {
            return ContextFusionDecision(
                effect: families.isEmpty ? .none : .ambientMenuOnly,
                effectiveVotes: families.count,
                wouldHaveSuggested: false,
            )
        }
        return ContextFusionDecision(
            effect: .suggest,
            effectiveVotes: families.count,
            suggestion: ContextSuggestion(
                headline: headline(forFamilies: families),
                familyCodes: families,
                confidence: confidence(forRank: weakestRank),
                validUntilTicks: validUntil,
            ),
            wouldHaveSuggested: true,
        )
    }

    /// Qualified copy for the voting families: likely/contextual facts
    /// only, never a universal meeting claim.
    public static func headline(forFamilies families: [String]) -> String {
        let phrases = families.map { family -> String in
            switch family {
            case "call": "call-like signals are active (selected app, device)"
            case "focus": "the selected Focus filter is on"
            case "calendar": "the selected calendar shows busy"
            default: "context signals are active"
            }
        }
        return "Likely context: \(phrases.joined(separator: " and ")) — suggestion only, nothing held."
    }

    private static func isProvenanceLive(
        _ provenance: EvidenceProvenance, // RAWGUARD-ALLOW: S4 layered fusion reads the Class 0 frontier (never persists/exports it)
        authority: inout SensingLeaseAuthority,
        atTicks ticks: TimeInterval,
    ) -> Bool {
        authority.validate(
            provenance.lease,
            for: provenance.provider,
            originRevision: provenance.originRevision,
            epoch: provenance.epoch,
            presentingDeviceID: provenance.presentingDeviceID,
            atTicks: ticks,
        ) == nil
    }

    private static func confidence(forRank rank: Int) -> EvidenceConfidence { // RAWGUARD-ALLOW: S4 layered fusion reads the Class 0 frontier (never persists/exports it)
        if rank >= EvidenceConfidence.high.rank { return .high } // RAWGUARD-ALLOW: S4 layered fusion reads the Class 0 frontier (never persists/exports it)
        if rank >= EvidenceConfidence.medium.rank { return .medium } // RAWGUARD-ALLOW: S4 layered fusion reads the Class 0 frontier (never persists/exports it)
        return .low
    }
}
