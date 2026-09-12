import Foundation
import Testing

@testable import Domain

func makePolicyDecision(
    counter: UInt64 = 1,
    recordedAt: Date = ledgerT0,
) throws -> LedgerPolicyDecisionRecord {
    try LedgerPolicyDecisionRecord(
        id: LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerSeed, counter: counter),
        recordedAt: recordedAt,
        actionUUID: LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerSeed, counter: counter + 10000),
        actionDeviceID: ledgerDeviceText,
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

func makeCorrection(
    counter: UInt64 = 1,
    recordedAt: Date = ledgerT0,
    generation: UInt64 = 3,
    globalRevision: UInt64 = 7,
) throws -> LedgerCorrectionRecord {
    try LedgerCorrectionRecord(
        id: LedgerIdentity.derive(ledger: .correction, seed: ledgerSeed, counter: counter),
        recordedAt: recordedAt,
        correctedActionUUID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        correctedActionDeviceID: ledgerDeviceText,
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

@Suite("Policy-decision ledger")
struct LedgerPolicyDecisionTests {
    @Test("Appends read back in recorded order with an insertion-order tiebreak")
    func appendReadOrdering() async throws {
        let store = InMemoryLedgerStores.policyDecision(now: { ledgerT0 })
        let second = try makePolicyDecision(counter: 2, recordedAt: ledgerT0.addingTimeInterval(10))
        let first = try makePolicyDecision(counter: 1, recordedAt: ledgerT0)
        try await store.append(second)
        try await store.append(first)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("A codec round-trip preserves every sanitized receipt field")
    func codecRoundTrip() async throws {
        let record = try makePolicyDecision()
        #expect(try LedgerPolicyDecisionCodec.decode(LedgerPolicyDecisionCodec.encode(record)) == record)
    }

    @Test("An unknown envelope version throws instead of defaulting")
    func unknownVersionThrows() async throws {
        let record = try makePolicyDecision()
        for version in [0, 2, 999] {
            let tampered = try reversioned(LedgerPolicyDecisionCodec.encode(record), to: version)
            #expect(throws: LedgerStoreError.unknownSchemaVersion(ledger: "policy-decision", version: version)) {
                try LedgerPolicyDecisionCodec.decode(tampered)
            }
        }
    }

    @Test("Closed kinds and effects refuse unknown spellings at construction")
    func closedVocabulary() {
        #expect(throws: LedgerStoreError.self) {
            try LedgerPolicyDecisionRecord(
                id: UUID(),
                recordedAt: ledgerT0,
                actionUUID: UUID(),
                actionDeviceID: ledgerDeviceText,
                actionCounter: 1,
                holdDecisionUUID: nil,
                kindCode: "nowAcceptVisual",
                effectCode: "quiet",
                leaseGrantedTicks: 1,
                leaseExpiryTicks: 2,
                assessmentDigest: "abc123",
                evaluatedTicks: 1,
            )
        }
        #expect(throws: LedgerStoreError.self) {
            try LedgerPolicyDecisionRecord(
                id: UUID(),
                recordedAt: ledgerT0,
                actionUUID: UUID(),
                actionDeviceID: ledgerDeviceText,
                actionCounter: 1,
                holdDecisionUUID: nil,
                kindCode: "holdBegin",
                effectCode: "launch-rockets",
                leaseGrantedTicks: 1,
                leaseExpiryTicks: 2,
                assessmentDigest: "abc123",
                evaluatedTicks: 1,
            )
        }
    }

    @Test("Replaying an identical record is idempotent")
    func duplicateReplayIdempotent() async throws {
        let store = InMemoryLedgerStores.policyDecision(now: { ledgerT0 })
        let record = try makePolicyDecision()
        try await store.append(record)
        try await store.append(record)
        #expect(try await store.loadRecords() == [record])
    }

    @Test("A write reusing an identifier with different facts is refused")
    func conflictingIdentifierRefused() async throws {
        let store = InMemoryLedgerStores.policyDecision(now: { ledgerT0 })
        let record = try makePolicyDecision()
        try await store.append(record)
        let altered = try LedgerPolicyDecisionRecord(
            id: record.id,
            recordedAt: record.recordedAt,
            actionUUID: record.actionUUID,
            actionDeviceID: record.actionDeviceID,
            actionCounter: record.actionCounter,
            holdDecisionUUID: record.holdDecisionUUID,
            kindCode: "holdRelease",
            effectCode: "resume",
            leaseGrantedTicks: record.leaseGrantedTicks,
            leaseExpiryTicks: record.leaseExpiryTicks,
            assessmentDigest: record.assessmentDigest,
            evaluatedTicks: record.evaluatedTicks,
        )
        await #expect(throws: LedgerStoreError.conflictingRecord(id: record.id)) {
            try await store.append(altered)
        }
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Record identifiers derive from retained seeds, never fresh randomness")
    func identifiersDerived() {
        let first = LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerSeed, counter: 1)
        #expect(first == LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerSeed, counter: 1))
        #expect(first != LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerSeed, counter: 2))
        #expect(first != ledgerSeed)
    }

    @Test("Decision rows persist for ninety days, then prune")
    func retentionPruneAndPurge() async throws {
        #expect(LedgerRetention.policy(for: .policyDecision) == .ninetyDays)
        let store = InMemoryLedgerStores.policyDecision(now: { ledgerT0 })
        try await store.append(makePolicyDecision(counter: 1, recordedAt: ledgerT0.addingTimeInterval(-31 * ledgerDay)))
        #expect(try await store.loadRecords().count == 1)
        try await store.append(makePolicyDecision(counter: 2, recordedAt: ledgerT0.addingTimeInterval(-91 * ledgerDay)))
        #expect(try await store.loadRecords().count == 1)
        #expect(await store.purge(asOf: ledgerT0.addingTimeInterval(100 * ledgerDay)) == 1)
    }

    @Test("A keep-nothing policy stores nothing")
    func keepNothing() async throws {
        let store = InMemoryLedgerStores.policyDecision(now: { ledgerT0 }, retention: .keepNothing)
        try await store.append(makePolicyDecision())
        #expect(try await store.loadRecords() == [])
    }

    @Test("Export uses a closed vocabulary in canonical order with selected keys only")
    func exportClosedVocabulary() async throws {
        let store = InMemoryLedgerStores.policyDecision(now: { ledgerT0 })
        try await store.append(makePolicyDecision())
        let selection = try LedgerExportSelection<LedgerPolicyDecisionExportField>(selected: [.effect, .kind])
        #expect(selection.fields == [.kind, .effect])
        let text = try #require(try await String(
            data: store.export(selected: selection, format: .json),
            encoding: .utf8,
        ))
        let kindRange = try #require(text.range(of: "\"kind\""))
        let effectRange = try #require(text.range(of: "\"effect\""))
        #expect(kindRange.lowerBound < effectRange.lowerBound)
        #expect(!text.contains("assessmentDigest"))
    }

    @Test("Delete removes rows and a failed write preserves data")
    func deleteAndFailurePreserves() async throws {
        let store = InMemoryLedgerStores.policyDecision(now: { ledgerT0 })
        let record = try makePolicyDecision()
        try await store.append(record)
        try await store.deleteAllRecords()
        #expect(try await store.loadRecords() == [])
        try await store.append(record)
        store.saveHook = { throw LedgerStoreError.illegalRollback }
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.append(makePolicyDecision(counter: 9))
        }
        store.saveHook = nil
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Encoded rows replay into a fresh store without loss")
    func replayAcrossRelaunch() async throws {
        let first = try makePolicyDecision(counter: 1)
        let second = try makePolicyDecision(counter: 2, recordedAt: ledgerT0.addingTimeInterval(5))
        let payloads = try [first, second].map { try LedgerPolicyDecisionCodec.encode($0) }
        let reopened = InMemoryLedgerStores.policyDecision(now: { ledgerT0 })
        for payload in payloads {
            try await reopened.append(LedgerPolicyDecisionCodec.decode(payload))
        }
        #expect(try await reopened.loadRecords() == [first, second])
    }
}

@Suite("Correction ledger")
struct LedgerCorrectionTests {
    @Test("Appends read back in recorded order with an insertion-order tiebreak")
    func appendReadOrdering() async throws {
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 })
        let second = try makeCorrection(counter: 2, recordedAt: ledgerT0.addingTimeInterval(10))
        let first = try makeCorrection(counter: 1, recordedAt: ledgerT0)
        try await store.append(second)
        try await store.append(first)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("A codec round-trip preserves every sanitized field")
    func codecRoundTrip() async throws {
        let record = try makeCorrection()
        #expect(try LedgerCorrectionCodec.decode(LedgerCorrectionCodec.encode(record)) == record)
    }

    @Test("An unknown envelope version throws instead of defaulting")
    func unknownVersionThrows() async throws {
        let record = try makeCorrection()
        for version in [0, 2, 999] {
            let tampered = try reversioned(LedgerCorrectionCodec.encode(record), to: version)
            #expect(throws: LedgerStoreError.unknownSchemaVersion(ledger: "correction", version: version)) {
                try LedgerCorrectionCodec.decode(tampered)
            }
        }
    }

    @Test("Closed outcomes refuse unknown spellings at construction")
    func closedVocabulary() {
        #expect(throws: LedgerStoreError.self) {
            try LedgerCorrectionRecord(
                id: UUID(),
                recordedAt: ledgerT0,
                correctedActionUUID: UUID(),
                correctedActionDeviceID: ledgerDeviceText,
                correctedActionCounter: 1,
                correctingActionUUID: nil,
                correctingActionDeviceID: nil,
                correctingActionCounter: nil,
                outcomeCode: "mind-changed",
                reasonCode: "x",
                generation: 1,
                globalRevision: 1,
                supersededDecisionUUIDs: [],
            )
        }
    }

    @Test("Replaying an identical record is idempotent")
    func duplicateReplayIdempotent() async throws {
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 })
        let record = try makeCorrection()
        try await store.append(record)
        try await store.append(record)
        #expect(try await store.loadRecords() == [record])
    }

    @Test("A regressed generation is refused before any mutation")
    func regressedGenerationRefused() async throws {
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 })
        let committed = try makeCorrection(counter: 1, generation: 3, globalRevision: 7)
        try await store.append(committed)
        let regressed = try makeCorrection(counter: 2, generation: 2, globalRevision: 8)
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.append(regressed)
        }
        #expect(try await store.loadRecords() == [committed])
    }

    @Test("A same-generation write superseding with a lower revision is refused")
    func supersededRevisionRefused() async throws {
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 })
        let committed = try makeCorrection(counter: 1, generation: 3, globalRevision: 7)
        try await store.append(committed)
        let dropping = try LedgerCorrectionRecord(
            id: LedgerIdentity.derive(ledger: .correction, seed: ledgerSeed, counter: 2),
            recordedAt: ledgerT0,
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
            try await store.append(dropping)
        }
        #expect(try await store.loadRecords() == [committed])
    }

    @Test("A write reusing an identifier with different facts is refused")
    func conflictingIdentifierRefused() async throws {
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 })
        let record = try makeCorrection()
        try await store.append(record)
        let altered = try LedgerCorrectionRecord(
            id: record.id,
            recordedAt: record.recordedAt,
            correctedActionUUID: record.correctedActionUUID,
            correctedActionDeviceID: record.correctedActionDeviceID,
            correctedActionCounter: record.correctedActionCounter,
            correctingActionUUID: nil,
            correctingActionDeviceID: nil,
            correctingActionCounter: nil,
            outcomeCode: "committed",
            reasonCode: record.reasonCode,
            generation: record.generation,
            globalRevision: record.globalRevision,
            supersededDecisionUUIDs: [],
        )
        await #expect(throws: LedgerStoreError.conflictingRecord(id: record.id)) {
            try await store.append(altered)
        }
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Record identifiers derive from retained seeds, never fresh randomness")
    func identifiersDerived() {
        let first = LedgerIdentity.derive(ledger: .correction, seed: ledgerSeed, counter: 1)
        #expect(first == LedgerIdentity.derive(ledger: .correction, seed: ledgerSeed, counter: 1))
        #expect(first != LedgerIdentity.derive(ledger: .correction, seed: ledgerSeed, counter: 2))
        #expect(first != ledgerSeed)
    }

    @Test("Correction rows persist for ninety days, then prune")
    func retentionPruneAndPurge() async throws {
        #expect(LedgerRetention.policy(for: .correction) == .ninetyDays)
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 })
        try await store.append(makeCorrection(counter: 1, recordedAt: ledgerT0.addingTimeInterval(-91 * ledgerDay)))
        #expect(try await store.loadRecords() == [])
        let live = try makeCorrection(counter: 2, recordedAt: ledgerT0)
        try await store.append(live)
        #expect(await store.purge(asOf: ledgerT0.addingTimeInterval(100 * ledgerDay)) == 1)
        #expect(try await store.loadRecords() == [])
    }

    @Test("A keep-nothing policy stores nothing")
    func keepNothing() async throws {
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 }, retention: .keepNothing)
        try await store.append(makeCorrection())
        #expect(try await store.loadRecords() == [])
    }

    @Test("Export uses a closed vocabulary in canonical order with selected keys only")
    func exportClosedVocabulary() async throws {
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 })
        try await store.append(makeCorrection())
        let selection = try LedgerExportSelection<LedgerCorrectionExportField>(selected: [.generation, .outcome])
        #expect(selection.fields == [.outcome, .generation])
        let text = try #require(try await String(
            data: store.export(selected: selection, format: .json),
            encoding: .utf8,
        ))
        let outcomeRange = try #require(text.range(of: "\"outcome\""))
        let generationRange = try #require(text.range(of: "\"generation\""))
        #expect(outcomeRange.lowerBound < generationRange.lowerBound)
        #expect(!text.contains("globalRevision"))
    }

    @Test("Delete removes rows and a failed write preserves data")
    func deleteAndFailurePreserves() async throws {
        let store = InMemoryLedgerStores.correction(now: { ledgerT0 })
        let record = try makeCorrection()
        try await store.append(record)
        try await store.deleteAllRecords()
        #expect(try await store.loadRecords() == [])
        try await store.append(record)
        store.saveHook = { throw LedgerStoreError.illegalRollback }
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.append(makeCorrection(counter: 9, generation: 4))
        }
        store.saveHook = nil
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Encoded rows replay into a fresh store without loss")
    func replayAcrossRelaunch() async throws {
        let first = try makeCorrection(counter: 1, generation: 3, globalRevision: 7)
        let second = try makeCorrection(
            counter: 2,
            recordedAt: ledgerT0.addingTimeInterval(5),
            generation: 4,
            globalRevision: 8,
        )
        let payloads = try [first, second].map { try LedgerCorrectionCodec.encode($0) }
        let reopened = InMemoryLedgerStores.correction(now: { ledgerT0 })
        for payload in payloads {
            try await reopened.append(LedgerCorrectionCodec.decode(payload))
        }
        #expect(try await reopened.loadRecords() == [first, second])
    }
}
