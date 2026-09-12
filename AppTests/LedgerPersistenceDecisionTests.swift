import Domain
import Foundation
import SwiftData
import Testing
@testable import App

/// Story 5 RED (continued): correction, consent-receipt, and
/// companion-action stores plus the whole-ledger delete. Shared makers
/// live in `LedgerPersistenceTests.swift`.

@Suite("Ledger persistence: correction, consent-receipt, companion-action")
struct LedgerPersistenceDecisionTests {
    @Test("Correction rows round-trip every sanitized field")
    func correctionRoundTrip() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerCorrection()
        try await store.appendCorrection(record)
        #expect(try await store.loadCorrections() == [record])
    }

    @Test("A regressed correction generation is refused before any mutation")
    func correctionRegressionRefused() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let committed = try ledgerCorrection(counter: 1, generation: 3, globalRevision: 7)
        try await store.appendCorrection(committed)
        let regressed = try ledgerCorrection(counter: 2, generation: 2, globalRevision: 8)
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.appendCorrection(regressed)
        }
        #expect(try await store.loadCorrections() == [committed])
    }

    @Test("A same-generation correction dropping a retained revision is refused")
    func correctionRevisionDropRefused() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let committed = try ledgerCorrection(counter: 1, generation: 3, globalRevision: 7)
        try await store.appendCorrection(committed)
        let dropping = try LedgerCorrectionRecord(
            id: LedgerIdentity.derive(ledger: .correction, seed: ledgerTestSeed, counter: 2),
            recordedAt: ledgerTestT0,
            correctedActionUUID: committed.correctedActionUUID,
            correctedActionDeviceID: committed.correctedActionDeviceID,
            correctedActionCounter: committed.correctedActionCounter,
            correctingActionUUID: nil,
            correctingActionDeviceID: nil,
            correctingActionCounter: nil,
            outcomeCode: "duplicateReplay",
            reasonCode: "duplicate-action-id",
            generation: 3,
            globalRevision: 6,
            supersededDecisionUUIDs: [],
        )
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.appendCorrection(dropping)
        }
        #expect(try await store.loadCorrections() == [committed])
    }

    @Test("An unknown correction row version is refused and the row is preserved")
    func correctionUnknownVersionRefused() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        try await store.appendCorrection(ledgerCorrection())
        let tampered = try store.context.fetch(FetchDescriptor<StoredLedgerCorrection>())
        try #require(tampered.count == 1)
        tampered[0].schemaVersion = 999
        try store.context.save()
        await #expect(throws: LedgerStoreError.unknownSchemaVersion(ledger: "correction", version: 999)) {
            try await store.loadCorrections()
        }
        let preserved = try store.context.fetch(FetchDescriptor<StoredLedgerCorrection>())
        #expect(preserved.count == 1)
    }
    @Test("Consent-receipt rows round-trip every sanitized field")
    func consentReceiptRoundTrip() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerConsentReceipt()
        try await store.appendConsentReceipt(record)
        #expect(try await store.loadConsentReceipts() == [record])
    }

    @Test("A regressed consent scope revision is refused before any mutation")
    func consentRevisionRefused() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let current = try ledgerConsentReceipt(counter: 1, scopeRevision: 2)
        try await store.appendConsentReceipt(current)
        let regressed = try ledgerConsentReceipt(counter: 2, scopeRevision: 1)
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.appendConsentReceipt(regressed)
        }
        #expect(try await store.loadConsentReceipts() == [current])
    }

    @Test("Consent receipts prune after ninety days and keep longer rows")
    func consentRetention() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        try await store.appendConsentReceipt(ledgerConsentReceipt(
            counter: 1,
            recordedAt: ledgerTestT0.addingTimeInterval(-31 * ledgerTestDay),
        ))
        #expect(try await store.loadConsentReceipts().count == 1)
        #expect(await store.purgeConsentReceipts(asOf: ledgerTestT0.addingTimeInterval(100 * ledgerTestDay)) == 1)
        #expect(try await store.loadConsentReceipts() == [])
    }

    @Test("Companion-action rows round-trip every sanitized field")
    func companionActionRoundTrip() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerCompanionAction()
        try await store.appendCompanionAction(record)
        #expect(try await store.loadCompanionActions() == [record])
    }

    @Test("A write reusing a companion identifier with different facts is refused")
    func companionConflictRefused() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerCompanionAction()
        try await store.appendCompanionAction(record)
        let altered = try LedgerCompanionActionRecord(
            id: record.id,
            recordedAt: record.recordedAt,
            actionDeviceID: record.actionDeviceID,
            actionCounter: record.actionCounter,
            kindCode: "handoff",
            scopeCode: record.scopeCode,
            originRevision: record.originRevision,
            segmentUUID: record.segmentUUID,
            causalParents: record.causalParents,
            leaseGrantedTicks: record.leaseGrantedTicks,
            leaseExpiryTicks: record.leaseExpiryTicks,
            outcomeCode: record.outcomeCode,
            reasonCode: record.reasonCode,
        )
        await #expect(throws: LedgerStoreError.conflictingRecord(id: record.id)) {
            try await store.appendCompanionAction(altered)
        }
        #expect(try await store.loadCompanionActions() == [record])
    }

    @Test("Companion export carries no titles, payloads, or content identifiers")
    func companionExportSanitized() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        try await store.appendCompanionAction(ledgerCompanionAction())
        let selection = try LedgerExportSelection<LedgerCompanionActionExportField>(selected: [.outcome, .kind])
        #expect(selection.fields == [.kind, .outcome])
        let text = try #require(String(
            data: try await store.exportCompanionActions(selected: selection, format: .json),
            encoding: .utf8,
        ))
        #expect(!text.contains("causalParents"))
        #expect(text.contains("\"kind\""))
        #expect(text.contains("\"outcome\""))
    }

    @Test("A whole-ledger delete clears every store and preserves nothing")
    func deleteAllLedgers() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        try await store.appendObservation(ledgerObservation())
        try await store.appendAssessment(ledgerAssessment())
        try await store.appendPolicyDecision(ledgerPolicyDecision())
        try await store.appendCorrection(ledgerCorrection())
        try await store.appendConsentReceipt(ledgerConsentReceipt())
        try await store.appendCompanionAction(ledgerCompanionAction())
        try await store.deleteAllLedgers()
        #expect(try await store.loadObservations() == [])
        #expect(try await store.loadAssessments() == [])
        #expect(try await store.loadPolicyDecisions() == [])
        #expect(try await store.loadCorrections() == [])
        #expect(try await store.loadConsentReceipts() == [])
        #expect(try await store.loadCompanionActions() == [])
    }

    @Test("Correction export keeps canonical order with selected keys only")
    func correctionExportCanonical() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        try await store.appendCorrection(ledgerCorrection())
        let selection = try LedgerExportSelection<LedgerCorrectionExportField>(selected: [.generation, .outcome])
        #expect(selection.fields == [.outcome, .generation])
        let text = try #require(String(
            data: try await store.exportCorrections(selected: selection, format: .json),
            encoding: .utf8,
        ))
        let outcomeRange = try #require(text.range(of: "\"outcome\""))
        let generationRange = try #require(text.range(of: "\"generation\""))
        #expect(outcomeRange.lowerBound < generationRange.lowerBound)
        #expect(!text.contains("globalRevision"))
    }
}
