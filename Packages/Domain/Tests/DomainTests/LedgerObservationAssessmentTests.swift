import Foundation
import Testing

@testable import Domain

let ledgerSeed = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
let ledgerDeviceText = "22222222-2222-2222-2222-222222222222"
let ledgerEpoch = "33333333-3333-3333-3333-333333333333"
let ledgerDay: TimeInterval = 24 * 60 * 60
let ledgerT0 = Date(timeIntervalSince1970: 1_800_000_000)

func makeObservation(
    counter: UInt64 = 1,
    recordedAt: Date = ledgerT0,
) throws -> LedgerObservationRecord {
    try LedgerObservationRecord(
        id: LedgerIdentity.derive(ledger: .observation, seed: ledgerSeed, counter: counter),
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
        presentingDeviceID: ledgerDeviceText,
    )
}

func makeAssessment(
    counter: UInt64 = 1,
    recordedAt: Date = ledgerT0,
) throws -> LedgerAssessmentRecord {
    try LedgerAssessmentRecord(
        id: LedgerIdentity.derive(ledger: .assessment, seed: ledgerSeed, counter: counter),
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

/// Rewrites the envelope version of an encoded row without touching the row.
func reversioned(_ data: Data, to version: Int) throws -> Data {
    let text = try #require(String(data: data, encoding: .utf8))
    let rewritten = text.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":\(version)")
    try #require(rewritten != text)
    return try #require(rewritten.data(using: .utf8))
}

@Suite("Observation ledger")
struct LedgerObservationTests {
    @Test("Appends read back in recorded order with an insertion-order tiebreak")
    func appendReadOrdering() async throws {
        let store = InMemoryLedgerStores.observation(now: { ledgerT0 })
        let second = try makeObservation(counter: 2, recordedAt: ledgerT0.addingTimeInterval(10))
        let first = try makeObservation(counter: 1, recordedAt: ledgerT0)
        try await store.append(second)
        try await store.append(first)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("A codec round-trip preserves every sanitized field")
    func codecRoundTrip() async throws {
        let record = try makeObservation()
        #expect(try LedgerObservationCodec.decode(LedgerObservationCodec.encode(record)) == record)
    }

    @Test("An unknown envelope version throws instead of defaulting")
    func unknownVersionThrows() async throws {
        let record = try makeObservation()
        for version in [0, 2, 999] {
            let tampered = try reversioned(LedgerObservationCodec.encode(record), to: version)
            #expect(throws: LedgerStoreError.unknownSchemaVersion(ledger: "observation", version: version)) {
                try LedgerObservationCodec.decode(tampered)
            }
        }
    }

    @Test("A corrupt payload throws instead of defaulting")
    func corruptPayloadThrows() {
        #expect(throws: LedgerStoreError.self) {
            try LedgerObservationCodec.decode(Data("{\"schemaVersion\":1}".utf8))
        }
        #expect(throws: LedgerStoreError.self) {
            try LedgerObservationCodec.decode(Data("not-json".utf8))
        }
    }

    @Test("Replaying an identical record is idempotent")
    func duplicateReplayIdempotent() async throws {
        let store = InMemoryLedgerStores.observation(now: { ledgerT0 })
        let record = try makeObservation()
        try await store.append(record)
        try await store.append(record)
        #expect(try await store.loadRecords() == [record])
    }

    @Test("A write reusing an identifier with different facts is refused")
    func conflictingIdentifierRefused() async throws {
        let store = InMemoryLedgerStores.observation(now: { ledgerT0 })
        let record = try makeObservation()
        try await store.append(record)
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
            try await store.append(altered)
        }
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Record identifiers derive from retained seeds, never fresh randomness")
    func identifiersDerived() {
        let first = LedgerIdentity.derive(ledger: .observation, seed: ledgerSeed, counter: 1)
        #expect(first == LedgerIdentity.derive(ledger: .observation, seed: ledgerSeed, counter: 1))
        #expect(first != LedgerIdentity.derive(ledger: .observation, seed: ledgerSeed, counter: 2))
        #expect(first != ledgerSeed)
    }

    @Test("Writes prune expired rows and an explicit purge clears the window")
    func retentionPruneAndPurge() async throws {
        let store = InMemoryLedgerStores.observation(now: { ledgerT0 })
        try await store.append(makeObservation(counter: 1, recordedAt: ledgerT0.addingTimeInterval(-31 * ledgerDay)))
        #expect(try await store.loadRecords() == [])
        let live = try makeObservation(counter: 2, recordedAt: ledgerT0)
        try await store.append(live)
        #expect(try await store.loadRecords() == [live])
        #expect(await store.purge(asOf: ledgerT0.addingTimeInterval(40 * ledgerDay)) == 1)
        #expect(try await store.loadRecords() == [])
    }

    @Test("A keep-nothing policy stores nothing and purges everything")
    func keepNothing() async throws {
        let store = InMemoryLedgerStores.observation(now: { ledgerT0 }, retention: .keepNothing)
        try await store.append(makeObservation())
        #expect(try await store.loadRecords() == [])
    }

    @Test("Export uses a closed vocabulary in canonical order with selected keys only")
    func exportClosedVocabulary() async throws {
        let store = InMemoryLedgerStores.observation(now: { ledgerT0 })
        try await store.append(makeObservation())
        let selection = try LedgerExportSelection<LedgerObservationExportField>(selected: [.kind, .provider])
        #expect(selection.fields == [.provider, .kind])
        let text = try #require(try await String(
            data: store.export(selected: selection, format: .json),
            encoding: .utf8,
        ))
        let providerRange = try #require(text.range(of: "\"provider\""))
        let kindRange = try #require(text.range(of: "\"kind\""))
        #expect(providerRange.lowerBound < kindRange.lowerBound)
        #expect(!text.contains("confidence"))
        #expect(!text.contains("expiryTicks"))
        let csv = try #require(try await String(data: store.export(selected: selection, format: .csv), encoding: .utf8))
        #expect(csv.hasPrefix("provider,kind\n"))
        #expect(throws: LedgerStoreError.exportNoFields) {
            try LedgerExportSelection<LedgerObservationExportField>(selected: [])
        }
    }

    @Test("Delete removes rows and a failed write preserves data")
    func deleteAndFailurePreserves() async throws {
        let store = InMemoryLedgerStores.observation(now: { ledgerT0 })
        let record = try makeObservation()
        try await store.append(record)
        try await store.deleteAllRecords()
        #expect(try await store.loadRecords() == [])
        try await store.append(record)
        store.saveHook = { throw LedgerStoreError.illegalRollback }
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.append(makeObservation(counter: 9))
        }
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.deleteAllRecords()
        }
        store.saveHook = nil
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Encoded rows replay into a fresh store without loss")
    func replayAcrossRelaunch() async throws {
        let first = try makeObservation(counter: 1)
        let second = try makeObservation(counter: 2, recordedAt: ledgerT0.addingTimeInterval(5))
        let payloads = try [first, second].map { try LedgerObservationCodec.encode($0) }
        let reopened = InMemoryLedgerStores.observation(now: { ledgerT0 })
        for payload in payloads {
            try await reopened.append(LedgerObservationCodec.decode(payload))
        }
        #expect(try await reopened.loadRecords() == [first, second])
    }
}

@Suite("Assessment ledger")
struct LedgerAssessmentTests {
    @Test("Appends read back in recorded order with an insertion-order tiebreak")
    func appendReadOrdering() async throws {
        let store = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        let second = try makeAssessment(counter: 2, recordedAt: ledgerT0.addingTimeInterval(10))
        let first = try makeAssessment(counter: 1, recordedAt: ledgerT0)
        try await store.append(second)
        try await store.append(first)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("A codec round-trip preserves every sanitized field")
    func codecRoundTrip() async throws {
        let record = try makeAssessment()
        #expect(try LedgerAssessmentCodec.decode(LedgerAssessmentCodec.encode(record)) == record)
    }

    @Test("An unknown envelope version throws instead of defaulting")
    func unknownVersionThrows() async throws {
        let record = try makeAssessment()
        for version in [0, 2, 999] {
            let tampered = try reversioned(LedgerAssessmentCodec.encode(record), to: version)
            #expect(throws: LedgerStoreError.unknownSchemaVersion(ledger: "assessment", version: version)) {
                try LedgerAssessmentCodec.decode(tampered)
            }
        }
    }

    @Test("Replaying an identical record is idempotent")
    func duplicateReplayIdempotent() async throws {
        let store = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        let record = try makeAssessment()
        try await store.append(record)
        try await store.append(record)
        #expect(try await store.loadRecords() == [record])
    }

    @Test("A write reusing an identifier with different facts is refused")
    func conflictingIdentifierRefused() async throws {
        let store = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        let record = try makeAssessment()
        try await store.append(record)
        let altered = try LedgerAssessmentRecord(
            id: record.id,
            recordedAt: record.recordedAt,
            readingCode: "absent",
            confidenceCode: record.confidenceCode,
            supportingGroups: record.supportingGroups,
            representativeKindCode: record.representativeKindCode,
            representativeSourceCode: record.representativeSourceCode,
            representativeReadingCode: record.representativeReadingCode,
            representativeQualityCode: record.representativeQualityCode,
            representativeConfidenceCode: record.representativeConfidenceCode,
            representativeCoverageCode: record.representativeCoverageCode,
            representativeGroupCode: record.representativeGroupCode,
            representativeExpiryTicks: record.representativeExpiryTicks,
            evaluatedTicks: record.evaluatedTicks,
            assessmentDigest: record.assessmentDigest,
        )
        await #expect(throws: LedgerStoreError.conflictingRecord(id: record.id)) {
            try await store.append(altered)
        }
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Record identifiers derive from retained seeds, never fresh randomness")
    func identifiersDerived() {
        let first = LedgerIdentity.derive(ledger: .assessment, seed: ledgerSeed, counter: 1)
        #expect(first == LedgerIdentity.derive(ledger: .assessment, seed: ledgerSeed, counter: 1))
        #expect(first != LedgerIdentity.derive(ledger: .assessment, seed: ledgerSeed, counter: 2))
        #expect(first != LedgerIdentity.derive(ledger: .observation, seed: ledgerSeed, counter: 1))
        #expect(first != ledgerSeed)
    }

    @Test("Writes prune expired rows and an explicit purge clears the window")
    func retentionPruneAndPurge() async throws {
        let store = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        try await store.append(makeAssessment(counter: 1, recordedAt: ledgerT0.addingTimeInterval(-31 * ledgerDay)))
        #expect(try await store.loadRecords() == [])
        let live = try makeAssessment(counter: 2, recordedAt: ledgerT0)
        try await store.append(live)
        #expect(await store.purge(asOf: ledgerT0.addingTimeInterval(40 * ledgerDay)) == 1)
        #expect(try await store.loadRecords() == [])
    }

    @Test("A keep-nothing policy stores nothing")
    func keepNothing() async throws {
        let store = InMemoryLedgerStores.assessment(now: { ledgerT0 }, retention: .keepNothing)
        try await store.append(makeAssessment())
        #expect(try await store.loadRecords() == [])
    }

    @Test("Export uses a closed vocabulary in canonical order with selected keys only")
    func exportClosedVocabulary() async throws {
        let store = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        try await store.append(makeAssessment())
        let selection = try LedgerExportSelection<LedgerAssessmentExportField>(selected: [.assessmentDigest, .reading])
        #expect(selection.fields == [.reading, .assessmentDigest])
        let text = try #require(try await String(
            data: store.export(selected: selection, format: .json),
            encoding: .utf8,
        ))
        let readingRange = try #require(text.range(of: "\"reading\""))
        let digestRange = try #require(text.range(of: "\"assessmentDigest\""))
        #expect(readingRange.lowerBound < digestRange.lowerBound)
        #expect(!text.contains("supportingGroups"))
    }

    @Test("Delete removes rows and a failed write preserves data")
    func deleteAndFailurePreserves() async throws {
        let store = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        let record = try makeAssessment()
        try await store.append(record)
        try await store.deleteAllRecords()
        #expect(try await store.loadRecords() == [])
        try await store.append(record)
        store.saveHook = { throw LedgerStoreError.illegalRollback }
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.append(makeAssessment(counter: 9))
        }
        store.saveHook = nil
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Encoded rows replay into a fresh store without loss")
    func replayAcrossRelaunch() async throws {
        let first = try makeAssessment(counter: 1)
        let second = try makeAssessment(counter: 2, recordedAt: ledgerT0.addingTimeInterval(5))
        let payloads = try [first, second].map { try LedgerAssessmentCodec.encode($0) }
        let reopened = InMemoryLedgerStores.assessment(now: { ledgerT0 })
        for payload in payloads {
            try await reopened.append(LedgerAssessmentCodec.decode(payload))
        }
        #expect(try await reopened.loadRecords() == [first, second])
    }
}
