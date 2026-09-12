import Foundation

/// Epic 5 story S5 (issue #6, gates G2+G3): separately-consented bounded
/// auto-hold. The LAST automation and the SMALLEST one.
///
/// Firing is deny-by-default over four gates, all of which must pass at the
/// same evaluation tick:
/// 1. Separate effect consent: `broker.canEmitEffect(.effectHold)`. Sensing
///    consent never suffices; a draining revocation or the engaged kill
///    switch closes the path at once.
/// 2. S4 suggest-layer promotion: `ContextFusion.evaluate(..., mode:
///    .suggest)` must surface `.suggest` with a live suggestion. Shadow
///    never fires, ambient never fires, manual state outranks everything.
/// 3. Firewall qualification: the hold routes `.holdBegin` and the release
///    routes `.holdRelease`, both inside
///    `ClosedPolicyFirewall.emittableKinds`. No new emittable kind exists
///    here by construction; the quiet-only effect class is pinned by
///    requiring every projected reason to resolve `.continue`.
/// 4. Bounded windows: expiry is the smaller of the suggestion lapse and
///    the tapered cap; a 90-second landing corridor follows every release
///    and back-to-back episodes taper the cap.
///
/// Holds never freeze need clocks and never discard accumulated need (G2):
/// every projected reason resolves `.continue`, and releases mark nothing
/// complete. `Not a call` releases promptly and disables the offending
/// sources (G3): voting leases are revoked in the passed bus — so fusion
/// un-votes them with zero fusion changes — and the disable stays sticky
/// for this layer across lease churn. Every terminal mutation appends a
/// correction row (the undo path is idempotent: a second release is a
/// no-op and a replayed row is a store-level no-op).
///
/// Data only: Why-now, the heads-up capsule-retraction directive, and the
/// single merged post-context opportunity are structs for later surfaces.
/// No UI, no clocks, no new product vocabulary.

/// Closed reason for one auto-hold release.
public enum AutoHoldReleaseReason: String, Sendable, Equatable, CaseIterable {
    case released
    case notACall
    case holdExpired
    case effectConsentWithdrawn
    case killSwitchDrained

    /// Stable code recorded on the correction row.
    public var code: String {
        switch self {
        case .released: "released"
        case .notACall: "not-a-call"
        case .holdExpired: "hold-expired"
        case .effectConsentWithdrawn: "effect-consent-withdrawn"
        case .killSwitchDrained: "kill-switch-drained"
        }
    }

    /// Qualified user-facing note. Likely/contextual facts only, never a
    /// universal meeting claim; every note states need was kept.
    public var note: String {
        switch self {
        case .released:
            "Hold released. Accumulated need was kept — nothing was marked complete."
        case .notACall:
            "Not a call — released, and the voting sources were switched off. Accumulated need was kept."
        case .holdExpired:
            "Hold expired at its bound. Accumulated need was kept — nothing was marked complete."
        case .effectConsentWithdrawn:
            "Effect consent was withdrawn — the hold released inside the drain bound. Accumulated need was kept."
        case .killSwitchDrained:
            "Kill switch engaged — the hold released at once. Accumulated need was kept."
        }
    }
}

/// Why one evaluation did not fire.
public enum AutoHoldBlockReason: String, Sendable, Equatable {
    case effectConsentNotGranted
    case insufficientEvidence
    case sourcesDisabled
    case inLandingCorridor
    case staleEvidence
    case unprojectableFamilies
    case firewallNotEmittable
}

/// Why-now explanation data for one fired hold. Sanitized scalars only:
/// family codes, a confidence code, and tick windows — never titles,
/// names, history, or readings.
public struct AutoHoldWhyNow: Sendable, Equatable {
    public let headline: String
    public let familyCodes: [String]
    public let confidenceCode: String
    public let validUntilTicks: TimeInterval
    public let startedTicks: TimeInterval
    public let effectConsentScopeCode: String
    public let firewallKindCode: String
}

/// Capsule directive for the later heads-up wiring: a mid-heads-up hold
/// retracts the capsule to Held with the qualified reason. Data only.
public struct AutoHoldHeadsUpRetraction: Sendable, Equatable {
    public let retractCapsuleToHeld: Bool
    public let heldReasonCode: String
    public let qualifiedHeadline: String
}

/// One fired bounded hold: cap, expiry, visible sources, and the data the
/// release, correction, and Why-now paths need.
public struct AutoHoldRecord: Sendable, Equatable {
    public let holdActionID: UUID
    public let holdDecisionID: UUID
    public let actionDeviceID: UUID
    public let actionCounter: UInt64
    public let startedTicks: TimeInterval
    public let expiresTicks: TimeInterval
    public let capSeconds: TimeInterval
    public let familyCodes: [String]
    public let votingSources: Set<EvidenceSource> // RAWGUARD-ALLOW: S5 auto-hold reads the Class 0 frontier (never persists/exports it)
    public let suppressionReasons: Set<SuppressionReason>
    public let actionKind: OpportunityActionKind
    public let whyNow: AutoHoldWhyNow
    public let headsUpRetraction: AutoHoldHeadsUpRetraction
}

/// Receipt for one terminal auto-hold mutation. Releasing preserves need
/// by construction: `needPreserved` is unconditionally true.
public struct AutoHoldReleaseReceipt: Sendable, Equatable {
    public let holdActionID: UUID
    public let releaseActionID: UUID
    public let reasonCode: String
    public let releasedTicks: TimeInterval
    public let corridorUntilTicks: TimeInterval
    public let postContextEligibleUntilTicks: TimeInterval
    public let needPreserved: Bool
    public let note: String
}

/// The single merged post-context opportunity for one released hold.
/// Data only: at most one per hold, eligible inside the corridor.
public struct AutoHoldPostContextOpportunity: Sendable, Equatable {
    public let holdActionID: UUID
    public let familyCodes: [String]
    public let headline: String
    public let eligibleUntilTicks: TimeInterval
}

/// The observable result of one auto-hold evaluation.
public enum AutoHoldEvaluation: Sendable, Equatable {
    case fired(AutoHoldRecord)
    case sustained(AutoHoldRecord)
    case manualHoldOutranks
    case released(AutoHoldReleaseReceipt)
    case noHold(AutoHoldBlockReason)
}

/// Closed constants and family wiring for the bounded auto-hold.
public enum BoundedAutoHold {
    /// Hard cap for one auto-hold episode. Back-to-back episodes taper it.
    public static let capSeconds: TimeInterval = 1800
    /// Taper floor: consecutive holds never shrink below this.
    public static let minimumCapSeconds: TimeInterval = 300
    /// Quiet window after every release; no auto-hold fires inside it.
    public static let landingCorridorSeconds: TimeInterval = 90
    /// Gap after which the back-to-back taper resets.
    public static let backToBackResetSeconds: TimeInterval = 3600
    /// The separate effect consent that gates firing. Sensing consent is
    /// never consulted here.
    public static let effectCapability = PermissionCapability.effectHold
    /// The only kind a hold routes: inside the firewall allowlist.
    public static let holdKind = OpportunityActionKind.holdBegin
    /// The only kind a release routes: inside the firewall allowlist.
    public static let releaseKind = OpportunityActionKind.holdRelease
    /// Correction generation for auto-hold rows.
    public static let correctionGeneration: UInt64 = 1

    /// Data hook for the R2 consent-management surface: the scope code the
    /// effect toggle grants or withdraws.
    public static var effectConsentScopeCode: String { effectCapability.scopeCode }

    /// Families that survive a per-source disable. The call family fuses
    /// as one vote, so it survives while ANY of its sources stays enabled;
    /// unknown families survive (fail-open would invent a mapping, so an
    /// unrecognized origin is never silently merged away).
    public static func survivingFamilies(
        _ families: [String],
        disabled: Set<EvidenceSource>, // RAWGUARD-ALLOW: S5 auto-hold reads the Class 0 frontier (never persists/exports it)
    ) -> [String] {
        families.filter { family in
            switch family {
            case "call":
                !(disabled.contains(.frontmostApp) && disabled.contains(.mediaDevice))
            case "focus":
                !disabled.contains(.focusFilter)
            default:
                true
            }
        }
    }

    /// Sources behind the surviving families: the visible, disablable set.
    public static func votingSources(
        forFamilies families: [String],
    ) -> Set<EvidenceSource> { // RAWGUARD-ALLOW: S5 auto-hold reads the Class 0 frontier (never persists/exports it)
        families.reduce(into: Set<EvidenceSource>()) { into, family in // RAWGUARD-ALLOW: S5 auto-hold reads the Class 0 frontier (never persists/exports it)
            switch family {
            case "call": into.formUnion([.frontmostApp, .mediaDevice])
            case "focus": into.insert(.focusFilter)
            default: break
            }
        }
    }

    /// Projects voting families onto the existing suppression vocabulary.
    /// Every projection resolves `.continue`: the selected app holds
    /// presentation as if excluded, the selected filter as focus, the
    /// selected busy interval as calendar busy. The qualified Likely-fact
    /// lives in Why-now; the reason is only the coordinator projection.
    public static func projectedReasons(forFamilies families: [String]) -> Set<SuppressionReason> {
        families.reduce(into: Set<SuppressionReason>()) { into, family in
            switch family {
            case "call": into.insert(.excludedApplication)
            case "focus": into.insert(.focusFilter)
            case "calendar": into.insert(.calendarBusy)
            default: break
            }
        }
    }
}

/// Live auto-hold state: the outstanding hold, per-source disables, the
/// landing corridor, the back-to-back taper, and the correction frontier.
public struct BoundedAutoHoldState: Sendable {
    public private(set) var activeHold: AutoHoldRecord?
    public private(set) var disabledSources: Set<EvidenceSource> = [] // RAWGUARD-ALLOW: S5 auto-hold reads the Class 0 frontier (never persists/exports it)
    public private(set) var landingCorridorUntilTicks: TimeInterval?
    public private(set) var lastReleaseTicks: TimeInterval?
    public private(set) var consecutiveAutoHolds: Int = 0
    private var lastReleasedHold: AutoHoldRecord?
    private var postContextTaken: Set<UUID> = []
    private var correctionRevision: UInt64 = 1
    private var actionCounter: UInt64 = 1
    private let deviceID: UUID

    public init(deviceID: UUID = UUID()) {
        self.deviceID = deviceID
    }

    /// Whether the landing corridor is still quiet at these ticks.
    public func isInLandingCorridor(atTicks ticks: TimeInterval) -> Bool {
        guard let until = landingCorridorUntilTicks else { return false }
        return ticks < until
    }

    /// One deny-by-default evaluation: sustain or drain the outstanding
    /// hold, or fire exactly when effect consent, suggest promotion,
    /// firewall qualification, and the bounded windows all agree.
    public mutating func evaluate(
        _ bus: EvidenceBus, // RAWGUARD-ALLOW: S5 auto-hold reads the Class 0 frontier (never persists/exports it)
        atTicks ticks: TimeInterval,
        now: Date,
        manualHold: ManualContextHold?,
        broker: PermissionBroker,
        corrections: any LedgerCorrectionStore,
    ) async throws -> AutoHoldEvaluation {
        if let hold = activeHold {
            if !broker.canEmitEffect(for: BoundedAutoHold.effectCapability) {
                let reason: AutoHoldReleaseReason =
                    broker.isKillSwitchEngaged ? .killSwitchDrained : .effectConsentWithdrawn
                let receipt = try await release(
                    atTicks: ticks, now: now, reason: reason, corrections: corrections,
                )
                return .released(try requireReceipt(receipt))
            }
            if ticks >= hold.expiresTicks {
                let receipt = try await release(
                    atTicks: ticks, now: now, reason: .holdExpired, corrections: corrections,
                )
                return .released(try requireReceipt(receipt))
            }
            return .sustained(hold)
        }
        if let manual = manualHold, manual.isActive(at: now) {
            consecutiveAutoHolds = 0
            return .manualHoldOutranks
        }
        guard broker.canEmitEffect(for: BoundedAutoHold.effectCapability) else {
            return .noHold(.effectConsentNotGranted)
        }
        if isInLandingCorridor(atTicks: ticks) {
            return .noHold(.inLandingCorridor)
        }
        let fusion = ContextFusion.evaluate(
            bus, atTicks: ticks, manualHold: nil, now: now, mode: .suggest,
        )
        guard fusion.effect == .suggest, let suggestion = fusion.suggestion else {
            return .noHold(.insufficientEvidence)
        }
        let surviving = BoundedAutoHold.survivingFamilies(
            suggestion.familyCodes, disabled: disabledSources,
        )
        guard surviving.count >= 2 else {
            return .noHold(.sourcesDisabled)
        }
        guard suggestion.validUntilTicks > ticks else {
            return .noHold(.staleEvidence)
        }
        guard ClosedPolicyFirewall.isEmittable(BoundedAutoHold.holdKind) else {
            return .noHold(.firewallNotEmittable)
        }
        let reasons = BoundedAutoHold.projectedReasons(forFamilies: surviving)
        guard !reasons.isEmpty else {
            return .noHold(.unprojectableFamilies)
        }
        guard SuppressionResolver.resolve(activeReasons: reasons).accumulationPolicy == .continue else {
            return .noHold(.firewallNotEmittable)
        }
        if let lastRelease = lastReleaseTicks,
           ticks - lastRelease > BoundedAutoHold.backToBackResetSeconds
        {
            consecutiveAutoHolds = 0
        }
        let cap = max(
            BoundedAutoHold.minimumCapSeconds,
            BoundedAutoHold.capSeconds / TimeInterval(1 << min(consecutiveAutoHolds, 4)),
        )
        let expiry = min(suggestion.validUntilTicks, ticks + cap)
        guard expiry > ticks else {
            return .noHold(.staleEvidence)
        }
        let counter = actionCounter
        actionCounter += 1
        let primaryReason = SuppressionReason.precedence.first(where: reasons.contains)
        let record = AutoHoldRecord(
            holdActionID: UUID(),
            holdDecisionID: UUID(),
            actionDeviceID: deviceID,
            actionCounter: counter,
            startedTicks: ticks,
            expiresTicks: expiry,
            capSeconds: cap,
            familyCodes: surviving,
            votingSources: BoundedAutoHold.votingSources(forFamilies: surviving),
            suppressionReasons: reasons,
            actionKind: BoundedAutoHold.holdKind,
            whyNow: AutoHoldWhyNow(
                headline: suggestion.headline,
                familyCodes: surviving,
                confidenceCode: suggestion.confidence.rawValue,
                validUntilTicks: suggestion.validUntilTicks,
                startedTicks: ticks,
                effectConsentScopeCode: BoundedAutoHold.effectConsentScopeCode,
                firewallKindCode: BoundedAutoHold.holdKind.rawValue,
            ),
            headsUpRetraction: AutoHoldHeadsUpRetraction(
                retractCapsuleToHeld: true,
                heldReasonCode: primaryReason?.rawValue ?? "unknown",
                qualifiedHeadline: suggestion.headline,
            ),
        )
        activeHold = record
        consecutiveAutoHolds += 1
        return .fired(record)
    }

    /// One-action release. Idempotent: with no outstanding hold there is
    /// nothing to undo and no row is appended.
    @discardableResult
    public mutating func release(
        atTicks ticks: TimeInterval,
        now: Date,
        reason: AutoHoldReleaseReason,
        corrections: any LedgerCorrectionStore,
    ) async throws -> AutoHoldReleaseReceipt? {
        guard let hold = activeHold else { return nil }
        activeHold = nil
        let corridorUntil = ticks + BoundedAutoHold.landingCorridorSeconds
        landingCorridorUntilTicks = corridorUntil
        lastReleaseTicks = ticks
        lastReleasedHold = hold
        let releaseID = UUID()
        let revision = correctionRevision
        correctionRevision += 1
        try await corrections.append(LedgerCorrectionRecord(
            id: UUID(),
            recordedAt: now,
            correctedActionUUID: hold.holdActionID,
            correctedActionDeviceID: hold.actionDeviceID.uuidString,
            correctedActionCounter: hold.actionCounter,
            correctingActionUUID: releaseID,
            correctingActionDeviceID: deviceID.uuidString,
            correctingActionCounter: revision,
            outcomeCode: "committed",
            reasonCode: reason.code,
            generation: BoundedAutoHold.correctionGeneration,
            globalRevision: revision,
            supersededDecisionUUIDs: [hold.holdDecisionID],
        ))
        return AutoHoldReleaseReceipt(
            holdActionID: hold.holdActionID,
            releaseActionID: releaseID,
            reasonCode: reason.code,
            releasedTicks: ticks,
            corridorUntilTicks: corridorUntil,
            postContextEligibleUntilTicks: corridorUntil,
            needPreserved: true,
            note: reason.note,
        )
    }

    /// `Not a call`: releases promptly AND disables the offending sources.
    /// Voting leases are revoked in the passed bus, so layered fusion
    /// un-votes them at once with no fusion change; the disable stays
    /// sticky here across later lease churn. Defaults to the hold's own
    /// voting sources; an explicit subset may name fewer.
    @discardableResult
    public mutating func notACall(
        atTicks ticks: TimeInterval,
        now: Date,
        bus: inout EvidenceBus, // RAWGUARD-ALLOW: S5 auto-hold reads the Class 0 frontier (never persists/exports it)
        disabling sources: Set<EvidenceSource>? = nil, // RAWGUARD-ALLOW: S5 auto-hold reads the Class 0 frontier (never persists/exports it)
        corrections: any LedgerCorrectionStore,
    ) async throws -> AutoHoldReleaseReceipt? {
        guard let hold = activeHold else { return nil }
        let targets = sources ?? hold.votingSources
        for atom in bus.live(atTicks: ticks) where targets.contains(atom.source) {
            bus.revoke(atom.provenance.lease)
        }
        disabledSources.formUnion(targets)
        return try await release(
            atTicks: ticks, now: now, reason: .notACall, corrections: corrections,
        )
    }

    /// The one merged post-context opportunity for the last released hold:
    /// at most one, eligible only inside the landing corridor. Data only.
    public mutating func takePostContextOpportunity(
        atTicks ticks: TimeInterval,
    ) -> AutoHoldPostContextOpportunity? {
        guard let hold = lastReleasedHold,
              let corridorUntil = landingCorridorUntilTicks,
              ticks < corridorUntil,
              !postContextTaken.contains(hold.holdActionID)
        else { return nil }
        postContextTaken.insert(hold.holdActionID)
        return AutoHoldPostContextOpportunity(
            holdActionID: hold.holdActionID,
            familyCodes: hold.familyCodes,
            headline: hold.whyNow.headline,
            eligibleUntilTicks: corridorUntil,
        )
    }
}

private enum AutoHoldInternalError: Error {
    case releasedWithoutReceipt
}

private func requireReceipt(_ receipt: AutoHoldReleaseReceipt?) throws -> AutoHoldReleaseReceipt {
    guard let receipt else { throw AutoHoldInternalError.releasedWithoutReceipt }
    return receipt
}
