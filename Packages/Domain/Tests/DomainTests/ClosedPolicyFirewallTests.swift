import Foundation
import Testing
@testable import Domain

/// Story 4 RED: the closed evidence-to-behavior firewall.
///
/// The firewall is the sole bridge from fused sensing input to product
/// behavior. It owns one evidence bus, fuses internally at injected ticks,
/// and routes only through the fenced `dispatchAction` entry point — never
/// the unfenced single-producer `dispatch` path. Weak (low-confidence)
/// signals may only quiet (hold presentation, accumulation continues) or
/// shift within the live soft/target/latest window; strong signals drive
/// bounded, replayable, provenance-carrying mutations. Unknown, stale,
/// denied, degraded, contradictory, revoked, and absent signals emit nothing.
private let fwSensingDevice = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000faa001")!)
private let fwEpoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000efaa001")!)
private let fwGlobal = GlobalStateID(UUID(uuidString: "00000000-0000-0000-0000-00000000b001")!)
private let fwDevice = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000d001")!)
private let fwActionSeed = UUID(uuidString: "00000000-0000-0000-0000-000000a00101")!
private let fwDecisionSeed = UUID(uuidString: "00000000-0000-0000-0000-000000d00101")!
private let fwFirewallID = UUID(uuidString: "11111111-0000-0000-0000-000000f00101")!
private let fwFirewallIDOther = UUID(uuidString: "22222222-0000-0000-0000-000000f00102")!

private func firewallConfiguration(
    visualSoft: TimeInterval = 997,
    visualTarget: TimeInterval = 1_009,
    visualLatest: TimeInterval = 1_061,
    movementSoft: TimeInterval = 2_000,
    movementTarget: TimeInterval = 2_100,
    movementLatest: TimeInterval = 2_300
) throws -> ProtocolConfiguration {
    try ProtocolConfiguration(
        visual: OpportunitySchedule(
            softDueSeconds: visualSoft,
            targetSeconds: visualTarget,
            latestPreferredSeconds: visualLatest,
            durationOptionsSeconds: [5]
        ),
        movement: OpportunitySchedule(
            softDueSeconds: movementSoft,
            targetSeconds: movementTarget,
            latestPreferredSeconds: movementLatest,
            durationOptionsSeconds: [300]
        ),
        activityEstimator: ActivityEstimatorConfiguration(
            recentInputWindowSeconds: 60,
            longIdleResetSeconds: 300,
            wakeUnlockGraceSeconds: 90
        ),
        delivery: OpportunityDeliveryConfiguration(
            waitForLowFrictionMoment: false,
            mergeWindowSeconds: 5,
            headsUpDefault: true,
            headsUpSecondsBeforeTarget: 2,
            snoozeOptionsSeconds: [300, 600, 900],
            maximumRepeatedEscalations: 1,
            lockoutAllowed: false
        )
    )
}

private struct FirewallHarness {
    var authority: SensingLeaseAuthority
    var presenceLease: SensingProviderLease
    var motionLease: SensingProviderLease
    var ambientLease: SensingProviderLease
    var coordinator: OpportunityCoordinator
    var firewall: ClosedPolicyFirewall
}
private func firewallHarness(
    configuration: ProtocolConfiguration? = nil,
    leaseLifetime: TimeInterval = 60,
    firewallID: UUID = fwFirewallID
) throws -> FirewallHarness {
    let configuration = try configuration ?? firewallConfiguration()
    var authority = SensingLeaseAuthority()
    func issue(_ provider: SensingProviderID) throws -> SensingProviderLease {
        try authority.issue(
            provider: provider,
            epoch: fwEpoch,
            device: fwSensingDevice,
            lifetimeSeconds: leaseLifetime,
            atTicks: 1_000
        )
    }
    let presence = try issue(.fakePresence)
    let motion = try issue(.fakeMotion)
    let ambient = try issue(.fakeAmbient)
    let bus = EvidenceBus(capacity: 8, authority: authority)
    let firewall = ClosedPolicyFirewall(
        bus: bus,
        globalID: fwGlobal,
        deviceID: fwDevice,
        firewallID: firewallID,
        actionSeed: fwActionSeed,
        decisionSeed: fwDecisionSeed
    )
    let coordinator = OpportunityCoordinator(engine: ProtocolEngine(configuration: configuration))
    return FirewallHarness(
        authority: authority,
        presenceLease: presence,
        motionLease: motion,
        ambientLease: ambient,
        coordinator: coordinator,
        firewall: firewall
    )
}

private func firewallProposal(
    kind: EvidenceKind,
    reading: EvidenceReading = .present,
    quality: EvidenceQuality = .full,
    confidence: EvidenceConfidence = .medium,
    group: EvidenceIndependenceGroup = .fakeAlpha,
    observed: TimeInterval = 1_000,
    ttl: TimeInterval = 60
) throws -> EvidenceProposal {
    let source: EvidenceSource =
        switch kind {
        case .presence: .fakePresence
        case .motion: .fakeMotion
        case .ambient: .fakeAmbient
        }
    return try EvidenceProposal(
        kind: kind,
        source: source,
        reading: reading,
        quality: quality,
        confidence: confidence,
        coverage: .full,
        independenceGroup: group,
        observedTicks: observed,
        timeToLiveSeconds: ttl
    )
}

private func firewallAdmit(
    harness: inout FirewallHarness,
    kind: EvidenceKind,
    reading: EvidenceReading = .present,
    quality: EvidenceQuality = .full,
    confidence: EvidenceConfidence = .medium,
    group: EvidenceIndependenceGroup = .fakeAlpha,
    observed: TimeInterval = 1_000,
    ttl: TimeInterval = 60,
    atTicks: TimeInterval = 1_010
) throws {
    let proposal = try firewallProposal(
        kind: kind,
        reading: reading,
        quality: quality,
        confidence: confidence,
        group: group,
        observed: observed,
        ttl: ttl
    )
    let lease =
        switch kind {
        case .presence: harness.presenceLease
        case .motion: harness.motionLease
        case .ambient: harness.ambientLease
        }
    #expect(
        harness.firewall.admit(
            proposal,
            lease: lease,
            for: proposal.source.providerID,
            originRevision: 0,
            epoch: fwEpoch,
            presentingDeviceID: fwSensingDevice,
            atTicks: atTicks
        ) == .admitted
    )
}

// MARK: - Closed allowlist

@Suite("Closed firewall allowlist")
struct ClosedPolicyFirewallAllowlistTests {
    @Test("The evidence-emittable set is exactly hold, release, and strong restart")
    func emittableSetIsExactlyTheTriple() {
        #expect(ClosedPolicyFirewall.emittableKinds == [
            .holdBegin, .holdRelease, .sensorStrongMovementRestart,
        ])
    }

    @Test("Every one of the 51 action kinds is either allowlisted or refused")
    func allKindsPartitioned() {
        #expect(OpportunityActionKind.allCases.count == 51)
        for kind in OpportunityActionKind.allCases {
            #expect(
                ClosedPolicyFirewall.isEmittable(kind)
                    == ClosedPolicyFirewall.emittableKinds.contains(kind),
                "allowlist disagrees with itself on \(kind.rawValue)"
            )
        }
        #expect(OpportunityActionKind.allCases.filter(ClosedPolicyFirewall.isEmittable).count == 3)
    }

    @Test("No new action kinds were invented beside the 2.x vocabulary")
    func noNewActionKinds() {
        #expect(OpportunityActionKind.allCases.count == 51)
    }

    @Test("Every forbidden kind spelled by raw value is refused")
    func forbiddenRawValuesRefused() {
        for kind in OpportunityActionKind.allCases where !ClosedPolicyFirewall.emittableKinds.contains(kind) {
            let respelled = OpportunityActionKind(rawValue: kind.rawValue)
            #expect(respellikind(respelled, named: kind.rawValue))
        }
    }

    @Test("Codable-smuggled forbidden kinds are refused after decode")
    func decodedForbiddenKindsRefused() throws {
        for kind in OpportunityActionKind.allCases where !ClosedPolicyFirewall.emittableKinds.contains(kind) {
            let data = Data(#""\#(kind.rawValue)""#.utf8)
            let decoded = try JSONDecoder().decode(OpportunityActionKind.self, from: data)
            #expect(!ClosedPolicyFirewall.isEmittable(decoded))
        }
    }

    @Test("Unknown spellings decode fail-closed, including the missing shift case")
    func unknownSpellingsDoNotDecode() {
        for spelling in [
            "deliveryShiftToSeam",
            "delivery.shift_to_seam",
            "delivery_shift_to_seam",
            "holdbegin",
            "HOLDBEGIN",
            "HoldBegin",
            "visualSkip ",
            "",
        ] {
            let data = Data(#""\#(spelling)""#.utf8)
            #expect(
                throws: (any Error).self,
                "unregistered spelling \(spelling) must not decode"
            ) {
                _ = try JSONDecoder().decode(OpportunityActionKind.self, from: data)
            }
            #expect(OpportunityActionKind(rawValue: spelling) == nil)
        }
    }

    @Test("The three plan cases map to exactly the three allowlisted commands")
    func planCasesMapToAllowlistedKinds() {
        let hold = FirewallPlan.hold(deferralSeconds: 5, leaseLifeSeconds: 60)
        let restart = FirewallPlan.restart(leaseLifeSeconds: 60)
        let release = FirewallPlan.release(
            hold: DecisionID(UUID(uuidString: "00000000-0000-0000-0000-00000000d101")!),
            leaseLifeSeconds: 60
        )
        #expect(hold.actionKind == .holdBegin)
        #expect(restart.actionKind == .sensorStrongMovementRestart)
        #expect(release.actionKind == .holdRelease)
        #expect(Set([hold.actionKind, restart.actionKind, release.actionKind]) == ClosedPolicyFirewall.emittableKinds)
    }
}

// MARK: - Authority retirement

@Suite("Closed firewall authority retirement")
struct ClosedPolicyFirewallRetirementTests {
    @Test("Session rotation retires admitted input: nothing emits, no new generation routes")
    func rotationRetiresAdmittedInput() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .high)
        harness.firewall.noteSensingRotation()
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
        #expect(harness.coordinator.state == before)
        #expect(harness.coordinator.actionReducer.globalRevision == 0)
    }

    @Test("Revision advance retires predecessor leases immediately")
    func revisionAdvanceRetiresLeases() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .high)
        harness.firewall.advanceSensingRevision(for: .fakePresence)
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
    }

    @Test("Epoch fencing retires every lease bound to the epoch")
    func epochFenceRetiresLeases() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .high)
        harness.firewall.fenceSensingEpoch(fwEpoch)
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
    }
}

private func respellikind(_ kind: OpportunityActionKind?, named raw: String) -> Bool {
    guard let kind else { return false }
    return !ClosedPolicyFirewall.isEmittable(kind)
}

// MARK: - Silence

@Suite("Closed firewall silence")
struct ClosedPolicyFirewallSilenceTests {
    @Test("Missing evidence emits nothing and leaves the coordinator untouched")
    func missingEmitsNothing() throws {
        var harness = try firewallHarness()
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
        #expect(harness.coordinator.state == before)
    }

    @Test("Stale evidence emits nothing")
    func staleEmitsNothing() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence)
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 2_000) == nil)
        #expect(harness.coordinator.state == before)
    }

    @Test("Denied evidence emits nothing")
    func deniedEmitsNothing() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, quality: .denied)
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
        #expect(harness.coordinator.state == before)
    }

    @Test("Degraded evidence emits nothing")
    func degradedEmitsNothing() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, quality: .degraded)
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
        #expect(harness.coordinator.state == before)
    }

    @Test("Contradictory evidence emits nothing")
    func contradictoryEmitsNothing() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, reading: .present, group: .fakeAlpha)
        try firewallAdmit(harness: &harness, kind: .presence, reading: .absent, group: .fakeBeta)
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
        #expect(harness.coordinator.state == before)
    }

    @Test("Revoked evidence stops emitting immediately")
    func revokedEmitsNothing() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence)
        harness.firewall.revokeSensingLease(harness.presenceLease)
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
        #expect(harness.coordinator.state == before)
    }

    @Test("Strong absence with no outstanding hold emits nothing")
    func absentWithoutHoldEmitsNothing() throws {
        var harness = try firewallHarness()
        try firewallAdmit(
            harness: &harness,
            kind: .presence,
            reading: .absent,
            confidence: .high
        )
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
        #expect(harness.coordinator.state == before)
    }
}

// MARK: - Weak evidence

@Suite("Closed firewall weak evidence")
struct ClosedPolicyFirewallWeakTests {
    @Test("Weak presence quiets or shifts inside the live visual window")
    func weakPresenceShiftIsWindowBounded() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low)
        guard let dispatch = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("weak qualified presence must emit")
            return
        }
        #expect(dispatch.decision.envelope.kind == .holdBegin)
        // Remaining evidence life is 40 s; latest - now is 41 s.
        #expect(dispatch.decision.effect == .shift(deferralSeconds: 40))
        #expect(dispatch.receipt.outcome == .committed)
        #expect(dispatch.receipt.facts.isEmpty)
    }

    @Test("The shift cap tracks the live engine configuration, never a held copy")
    func shiftCapTracksLiveConfiguration() throws {
        let narrow = try firewallConfiguration(
            visualSoft: 500,
            visualTarget: 505,
            visualLatest: 1_032
        )
        var harness = try firewallHarness(configuration: narrow)
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low)
        guard let dispatch = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("weak qualified presence must emit under the narrow schedule")
            return
        }
        // Same 40 s of remaining evidence life, now clamped to latest - now = 12 s.
        #expect(dispatch.decision.effect == .shift(deferralSeconds: 12))
    }

    @Test("One firewall reads each coordinator engine's live window")
    func shiftCapFollowsEachEngine() throws {
        let wide = try firewallConfiguration(visualLatest: 1_320)
        let narrow = try firewallConfiguration(
            visualSoft: 500,
            visualTarget: 505,
            visualLatest: 1_032
        )
        var wideHarness = try firewallHarness(configuration: wide)
        var narrowHarness = try firewallHarness(configuration: narrow)
        try firewallAdmit(harness: &wideHarness, kind: .presence, confidence: .low)
        try firewallAdmit(harness: &narrowHarness, kind: .presence, confidence: .low)
        let wideDispatch = try #require(
            wideHarness.firewall.evaluateDispatch(.presence, on: &wideHarness.coordinator, atTicks: 1_020)
        )
        let narrowDispatch = try #require(
            narrowHarness.firewall.evaluateDispatch(.presence, on: &narrowHarness.coordinator, atTicks: 1_020)
        )
        // latest - now is 300 s vs 12 s; remaining evidence life is 40 s either way.
        #expect(wideDispatch.decision.effect == .shift(deferralSeconds: 40))
        #expect(narrowDispatch.decision.effect == .shift(deferralSeconds: 12))
    }

    @Test("One second below latest shifts by exactly one second")
    func oneSecondBelowLatestShiftsOne() throws {
        var harness = try firewallHarness(leaseLifetime: 90)
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low, ttl: 120)
        guard let dispatch = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_060)
        else {
            Issue.record("weak qualified presence must emit one second below latest")
            return
        }
        #expect(dispatch.decision.envelope.kind == .holdBegin)
        #expect(dispatch.decision.effect == .shift(deferralSeconds: 1))
        #expect(dispatch.receipt.outcome == .committed)
    }

    @Test("At latest the horizon is gone and weak presence quiets")
    func atLatestWeakPresenceQuiets() throws {
        var harness = try firewallHarness(leaseLifetime: 90)
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low, ttl: 120)
        guard let dispatch = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_061)
        else {
            Issue.record("weak qualified presence must emit at latest")
            return
        }
        #expect(dispatch.decision.effect == .quiet)
        #expect(dispatch.decision.envelope.kind == .holdBegin)
        #expect(dispatch.receipt.outcome == .committed)
    }

    @Test("A repeat evaluation sustains a single hold without a new revision")
    func repeatEvaluationSustainsSingleHold() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low)
        guard harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020) != nil
        else {
            Issue.record("weak qualified presence must emit first")
            return
        }
        #expect(harness.coordinator.actionReducer.globalRevision == 1)
        #expect(harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020) == nil)
        #expect(harness.coordinator.actionReducer.globalRevision == 1)
    }

    @Test("A degenerate live window quiets instead of shifting")
    func degenerateWindowQuiets() throws {
        let degenerate = try firewallConfiguration(
            visualSoft: 500,
            visualTarget: 500,
            visualLatest: 500
        )
        var harness = try firewallHarness(configuration: degenerate)
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low)
        guard let dispatch = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("weak qualified presence must emit under the degenerate schedule")
            return
        }
        #expect(dispatch.decision.effect == .quiet)
        #expect(dispatch.decision.envelope.kind == .holdBegin)
        #expect(dispatch.receipt.outcome == .committed)
        #expect(dispatch.receipt.facts.isEmpty)
    }

    @Test("Weak motion reads the live movement window and never restarts")
    func weakMotionReadsMovementWindow() throws {
        let config = try firewallConfiguration(
            movementSoft: 700,
            movementTarget: 705,
            movementLatest: 1_032
        )
        var harness = try firewallHarness(configuration: config)
        try firewallAdmit(harness: &harness, kind: .motion, confidence: .low)
        guard let dispatch = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("weak qualified motion must emit")
            return
        }
        #expect(dispatch.decision.envelope.kind == .holdBegin)
        #expect(dispatch.decision.envelope.kind != .sensorStrongMovementRestart)
        // Clamped to latest - now = 12 s on the movement schedule, not the visual one.
        #expect(dispatch.decision.effect == .shift(deferralSeconds: 12))
        #expect(dispatch.receipt.outcome == .committed)
        #expect(dispatch.receipt.facts.isEmpty)
    }

    @Test("Weak absence never releases an outstanding hold")
    func weakAbsenceNeverReleases() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low)
        guard harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_020) != nil
        else {
            Issue.record("weak qualified presence must emit first")
            return
        }
        try firewallAdmit(
            harness: &harness,
            kind: .presence,
            reading: .absent,
            confidence: .low,
            group: .fakeBeta,
            atTicks: 1_021
        )
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_022) == nil)
    }
}

// MARK: - Strong evidence

@Suite("Closed firewall strong evidence")
struct ClosedPolicyFirewallStrongTests {
    @Test("Strong motion restarts with provenance and no facts")
    func strongMotionRestarts() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .motion, confidence: .high)
        guard let dispatch = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("strong motion must emit")
            return
        }
        #expect(dispatch.decision.effect == .restart)
        #expect(dispatch.decision.envelope.kind == .sensorStrongMovementRestart)
        #expect(dispatch.receipt.outcome == .committed)
        #expect(dispatch.receipt.facts.isEmpty)
        let provenance = dispatch.decision.provenance
        #expect(provenance.reading == .present)
        #expect(provenance.confidence == .high)
        #expect(provenance.supportingGroups == 1)
        #expect(provenance.provider == .fakeMotion)
        #expect(provenance.evidenceAdmittedTicks == 1_010)
        #expect(provenance.evidenceExpiryTicks == 1_060)
        #expect(provenance.evaluatedTicks == 1_020)
        #expect(provenance.softDueSeconds == 2_000)
        #expect(provenance.targetSeconds == 2_100)
        #expect(provenance.latestPreferredSeconds == 2_300)
    }

    @Test("Medium motion counts as strong and restarts")
    func mediumMotionRestarts() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .motion, confidence: .medium)
        let dispatch = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_020)
        #expect(dispatch?.decision.envelope.kind == .sensorStrongMovementRestart)
        #expect(dispatch?.receipt.outcome == .committed)
        #expect(dispatch?.receipt.facts.isEmpty == true)
    }

    @Test("Strong presence holds quietly instead of restarting")
    func strongPresenceHolds() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .high)
        guard let dispatch = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("strong presence must emit")
            return
        }
        #expect(dispatch.decision.effect == .quiet)
        #expect(dispatch.decision.envelope.kind == .holdBegin)
        #expect(dispatch.receipt.outcome == .committed)
        #expect(dispatch.receipt.facts.isEmpty)
    }

    @Test("Strong absence releases exactly the firewall's own outstanding hold")
    func strongAbsenceReleasesOwnHold() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low)
        guard let hold = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("weak qualified presence must emit first")
            return
        }
        #expect(hold.receipt.outcome == .committed)
        try firewallAdmit(
            harness: &harness,
            kind: .presence,
            reading: .absent,
            confidence: .high,
            atTicks: 1_021
        )
        guard let release = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_022)
        else {
            Issue.record("strong absence must release the outstanding hold")
            return
        }
        #expect(release.decision.effect == .resume)
        #expect(release.decision.envelope.kind == .holdRelease)
        #expect(release.decision.envelope.payload.holdDecisionID == hold.decision.envelope.payload.holdDecisionID)
        #expect(release.receipt.outcome == .committed)
        #expect(release.receipt.facts.isEmpty)
        // The hold is consumed: a further strong absence emits nothing.
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_023) == nil)
    }

    @Test("Cross-kind absence never releases another kind's hold")
    func crossKindAbsenceNeverReleases() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low)
        guard harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020) != nil
        else {
            Issue.record("weak qualified presence must emit first")
            return
        }
        try firewallAdmit(
            harness: &harness,
            kind: .motion,
            reading: .absent,
            confidence: .high,
            atTicks: 1_021
        )
        // Strong motion absence has no motion hold to release and must not touch presence.
        #expect(harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_022) == nil)
        // The presence hold is still outstanding: same-kind absence releases it.
        try firewallAdmit(
            harness: &harness,
            kind: .presence,
            reading: .absent,
            confidence: .high,
            atTicks: 1_023
        )
        guard let release = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_024)
        else {
            Issue.record("same-kind absence must still release the presence hold")
            return
        }
        #expect(release.decision.envelope.kind == .holdRelease)
        #expect(release.receipt.outcome == .committed)
    }

    @Test("An expired hold is released lazily at the next evaluation of its kind")
    func expiredHoldAutoReleases() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low)
        guard let hold = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("weak qualified presence must emit first")
            return
        }
        // The shift horizon is 40 s, so the hold deadline is 1060.
        #expect(hold.decision.effect == .shift(deferralSeconds: 40))
        guard let auto = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_060)
        else {
            Issue.record("the expired hold must auto-release")
            return
        }
        #expect(auto.decision.effect == .resume)
        #expect(auto.decision.envelope.kind == .holdRelease)
        #expect(auto.decision.envelope.payload.holdDecisionID == hold.decision.envelope.payload.holdDecisionID)
        #expect(auto.receipt.outcome == .committed)
        let lease = try #require(auto.decision.envelope.lease)
        #expect(lease.grantedTicks == 1_060)
        #expect(lease.expiryTicks == 1_061)
        // The ledger is empty and the input is spent: nothing further emits.
        #expect(harness.firewall.evaluate(.presence, on: &harness.coordinator, atTicks: 1_061) == nil)
    }

    @Test("The outbound lease dies with the atom when the atom is shorter")
    func outboundLeaseIsAtomBound() throws {
        var harness = try firewallHarness(leaseLifetime: 90)
        try firewallAdmit(
            harness: &harness,
            kind: .motion,
            confidence: .high,
            observed: 1_000,
            ttl: 60,
            atTicks: 1_010
        )
        guard let dispatch = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("strong motion must emit")
            return
        }
        let lease = try #require(dispatch.decision.envelope.lease)
        #expect(lease.scope == .global(id: fwGlobal, revision: 0))
        #expect(lease.generation == CoordinatorGeneration(0))
        #expect(lease.grantedTicks == 1_020)
        // Atom TTL runs through 1060; the sensing lease runs through 1090.
        #expect(lease.expiryTicks == 1_060)
        #expect(dispatch.receipt.globalRevision == harness.coordinator.actionReducer.globalRevision)
    }

    @Test("The outbound lease dies with the sensing lease when the lease is shorter")
    func outboundLeaseIsSensingBound() throws {
        var harness = try firewallHarness(leaseLifetime: 60)
        try firewallAdmit(
            harness: &harness,
            kind: .motion,
            confidence: .high,
            observed: 1_000,
            ttl: 300,
            atTicks: 1_010
        )
        guard let dispatch = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("strong motion must emit")
            return
        }
        let lease = try #require(dispatch.decision.envelope.lease)
        #expect(lease.grantedTicks == 1_020)
        // Atom TTL runs through 1300; the sensing lease runs through 1060.
        #expect(lease.expiryTicks == 1_060)
        #expect(lease.expiryTicks - lease.grantedTicks <= OpportunityLease.maximumLifetimeSeconds)
    }

    @Test("The public receipt carries no fused-content path")
    func publicReceiptCarriesNoFusedContent() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .motion, confidence: .high)
        guard let receipt = harness.firewall.evaluate(.motion, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("strong motion must emit a public receipt")
            return
        }
        #expect(receipt.kind == .sensorStrongMovementRestart)
        #expect(receipt.effect == .restart)
        #expect(receipt.leaseGrantedTicks == 1_020)
        #expect(receipt.evaluatedTicks == 1_020)
        #expect(!receipt.assessmentDigest.isEmpty)
        let labels = Set(Mirror(reflecting: receipt).children.compactMap(\.label))
        #expect(labels == [
            "actionID", "holdDecisionID", "kind", "effect",
            "leaseGrantedTicks", "leaseExpiryTicks", "assessmentDigest", "evaluatedTicks",
        ])
        #expect(!labels.contains("reading"))
        #expect(!labels.contains("confidence"))
        #expect(!labels.contains("provider"))
        #expect(!labels.contains("supportingGroups"))
    }

    @Test("Identical inputs digest identically; different verdicts digest differently")
    func assessmentDigestIsStableAndSensitive() throws {
        var first = try firewallHarness()
        var second = try firewallHarness()
        try firewallAdmit(harness: &first, kind: .motion, confidence: .high)
        try firewallAdmit(harness: &second, kind: .motion, confidence: .high)
        let firstReceipt = try #require(first.firewall.evaluate(.motion, on: &first.coordinator, atTicks: 1_020))
        let secondReceipt = try #require(second.firewall.evaluate(.motion, on: &second.coordinator, atTicks: 1_020))
        #expect(firstReceipt.assessmentDigest == secondReceipt.assessmentDigest)
        var third = try firewallHarness()
        try firewallAdmit(harness: &third, kind: .motion, confidence: .medium)
        let thirdReceipt = try #require(third.firewall.evaluate(.motion, on: &third.coordinator, atTicks: 1_020))
        #expect(thirdReceipt.assessmentDigest != firstReceipt.assessmentDigest)
    }

    @Test("Different firewall identities never collide on minted commands")
    func firewallIdentitiesDoNotCollide() throws {
        var first = try firewallHarness(firewallID: fwFirewallID)
        var second = try firewallHarness(firewallID: fwFirewallIDOther)
        try firewallAdmit(harness: &first, kind: .motion, confidence: .high)
        try firewallAdmit(harness: &second, kind: .motion, confidence: .high)
        let firstDispatch = try #require(
            first.firewall.evaluateDispatch(.motion, on: &first.coordinator, atTicks: 1_020)
        )
        let secondDispatch = try #require(
            second.firewall.evaluateDispatch(.motion, on: &second.coordinator, atTicks: 1_020)
        )
        #expect(firstDispatch.decision.envelope.action.uuid != secondDispatch.decision.envelope.action.uuid)
        #expect(firstDispatch.decision.envelope.action != secondDispatch.decision.envelope.action)
    }

    @Test("Dispatched commands replay without reapplying")
    func dispatchedCommandsReplay() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .motion, confidence: .high)
        guard let dispatch = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("strong motion must emit")
            return
        }
        let replay = harness.coordinator.dispatchAction(dispatch.decision.envelope, atTicks: 1_020)
        #expect(replay.receipt.outcome == .duplicateReplay)
        #expect(replay.receipt.actionID == dispatch.decision.envelope.action)
        #expect(replay.receipt.facts == dispatch.receipt.facts)
    }

    @Test("A repeat evaluation emits a single restart until a new admission supersedes it")
    func repeatEvaluationEmitsSingleRestart() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .motion, confidence: .high)
        guard let first = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("strong motion must emit first")
            return
        }
        #expect(first.decision.envelope.kind == .sensorStrongMovementRestart)
        #expect(harness.coordinator.actionReducer.globalRevision == 1)
        // Same live representative, no new admission: nothing re-emits.
        #expect(harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_020) == nil)
        #expect(harness.coordinator.actionReducer.globalRevision == 1)
        // A new admission supersedes the representative: the restart routes again.
        try firewallAdmit(
            harness: &harness,
            kind: .motion,
            confidence: .high,
            observed: 1_021,
            ttl: 60,
            atTicks: 1_022
        )
        guard let second = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1_023)
        else {
            Issue.record("a superseding admission must restart again")
            return
        }
        #expect(second.decision.envelope.kind == .sensorStrongMovementRestart)
        #expect(second.decision.envelope.action != first.decision.envelope.action)
        #expect(second.receipt.outcome == .committed)
        #expect(harness.coordinator.actionReducer.globalRevision == 2)
    }

    @Test("Identical seeds and inputs reproduce identical commands")
    func identicalInputsReproduceIdenticalCommands() throws {
        var first = try firewallHarness()
        var second = try firewallHarness()
        try firewallAdmit(harness: &first, kind: .motion, confidence: .high)
        try firewallAdmit(harness: &second, kind: .motion, confidence: .high)
        let firstDispatch = first.firewall.evaluateDispatch(.motion, on: &first.coordinator, atTicks: 1_020)
        let secondDispatch = second.firewall.evaluateDispatch(.motion, on: &second.coordinator, atTicks: 1_020)
        let firstEnvelope = try #require(firstDispatch?.decision.envelope)
        let secondEnvelope = try #require(secondDispatch?.decision.envelope)
        #expect(firstEnvelope == secondEnvelope)
    }
}

// MARK: - Fenced route only

@Suite("Closed firewall fenced route")
struct ClosedPolicyFirewallRouteTests {
    @Test("The firewall implementation never touches the unfenced entry point")
    func firewallSourceAvoidsUnfencedEntryPoint() throws {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        url.append(path: "Sources/Domain/ClosedPolicyFirewall.swift", directoryHint: .notDirectory)
        let text = try String(contentsOf: url, encoding: .utf8)
        let withoutFenced = text
            .replacingOccurrences(of: "dispatchAction", with: "")
            .replacingOccurrences(of: "FirewallDispatch", with: "")
        #expect(
            withoutFenced.range(of: #"\b[Dd]ispatch\w*"#, options: .regularExpression) == nil,
            "ClosedPolicyFirewall must route only through the fenced entry point"
        )
    }

    @Test("Replay outcomes prove the fenced reducer path was taken")
    func replayProvesFencedPath() throws {
        var harness = try firewallHarness()
        try firewallAdmit(harness: &harness, kind: .presence, confidence: .low)
        guard let dispatch = harness.firewall.evaluateDispatch(.presence, on: &harness.coordinator, atTicks: 1_020)
        else {
            Issue.record("weak qualified presence must emit")
            return
        }
        // Only the fenced reducer dedupes ActionIDs; the unfenced path has no
        // replay outcome, so a duplicate replay proves which route was taken.
        let replay = harness.coordinator.dispatchAction(dispatch.decision.envelope, atTicks: 1_020)
        #expect(replay.receipt.outcome == .duplicateReplay)
    }
}
