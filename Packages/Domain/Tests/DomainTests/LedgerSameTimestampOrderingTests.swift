import Foundation
import Testing

@testable import Domain

/// Fix-forward regression pins: same-timestamp rows must read back in
/// insertion order on every InMemory fake (the identifier tiebreak was a
/// coin flip for same-moment appends), and broker receipt identifiers must
/// derive deterministically from their consent inputs.
///
/// Each ordering test inserts against identifier order, so the old
/// `id.uuidString` tiebreak deterministically disagrees with the expected
/// insertion order. The consent-receipt fake is pinned by the broker's
/// same-recordedAt grant/revoke test; the other five fakes pin here.
@Suite("Ledger same-timestamp insertion order")
struct LedgerSameTimestampOrderingTests {
    @Test("Observation same-timestamp rows read back in insertion order")
    func observationSameTimestamp() async throws {
        let a = try makeObservation(counter: 1)
        let b = try makeObservation(counter: 2)
        let store = InMemoryLedgerStores.observation(now: { ledgerT0 })
        let first = a.id.uuidString > b.id.uuidString ? a : b
        let second = first.id == a.id ? b : a
        try await store.append(first)
        try await store.append(second)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("Assessment same-timestamp rows read back in insertion order")
    func assessmentSameTimestamp() async throws {
        let a = try makeAssessment(counter: 1)
        let b = try makeAssessment(counter: 2)
        let store = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        let first = a.id.uuidString > b.id.uuidString ? a : b
        let second = first.id == a.id ? b : a
        try await store.append(first)
        try await store.append(second)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("Policy-decision same-timestamp rows read back in insertion order")
    func policyDecisionSameTimestamp() async throws {
        let a = try makePolicyDecision(counter: 1)
        let b = try makePolicyDecision(counter: 2)
        let store = InMemoryLedgerStores.policyDecision(now: { ledgerT0 })
        let first = a.id.uuidString > b.id.uuidString ? a : b
        let second = first.id == a.id ? b : a
        try await store.append(first)
        try await store.append(second)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("Correction same-timestamp rows read back in insertion order")
    func correctionSameTimestamp() async throws {
        let a = try makeCorrection(counter: 1)
        let b = try makeCorrection(counter: 2)
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 })
        let first = a.id.uuidString > b.id.uuidString ? a : b
        let second = first.id == a.id ? b : a
        try await store.append(first)
        try await store.append(second)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("Companion-action same-timestamp rows read back in insertion order")
    func companionActionSameTimestamp() async throws {
        let a = try makeCompanionAction(counter: 1)
        let b = try makeCompanionAction(counter: 2)
        let store = InMemoryLedgerStores.companionAction(now: { ledgerT0 })
        let first = a.id.uuidString > b.id.uuidString ? a : b
        let second = first.id == a.id ? b : a
        try await store.append(first)
        try await store.append(second)
        #expect(try await store.loadRecords() == [first, second])
    }
}

private let deterministicDevice = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
private let deterministicEpoch = "deterministic-epoch"
private let deterministicT0 = Date(timeIntervalSince1970: 1_800_000_000)

@Suite("Broker deterministic receipt identity")
struct BrokerDeterministicIdentityTests {
    @Test("Same consent inputs derive the same receipt ID; a revision bump changes it")
    func deterministicReceiptIDs() async throws {
        var first = try PermissionBroker(deviceID: deterministicDevice, epochCode: deterministicEpoch)
        var second = try PermissionBroker(deviceID: deterministicDevice, epochCode: deterministicEpoch)
        let storeA = InMemoryLedgerConsentReceiptStore(now: { deterministicT0 })
        let storeB = InMemoryLedgerConsentReceiptStore(now: { deterministicT0 })
        try await first.grant(.sensingPresence, atTicks: 1000, recordedAt: deterministicT0, store: storeA)
        try await second.grant(.sensingPresence, atTicks: 1000, recordedAt: deterministicT0, store: storeB)
        let idsA = try await storeA.loadRecords().map(\.id)
        let idsB = try await storeB.loadRecords().map(\.id)
        #expect(idsA == idsB)
        #expect(idsA.count == 1)
        // A retried identical append is an idempotent replay, never a second row.
        let rowsA = try await storeA.loadRecords()
        try await storeA.append(rowsA[0])
        #expect(try await storeA.loadRecords().count == 1)
        // A revision bump mints fresh identifiers for every further receipt.
        _ = try await first.revoke(.sensingPresence, atTicks: 1001, recordedAt: deterministicT0, store: storeA)
        try await first.grant(.sensingPresence, atTicks: 1002, recordedAt: deterministicT0, store: storeA)
        #expect(try await Set(storeA.loadRecords().map(\.id)).count == 3)
    }
}
