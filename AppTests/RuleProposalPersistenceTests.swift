import Domain
import Foundation
import SwiftData
import Testing
@testable import App

/// Epic 13 R1 RED: SwiftData rule-proposal persistence.
///
/// An additive-only `StoredRuleProposal` row plus `SwiftDataRuleProposalStore`
/// following the `SwiftDataLedgerStore` pattern: versioned payload blob
/// decoded by the Domain codec, fail-closed unknown versions, retention-aware
/// pruning on every write and read, `.keepNothing` honored, and export/delete
/// through the ledger export vocabulary. The proposal store is a separate
/// seam beside the six ledgers — never a seventh ledger row.
///
/// Fails before implementation: `StoredRuleProposal` and
/// `SwiftDataRuleProposalStore` do not exist.

let rulePersistenceSeed = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
let rulePersistenceDevice = "44444444-4444-4444-4444-444444444444"
let rulePersistenceT0 = Date(timeIntervalSince1970: 1_800_000_000)

func rulePersistenceRecord(counter: UInt64 = 1, recordedAt: Date = rulePersistenceT0) throws -> RuleProposal {
    try RuleProposal(
        id: LedgerIdentity.derive(ledger: .policyDecision, seed: rulePersistenceSeed, counter: counter),
        recordedAt: recordedAt,
        ruleKey: "shift-within-window",
        kindCode: "holdBegin",
        effectCode: "shift",
        supportingEvidenceCount: 3,
        requiredEvidenceCount: 2,
        status: .pending,
        statusUpdatedTicks: 20_000,
    )
}

@Test func ruleProposalPersistenceRoundTrip() async throws {
    let store = try SwiftDataRuleProposalStore(inMemory: true, now: { rulePersistenceT0 })
    let record = try rulePersistenceRecord()
    try await store.append(record)
    #expect(try await store.loadProposals() == [record])
}

@Test func ruleProposalPersistenceUpdateRoundTrip() async throws {
    let store = try SwiftDataRuleProposalStore(inMemory: true, now: { rulePersistenceT0 })
    let record = try rulePersistenceRecord()
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
        statusUpdatedTicks: 21_000,
    )
    try await store.update(added)
    #expect(try await store.loadProposals() == [added])
}

@Test func ruleProposalPersistenceRefusesMigration() async throws {
    let store = try SwiftDataRuleProposalStore(inMemory: true, now: { rulePersistenceT0 })
    let record = try rulePersistenceRecord()
    try await store.append(record)
    // A future schema version row must fail closed before any decode.
    let rows = try store.context.fetch(FetchDescriptor<StoredRuleProposal>())
    #expect(rows.count == 1)
    rows[0].schemaVersion = 999
    await #expect(throws: LedgerStoreError.self) {
        try await store.loadProposals()
    }
    // Nothing was pruned or mutated by the refused read.
    #expect(try store.context.fetch(FetchDescriptor<StoredRuleProposal>()).count == 1)
}

@Test func ruleProposalPersistenceHonorsKeepNothing() async throws {
    let store = try SwiftDataRuleProposalStore(inMemory: true, now: { rulePersistenceT0 })
    store.retentionOverride = .keepNothing
    try await store.append(rulePersistenceRecord())
    #expect(try await store.loadProposals().isEmpty)
    #expect(try store.context.fetch(FetchDescriptor<StoredRuleProposal>()).isEmpty)
}

@Test func ruleProposalPersistenceExportsAndDeletes() async throws {
    let store = try SwiftDataRuleProposalStore(inMemory: true, now: { rulePersistenceT0 })
    try await store.append(rulePersistenceRecord())
    let selected = try LedgerExportSelection<RuleProposalExportField>(selected: [.ruleKey, .effect, .status])
    let data = try await store.export(selected: selected, format: .csv)
    let text = String(data: data, encoding: .utf8) ?? ""
    #expect(text.hasPrefix("ruleKey,effect,status"))
    #expect(text.contains("shift-within-window"))
    try await store.deleteAllProposals()
    #expect(try await store.loadProposals().isEmpty)
}
