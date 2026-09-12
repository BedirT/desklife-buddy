import Foundation
import Testing

@testable import Domain

/// Story 6 RED: permission broker + consent + kill switch.
///
/// The broker is the Domain consent state machine beside the lease
/// authority: placeholder capabilities only (never real entitlement
/// strings), separate sensing-consent vs effect-consent paths, JIT
/// education owed-state, receipts on the story-5 consent-receipt seam,
/// revocation with a tick-measured deadline, one-action kill switch, and
/// a denied-fixture core that stays useful with nothing granted.
///
/// Fails before implementation: `PermissionBroker`,
/// `PermissionCapability`, `PermissionConsentState`,
/// `PermissionRevocation`, and `PermissionKillSwitchResult` do not exist.
private let brokerT0 = Date(timeIntervalSince1970: 1_800_000_000)
private let brokerTicks: TimeInterval = 1_000
private let brokerDevice = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
private let brokerEpoch = "55555555-5555-5555-5555-555555555555"

private func brokerReceiptStore() -> InMemoryLedgerConsentReceiptStore {
    InMemoryLedgerConsentReceiptStore(now: { brokerT0 })
}

private func makeBroker() throws -> PermissionBroker {
    try PermissionBroker(deviceID: brokerDevice, epochCode: brokerEpoch)
}

private func grantedBroker(
    _ capabilities: [PermissionCapability] = [.sensingPresence, .effectHold],
    atTicks ticks: TimeInterval = brokerTicks,
) async throws -> (PermissionBroker, InMemoryLedgerConsentReceiptStore) {
    var broker = try makeBroker()
    let store = brokerReceiptStore()
    for capability in capabilities {
        try await broker.grant(capability, atTicks: ticks, recordedAt: brokerT0, store: store)
    }
    return (broker, store)
}

@Suite("Permission broker: consent states and education")
struct PermissionBrokerConsentTests {
    @Test("A fresh broker denies everything by default and owes education")
    func freshBrokerDeniesByDefault() throws {
        let broker = try makeBroker()
        for capability in PermissionCapability.allCases {
            #expect(broker.state(for: capability) == .unknown)
            #expect(broker.educationOwed(for: capability))
            #expect(!broker.canIssueLease(for: capability))
            #expect(!broker.canEmitEffect(for: capability))
        }
        #expect(broker.educationOwedCapabilities.count == PermissionCapability.allCases.count)
        #expect(broker.pendingRevocationCount == 0)
        #expect(!broker.isKillSwitchEngaged)
    }

    @Test("Education runs unknown to educating to granted")
    func educationFlowToGrant() async throws {
        var broker = try makeBroker()
        let store = brokerReceiptStore()
        broker.beginEducation(for: .sensingPresence)
        #expect(broker.state(for: .sensingPresence) == .educating)
        #expect(broker.educationOwed(for: .sensingPresence))
        #expect(!broker.canIssueLease(for: .sensingPresence))
        try await broker.grant(.sensingPresence, atTicks: brokerTicks, recordedAt: brokerT0, store: store)
        #expect(broker.state(for: .sensingPresence) == .granted)
        #expect(!broker.educationOwed(for: .sensingPresence))
        #expect(broker.canIssueLease(for: .sensingPresence))
    }

    @Test("A grant without prior education is still honored and receipted")
    func grantFromUnknownIsHonored() async throws {
        var broker = try makeBroker()
        let store = brokerReceiptStore()
        try await broker.grant(.effectHold, atTicks: brokerTicks, recordedAt: brokerT0, store: store)
        #expect(broker.state(for: .effectHold) == .granted)
        #expect(broker.canEmitEffect(for: .effectHold))
        let receipts = try await store.loadRecords()
        #expect(receipts.count == 1)
        #expect(receipts[0].statusCode == "granted")
        #expect(receipts[0].revokedTicks == nil)
    }

    @Test("A denial closes its gate and records a revoked-status receipt")
    func denyRecordsRevokedReceipt() async throws {
        var broker = try makeBroker()
        let store = brokerReceiptStore()
        broker.beginEducation(for: .sensingMotion)
        try await broker.deny(.sensingMotion, atTicks: brokerTicks, recordedAt: brokerT0, store: store)
        #expect(broker.state(for: .sensingMotion) == .denied)
        #expect(!broker.educationOwed(for: .sensingMotion))
        #expect(!broker.canIssueLease(for: .sensingMotion))
        let receipts = try await store.loadRecords()
        #expect(receipts.count == 1)
        #expect(receipts[0].scopeCode == PermissionCapability.sensingMotion.scopeCode)
        #expect(receipts[0].statusCode == "revoked")
        #expect(receipts[0].revokedTicks == brokerTicks)
    }

    @Test("A repeat grant while granted appends no duplicate receipt")
    func grantIsIdempotentWhileGranted() async throws {
        var broker = try makeBroker()
        let store = brokerReceiptStore()
        try await broker.grant(.sensingPresence, atTicks: brokerTicks, recordedAt: brokerT0, store: store)
        try await broker.grant(.sensingPresence, atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store)
        #expect(broker.state(for: .sensingPresence) == .granted)
        #expect(try await store.loadRecords().count == 1)
    }

    @Test("Revoking a never-granted capability is a no-op without a receipt")
    func revokeWithoutGrantIsNoOp() async throws {
        var broker = try makeBroker()
        let store = brokerReceiptStore()
        let revocation = try await broker.revoke(
            .sensingPresence, atTicks: brokerTicks, recordedAt: brokerT0, store: store,
        )
        #expect(revocation == nil)
        #expect(broker.state(for: .sensingPresence) == .unknown)
        #expect(try await store.loadRecords().isEmpty)
    }
}

@Suite("Permission broker: sensing/effect consent confusion")
struct PermissionBrokerConfusionTests {
    @Test("A sensing grant must not enable the effect emission path")
    func sensingGrantDoesNotEnableEffects() async throws {
        let (broker, _) = try await grantedBroker([.sensingPresence])
        #expect(broker.canIssueLease(for: .sensingPresence))
        for effect in PermissionCapability.allCases where effect.isEffect {
            #expect(!broker.canEmitEffect(for: effect))
        }
        #expect(broker.isAutomaticEmissionBlocked)
    }

    @Test("An effect grant must not enable the sensing issuance path")
    func effectGrantDoesNotEnableSensing() async throws {
        let (broker, _) = try await grantedBroker([.effectHold])
        #expect(broker.canEmitEffect(for: .effectHold))
        for sensing in PermissionCapability.allCases where sensing.isSensing {
            #expect(!broker.canIssueLease(for: sensing))
        }
        #expect(broker.isSensingSilent)
    }

    @Test("Revoking sensing leaves an granted effect emission intact")
    func revokeSensingLeavesEffectsIntact() async throws {
        var (broker, store) = try await grantedBroker([.sensingPresence, .effectHold])
        let revocation = try await broker.revoke(
            .sensingPresence, atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store,
        )
        #expect(revocation != nil)
        #expect(!broker.canIssueLease(for: .sensingPresence))
        #expect(broker.canEmitEffect(for: .effectHold))
        #expect(!broker.isAutomaticEmissionBlocked)
    }

    @Test("Revoking an effect leaves sensing issuance intact")
    func revokeEffectLeavesSensingIntact() async throws {
        var (broker, store) = try await grantedBroker([.sensingPresence, .effectHold])
        let revocation = try await broker.revoke(
            .effectHold, atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store,
        )
        #expect(revocation != nil)
        #expect(!broker.canEmitEffect(for: .effectHold))
        #expect(broker.canIssueLease(for: .sensingPresence))
        #expect(!broker.isSensingSilent)
    }
}

@Suite("Permission broker: consent receipts")
struct PermissionBrokerReceiptTests {
    @Test("Every capability maps into the ledger closed scope set")
    func capabilitiesMapToClosedScopes() {
        for capability in PermissionCapability.allCases {
            #expect(LedgerConsentReceiptRecord.scopes.contains(capability.scopeCode))
            #expect(!capability.providerCode.isEmpty)
        }
        let scopes = PermissionCapability.allCases.map(\.scopeCode)
        #expect(Set(scopes).count == scopes.count)
    }

    @Test("Grant then revoke appends a granted and revoked pair in order")
    func grantThenRevokeReceiptPair() async throws {
        var broker = try makeBroker()
        let store = brokerReceiptStore()
        try await broker.grant(.sensingAmbient, atTicks: brokerTicks, recordedAt: brokerT0, store: store)
        _ = try await broker.revoke(
            .sensingAmbient, atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store,
        )
        let receipts = try await store.loadRecords()
        #expect(receipts.count == 2)
        #expect(receipts.allSatisfy { $0.scopeCode == PermissionCapability.sensingAmbient.scopeCode })
        #expect(receipts[0].statusCode == "granted")
        #expect(receipts[1].statusCode == "revoked")
        #expect(receipts[1].revokedTicks == brokerTicks + 1)
        #expect(receipts[1].scopeRevision >= receipts[0].scopeRevision)
    }
}

@Suite("Permission broker: measured revocation deadline")
struct PermissionBrokerRevocationTests {
    @Test("Revocation closes the gate at once and drains inside the deadline")
    func revokeDrainsWithinDeadline() async throws {
        var (broker, store) = try await grantedBroker([.sensingPresence])
        let revoked = try await broker.revoke(
            .sensingPresence, atTicks: brokerTicks, recordedAt: brokerT0, store: store,
        )
        #expect(revoked != nil)
        #expect(revoked?.leasesRevokedImmediately == true)
        #expect(!broker.canIssueLease(for: .sensingPresence))
        #expect(broker.pendingRevocationCount == 1)
        #expect(!broker.isQuiescent(atTicks: brokerTicks))
        let completed = broker.drainRevocations(atTicks: brokerTicks + 2)
        #expect(completed.count == 1)
        let record = completed[0]
        #expect(record.completedTicks != nil)
        #expect((record.completedTicks ?? 0) - record.requestedTicks <= PermissionBroker.revocationDeadlineTicks)
        #expect(broker.pendingRevocationCount == 0)
        #expect(broker.isQuiescent(atTicks: brokerTicks + 2))
        #expect(!broker.revocationOverdue(atTicks: brokerTicks + 2))
    }

    @Test("A revocation left undrained past its deadline reads as overdue")
    func lateDrainReadsAsOverdue() async throws {
        var (broker, store) = try await grantedBroker([.sensingPresence])
        _ = try await broker.revoke(
            .sensingPresence, atTicks: brokerTicks, recordedAt: brokerT0, store: store,
        )
        let lateTicks = brokerTicks + PermissionBroker.revocationDeadlineTicks + 1
        #expect(broker.revocationOverdue(atTicks: lateTicks))
        #expect(!broker.isQuiescent(atTicks: lateTicks))
        let completed = broker.drainRevocations(atTicks: lateTicks)
        #expect(completed.count == 1)
        #expect((completed[0].completedTicks ?? 0) - completed[0].requestedTicks > PermissionBroker.revocationDeadlineTicks)
    }
}

@Suite("Permission broker: kill switch")
struct PermissionBrokerKillSwitchTests {
    @Test("One action silences sensing and blocks automatic emission")
    func killSwitchSilencesAndBlocks() async throws {
        var (broker, store) = try await grantedBroker([.sensingPresence, .sensingMotion, .effectHold])
        let result = try await broker.engageKillSwitch(
            atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store,
        )
        #expect(broker.isKillSwitchEngaged)
        #expect(result.revokedCapabilities.count == 3)
        for capability in PermissionCapability.allCases {
            #expect(!broker.canIssueLease(for: capability))
            #expect(!broker.canEmitEffect(for: capability))
        }
        #expect(broker.isSensingSilent)
        #expect(broker.isAutomaticEmissionBlocked)
        #expect(broker.activeSuppressionReasons == [.manualPause])
        #expect(broker.firewallHoldsCleared)
        #expect(broker.fencedEpochCodes.contains(brokerEpoch))
        #expect(broker.pendingRevocationCount == 3)
    }

    @Test("Resume after the kill switch requires re-consent, never silent resume")
    func killSwitchResumeRequiresReconsent() async throws {
        var (broker, store) = try await grantedBroker([.sensingPresence, .effectHold])
        _ = try await broker.engageKillSwitch(
            atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store,
        )
        broker.disengageKillSwitch()
        #expect(!broker.isKillSwitchEngaged)
        #expect(broker.activeSuppressionReasons.isEmpty)
        #expect(!broker.canIssueLease(for: .sensingPresence))
        #expect(!broker.canEmitEffect(for: .effectHold))
        #expect(broker.isSensingSilent)
        #expect(broker.isAutomaticEmissionBlocked)
        try await broker.grant(.sensingPresence, atTicks: brokerTicks + 2, recordedAt: brokerT0, store: store)
        #expect(broker.canIssueLease(for: .sensingPresence))
        #expect(!broker.canEmitEffect(for: .effectHold))
    }
}

@Suite("Permission broker: denied fixture")
struct PermissionBrokerDeniedFixtureTests {
    @Test("A fully denied broker keeps the permission-free core useful and emits nothing")
    func deniedFixtureCoreStillUseful() async throws {
        var broker = try makeBroker()
        let store = brokerReceiptStore()
        for capability in PermissionCapability.allCases {
            try await broker.deny(capability, atTicks: brokerTicks, recordedAt: brokerT0, store: store)
        }
        for capability in PermissionCapability.allCases {
            #expect(broker.state(for: capability) == .denied)
            #expect(!broker.canIssueLease(for: capability))
            #expect(!broker.canEmitEffect(for: capability))
        }
        #expect(broker.permissionFreeCoreAvailable)
        #expect(broker.isSensingSilent)
        #expect(broker.isAutomaticEmissionBlocked)
        #expect(try await store.loadRecords().count == PermissionCapability.allCases.count)
    }
}

/// A consent-receipt seam whose appends always fail, pinning that the
/// broker never mutates a gate it could not receipt.
private struct ThrowingConsentReceiptStore: LedgerConsentReceiptStore {
    struct AppendFailure: Error {}
    func append(_ record: LedgerConsentReceiptRecord) async throws { throw AppendFailure() }
    func loadRecords() async throws -> [LedgerConsentReceiptRecord] { [] }
    func deleteAllRecords() async throws {}
}

/// A consent-receipt seam whose loads fail a fixed number of times before
/// recovering, pinning that a transient seed-read blip stays retryable.
private final class TransientLoadConsentReceiptStore: LedgerConsentReceiptStore {
    struct LoadBlip: Error {}
    var remainingLoadFailures: Int
    let inner: InMemoryLedgerConsentReceiptStore
    init(inner: InMemoryLedgerConsentReceiptStore, loadFailures: Int) {
        self.inner = inner
        self.remainingLoadFailures = loadFailures
    }
    func append(_ record: LedgerConsentReceiptRecord) async throws {
        try await inner.append(record)
    }
    func loadRecords() async throws -> [LedgerConsentReceiptRecord] {
        guard remainingLoadFailures == 0 else {
            remainingLoadFailures -= 1
            throw LoadBlip()
        }
        return try await inner.loadRecords()
    }
    func deleteAllRecords() async throws {
        try await inner.deleteAllRecords()
    }
}

@Suite("Permission broker: relaunch durability and ledger failure")
struct PermissionBrokerDurabilityTests {
    @Test("A relaunched broker continues retained revisions, kill switch included")
    func relaunchContinuesRetainedRevisions() async throws {
        let store = brokerReceiptStore()
        var first = try makeBroker()
        try await first.grant(.sensingPresence, atTicks: brokerTicks, recordedAt: brokerT0, store: store)
        _ = try await first.revoke(
            .sensingPresence, atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store,
        )
        // Relaunch with history: the next grant must continue the retained
        // sequence (revision 3), not restart at 1 and trip the frontier.
        var relaunched = try makeBroker()
        try await relaunched.grant(
            .sensingPresence, atTicks: brokerTicks + 2, recordedAt: brokerT0, store: store,
        )
        #expect(relaunched.state(for: .sensingPresence) == .granted)
        #expect(relaunched.canIssueLease(for: .sensingPresence))
        // The kill switch revocation continues the same sequence (revision 4).
        _ = try await relaunched.engageKillSwitch(
            atTicks: brokerTicks + 3, recordedAt: brokerT0, store: store,
        )
        let receipts = try await store.loadRecords().sorted { $0.scopeRevision < $1.scopeRevision }
        #expect(receipts.count == 4)
        #expect(receipts.map(\.scopeRevision) == [1, 2, 3, 4])
        #expect(relaunched.isSensingSilent)
    }

    @Test("A failed ledger append leaves the gate and state unchanged")
    func appendFailureKeepsGate() async throws {
        let failing = ThrowingConsentReceiptStore()
        var broker = try makeBroker()
        await #expect(throws: ThrowingConsentReceiptStore.AppendFailure.self) {
            try await broker.grant(.sensingPresence, atTicks: brokerTicks, recordedAt: brokerT0, store: failing)
        }
        #expect(broker.state(for: .sensingPresence) == .unknown)
        #expect(!broker.canIssueLease(for: .sensingPresence))
        #expect(broker.educationOwed(for: .sensingPresence))
        #expect(broker.pendingRevocationCount == 0)
        // A granted gate survives a failed revocation append alike.
        let store = brokerReceiptStore()
        try await broker.grant(.sensingPresence, atTicks: brokerTicks, recordedAt: brokerT0, store: store)
        await #expect(throws: ThrowingConsentReceiptStore.AppendFailure.self) {
            try await broker.revoke(
                .sensingPresence, atTicks: brokerTicks + 1, recordedAt: brokerT0, store: failing,
            )
        }
        #expect(broker.state(for: .sensingPresence) == .granted)
        #expect(broker.canIssueLease(for: .sensingPresence))
        #expect(broker.pendingRevocationCount == 0)
    }

    @Test("A ledger failure mid-engagement still leaves every gate shut")
    func failedEngagementLeavesGatesShut() async throws {
        var (broker, _) = try await grantedBroker([.sensingPresence, .effectHold])
        let failing = ThrowingConsentReceiptStore()
        await #expect(throws: ThrowingConsentReceiptStore.AppendFailure.self) {
            try await broker.engageKillSwitch(atTicks: brokerTicks + 1, recordedAt: brokerT0, store: failing)
        }
        #expect(broker.isKillSwitchEngaged)
        for capability in PermissionCapability.allCases {
            #expect(!broker.canIssueLease(for: capability))
            #expect(!broker.canEmitEffect(for: capability))
        }
        #expect(broker.isSensingSilent)
        #expect(broker.isAutomaticEmissionBlocked)
        #expect(broker.activeSuppressionReasons == [.manualPause])
    }

    @Test("Grants during engagement throw and disengage alone re-enables nothing")
    func grantDuringEngagementThrows() async throws {
        var (broker, store) = try await grantedBroker([.sensingPresence])
        _ = try await broker.engageKillSwitch(atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store)
        await #expect(throws: PermissionBrokerError.grantWhileKillSwitchEngaged(capability: .effectHold)) {
            try await broker.grant(.effectHold, atTicks: brokerTicks + 2, recordedAt: brokerT0, store: store)
        }
        await #expect(throws: PermissionBrokerError.grantWhileKillSwitchEngaged(capability: .sensingPresence)) {
            try await broker.grant(.sensingPresence, atTicks: brokerTicks + 2, recordedAt: brokerT0, store: store)
        }
        broker.disengageKillSwitch()
        #expect(!broker.canIssueLease(for: .sensingPresence))
        #expect(!broker.canEmitEffect(for: .effectHold))
        #expect(broker.isSensingSilent)
        #expect(broker.isAutomaticEmissionBlocked)
    }

    @Test("A transient seed-load failure stays retryable and continues retained revisions")
    func transientSeedFailureRetries() async throws {
        let store = brokerReceiptStore()
        var first = try makeBroker()
        try await first.grant(.sensingPresence, atTicks: brokerTicks, recordedAt: brokerT0, store: store)
        _ = try await first.revoke(
            .sensingPresence, atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store,
        )
        try await first.grant(.sensingPresence, atTicks: brokerTicks + 2, recordedAt: brokerT0, store: store)
        _ = try await first.revoke(
            .sensingPresence, atTicks: brokerTicks + 3, recordedAt: brokerT0, store: store,
        )
        try await first.grant(.sensingPresence, atTicks: brokerTicks + 4, recordedAt: brokerT0, store: store)
        let flaky = TransientLoadConsentReceiptStore(inner: store, loadFailures: 1)
        var relaunched = try makeBroker()
        await #expect(throws: TransientLoadConsentReceiptStore.LoadBlip.self) {
            try await relaunched.grant(
                .sensingPresence, atTicks: brokerTicks + 5, recordedAt: brokerT0, store: flaky,
            )
        }
        #expect(relaunched.state(for: .sensingPresence) == .unknown)
        try await relaunched.grant(
            .sensingPresence, atTicks: brokerTicks + 5, recordedAt: brokerT0, store: flaky,
        )
        #expect(relaunched.canIssueLease(for: .sensingPresence))
        let revisions = try await store.loadRecords().map(\.scopeRevision).sorted()
        #expect(revisions == [1, 2, 3, 4, 5, 6])
    }

    @Test("Denying after revoke settles the pending drain")
    func denyAfterRevokeSettlesDrain() async throws {
        var (broker, store) = try await grantedBroker([.sensingPresence])
        _ = try await broker.revoke(
            .sensingPresence, atTicks: brokerTicks + 1, recordedAt: brokerT0, store: store,
        )
        #expect(broker.pendingRevocationCount == 1)
        try await broker.deny(.sensingPresence, atTicks: brokerTicks + 2, recordedAt: brokerT0, store: store)
        #expect(broker.state(for: .sensingPresence) == .denied)
        #expect(broker.pendingRevocationCount == 0)
        #expect(broker.isQuiescent(atTicks: brokerTicks + 2))
        let lateTicks = brokerTicks + 2 + PermissionBroker.revocationDeadlineTicks + 1
        #expect(!broker.revocationOverdue(atTicks: lateTicks))
        #expect(broker.isQuiescent(atTicks: lateTicks))
    }
}
