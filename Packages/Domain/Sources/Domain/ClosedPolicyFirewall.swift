import Foundation

/// The closed evidence-to-behavior firewall (Story 4).
///
/// The firewall is the sole bridge from fused sensing input to product
/// behavior. It owns one in-memory bus, fuses internally at injected ticks,
/// qualifies the fused verdict, and routes at most one closed command per
/// evaluation through the fenced coordinator entry point. It never touches
/// the unfenced single-producer path, never invents action kinds, never
/// presents UI, never settles product facts, and never mutates clocks: every
/// command it routes commits identity, rank, and fence only, with no fact
/// and no clock delta.
///
/// Qualification (deny by default):
/// - Unknown verdicts — missing, stale, denied, degraded, contradictory,
///   revoked, fenced, rotated-out — emit nothing. The firewall exposes every
///   authority retirement (revision advance, epoch fence, session rotation)
///   as a passthrough to the held bus authority, so no retirement is
///   unreceivable: post-retirement atoms stop voting at once.
/// - Weak (low-confidence) presence may only quiet (hold presentation while
///   accumulation continues, per the non-pausing suppression semantics) or
///   shift within the live soft-to-latest window. Weak signals never restart
///   and never release. One live representative sustains at most one
///   outstanding hold per input kind: a repeat evaluation with no new
///   admission emits nothing.
/// - Strong (medium/high-confidence) motion restarts the movement cycle
///   through the registered strong-movement command. Strong presence holds
///   quietly. Strong absence releases at most the firewall's own outstanding
///   hold for the same input kind, by naming its exact decision identity;
///   cross-kind absence and absence with no outstanding hold emit nothing.
/// - Shift has no dedicated command in the 2.x vocabulary (the canonical
///   shift-to-seam transition stays 2.x-owned), so a shift is a hold paired
///   with a bounded re-evaluation horizon read live from the passed
///   coordinator's engine configuration — never from a held copy: the
///   smaller of the remaining source lifetime and `latest - now` clamped at
///   zero, degenerate windows quieting instead. Every hold carries a
///   deadline; an expired hold is released lazily at the next evaluation of
///   its kind. Motion reads the movement schedule, every other kind reads
///   the visual schedule, so custom schedules govern without hardcoded
///   profile numbers.
///
/// Every routed command carries a coordinator lease whose lifetime is the
/// smaller of the remaining source lifetime — itself the smaller of the
/// atom TTL remainder and the sensing-lease remainder — and the 90-second
/// coordinator maximum, minted at the evaluation ticks. The lazy
/// auto-release carries no fresh input, so it takes a one-second validity
/// floor: live through the single synchronous fenced reduction, authoritative
/// for nothing beyond it. Action and hold identities mix an injected
/// firewall identity with seeds plus a per-emission counter, so identical
/// inputs on one firewall reproduce identical commands while different
/// firewalls never collide; routing the same command twice replays the
/// original receipt without reapplying.
///
/// Memory-only (Class 0): the firewall persists nothing. The public result
/// is a sanitized receipt — identities, closed kind, effect class, lease
/// window, an opaque assessment digest, and ticks — carrying no reading,
/// confidence, provider, or group content. Full provenance stays
/// module-internal, pinned by in-module tests.
public enum FirewallEffect: Equatable, Sendable {
    /// Hold presentation; accumulation continues.
    case quiet
    /// Hold presentation, re-evaluating no later than the bound.
    case shift(deferralSeconds: TimeInterval)
    /// Restart the movement cycle on strong motion input.
    case restart
    /// Release the firewall's own outstanding hold on strong absence.
    case resume
}

/// The sanitized public result of one firewall evaluation: everything a
/// caller needs to audit the mutation, and nothing Class 0.
public struct FirewallReceipt: Equatable, Sendable {
    public let actionID: ActionID
    public let holdDecisionID: DecisionID?
    public let kind: OpportunityActionKind
    public let effect: FirewallEffect
    public let leaseGrantedTicks: TimeInterval
    public let leaseExpiryTicks: TimeInterval
    public let assessmentDigest: String
    public let evaluatedTicks: TimeInterval
}

/// The full evidence provenance behind one routed command.
/// Module-internal: never leaves Domain in a public result.
struct FirewallProvenance: Equatable, Sendable {
    let reading: FusedReading // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
    let confidence: EvidenceConfidence // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
    let supportingGroups: Int
    let provider: SensingProviderID
    let evidenceAdmittedTicks: TimeInterval
    let evidenceExpiryTicks: TimeInterval
    let evaluatedTicks: TimeInterval
    let softDueSeconds: TimeInterval
    let targetSeconds: TimeInterval
    let latestPreferredSeconds: TimeInterval

    /// Re-ticks a stored provenance for a lazy auto-release: the justification
    /// is unchanged, only the routing moment moves.
    func resolving(atTicks ticks: TimeInterval) -> FirewallProvenance {
        FirewallProvenance(
            reading: reading,
            confidence: confidence,
            supportingGroups: supportingGroups,
            provider: provider,
            evidenceAdmittedTicks: evidenceAdmittedTicks,
            evidenceExpiryTicks: evidenceExpiryTicks,
            evaluatedTicks: ticks,
            softDueSeconds: softDueSeconds,
            targetSeconds: targetSeconds,
            latestPreferredSeconds: latestPreferredSeconds,
        )
    }
}

/// One qualified firewall decision: its effect, the closed command that
/// carries it, and the provenance that justifies it.
/// Module-internal: callers see the sanitized receipt only.
struct FirewallDecision: Equatable, Sendable {
    let effect: FirewallEffect
    let envelope: OpportunityActionEnvelope
    let holdID: DecisionID?
    let provenance: FirewallProvenance
    let assessmentDigest: String
}

/// The full observable result of one routed evaluation.
/// Module-internal: callers see the sanitized receipt only.
struct FirewallDispatch: Equatable, Sendable {
    let decision: FirewallDecision
    let receipt: OpportunityActionReceipt
    let presentation: OpportunityPresentation?
}

/// One outstanding firewall hold: its decision identity, the ticks at which
/// its justification lapses, and the provenance behind it.
private struct OutstandingHold {
    var id: DecisionID
    var deadlineTicks: TimeInterval
    var provenance: FirewallProvenance
}

/// One qualified plan. Three cases for three allowlisted commands, so a
/// non-allowlisted kind is unrepresentable by construction.
enum FirewallPlan {
    /// Open a hold: a bounded shift when the deferral is set, a quiet hold
    /// that lapses with its input when it is not.
    case hold(deferralSeconds: TimeInterval?, leaseLifeSeconds: TimeInterval)
    /// Restart the movement cycle on strong motion input.
    case restart(leaseLifeSeconds: TimeInterval)
    /// Release one outstanding hold.
    case release(hold: DecisionID, leaseLifeSeconds: TimeInterval)

    /// The closed command this plan routes. Exhaustive over the three
    /// cases, mirroring the public allowlist predicate below.
    var actionKind: OpportunityActionKind {
        switch self {
        case .hold:
            .holdBegin
        case .restart:
            .sensorStrongMovementRestart
        case .release:
            .holdRelease
        }
    }

    /// The caller-visible effect of this plan.
    var effect: FirewallEffect {
        switch self {
        case let .hold(deferral, _):
            if let deferral {
                .shift(deferralSeconds: deferral)
            } else {
                .quiet
            }
        case .restart:
            .restart
        case .release:
            .resume
        }
    }

    /// The coordinator-lease lifetime this plan was qualified with.
    var leaseLifeSeconds: TimeInterval {
        switch self {
        case let .hold(_, life):
            life
        case let .restart(life):
            life
        case let .release(_, life):
            life
        }
    }
}

private enum MintRole {
    case action
    case decision
}

public struct ClosedPolicyFirewall: Sendable {
    /// Deny-by-default allowlist: the only commands sensing input may ever
    /// route. Holds quiet or release presentation, and the strong-movement
    /// command restarts the movement cycle; all three commit with no fact
    /// and no clock delta. Every terminal, fact-settling, presentation,
    /// pause, schedule, raw-system, content-choice, companion, and
    /// correction/undo command is refused — including every spelling that
    /// decodes to one.
    public static let emittableKinds: Set<OpportunityActionKind> = [
        .holdBegin, .holdRelease, .sensorStrongMovementRestart,
    ]

    /// Whether sensing input may ever route this command.
    public static func isEmittable(_ kind: OpportunityActionKind) -> Bool {
        emittableKinds.contains(kind)
    }

    /// Opaque digest of one assessment: stable for identical inputs,
    /// revealing nothing about the fused content.
    static func digest(_ provenance: FirewallProvenance) -> String {
        let canonical = [
            String(describing: provenance.reading),
            String(describing: provenance.confidence),
            String(provenance.supportingGroups),
            provenance.provider.code,
            String(provenance.evidenceAdmittedTicks),
            String(provenance.evidenceExpiryTicks),
            String(provenance.evaluatedTicks),
        ].joined(separator: "|")
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in canonical.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0100_0000_01B3
        }
        return String(hash, radix: 16, uppercase: false)
    }

    private var bus: EvidenceBus // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
    private let globalID: GlobalStateID
    private let deviceID: DeviceID
    private let firewallID: UUID
    private let actionSeed: UUID
    private let decisionSeed: UUID
    private var emissionCounter: UInt64 = 0
    private var outstandingHolds: [EvidenceKind: OutstandingHold] = [:] // RAWGUARD-ALLOW: firewall
    private var emittedRestarts: [EvidenceKind: EvidenceAtomID] = [:] // RAWGUARD-ALLOW: firewall
    /// Creates a firewall owning its bus. The schedule always comes from the
    /// coordinator passed to evaluation, never from construction, so a held
    /// copy can never go stale. Stories 6-7 wire this into the live
    /// composition root; until then tests construct it directly.
    public init(
        bus: EvidenceBus, // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        globalID: GlobalStateID,
        deviceID: DeviceID,
        firewallID: UUID,
        actionSeed: UUID,
        decisionSeed: UUID,
    ) {
        self.bus = bus
        self.globalID = globalID
        self.deviceID = deviceID
        self.firewallID = firewallID
        self.actionSeed = actionSeed
        self.decisionSeed = decisionSeed
    }

    /// Admits one sensing proposal through the owned bus. The bus validates
    /// lease provenance, source equality, and freshness; rejections store
    /// nothing.
    public mutating func admit(
        _ proposal: EvidenceProposal, // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        lease: SensingProviderLease,
        for provider: SensingProviderID,
        originRevision: UInt64,
        epoch: ProjectionEpochID,
        presentingDeviceID: DeviceID,
        atTicks ticks: TimeInterval,
    ) -> EvidenceAdmission { // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        bus.admit(
            proposal,
            lease: lease,
            for: provider,
            originRevision: originRevision,
            epoch: epoch,
            presentingDeviceID: presentingDeviceID,
            atTicks: ticks,
        )
    }

    /// Revokes one sensing lease against the owned bus with immediate
    /// effect: the revoked lease's atoms stop voting at once.
    public mutating func revokeSensingLease(_ lease: SensingProviderLease) {
        bus.revoke(lease)
    }

    /// Advances one provider's scope revision on the held authority,
    /// implicitly retiring every predecessor lease bound to an earlier
    /// revision.
    public mutating func advanceSensingRevision(for provider: SensingProviderID) {
        bus.advanceRevision(for: provider)
    }

    /// Fences one epoch on the held authority, implicitly retiring every
    /// lease bound to it regardless of remaining lease time.
    public mutating func fenceSensingEpoch(_ epoch: ProjectionEpochID) {
        bus.authority.fenceEpoch(epoch)
    }

    /// Rotates the session generation on the held authority, retiring every
    /// prior-generation lease. Firewall hold authority retires with it: no
    /// pre-rotation hold may be released post-rotation.
    public mutating func noteSensingRotation() {
        bus.authority.noteSessionRotation()
        outstandingHolds = [:]
        emittedRestarts = [:]
    }

    /// Fuses one input kind at the presented ticks and routes at most one
    /// closed command through the fenced coordinator entry point, returning
    /// the sanitized receipt. Returns nil — routing nothing and mutating
    /// neither the coordinator nor the hold ledger — for every unqualified
    /// verdict.
    public mutating func evaluate(
        _ kind: EvidenceKind, // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        on coordinator: inout OpportunityCoordinator,
        atTicks ticks: TimeInterval,
    ) -> FirewallReceipt? {
        guard let routed = evaluateDispatch(kind, on: &coordinator, atTicks: ticks) else { return nil }
        guard let lease = routed.decision.envelope.lease else { return nil }
        return FirewallReceipt(
            actionID: routed.decision.envelope.action,
            holdDecisionID: routed.decision.holdID,
            kind: routed.decision.envelope.kind,
            effect: routed.decision.effect,
            leaseGrantedTicks: lease.grantedTicks,
            leaseExpiryTicks: lease.expiryTicks,
            assessmentDigest: routed.decision.assessmentDigest,
            evaluatedTicks: ticks,
        )
    }

    /// Full-fidelity evaluation for in-module pins: the decision, the closed
    /// command, the fenced receipt, and the resulting presentation.
    mutating func evaluateDispatch(
        _ kind: EvidenceKind, // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        on coordinator: inout OpportunityCoordinator,
        atTicks ticks: TimeInterval,
    ) -> FirewallDispatch? {
        if let held = outstandingHolds[kind], held.deadlineTicks <= ticks {
            return releaseOutstanding(kind: kind, held: held, coordinator: &coordinator, atTicks: ticks)
        }
        let assessment: FusedAssessment = EvidenceFusion // RAWGUARD-ALLOW: firewall
            .fuse(bus, kind: kind, atTicks: ticks)
        guard let representative = assessment.representative else { return nil }
        let remaining = min(representative.expiryTicks, representative.provenance.lease.expiryTicks) - ticks
        guard remaining > 0 else { return nil }
        let schedule = schedule(for: kind, configuration: coordinator.engine.configuration)
        guard let plan = qualify(
            assessment,
            remainingEvidenceSeconds: remaining,
            kind: kind,
            schedule: schedule,
            atTicks: ticks,
        ) else {
            return nil
        }
        let provenance = FirewallProvenance(
            reading: assessment.reading,
            confidence: assessment.confidence,
            supportingGroups: assessment.supportingGroups,
            provider: representative.provenance.provider,
            evidenceAdmittedTicks: representative.provenance.admittedTicks,
            evidenceExpiryTicks: representative.expiryTicks,
            evaluatedTicks: ticks,
            softDueSeconds: schedule.softDueSeconds,
            targetSeconds: schedule.targetSeconds,
            latestPreferredSeconds: schedule.latestPreferredSeconds,
        )
        guard let routed = route(
            plan: plan,
            kind: kind,
            provenance: provenance,
            coordinator: &coordinator,
            atTicks: ticks,
        )
        else {
            return nil
        }
        if case .restart = plan {
            emittedRestarts[kind] = representative.id
        }
        return routed
    }

    /// Qualifies one fused verdict into a closed plan, or refuses it. A live
    /// outstanding hold for the kind suppresses every new hold (idempotent:
    /// one representative sustains at most one hold); an already-emitted
    /// restart for the same representative never re-emits until a new
    /// admission supersedes it; absence releases only the same kind's hold.
    private func qualify(
        _ assessment: FusedAssessment, // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        remainingEvidenceSeconds remaining: TimeInterval,
        kind: EvidenceKind, // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        schedule: OpportunitySchedule,
        atTicks ticks: TimeInterval,
    ) -> FirewallPlan? {
        let leaseLife = min(remaining, OpportunityLease.maximumLifetimeSeconds)
        switch assessment.reading {
        case .unknown:
            return nil
        case .absent:
            guard assessment.confidence != .low else { return nil }
            guard let held = outstandingHolds[kind] else { return nil }
            return .release(hold: held.id, leaseLifeSeconds: leaseLife)
        case .present:
            guard outstandingHolds[kind] == nil else { return nil }
            if assessment.confidence == .low {
                let horizon = max(schedule.latestPreferredSeconds - ticks, 0)
                guard horizon > 0 else {
                    return .hold(deferralSeconds: nil, leaseLifeSeconds: leaseLife)
                }
                return .hold(deferralSeconds: min(remaining, horizon), leaseLifeSeconds: leaseLife)
            }
            if kind == .motion {
                guard emittedRestarts[kind] != assessment.representative?.id else { return nil }
                return .restart(leaseLifeSeconds: leaseLife)
            }
            return .hold(deferralSeconds: nil, leaseLifeSeconds: leaseLife)
        }
    }

    /// Routes one qualified plan through the fenced entry point. On commit,
    /// holds open exactly one ledger entry per kind, releases close their
    /// kind's entry, and restarts touch no entry. Rejections change nothing.
    private mutating func route(
        plan: FirewallPlan,
        kind: EvidenceKind, // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        provenance: FirewallProvenance,
        coordinator: inout OpportunityCoordinator,
        atTicks ticks: TimeInterval,
    ) -> FirewallDispatch? {
        emissionCounter &+= 1
        let counter = emissionCounter
        let holdID: DecisionID? = switch plan {
        case .hold:
            DecisionID(mintedUUID(from: decisionSeed, counter: counter, role: .decision))
        case let .release(held, _):
            held
        case .restart:
            nil
        }
        guard let envelope = makeEnvelope(
            kind: plan.actionKind,
            holdID: holdID,
            counter: counter,
            leaseLifeSeconds: plan.leaseLifeSeconds,
            coordinator: coordinator,
            atTicks: ticks,
        ) else {
            return nil
        }
        let output = coordinator.dispatchAction(envelope, atTicks: ticks)
        guard output.receipt.outcome == .committed else { return nil }
        switch plan {
        case let .hold(deferral, _):
            guard let holdID else { return nil }
            let deadline = ticks + (deferral ?? max(provenance.evidenceExpiryTicks - ticks, 0))
            outstandingHolds[kind] = OutstandingHold(id: holdID, deadlineTicks: deadline, provenance: provenance)
        case .release:
            outstandingHolds[kind] = nil
        case .restart:
            break
        }
        let decision = FirewallDecision(
            effect: plan.effect,
            envelope: envelope,
            holdID: holdID,
            provenance: provenance,
            assessmentDigest: Self.digest(provenance),
        )
        return FirewallDispatch(decision: decision, receipt: output.receipt, presentation: output.presentation)
    }

    /// Releases one deadline-expired hold lazily at the next evaluation of
    /// its kind. The release carries no fresh input, so its lease takes a
    /// one-second validity floor: live through the single synchronous fenced
    /// reduction, authoritative for nothing beyond it.
    private mutating func releaseOutstanding(
        kind: EvidenceKind, // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        held: OutstandingHold,
        coordinator: inout OpportunityCoordinator,
        atTicks ticks: TimeInterval,
    ) -> FirewallDispatch? {
        route(
            plan: .release(hold: held.id, leaseLifeSeconds: 1),
            kind: kind,
            provenance: held.provenance.resolving(atTicks: ticks),
            coordinator: &coordinator,
            atTicks: ticks,
        )
    }

    /// Builds the closed command for one qualified plan, minted against the
    /// coordinator's live generation and global revision so the fenced entry
    /// point accepts exactly what the firewall qualified.
    private func makeEnvelope(
        kind: OpportunityActionKind,
        holdID: DecisionID?,
        counter: UInt64,
        leaseLifeSeconds: TimeInterval,
        coordinator: OpportunityCoordinator,
        atTicks ticks: TimeInterval,
    ) -> OpportunityActionEnvelope? {
        var payload = OpportunityActionPayload()
        payload.holdDecisionID = holdID
        let generation = coordinator.actionReducer.generation
        let revision = coordinator.actionReducer.globalRevision
        guard let lease = try? OpportunityLease(
            scope: .global(id: globalID, revision: revision),
            generation: generation,
            grantedDeviceID: deviceID,
            grantedTicks: ticks,
            expiryTicks: ticks + leaseLifeSeconds,
        ) else {
            return nil
        }
        return OpportunityActionEnvelope(
            action: ActionID(
                uuid: mintedUUID(from: actionSeed, counter: counter, role: .action),
                deviceID: deviceID,
                counter: counter,
            ),
            kind: kind,
            scope: .globalSystem,
            originRevision: revision,
            generation: generation,
            projectionEpoch: nil,
            originPhase: nil,
            segmentID: nil,
            causalParents: [],
            lease: lease,
            payload: payload,
        )
    }

    /// The live schedule governing one input kind: motion reads the movement
    /// schedule, every other kind reads the visual schedule.
    private func schedule(
        for kind: EvidenceKind, // RAWGUARD-ALLOW: closed Domain firewall consumes Class 0 evidence
        configuration: ProtocolConfiguration,
    ) -> OpportunitySchedule {
        switch kind {
        case .motion:
            configuration.movement
        case .presence, .ambient:
            configuration.visual
        }
    }

    /// Mixes the firewall identity, a seed, a role, and the per-emission
    /// counter into one identity: deterministic without randomness, unique
    /// per emission and role, and disjoint across firewalls even when seeds
    /// repeat.
    private func mintedUUID(from seed: UUID, counter: UInt64, role: MintRole) -> UUID {
        let seedText = seed.uuidString.lowercased()
        let idText = firewallID.uuidString.lowercased()
        let mixed = counter | (role == .decision ? 0x8000_0000_0000 : 0)
        let hex = String(mixed, radix: 16, uppercase: false)
        let tail = String(repeating: "0", count: max(0, 12 - hex.count)) + hex.suffix(12)
        let stem = String(idText.prefix(8)) + String(seedText.dropFirst(8).prefix(15))
        return UUID(uuidString: stem + "-" + tail) ?? seed
    }
}
