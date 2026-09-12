import Foundation
import Testing

@testable import Domain

/// Epic 13 R1 RED: rule-proposal store seam beside the six ledgers.
///
/// A `RuleProposalStore` protocol (NOT a seventh ledger row) with an
/// in-memory implementation for deterministic tests. Retention prunes on
/// every write and read; identical replays are idempotent; reused
/// identifiers with different facts are refused; `.keepNothing` retains
/// nothing; export and delete use the ledger export vocabulary.
///
/// Fails before implementation: `RuleProposalStore`,
/// `InMemoryRuleProposalStore`, `RuleProposalCodec`, and
/// `RuleProposalExportField` do not exist.

private let storeSeed = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
private let storeT0 = Date(timeIntervalSince1970: 1_800_000_000)

private func storedRule(
    counter: UInt64 = 1,
    recordedAt: Date = storeT0,
    status: RuleProposalStatus = .pending,
) throws -> RuleProposal {
    try RuleProposal(
        id: LedgerIdentity.derive(ledger: .policyDecision, seed: storeSeed, counter: counter),
        recordedAt: recordedAt,
        ruleKey: "quiet-when-weak",
        kindCode: "holdBegin",
        effectCode: "quiet",
        supportingEvidenceCount: 2,
        requiredEvidenceCount: 2,
        status: status,
        statusUpdatedTicks: 10_000,
    )
}

@Test func ruleStoreRoundTripsInRecordedOrder() async throws {
    let store = InMemoryRuleProposalStore(now: { storeT0 })
    let first = try storedRule(counter: 1, recordedAt: storeT0)
    let second = try storedRule(counter: 2, recordedAt: storeT0.addingTimeInterval(60))
    try await store.append(second)
    try await store.append(first)
    let loaded = try await store.loadProposals()
    #expect(loaded == [first, second])
}

@Test func ruleStoreReplayIsIdempotent() async throws {
    let store = InMemoryRuleProposalStore(now: { storeT0 })
    let record = try storedRule()
    try await store.append(record)
    try await store.append(record)
    #expect(try await store.loadProposals() == [record])
}

@Test func ruleStoreRefusesConflictingReuse() async throws {
    let store = InMemoryRuleProposalStore(now: { storeT0 })
    try await store.append(storedRule())
    let conflict = try storedRule(status: .added)
    await #expect(throws: LedgerStoreError.self) {
        try await store.append(conflict)
    }
}

@Test func ruleStoreUpdatePersistsStatusTransitions() async throws {
    let store = InMemoryRuleProposalStore(now: { storeT0 })
    let record = try storedRule()
    try await store.append(record)
    let added = try RuleProposal(
        id: record.id,
        recordedAt: record.recordedAt,
        ruleKey: record.ruleKey,
        kindCode: record.kindCode,
        effectCode: record.effectCode,
        supportingEvidenceCount: record.supportingEvidenceCount,
        requiredEvidenceCount: record.requiredEvidenceCount,
        status: .added,
        statusUpdatedTicks: 11_000,
    )
    try await store.update(added)
    #expect(try await store.loadProposals() == [added])
}

@Test func ruleStoreKeepNothingRetainsNothing() async throws {
    let store = InMemoryRuleProposalStore(now: { storeT0 }, retention: .keepNothing)
    try await store.append(storedRule())
    #expect(try await store.loadProposals().isEmpty)
    #expect(await store.purge(asOf: storeT0) == 0)
}

@Test func ruleStorePrunesExpiredRows() async throws {
    let store = InMemoryRuleProposalStore(now: { storeT0 })
    let old = try storedRule(
        counter: 1,
        recordedAt: storeT0.addingTimeInterval(-100 * 24 * 60 * 60),
    )
    let fresh = try storedRule(counter: 2)
    try await store.append(old)
    try await store.append(fresh)
    #expect(try await store.loadProposals() == [fresh])
}

@Test func ruleStoreExportUsesLedgerVocabulary() async throws {
    let store = InMemoryRuleProposalStore(now: { storeT0 })
    try await store.append(storedRule())
    let selected = try LedgerExportSelection<RuleProposalExportField>(selected: RuleProposalExportField.allCases)
    let json = try await store.export(selected: selected, format: .json)
    let decoded = try JSONDecoder().decode(LedgerExportDocument.self, from: json)
    #expect(decoded.formatVersion == LedgerExportTable.formatVersion)
    #expect(decoded.fields == RuleProposalExportField.allCases.map(\.rawValue))
    #expect(decoded.records.count == 1)
    #expect(decoded.records[0]["ruleKey"] == "quiet-when-weak")
    await #expect(throws: LedgerStoreError.self) {
        try LedgerExportSelection<RuleProposalExportField>(selected: [])
    }
}

@Test func ruleCodecRefusesUnknownVersion() throws {
    let record = try storedRule()
    let payload = try RuleProposalCodec.encode(record)
    let tampered = try tamperSchemaVersion(payload, to: 999)
    #expect(throws: LedgerStoreError.self) {
        try RuleProposalCodec.decode(tampered)
    }
}

private struct LedgerExportDocument: Decodable {
    var formatVersion: Int
    var ledger: String
    var fields: [String]
    var records: [[String: String]]
}

private func tamperSchemaVersion(_ payload: Data, to version: Int) throws -> Data {
    guard var object = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
        throw LedgerStoreError.invalidRecord("rule-proposal envelope")
    }
    object["schemaVersion"] = version
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}
