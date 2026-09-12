import Foundation
import Testing

@testable import Domain

/// Epic 7 minimized movement-observation contract (pure slice, RED-first).
///
/// Proves the hardware-free contract end to end: a Core Motion-SHAPED scalar
/// sample becomes an `EvidenceProposal` (kind `.motion`, source
/// `.motionHardware`), rides the bus under a `motion-hardware` lease, fuses
/// with 1-vote/group Unknown semantics, passes the closed firewall, and lands
/// in the observation/assessment ledgers as sanitized codes only.
///
/// The adapter and fake shaped source below are test-side fakes: Domain never
/// imports sensing frameworks, and no fine-motion payload (waveforms, cadence,
/// coordinates), health-outcome language, or transport appears anywhere.

// MARK: - Shaped input (no sensing-framework imports anywhere in this file)

/// Shaped locomotion scalar: the only movement content the adapter reads.
/// Stepped and wheeled are equally valid movement; stationary is the binary
/// opposite. No gait quality, speed, or bout-length grading lives here.
enum ShapedLocomotion: String, Sendable, CaseIterable {
    case stepped
    case wheeled
    case stationary
}

/// One Core Motion-shaped scalar sample: locomotion class plus age, permission,
/// and availability scalars. Exact samples, timestamps, routes, and device
/// identifiers never cross — only these minimized scalars.
struct ShapedMotionSample: Sendable, Equatable {
    /// What the shaped source reports for the window.
    var locomotion: ShapedLocomotion
    /// Seconds between the motion window and the mapping ticks.
    var ageTicks: TimeInterval
    /// Shaped OS-level motion permission state.
    var permissionGranted: Bool
    /// Shaped hardware availability (low power / no device / desk-left phone).
    var sensorAvailable: Bool
}

/// In-memory scripted shaped source: vends queued scalar samples, nothing more.
struct FakeShapedMotionSource: Sendable {
    private var queued: [ShapedMotionSample]

    init(samples: [ShapedMotionSample]) {
        queued = samples
    }

    mutating func next() -> ShapedMotionSample? {
        guard !queued.isEmpty else { return nil }
        return queued.removeFirst()
    }
}

// MARK: - Outside-Domain adapter (producer side, test-side fake)

/// Maps shaped motion scalars to `EvidenceProposal`.
///
/// Declared mapping policy:
/// - Binary reduction: stepped/wheeled map to `.present`, stationary to
///   `.absent`. Wheeling (including pushes) counts as movement — manual,
///   walking, wheeling, pushing, and seated movement stay equally valid, and
///   the adapter never grades movement quality.
/// - Degraded-vs-denied split: revoked permission maps to `.denied`; granted
///   permission with unavailable hardware maps to `.degraded`; otherwise
///   `.full`. Denied and degraded proposals still carry their last reading,
///   but fusion never lets them vote.
/// - Confidence ladder: age <= 60s maps to `.high`, <= 180s to `.medium`,
///   older to `.low`. Low confidence never restarts (firewall rule).
/// - Coverage: age <= 60s maps to `.full`, older to `.partial`.
/// - Backdating + staleness: `observedTicks` is backdated to `now - age` with
///   the fixed 300s proposal maximum TTL, so the live interval is
///   `[now - age, now - age + 300)`. The 15-minute shaped lookback exceeds the
///   300s bus TTL by design: samples aged >= 300s (or from the future) map to
///   `nil` — no sample — so fusion reports missing/stale Unknown instead of
///   admitting a dead-on-arrival atom. Unknown never votes negative.
enum MotionObservationAdapter: Sendable {
    /// Default producer-declared independence group for one shaped window.
    static let defaultGroupCode = "motion-hardware-window"
    /// Fresh window: full coverage, high confidence.
    static let freshSeconds: TimeInterval = 60
    /// Recent window: partial coverage, medium confidence.
    static let recentSeconds: TimeInterval = 180

    static func proposal(
        sample: ShapedMotionSample,
        atTicks now: TimeInterval,
        groupCode: String = defaultGroupCode,
    ) -> EvidenceProposal? {
        guard sample.ageTicks >= 0,
              sample.ageTicks < EvidenceProposal.maximumTimeToLiveSeconds
        else {
            return nil
        }
        let reading: EvidenceReading =
            switch sample.locomotion {
            case .stepped, .wheeled: .present
            case .stationary: .absent
            }
        let quality: EvidenceQuality =
            if !sample.permissionGranted {
                .denied
            } else if !sample.sensorAvailable {
                .degraded
            } else {
                .full
            }
        let confidence: EvidenceConfidence =
            if sample.ageTicks <= freshSeconds {
                .high
            } else if sample.ageTicks <= recentSeconds {
                .medium
            } else {
                .low
            }
        let coverage: EvidenceCoverage =
            sample.ageTicks <= freshSeconds ? .full : .partial
        return try? EvidenceProposal(
            kind: .motion,
            source: .motionHardware,
            reading: reading,
            quality: quality,
            confidence: confidence,
            coverage: coverage,
            independenceGroup: EvidenceIndependenceGroup(code: groupCode),
            observedTicks: now - sample.ageTicks,
            timeToLiveSeconds: EvidenceProposal.maximumTimeToLiveSeconds,
        )
    }
}

// MARK: - Harness (private: no collisions with sibling test files)

private let motionObsDevice = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000d701")!)
private let motionObsEpoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000e070701")!)
private let motionObsGlobal = GlobalStateID(UUID(uuidString: "00000000-0000-0000-0000-00000000b701")!)
private let motionObsActionSeed = UUID(uuidString: "00000000-0000-0000-0000-000000a70101")!
private let motionObsDecisionSeed = UUID(uuidString: "00000000-0000-0000-0000-000000d70101")!
private let motionObsFirewallID = UUID(uuidString: "77777777-0000-0000-0000-000000f70101")!

private func motionObsConfiguration() throws -> ProtocolConfiguration {
    try ProtocolConfiguration(
        visual: OpportunitySchedule(
            softDueSeconds: 997,
            targetSeconds: 1009,
            latestPreferredSeconds: 1061,
            durationOptionsSeconds: [5],
        ),
        movement: OpportunitySchedule(
            softDueSeconds: 2000,
            targetSeconds: 2100,
            latestPreferredSeconds: 2300,
            durationOptionsSeconds: [300],
        ),
        activityEstimator: ActivityEstimatorConfiguration(
            recentInputWindowSeconds: 60,
            longIdleResetSeconds: 300,
            wakeUnlockGraceSeconds: 90,
        ),
        delivery: OpportunityDeliveryConfiguration(
            waitForLowFrictionMoment: false,
            mergeWindowSeconds: 5,
            headsUpDefault: true,
            headsUpSecondsBeforeTarget: 2,
            snoozeOptionsSeconds: [300, 600, 900],
            maximumRepeatedEscalations: 1,
            lockoutAllowed: false,
        ),
    )
}

private struct MotionObsHarness {
    var firewall: ClosedPolicyFirewall
    var coordinator: OpportunityCoordinator
    var hardwareLease: SensingProviderLease
}

private func motionObsHarness() throws -> MotionObsHarness {
    var authority = SensingLeaseAuthority()
    let lease = try authority.issue(
        provider: .motionHardware,
        epoch: motionObsEpoch,
        device: motionObsDevice,
        lifetimeSeconds: 90,
        atTicks: 1000,
    )
    let firewall = ClosedPolicyFirewall(
        bus: EvidenceBus(capacity: 8, authority: authority),
        globalID: motionObsGlobal,
        deviceID: motionObsDevice,
        firewallID: motionObsFirewallID,
        actionSeed: motionObsActionSeed,
        decisionSeed: motionObsDecisionSeed,
    )
    let coordinator = OpportunityCoordinator(
        engine: ProtocolEngine(configuration: try motionObsConfiguration()),
    )
    return MotionObsHarness(firewall: firewall, coordinator: coordinator, hardwareLease: lease)
}

private struct MotionObsBusFixture {
    var bus: EvidenceBus
    var lease: SensingProviderLease
}

private func motionObsBusFixture() throws -> MotionObsBusFixture {
    var authority = SensingLeaseAuthority()
    let lease = try authority.issue(
        provider: .motionHardware,
        epoch: motionObsEpoch,
        device: motionObsDevice,
        lifetimeSeconds: 90,
        atTicks: 1000,
    )
    return MotionObsBusFixture(
        bus: EvidenceBus(capacity: 8, authority: authority),
        lease: lease,
    )
}

private func motionObsAdmit(
    fixture: inout MotionObsBusFixture,
    proposal: EvidenceProposal,
    atTicks ticks: TimeInterval,
) -> EvidenceAdmission {
    fixture.bus.admit(
        proposal,
        lease: fixture.lease,
        for: .motionHardware,
        originRevision: 0,
        epoch: motionObsEpoch,
        presentingDeviceID: motionObsDevice,
        atTicks: ticks,
    )
}

private func freshSteppedSample(
    age: TimeInterval = 10,
    permissionGranted: Bool = true,
    sensorAvailable: Bool = true,
) -> ShapedMotionSample {
    ShapedMotionSample(
        locomotion: .stepped,
        ageTicks: age,
        permissionGranted: permissionGranted,
        sensorAvailable: sensorAvailable,
    )
}

// MARK: - Vocabulary

@Suite("Motion hardware vocabulary (additive)")
struct MotionHardwareVocabularyTests {
    @Test("Compiled registry admits the motion-hardware provider")
    func registryAdmitsMotionHardware() throws {
        let registry = SensingProviderRegistry.compiled
        #expect(registry.contains(.motionHardware))
        #expect(registry.providerCount == 7)
        #expect(try registry.descriptor(for: .motionHardware).id == .motionHardware)
    }

    @Test("The hardware source maps to the hardware provider")
    func sourceMapsToHardwareProvider() {
        #expect(EvidenceSource.motionHardware.providerID == .motionHardware)
        #expect(EvidenceSource.motionHardware.rawValue == "motionHardware")
        #expect(SensingProviderID.motionHardware.code == "motion-hardware")
    }

    @Test("Observation ledger admits hardware codes and still refuses raw codes")
    func observationLedgerAdmitsHardwareCodes() async throws {
        let store = InMemoryLedgerStores.observation(now: { ledgerT0 })
        let record = try LedgerObservationRecord(
            id: LedgerIdentity.derive(ledger: .observation, seed: ledgerSeed, counter: 901),
            recordedAt: ledgerT0,
            providerCode: "motion-hardware",
            kindCode: "motion",
            sourceCode: "motionHardware",
            qualityCode: "full",
            confidenceCode: "high",
            coverageCode: "full",
            groupCode: "motion-hardware-window",
            admittedTicks: 1010,
            expiryTicks: 1310,
            leaseGrantedTicks: 1000,
            leaseExpiryTicks: 1090,
            presentingDeviceID: ledgerDeviceText,
        )
        try await store.append(record)
        #expect(try await store.loadRecords() == [record])
        #expect(throws: LedgerStoreError.self) {
            try LedgerObservationRecord(
                id: LedgerIdentity.derive(ledger: .observation, seed: ledgerSeed, counter: 902),
                recordedAt: ledgerT0,
                providerCode: "core-motion",
                kindCode: "motion",
                sourceCode: "motionHardware",
                qualityCode: "full",
                confidenceCode: "high",
                coverageCode: "full",
                groupCode: "motion-hardware-window",
                admittedTicks: 1010,
                expiryTicks: 1310,
                leaseGrantedTicks: 1000,
                leaseExpiryTicks: 1090,
                presentingDeviceID: ledgerDeviceText,
            )
        }
    }

    @Test("Assessment ledger admits the hardware source and the Unknown readings")
    func assessmentLedgerAdmitsHardwareSource() async throws {
        #expect(LedgerAssessmentRecord.readings == [
            "present", "absent",
            "unknown-missing", "unknown-stale", "unknown-denied",
            "unknown-degraded", "unknown-contradictory",
        ])
        let store = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        let record = try LedgerAssessmentRecord(
            id: LedgerIdentity.derive(ledger: .assessment, seed: ledgerSeed, counter: 901),
            recordedAt: ledgerT0,
            readingCode: "present",
            confidenceCode: "high",
            supportingGroups: 1,
            representativeKindCode: "motion",
            representativeSourceCode: "motionHardware",
            representativeReadingCode: "present",
            representativeQualityCode: "full",
            representativeConfidenceCode: "high",
            representativeCoverageCode: "full",
            representativeGroupCode: "motion-hardware-window",
            representativeExpiryTicks: 1310,
            evaluatedTicks: 1020,
            assessmentDigest: "motion-contract-digest",
        )
        try await store.append(record)
        #expect(try await store.loadRecords() == [record])
    }
}

// MARK: - Adapter mapping policy

@Suite("Motion observation adapter mapping")
struct MotionObservationAdapterTests {
    @Test("Stepped and wheeled reduce to present; stationary to absent")
    func binaryReduction() {
        for locomotion in [ShapedLocomotion.stepped, .wheeled] {
            let sample = ShapedMotionSample(
                locomotion: locomotion,
                ageTicks: 10,
                permissionGranted: true,
                sensorAvailable: true,
            )
            let proposal = MotionObservationAdapter.proposal(sample: sample, atTicks: 1010)
            #expect(proposal?.reading == .present)
            #expect(proposal?.kind == .motion)
            #expect(proposal?.source == .motionHardware)
            #expect(proposal?.quality == .full)
        }
        let still = ShapedMotionSample(
            locomotion: .stationary,
            ageTicks: 10,
            permissionGranted: true,
            sensorAvailable: true,
        )
        #expect(MotionObservationAdapter.proposal(sample: still, atTicks: 1010)?.reading == .absent)
    }

    @Test("Revoked permission maps to denied; unavailable hardware to degraded")
    func deniedVersusDegraded() {
        let revoked = freshSteppedSample(permissionGranted: false)
        #expect(MotionObservationAdapter.proposal(sample: revoked, atTicks: 1010)?.quality == .denied)
        let unavailable = freshSteppedSample(sensorAvailable: false)
        #expect(MotionObservationAdapter.proposal(sample: unavailable, atTicks: 1010)?.quality == .degraded)
        let deniedReading = MotionObservationAdapter.proposal(sample: revoked, atTicks: 1010)
        #expect(deniedReading?.reading == .present)
    }

    @Test("Confidence follows the low/med/high age ladder with matching coverage")
    func confidenceLadder() {
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 10), atTicks: 1010)?.confidence == .high)
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 10), atTicks: 1010)?.coverage == .full)
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 120), atTicks: 1010)?.confidence == .medium)
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 120), atTicks: 1010)?.coverage == .partial)
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 250), atTicks: 1010)?.confidence == .low)
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 250), atTicks: 1010)?.coverage == .partial)
    }

    @Test("Observed ticks backdate by age with the fixed 300s TTL")
    func backdatedObservedTicks() {
        let proposal = MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 10), atTicks: 1010)
        #expect(proposal?.observedTicks == 1000)
        #expect(proposal?.timeToLiveSeconds == EvidenceProposal.maximumTimeToLiveSeconds)
        #expect(proposal?.independenceGroup == EvidenceIndependenceGroup(code: MotionObservationAdapter.defaultGroupCode))
    }

    @Test("Samples past the 300s TTL and future samples map to no sample")
    func stalenessRule() {
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 299.9), atTicks: 1010) != nil)
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 300), atTicks: 1010) == nil)
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 900), atTicks: 1010) == nil)
        #expect(MotionObservationAdapter.proposal(sample: freshSteppedSample(age: -5), atTicks: 1010) == nil)
    }

    @Test("Fake shaped source replays scripted scalars in order")
    func fakeSourceReplays() {
        var source = FakeShapedMotionSource(samples: [
            ShapedMotionSample(locomotion: .wheeled, ageTicks: 20, permissionGranted: true, sensorAvailable: true),
            ShapedMotionSample(locomotion: .stationary, ageTicks: 5, permissionGranted: true, sensorAvailable: true),
        ])
        #expect(source.next()?.locomotion == .wheeled)
        #expect(source.next()?.locomotion == .stationary)
        #expect(source.next() == nil)
    }
}

// MARK: - End to end

@Suite("Motion observation contract end to end")
struct MotionObservationContractTests {
    @Test("Strong stepped motion restarts and lands sanitized rows in both ledgers")
    func strongMotionRestartsAndLedgers() async throws {
        guard let proposal = MotionObservationAdapter.proposal(sample: freshSteppedSample(), atTicks: 1010) else {
            Issue.record("fresh stepped sample must map to a proposal")
            return
        }
        var fixture = try motionObsBusFixture()
        #expect(motionObsAdmit(fixture: &fixture, proposal: proposal, atTicks: 1010) == .admitted)
        let atoms = fixture.bus.live(atTicks: 1020)
        #expect(atoms.count == 1)
        guard let atom = atoms.first else { return }

        let observationStore = InMemoryLedgerStores.observation(now: { ledgerT0 })
        let observation = try LedgerObservationRecord(
            id: LedgerIdentity.derive(ledger: .observation, seed: ledgerSeed, counter: 911),
            recordedAt: ledgerT0,
            providerCode: atom.provenance.provider.code,
            kindCode: atom.kind.rawValue,
            sourceCode: atom.source.rawValue,
            qualityCode: atom.quality.rawValue,
            confidenceCode: atom.confidence.rawValue,
            coverageCode: atom.coverage.rawValue,
            groupCode: atom.independenceGroup.code,
            admittedTicks: atom.provenance.admittedTicks,
            expiryTicks: atom.expiryTicks,
            leaseGrantedTicks: atom.provenance.lease.grantedTicks,
            leaseExpiryTicks: atom.provenance.lease.expiryTicks,
            presentingDeviceID: ledgerDeviceText,
        )
        #expect(observation.providerCode == "motion-hardware")
        #expect(observation.sourceCode == "motionHardware")
        try await observationStore.append(observation)
        #expect(try await observationStore.loadRecords() == [observation])
        #expect(try LedgerObservationCodec.decode(LedgerObservationCodec.encode(observation)) == observation)

        let fused = EvidenceFusion.fuse(fixture.bus, kind: .motion, atTicks: 1020)
        #expect(fused.reading == .present)
        #expect(fused.confidence == .high)
        #expect(fused.supportingGroups == 1)
        #expect(fused.representative?.source == .motionHardware)

        let assessmentStore = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        let representative = try #require(fused.representative)
        let assessment = try LedgerAssessmentRecord(
            id: LedgerIdentity.derive(ledger: .assessment, seed: ledgerSeed, counter: 911),
            recordedAt: ledgerT0,
            readingCode: "present",
            confidenceCode: fused.confidence.rawValue,
            supportingGroups: fused.supportingGroups,
            representativeKindCode: representative.kind.rawValue,
            representativeSourceCode: representative.source.rawValue,
            representativeReadingCode: representative.reading.rawValue,
            representativeQualityCode: representative.quality.rawValue,
            representativeConfidenceCode: representative.confidence.rawValue,
            representativeCoverageCode: representative.coverage.rawValue,
            representativeGroupCode: representative.independenceGroup.code,
            representativeExpiryTicks: representative.expiryTicks,
            evaluatedTicks: 1020,
            assessmentDigest: "motion-contract-911",
        )
        #expect(assessment.representativeSourceCode == "motionHardware")
        try await assessmentStore.append(assessment)
        #expect(try await assessmentStore.loadRecords() == [assessment])

        var harness = try motionObsHarness()
        #expect(harness.firewall.admit(
            proposal,
            lease: harness.hardwareLease,
            for: .motionHardware,
            originRevision: 0,
            epoch: motionObsEpoch,
            presentingDeviceID: motionObsDevice,
            atTicks: 1010,
        ) == .admitted)
        guard let dispatch = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1020) else {
            Issue.record("strong hardware motion must emit")
            return
        }
        #expect(dispatch.decision.envelope.kind == .sensorStrongMovementRestart)
        #expect(dispatch.decision.effect == .restart)
        #expect(dispatch.receipt.outcome == .committed)
        #expect(dispatch.receipt.facts.isEmpty)
    }

    @Test("A wheeled short bout is equally valid movement and restarts")
    func wheeledBoutRestarts() throws {
        var source = FakeShapedMotionSource(samples: [
            ShapedMotionSample(locomotion: .wheeled, ageTicks: 20, permissionGranted: true, sensorAvailable: true),
        ])
        guard let sample = source.next(),
              let proposal = MotionObservationAdapter.proposal(sample: sample, atTicks: 1010)
        else {
            Issue.record("wheeled sample must map to a proposal")
            return
        }
        #expect(proposal.reading == .present)
        var harness = try motionObsHarness()
        #expect(harness.firewall.admit(
            proposal,
            lease: harness.hardwareLease,
            for: .motionHardware,
            originRevision: 0,
            epoch: motionObsEpoch,
            presentingDeviceID: motionObsDevice,
            atTicks: 1010,
        ) == .admitted)
        let receipt = harness.firewall.evaluate(.motion, on: &harness.coordinator, atTicks: 1020)
        #expect(receipt?.kind == .sensorStrongMovementRestart)
        #expect(receipt?.effect == .restart)
    }

    @Test("Aged low-confidence motion may only hold, never restart")
    func weakMotionNeverRestarts() throws {
        guard let proposal = MotionObservationAdapter.proposal(sample: freshSteppedSample(age: 250), atTicks: 1010) else {
            Issue.record("aged sample must still map inside the TTL")
            return
        }
        #expect(proposal.confidence == .low)
        var harness = try motionObsHarness()
        #expect(harness.firewall.admit(
            proposal,
            lease: harness.hardwareLease,
            for: .motionHardware,
            originRevision: 0,
            epoch: motionObsEpoch,
            presentingDeviceID: motionObsDevice,
            atTicks: 1010,
        ) == .admitted)
        guard let dispatch = harness.firewall.evaluateDispatch(.motion, on: &harness.coordinator, atTicks: 1020) else {
            Issue.record("weak qualified motion must emit")
            return
        }
        #expect(dispatch.decision.envelope.kind == .holdBegin)
        #expect(dispatch.decision.envelope.kind != .sensorStrongMovementRestart)
    }
}

// MARK: - Unknown semantics: missing/stale/denied/degraded/contradictory never vote negative

@Suite("Motion observation Unknown semantics")
struct MotionObservationUnknownTests {
    @Test("Missing hardware evidence fuses Unknown and emits nothing")
    func missingEmitsNothing() throws {
        var harness = try motionObsHarness()
        let before = harness.coordinator.state
        let empty = try motionObsBusFixture()
        #expect(EvidenceFusion.fuse(empty.bus, kind: .motion, atTicks: 1020).reading == .unknown(.missing))
        #expect(harness.firewall.evaluate(.motion, on: &harness.coordinator, atTicks: 1020) == nil)
        #expect(harness.coordinator.state == before)
    }

    @Test("Stale hardware evidence fuses Unknown and emits nothing")
    func staleEmitsNothing() throws {
        guard let proposal = MotionObservationAdapter.proposal(sample: freshSteppedSample(), atTicks: 1010) else {
            Issue.record("fresh stepped sample must map to a proposal")
            return
        }
        var fixture = try motionObsBusFixture()
        #expect(motionObsAdmit(fixture: &fixture, proposal: proposal, atTicks: 1010) == .admitted)
        #expect(EvidenceFusion.fuse(fixture.bus, kind: .motion, atTicks: 1400).reading == .unknown(.stale))
        var harness = try motionObsHarness()
        #expect(harness.firewall.admit(
            proposal,
            lease: harness.hardwareLease,
            for: .motionHardware,
            originRevision: 0,
            epoch: motionObsEpoch,
            presentingDeviceID: motionObsDevice,
            atTicks: 1010,
        ) == .admitted)
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.motion, on: &harness.coordinator, atTicks: 1400) == nil)
        #expect(harness.coordinator.state == before)
    }

    @Test("Denied and degraded hardware evidence never vote and never emit")
    func weakEvidenceNeverVotesNegative() throws {
        for (sample, reason) in [
            (freshSteppedSample(permissionGranted: false), EvidenceFailureReason.denied),
            (freshSteppedSample(sensorAvailable: false), EvidenceFailureReason.degraded),
        ] {
            guard let proposal = MotionObservationAdapter.proposal(sample: sample, atTicks: 1010) else {
                Issue.record("weak sample must still map to a proposal")
                continue
            }
            var fixture = try motionObsBusFixture()
            #expect(motionObsAdmit(fixture: &fixture, proposal: proposal, atTicks: 1010) == .admitted)
            #expect(EvidenceFusion.fuse(fixture.bus, kind: .motion, atTicks: 1020).reading == .unknown(reason))
            var harness = try motionObsHarness()
            #expect(harness.firewall.admit(
                proposal,
                lease: harness.hardwareLease,
                for: .motionHardware,
                originRevision: 0,
                epoch: motionObsEpoch,
                presentingDeviceID: motionObsDevice,
                atTicks: 1010,
            ) == .admitted)
            let before = harness.coordinator.state
            #expect(harness.firewall.evaluate(.motion, on: &harness.coordinator, atTicks: 1020) == nil)
            #expect(harness.coordinator.state == before)
        }
    }

    @Test("Conflicting hardware movement cannot auto-restart")
    func contradictoryEmitsNothing() throws {
        guard let present = MotionObservationAdapter.proposal(
            sample: freshSteppedSample(),
            atTicks: 1010,
            groupCode: "motion-hardware-window-a",
        ),
            let absent = MotionObservationAdapter.proposal(
                sample: ShapedMotionSample(locomotion: .stationary, ageTicks: 10, permissionGranted: true, sensorAvailable: true),
                atTicks: 1010,
                groupCode: "motion-hardware-window-b",
            )
        else {
            Issue.record("both sides of the conflict must map to proposals")
            return
        }
        var fixture = try motionObsBusFixture()
        #expect(motionObsAdmit(fixture: &fixture, proposal: present, atTicks: 1010) == .admitted)
        #expect(motionObsAdmit(fixture: &fixture, proposal: absent, atTicks: 1010) == .admitted)
        #expect(EvidenceFusion.fuse(fixture.bus, kind: .motion, atTicks: 1020).reading == .unknown(.contradictory))
        var harness = try motionObsHarness()
        #expect(harness.firewall.admit(
            present,
            lease: harness.hardwareLease,
            for: .motionHardware,
            originRevision: 0,
            epoch: motionObsEpoch,
            presentingDeviceID: motionObsDevice,
            atTicks: 1010,
        ) == .admitted)
        #expect(harness.firewall.admit(
            absent,
            lease: harness.hardwareLease,
            for: .motionHardware,
            originRevision: 0,
            epoch: motionObsEpoch,
            presentingDeviceID: motionObsDevice,
            atTicks: 1010,
        ) == .admitted)
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.motion, on: &harness.coordinator, atTicks: 1020) == nil)
        #expect(harness.coordinator.state == before)
    }

    @Test("Strong stillness with no hold releases nothing and emits nothing")
    func stillnessHasNoNegativeConsequence() throws {
        guard let proposal = MotionObservationAdapter.proposal(
            sample: ShapedMotionSample(locomotion: .stationary, ageTicks: 10, permissionGranted: true, sensorAvailable: true),
            atTicks: 1010,
        ) else {
            Issue.record("stationary sample must map to a proposal")
            return
        }
        #expect(proposal.reading == .absent)
        var harness = try motionObsHarness()
        #expect(harness.firewall.admit(
            proposal,
            lease: harness.hardwareLease,
            for: .motionHardware,
            originRevision: 0,
            epoch: motionObsEpoch,
            presentingDeviceID: motionObsDevice,
            atTicks: 1010,
        ) == .admitted)
        let before = harness.coordinator.state
        #expect(harness.firewall.evaluate(.motion, on: &harness.coordinator, atTicks: 1020) == nil)
        #expect(harness.coordinator.state == before)
    }
}
