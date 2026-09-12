import Domain
import Foundation
import SwiftData
import Testing
@testable import App

/// Story 5 RED: versioned ledger persistence, retention, export, and delete.
///
/// Six separate append-only stores (observation, assessment,
/// policy-decision, correction, consent-receipt, companion-action) holding
/// sanitized rows only. Every test fails until the `StoredLedger*` rows,
/// the versioned codecs' App-side store (`SwiftDataLedgerStore`), and the
/// additive container registration land. Schemas are additive-only;
/// migrations never invent identity.
///
/// Companion file: `LedgerPersistenceDecisionTests.swift` covers the
/// correction, consent-receipt, and companion-action stores plus the
/// whole-ledger delete.

let ledgerTestSeed = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
let ledgerTestDevice = "66666666-6666-6666-6666-666666666666"
let ledgerTestEpoch = "77777777-7777-7777-7777-777777777777"
let ledgerTestT0 = Date(timeIntervalSince1970: 1_800_000_000)
let ledgerTestDay: TimeInterval = 24 * 60 * 60

func ledgerObservation(counter: UInt64 = 1, recordedAt: Date = ledgerTestT0) throws -> LedgerObservationRecord {
    try LedgerObservationRecord(
        id: LedgerIdentity.derive(ledger: .observation, seed: ledgerTestSeed, counter: counter),
        recordedAt: recordedAt,
        providerCode: "fake-presence",
        kindCode: "presence",
        sourceCode: "fakePresence",
        qualityCode: "full",
        confidenceCode: "high",
        coverageCode: "full",
        groupCode: "fake-alpha",
        admittedTicks: 100,
        expiryTicks: 200,
        leaseGrantedTicks: 100,
        leaseExpiryTicks: 190,
        presentingDeviceID: ledgerTestDevice,
    )
}

func ledgerAssessment(counter: UInt64 = 1, recordedAt: Date = ledgerTestT0) throws -> LedgerAssessmentRecord {
    try LedgerAssessmentRecord(
        id: LedgerIdentity.derive(ledger: .assessment, seed: ledgerTestSeed, counter: counter),
        recordedAt: recordedAt,
        readingCode: "present",
        confidenceCode: "high",
        supportingGroups: 2,
        representativeKindCode: "presence",
        representativeSourceCode: "fakePresence",
        representativeReadingCode: "present",
        representativeQualityCode: "full",
        representativeConfidenceCode: "high",
        representativeCoverageCode: "full",
        representativeGroupCode: "fake-alpha",
        representativeExpiryTicks: 200,
        evaluatedTicks: 150,
        assessmentDigest: "abc123",
    )
}

func ledgerPolicyDecision(counter: UInt64 = 1, recordedAt: Date = ledgerTestT0) throws -> LedgerPolicyDecisionRecord {
    try LedgerPolicyDecisionRecord(
        id: LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerTestSeed, counter: counter),
        recordedAt: recordedAt,
        actionUUID: LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerTestSeed, counter: counter + 10000),
        actionDeviceID: ledgerTestDevice,
        actionCounter: counter,
        holdDecisionUUID: nil,
        kindCode: "holdBegin",
        effectCode: "quiet",
        leaseGrantedTicks: 150,
        leaseExpiryTicks: 180,
        assessmentDigest: "abc123",
        evaluatedTicks: 150,
    )
}

func ledgerCorrection(
    counter: UInt64 = 1,
    recordedAt: Date = ledgerTestT0,
    generation: UInt64 = 3,
    globalRevision: UInt64 = 7,
) throws -> LedgerCorrectionRecord {
    try LedgerCorrectionRecord(
        id: LedgerIdentity.derive(ledger: .correction, seed: ledgerTestSeed, counter: counter),
        recordedAt: recordedAt,
        correctedActionUUID: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
        correctedActionDeviceID: ledgerTestDevice,
        correctedActionCounter: counter,
        correctingActionUUID: nil,
        correctingActionDeviceID: nil,
        correctingActionCounter: nil,
        outcomeCode: "duplicateReplay",
        reasonCode: "duplicate-action-id",
        generation: generation,
        globalRevision: globalRevision,
        supersededDecisionUUIDs: [],
    )
}

func ledgerConsentReceipt(
    counter: UInt64 = 1,
    recordedAt: Date = ledgerTestT0,
    scopeRevision: UInt64 = 2,
) throws -> LedgerConsentReceiptRecord {
    try LedgerConsentReceiptRecord(
        id: LedgerIdentity.derive(ledger: .consentReceipt, seed: ledgerTestSeed, counter: counter),
        recordedAt: recordedAt,
        providerCode: "fake-presence",
        scopeCode: "sensing-presence",
        scopeRevision: scopeRevision,
        grantedTicks: 100,
        expiryTicks: 190,
        epochCode: ledgerTestEpoch,
        deviceID: ledgerTestDevice,
        statusCode: "granted",
        revokedTicks: nil,
    )
}

func ledgerCompanionAction(counter: UInt64 = 1, recordedAt: Date = ledgerTestT0) throws -> LedgerCompanionActionRecord {
    try LedgerCompanionActionRecord(
        id: LedgerIdentity.derive(ledger: .companionAction, seed: ledgerTestSeed, counter: counter),
        recordedAt: recordedAt,
        actionDeviceID: ledgerTestDevice,
        actionCounter: counter,
        kindCode: "takeWithMe",
        scopeCode: "globalSystem",
        originRevision: 5,
        segmentUUID: nil,
        causalParents: [],
        leaseGrantedTicks: 150,
        leaseExpiryTicks: 180,
        outcomeCode: "committed",
        reasonCode: "accepted",
    )
}

@Suite("Ledger persistence: observation, assessment, policy-decision")
struct LedgerPersistenceTests {
    @Test("A fresh store loads no rows in any ledger")
    func freshStoreLoadsEmpty() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        #expect(try await store.loadObservations() == [])
        #expect(try await store.loadAssessments() == [])
        #expect(try await store.loadPolicyDecisions() == [])
        #expect(try await store.loadCorrections() == [])
        #expect(try await store.loadConsentReceipts() == [])
        #expect(try await store.loadCompanionActions() == [])
    }

    @Test("Observation rows round-trip in recorded order with an insertion-order tiebreak")
    func observationRoundTrip() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let second = try ledgerObservation(counter: 2, recordedAt: ledgerTestT0.addingTimeInterval(10))
        let first = try ledgerObservation(counter: 1, recordedAt: ledgerTestT0)
        try await store.appendObservation(second)
        try await store.appendObservation(first)
        #expect(try await store.loadObservations() == [first, second])
    }

    @Test("Assessment rows round-trip every sanitized field")
    func assessmentRoundTrip() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerAssessment()
        try await store.appendAssessment(record)
        #expect(try await store.loadAssessments() == [record])
    }

    @Test("Policy-decision rows round-trip every sanitized receipt field")
    func policyDecisionRoundTrip() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerPolicyDecision()
        try await store.appendPolicyDecision(record)
        #expect(try await store.loadPolicyDecisions() == [record])
    }

    @Test("Replaying an identical observation is idempotent")
    func observationDuplicateIdempotent() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerObservation()
        try await store.appendObservation(record)
        try await store.appendObservation(record)
        #expect(try await store.loadObservations() == [record])
    }

    @Test("An unknown row version is refused and the row is preserved")
    func unknownRowVersionRefused() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerObservation()
        try await store.appendObservation(record)
        let tampered = try store.context.fetch(FetchDescriptor<StoredLedgerObservation>())
        try #require(tampered.count == 1)
        tampered[0].schemaVersion = 999
        try store.context.save()
        await #expect(throws: LedgerStoreError.unknownSchemaVersion(ledger: "observation", version: 999)) {
            try await store.loadObservations()
        }
        let preserved = try ModelContext(store.container).fetch(FetchDescriptor<StoredLedgerObservation>())
        #expect(preserved.count == 1)
    }

    @Test("A write reusing an identifier with different facts is refused and preserved")
    func conflictingIdentifierRefused() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerObservation()
        try await store.appendObservation(record)
        let altered = try LedgerObservationRecord(
            id: record.id,
            recordedAt: record.recordedAt,
            providerCode: "fake-motion",
            kindCode: record.kindCode,
            sourceCode: record.sourceCode,
            qualityCode: record.qualityCode,
            confidenceCode: record.confidenceCode,
            coverageCode: record.coverageCode,
            groupCode: record.groupCode,
            admittedTicks: record.admittedTicks,
            expiryTicks: record.expiryTicks,
            leaseGrantedTicks: record.leaseGrantedTicks,
            leaseExpiryTicks: record.leaseExpiryTicks,
            presentingDeviceID: record.presentingDeviceID,
        )
        await #expect(throws: LedgerStoreError.conflictingRecord(id: record.id)) {
            try await store.appendObservation(altered)
        }
        #expect(try await store.loadObservations() == [record])
    }

    @Test("Committed rows replay exactly once across a file-backed relaunch")
    func replayAcrossRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directory.appendingPathComponent("ledgers.sqlite")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try ledgerObservation(counter: 1)
        let second = try ledgerObservation(counter: 2, recordedAt: ledgerTestT0.addingTimeInterval(5))

        do {
            let container = try AppModelContainer.make(url: storeURL)
            let store = try SwiftDataLedgerStore(container: container, now: { ledgerTestT0 })
            try await store.appendObservation(first)
            try await store.appendObservation(second)
        }

        let reopenedContainer = try AppModelContainer.make(url: storeURL)
        let reopened = try SwiftDataLedgerStore(container: reopenedContainer, now: { ledgerTestT0 })
        #expect(try await reopened.loadObservations() == [first, second])
        try await reopened.appendObservation(first)
        #expect(try await reopened.loadObservations() == [first, second])
    }

    @Test("Writes prune expired rows, an explicit purge clears the window, keep-nothing stores nothing")
    func retentionPrunePurgeKeepNothing() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        try await store.appendObservation(ledgerObservation(
            counter: 1,
            recordedAt: ledgerTestT0.addingTimeInterval(-31 * ledgerTestDay),
        ))
        #expect(try await store.loadObservations() == [])
        let live = try ledgerObservation(counter: 2, recordedAt: ledgerTestT0)
        try await store.appendObservation(live)
        #expect(try await store.loadObservations() == [live])
        #expect(await store.purgeObservations(asOf: ledgerTestT0.addingTimeInterval(40 * ledgerTestDay)) == 1)
        #expect(try await store.loadObservations() == [])

        store.retentionOverrides = [.observation: .keepNothing]
        try await store.appendObservation(ledgerObservation(counter: 3))
        #expect(try await store.loadObservations() == [])
    }

    @Test("Ledger export uses a closed vocabulary in canonical order with selected keys only")
    func exportClosedVocabulary() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        try await store.appendObservation(ledgerObservation())
        let selection = try LedgerExportSelection<LedgerObservationExportField>(selected: [.kind, .provider])
        #expect(selection.fields == [.provider, .kind])
        let text = try #require(try await String(
            data: store.exportObservations(selected: selection, format: .json),
            encoding: .utf8,
        ))
        let providerRange = try #require(text.range(of: "\"provider\""))
        let kindRange = try #require(text.range(of: "\"kind\""))
        #expect(providerRange.lowerBound < kindRange.lowerBound)
        #expect(!text.contains("confidence"))

        try await store.appendPolicyDecision(ledgerPolicyDecision())
        let decisionSelection = try LedgerExportSelection<LedgerPolicyDecisionExportField>(selected: [.effect, .kind])
        let csv = try #require(try await String(
            data: store.exportPolicyDecisions(selected: decisionSelection, format: .csv),
            encoding: .utf8,
        ))
        #expect(csv.hasPrefix("kind,effect\n"))
    }

    @Test("Delete removes ledger rows; a failed save preserves every row")
    func deleteAndFailurePreserves() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let record = try ledgerObservation()
        try await store.appendObservation(record)
        try await store.deleteObservations()
        #expect(try await store.loadObservations() == [])

        try await store.appendObservation(record)
        struct SaveFailure: Error {}
        let failing = try SwiftDataLedgerStore(
            container: store.container,
            now: { ledgerTestT0 },
            save: { _ in throw SaveFailure() },
        )
        await #expect(throws: SaveFailure.self) {
            try await failing.appendObservation(ledgerObservation(counter: 9))
        }
        await #expect(throws: SaveFailure.self) {
            try await failing.deleteObservations()
        }
        #expect(try await store.loadObservations() == [record])
    }
}
