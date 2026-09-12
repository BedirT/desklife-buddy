import Foundation
import Testing
@testable import Domain

/// Epic 5 story S5 (issue #6, gates G2+G3): separately-consented bounded
/// auto-hold. RED-first: `BoundedAutoHoldState`, `AutoHoldRecord`, and the
/// release/correction APIs do not exist yet, so every test below fails on
/// the S4 base before the S5 layer lands.
private let ahDevice = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000a70001")!)
private let ahEpoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000ae70001")!)
private let ahTicks: TimeInterval = 2_000_000

private struct AHFixture {
    var bus: EvidenceBus
    var leases: [EvidenceSource: SensingProviderLease]
}

private func ahFixture() throws -> AHFixture {
    var authority = SensingLeaseAuthority()
    var leases: [EvidenceSource: SensingProviderLease] = [:]
    for source in [EvidenceSource.frontmostApp, .mediaDevice, .focusFilter] as [EvidenceSource] {
        leases[source] = try authority.issue(
            provider: source.providerID,
            epoch: ahEpoch,
            device: ahDevice,
            lifetimeSeconds: 90,
            atTicks: ahTicks,
        )
    }
    return AHFixture(
        bus: EvidenceBus(capacity: 16, authority: authority),
        leases: leases,
    )
}

/// Issues fresh leases from the bus's held authority (leases cap at 90 s,
/// so post-corridor evidence needs a fresh generation).
private func ahReissue(
    fixture: inout AHFixture,
    atTicks ticks: TimeInterval,
) throws -> [EvidenceSource: SensingProviderLease] {
    var fresh: [EvidenceSource: SensingProviderLease] = [:]
    for source in [EvidenceSource.frontmostApp, .mediaDevice, .focusFilter] as [EvidenceSource] {
        fresh[source] = try fixture.bus.authority.issue(
            provider: source.providerID,
            epoch: ahEpoch,
            device: ahDevice,
            lifetimeSeconds: 90,
            atTicks: ticks,
        )
    }
    return fresh
}

private func ahProposal(
    source: EvidenceSource,
    groupCode: String,
    confidence: EvidenceConfidence = .high,
    observed: TimeInterval = ahTicks,
    ttl: TimeInterval = 300,
) throws -> EvidenceProposal {
    try EvidenceProposal(
        kind: source == .mediaDevice ? .ambient : .presence,
        source: source,
        reading: .present,
        quality: .full,
        confidence: confidence,
        coverage: .partial,
        independenceGroup: EvidenceIndependenceGroup(code: groupCode),
        observedTicks: observed,
        timeToLiveSeconds: ttl,
    )
}

private func ahAdmitCallAndFocus(
    fixture: inout AHFixture,
    atTicks ticks: TimeInterval = ahTicks + 10,
    leaseSet: [EvidenceSource: SensingProviderLease]? = nil,
) throws {
    let set = leaseSet ?? fixture.leases
    for (source, group) in [
        (EvidenceSource.frontmostApp, "bundle-app"),
        (EvidenceSource.mediaDevice, "media-device"),
        (EvidenceSource.focusFilter, "focus-filter"),
    ] {
        let lease = try #require(set[source])
        let admission = fixture.bus.admit(
            try ahProposal(source: source, groupCode: group),
            lease: lease,
            for: source.providerID,
            originRevision: 0,
            epoch: ahEpoch,
            presentingDeviceID: ahDevice,
            atTicks: ticks,
        )
        guard case .admitted = admission else {
            Issue.record("context admission rejected: \(admission)")
            continue
        }
    }
}

private func ahNow(_ ticks: TimeInterval) -> Date {
    Date(timeIntervalSince1970: ticks)
}

private func ahGrantedBroker() async throws -> (PermissionBroker, InMemoryLedgerConsentReceiptStore) {
    var broker = try PermissionBroker(
        deviceID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        epochCode: "55555555-5555-5555-5555-555555555555",
    )
    let store = InMemoryLedgerConsentReceiptStore(now: { ahNow(ahTicks + 10_000) })
    try await broker.grant(.effectHold, atTicks: ahTicks, recordedAt: ahNow(ahTicks), store: store)
    return (broker, store)
}

private func ahCorrections() -> InMemoryLedgerCorrectionStore {
    InMemoryLedgerCorrectionStore(now: { ahNow(ahTicks + 10_000) })
}

private func ahFiredHold(
    fixture: inout AHFixture,
    broker: PermissionBroker,
    state: inout BoundedAutoHoldState,
    atTicks ticks: TimeInterval = ahTicks + 10,
) async throws -> AutoHoldRecord {
    let evaluation = try await state.evaluate(
        fixture.bus,
        atTicks: ticks,
        now: ahNow(ticks),
        manualHold: nil,
        broker: broker,
        corrections: ahCorrections(),
    )
    guard case let .fired(record) = evaluation else {
        Issue.record("expected a fired auto-hold, got \(evaluation)")
        throw AHTestError.expectedFire
    }
    return record
}

private enum AHTestError: Error {
    case expectedFire
}

@Suite("Bounded auto-hold (S5: consent + suggest + firewall)")
struct BoundedAutoHoldTests {
    @Test("Auto-hold never freezes need clocks (G2)")
    func autoHoldNeverFreezesNeedClocks() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        let (broker, _) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        let record = try await ahFiredHold(
            fixture: &fixture, broker: broker, state: &state,
        )

        #expect(!record.suppressionReasons.isEmpty)
        let resolution = SuppressionResolver.resolve(activeReasons: record.suppressionReasons)
        #expect(!resolution.shouldPresent)
        #expect(resolution.accumulationPolicy == .continue)

        let configuration = try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 10, targetSeconds: 20, latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: 15, targetSeconds: 50, latestPreferredSeconds: 60,
                durationOptionsSeconds: [12, 6],
            ),
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 60, longIdleResetSeconds: 300, wakeUnlockGraceSeconds: 90,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: true, mergeWindowSeconds: 5, headsUpDefault: true,
                headsUpSecondsBeforeTarget: 2, snoozeOptionsSeconds: [3, 6, 9],
                maximumRepeatedEscalations: 1, lockoutAllowed: false,
            ),
        )
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        let heldOutput = engine.observe(
            .active(uptimeSeconds: 5, secondsSinceInput: 0),
            activeSuppressions: record.suppressionReasons,
        )
        #expect(heldOutput.presentation == nil)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 5)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 5)

        let corrections = ahCorrections()
        let receipt = try await state.release(
            atTicks: ahTicks + 20, now: ahNow(ahTicks + 20),
            reason: .released, corrections: corrections,
        )
        let unwrapped = try #require(receipt)
        #expect(unwrapped.needPreserved)
        #expect(state.activeHold == nil)
        _ = engine.observe(.active(uptimeSeconds: 6, secondsSinceInput: 0))
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 6)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 6)
        let rows = try await corrections.loadRecords()
        #expect(rows.count == 1)
        #expect(rows[0].correctedActionUUID == record.holdActionID)
    }

    @Test("Not a call releases promptly and disables the source (G3)")
    func notACallReleasesAndDisablesSource() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        let (broker, _) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        let record = try await ahFiredHold(
            fixture: &fixture, broker: broker, state: &state,
        )
        #expect(state.activeHold != nil)

        let corrections = ahCorrections()
        let receipt = try await state.notACall(
            atTicks: ahTicks + 11, now: ahNow(ahTicks + 11),
            bus: &fixture.bus, corrections: corrections,
        )
        let unwrapped = try #require(receipt)
        #expect(unwrapped.reasonCode == "not-a-call")
        #expect(state.activeHold == nil)
        #expect(state.disabledSources.isSuperset(of: record.votingSources))
        #expect(state.disabledSources.contains(.frontmostApp))
        #expect(state.disabledSources.contains(.mediaDevice))

        let rows = try await corrections.loadRecords()
        #expect(rows.count == 1)
        #expect(rows[0].reasonCode == "not-a-call")
        #expect(rows[0].supersededDecisionUUIDs == [record.holdDecisionID])

        let revoked = ContextFusion.evaluate(
            fixture.bus, atTicks: ahTicks + 11, manualHold: nil,
            now: ahNow(ahTicks + 11), mode: .suggest,
        )
        #expect(revoked.effect != .suggest)

        let fresh = try ahReissue(fixture: &fixture, atTicks: ahTicks + 11)
        try ahAdmitCallAndFocus(
            fixture: &fixture, atTicks: ahTicks + 12, leaseSet: fresh,
        )
        let repromoted = ContextFusion.evaluate(
            fixture.bus, atTicks: ahTicks + 12, manualHold: nil,
            now: ahNow(ahTicks + 12), mode: .suggest,
        )
        #expect(repromoted.effect == .suggest)
        let laterLeases = try ahReissue(fixture: &fixture, atTicks: ahTicks + 110)
        try ahAdmitCallAndFocus(
            fixture: &fixture, atTicks: ahTicks + 112, leaseSet: laterLeases,
        )
        let blocked = try await state.evaluate(
            fixture.bus, atTicks: ahTicks + 112, now: ahNow(ahTicks + 112),
            manualHold: nil, broker: broker, corrections: ahCorrections(),
        )
        guard case let .noHold(blockReason) = blocked else {
            Issue.record("disabled sources must veto a re-fire, got \(blocked)")
            return
        }
        #expect(blockReason == .sourcesDisabled)
    }

    @Test("No effect consent means no fire")
    func noFireWithoutEffectConsent() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        let broker = try PermissionBroker(
            deviceID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            epochCode: "55555555-5555-5555-5555-555555555555",
        )
        var state = BoundedAutoHoldState()
        let evaluation = try await state.evaluate(
            fixture.bus, atTicks: ahTicks + 10, now: ahNow(ahTicks + 10),
            manualHold: nil, broker: broker, corrections: ahCorrections(),
        )
        guard case let .noHold(reason) = evaluation else {
            Issue.record("expected a consent block, got \(evaluation)")
            return
        }
        #expect(reason == .effectConsentNotGranted)
        #expect(state.activeHold == nil)
    }

    @Test("Manual state outranks auto-hold")
    func manualStateOutranksAutoHold() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        let (broker, _) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        let startedAt = ahNow(ahTicks)
        let manual = ManualContextHold(
            mode: .meetingOrCall, startedAt: startedAt,
            expiresAt: startedAt.addingTimeInterval(3600),
        )
        let evaluation = try await state.evaluate(
            fixture.bus, atTicks: ahTicks + 10, now: ahNow(ahTicks + 10),
            manualHold: manual, broker: broker, corrections: ahCorrections(),
        )
        guard case .manualHoldOutranks = evaluation else {
            Issue.record("expected manual outrank, got \(evaluation)")
            return
        }
        #expect(state.activeHold == nil)
    }

    @Test("Single weak signal never fires")
    func singleWeakSignalNeverFires() async throws {
        var fixture = try ahFixture()
        let lease = try #require(fixture.leases[.frontmostApp])
        let admitted = fixture.bus.admit(
            try ahProposal(source: .frontmostApp, groupCode: "bundle-app"),
            lease: lease, for: .frontmostApp, originRevision: 0, epoch: ahEpoch,
            presentingDeviceID: ahDevice, atTicks: ahTicks + 10,
        )
        guard case .admitted = admitted else {
            Issue.record("admission rejected: \(admitted)")
            return
        }
        let (broker, _) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        let evaluation = try await state.evaluate(
            fixture.bus, atTicks: ahTicks + 10, now: ahNow(ahTicks + 10),
            manualHold: nil, broker: broker, corrections: ahCorrections(),
        )
        guard case let .noHold(reason) = evaluation else {
            Issue.record("expected an evidence block, got \(evaluation)")
            return
        }
        #expect(reason == .insufficientEvidence)
    }

    @Test("Release opens a landing corridor with back-to-back taper")
    func releaseOpensLandingCorridor() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        let (broker, _) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        let first = try await ahFiredHold(
            fixture: &fixture, broker: broker, state: &state,
        )
        let corrections = ahCorrections()
        _ = try await state.release(
            atTicks: ahTicks + 20, now: ahNow(ahTicks + 20),
            reason: .released, corrections: corrections,
        )
        let during = try await state.evaluate(
            fixture.bus, atTicks: ahTicks + 30, now: ahNow(ahTicks + 30),
            manualHold: nil, broker: broker, corrections: corrections,
        )
        guard case let .noHold(corridorReason) = during else {
            Issue.record("expected a corridor block, got \(during)")
            return
        }
        #expect(corridorReason == .inLandingCorridor)
        let fresh = try ahReissue(fixture: &fixture, atTicks: ahTicks + 110)
        try ahAdmitCallAndFocus(
            fixture: &fixture, atTicks: ahTicks + 115, leaseSet: fresh,
        )
        let after = try await state.evaluate(
            fixture.bus, atTicks: ahTicks + 115, now: ahNow(ahTicks + 115),
            manualHold: nil, broker: broker, corrections: corrections,
        )
        guard case let .fired(second) = after else {
            Issue.record("expected a tapered re-fire after the corridor, got \(after)")
            return
        }
        #expect(second.capSeconds < first.capSeconds)
    }

    @Test("Effect revocation drains the hold inside the deadline")
    func effectRevocationDrainsHold() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        var (broker, store) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        _ = try await ahFiredHold(fixture: &fixture, broker: broker, state: &state)
        let requestedAt = ahTicks + 11
        _ = try await broker.revoke(
            .effectHold, atTicks: requestedAt, recordedAt: ahNow(requestedAt), store: store,
        )
        let corrections = ahCorrections()
        let drained = try await state.evaluate(
            fixture.bus, atTicks: requestedAt + 1, now: ahNow(requestedAt + 1),
            manualHold: nil, broker: broker, corrections: corrections,
        )
        guard case let .released(receipt) = drained else {
            Issue.record("expected a revocation drain release, got \(drained)")
            return
        }
        #expect(receipt.reasonCode == "effect-consent-withdrawn")
        #expect(receipt.releasedTicks <= requestedAt + PermissionBroker.revocationDeadlineTicks)
        let rows = try await corrections.loadRecords()
        #expect(rows.count == 1)
        #expect(broker.drainRevocations(atTicks: requestedAt + 1).count == 1)
        #expect(broker.isQuiescent(atTicks: requestedAt + 1))
    }

    @Test("Kill switch drains the hold")
    func killSwitchDrainsHold() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        var (broker, store) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        _ = try await ahFiredHold(fixture: &fixture, broker: broker, state: &state)
        _ = try await broker.engageKillSwitch(
            atTicks: ahTicks + 11, recordedAt: ahNow(ahTicks + 11), store: store,
        )
        let corrections = ahCorrections()
        let drained = try await state.evaluate(
            fixture.bus, atTicks: ahTicks + 12, now: ahNow(ahTicks + 12),
            manualHold: nil, broker: broker, corrections: corrections,
        )
        guard case let .released(receipt) = drained else {
            Issue.record("expected a kill-switch drain release, got \(drained)")
            return
        }
        #expect(receipt.reasonCode == "kill-switch-drained")
        #expect(state.activeHold == nil)
    }

    @Test("One merged post-context opportunity per hold")
    func postContextOpportunityOfferedOnce() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        let (broker, _) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        let record = try await ahFiredHold(
            fixture: &fixture, broker: broker, state: &state,
        )
        #expect(state.takePostContextOpportunity(atTicks: ahTicks + 15) == nil)
        let corrections = ahCorrections()
        _ = try await state.release(
            atTicks: ahTicks + 20, now: ahNow(ahTicks + 20),
            reason: .released, corrections: corrections,
        )
        let taken = state.takePostContextOpportunity(atTicks: ahTicks + 25)
        let first = try #require(taken)
        #expect(first.holdActionID == record.holdActionID)
        #expect(state.takePostContextOpportunity(atTicks: ahTicks + 26) == nil)
    }

    @Test("Releases are idempotent correction replays")
    func releasesReplayIdempotently() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        let (broker, _) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        _ = try await ahFiredHold(fixture: &fixture, broker: broker, state: &state)
        let corrections = ahCorrections()
        _ = try await state.release(
            atTicks: ahTicks + 20, now: ahNow(ahTicks + 20),
            reason: .released, corrections: corrections,
        )
        let replay = try await state.release(
            atTicks: ahTicks + 21, now: ahNow(ahTicks + 21),
            reason: .released, corrections: corrections,
        )
        #expect(replay == nil)
        var rows = try await corrections.loadRecords()
        #expect(rows.count == 1)
        try await corrections.append(rows[0])
        rows = try await corrections.loadRecords()
        #expect(rows.count == 1)
    }

    @Test("Holds use firewall-emittable kinds only")
    func holdsUseFirewallEmittableKinds() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        let (broker, _) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        let record = try await ahFiredHold(
            fixture: &fixture, broker: broker, state: &state,
        )
        #expect(record.actionKind == .holdBegin)
        #expect(ClosedPolicyFirewall.emittableKinds.contains(record.actionKind))
        #expect(ClosedPolicyFirewall.isEmittable(.holdRelease))
    }

    @Test("Auto-hold copy never claims universal detection")
    func copyNeverClaimsUniversalDetection() async throws {
        var fixture = try ahFixture()
        try ahAdmitCallAndFocus(fixture: &fixture)
        let (broker, _) = try await ahGrantedBroker()
        var state = BoundedAutoHoldState()
        let record = try await ahFiredHold(
            fixture: &fixture, broker: broker, state: &state,
        )
        let corrections = ahCorrections()
        let receipt = try await state.release(
            atTicks: ahTicks + 20, now: ahNow(ahTicks + 20),
            reason: .notACall, corrections: corrections,
        )
        let note = try #require(receipt).note
        #expect(record.whyNow.headline.contains("Likely"))
        for text in [record.whyNow.headline, note] {
            #expect(!text.contains("in a meeting"))
            #expect(!text.contains("on a call"))
            #expect(!text.contains("you are in"))
            #expect(!text.contains("detected"))
        }
    }
}
