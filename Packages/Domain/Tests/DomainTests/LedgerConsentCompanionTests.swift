import Foundation
import Testing

@testable import Domain

func makeConsentReceipt(
    counter: UInt64 = 1,
    recordedAt: Date = ledgerT0,
    scopeRevision: UInt64 = 2,
    statusCode: String = "granted",
) throws -> LedgerConsentReceiptRecord {
    try LedgerConsentReceiptRecord(
        id: LedgerIdentity.derive(ledger: .consentReceipt, seed: ledgerSeed, counter: counter),
        recordedAt: recordedAt,
        providerCode: "fake-presence",
        scopeCode: "sensing-presence",
        scopeRevision: scopeRevision,
        grantedTicks: 100,
        expiryTicks: 190,
        epochCode: ledgerEpoch,
        deviceID: ledgerDeviceText,
        statusCode: statusCode,
        revokedTicks: nil,
    )
}

func makeCompanionAction(
    counter: UInt64 = 1,
    recordedAt: Date = ledgerT0,
) throws -> LedgerCompanionActionRecord {
    try LedgerCompanionActionRecord(
        id: LedgerIdentity.derive(ledger: .companionAction, seed: ledgerSeed, counter: counter),
        recordedAt: recordedAt,
        actionDeviceID: ledgerDeviceText,
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

@Suite("Consent-receipt ledger")
struct LedgerConsentReceiptTests {
    @Test("Appends read back in recorded order with an insertion-order tiebreak")
    func appendReadOrdering() async throws {
        let store = InMemoryLedgerStores.consentReceipt(now: { ledgerT0 })
        let second = try makeConsentReceipt(counter: 2, recordedAt: ledgerT0.addingTimeInterval(10))
        let first = try makeConsentReceipt(counter: 1, recordedAt: ledgerT0)
        try await store.append(second)
        try await store.append(first)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("A codec round-trip preserves every sanitized receipt field")
    func codecRoundTrip() async throws {
        let record = try makeConsentReceipt()
        #expect(try LedgerConsentReceiptCodec.decode(LedgerConsentReceiptCodec.encode(record)) == record)
    }

    @Test("An unknown envelope version throws instead of defaulting")
    func unknownVersionThrows() async throws {
        let record = try makeConsentReceipt()
        for version in [0, 2, 999] {
            let tampered = try reversioned(LedgerConsentReceiptCodec.encode(record), to: version)
            #expect(throws: LedgerStoreError.unknownSchemaVersion(ledger: "consent-receipt", version: version)) {
                try LedgerConsentReceiptCodec.decode(tampered)
            }
        }
    }

    @Test("Closed scopes and statuses refuse unknown spellings at construction")
    func closedVocabulary() {
        #expect(throws: LedgerStoreError.self) {
            try LedgerConsentReceiptRecord(
                id: UUID(),
                recordedAt: ledgerT0,
                providerCode: "fake-presence",
                scopeCode: "camera-roll",
                scopeRevision: 1,
                grantedTicks: 1,
                expiryTicks: 2,
                epochCode: ledgerEpoch,
                deviceID: ledgerDeviceText,
                statusCode: "granted",
                revokedTicks: nil,
            )
        }
        #expect(throws: LedgerStoreError.self) {
            try LedgerConsentReceiptRecord(
                id: UUID(),
                recordedAt: ledgerT0,
                providerCode: "fake-presence",
                scopeCode: "sensing-presence",
                scopeRevision: 1,
                grantedTicks: 1,
                expiryTicks: 2,
                epochCode: ledgerEpoch,
                deviceID: ledgerDeviceText,
                statusCode: "maybe",
                revokedTicks: nil,
            )
        }
    }

    @Test("Replaying an identical record is idempotent")
    func duplicateReplayIdempotent() async throws {
        let store = InMemoryLedgerStores.consentReceipt(now: { ledgerT0 })
        let record = try makeConsentReceipt()
        try await store.append(record)
        try await store.append(record)
        #expect(try await store.loadRecords() == [record])
    }

    @Test("A regressed scope revision for the same provider and scope is refused")
    func regressedRevisionRefused() async throws {
        let store = InMemoryLedgerStores.consentReceipt(now: { ledgerT0 })
        let current = try makeConsentReceipt(counter: 1, scopeRevision: 2)
        try await store.append(current)
        let regressed = try makeConsentReceipt(counter: 2, scopeRevision: 1)
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.append(regressed)
        }
        #expect(try await store.loadRecords() == [current])
    }

    @Test("A write reusing an identifier with different facts is refused")
    func conflictingIdentifierRefused() async throws {
        let store = InMemoryLedgerStores.consentReceipt(now: { ledgerT0 })
        let record = try makeConsentReceipt()
        try await store.append(record)
        let altered = try LedgerConsentReceiptRecord(
            id: record.id,
            recordedAt: record.recordedAt,
            providerCode: record.providerCode,
            scopeCode: record.scopeCode,
            scopeRevision: record.scopeRevision,
            grantedTicks: record.grantedTicks,
            expiryTicks: record.expiryTicks,
            epochCode: record.epochCode,
            deviceID: record.deviceID,
            statusCode: "revoked",
            revokedTicks: 150,
        )
        await #expect(throws: LedgerStoreError.conflictingRecord(id: record.id)) {
            try await store.append(altered)
        }
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Record identifiers derive from retained seeds, never fresh randomness")
    func identifiersDerived() {
        let first = LedgerIdentity.derive(ledger: .consentReceipt, seed: ledgerSeed, counter: 1)
        #expect(first == LedgerIdentity.derive(ledger: .consentReceipt, seed: ledgerSeed, counter: 1))
        #expect(first != LedgerIdentity.derive(ledger: .consentReceipt, seed: ledgerSeed, counter: 2))
        #expect(first != ledgerSeed)
    }

    @Test("Receipt rows persist for ninety days, then prune")
    func retentionPruneAndPurge() async throws {
        #expect(LedgerRetention.policy(for: .consentReceipt) == .ninetyDays)
        let store = InMemoryLedgerStores.consentReceipt(now: { ledgerT0 })
        try await store.append(makeConsentReceipt(counter: 1, recordedAt: ledgerT0.addingTimeInterval(-91 * ledgerDay)))
        #expect(try await store.loadRecords() == [])
        let live = try makeConsentReceipt(counter: 2, recordedAt: ledgerT0)
        try await store.append(live)
        #expect(await store.purge(asOf: ledgerT0.addingTimeInterval(100 * ledgerDay)) == 1)
        #expect(try await store.loadRecords() == [])
    }

    @Test("A keep-nothing policy stores nothing")
    func keepNothing() async throws {
        let store = InMemoryLedgerStores.consentReceipt(now: { ledgerT0 }, retention: .keepNothing)
        try await store.append(makeConsentReceipt())
        #expect(try await store.loadRecords() == [])
    }

    @Test("Export uses a closed vocabulary in canonical order with selected keys only")
    func exportClosedVocabulary() async throws {
        let store = InMemoryLedgerStores.consentReceipt(now: { ledgerT0 })
        try await store.append(makeConsentReceipt())
        let selection = try LedgerExportSelection<LedgerConsentReceiptExportField>(selected: [.status, .scope])
        #expect(selection.fields == [.scope, .status])
        let text = try #require(try await String(
            data: store.export(selected: selection, format: .json),
            encoding: .utf8,
        ))
        let scopeRange = try #require(text.range(of: "\"scope\""))
        let statusRange = try #require(text.range(of: "\"status\""))
        #expect(scopeRange.lowerBound < statusRange.lowerBound)
        #expect(!text.contains("epoch"))
    }

    @Test("Delete removes rows and a failed write preserves data")
    func deleteAndFailurePreserves() async throws {
        let store = InMemoryLedgerStores.consentReceipt(now: { ledgerT0 })
        let record = try makeConsentReceipt()
        try await store.append(record)
        try await store.deleteAllRecords()
        #expect(try await store.loadRecords() == [])
        try await store.append(record)
        store.saveHook = { throw LedgerStoreError.illegalRollback }
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.append(makeConsentReceipt(counter: 9, scopeRevision: 3))
        }
        store.saveHook = nil
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Encoded rows replay into a fresh store without loss")
    func replayAcrossRelaunch() async throws {
        let first = try makeConsentReceipt(counter: 1, scopeRevision: 2)
        let second = try makeConsentReceipt(counter: 2, recordedAt: ledgerT0.addingTimeInterval(5), scopeRevision: 3)
        let payloads = try [first, second].map { try LedgerConsentReceiptCodec.encode($0) }
        let reopened = InMemoryLedgerStores.consentReceipt(now: { ledgerT0 })
        for payload in payloads {
            try await reopened.append(LedgerConsentReceiptCodec.decode(payload))
        }
        #expect(try await reopened.loadRecords() == [first, second])
    }
}

@Suite("Companion-action ledger")
struct LedgerCompanionActionTests {
    @Test("Appends read back in recorded order with an insertion-order tiebreak")
    func appendReadOrdering() async throws {
        let store = InMemoryLedgerStores.companionAction(now: { ledgerT0 })
        let second = try makeCompanionAction(counter: 2, recordedAt: ledgerT0.addingTimeInterval(10))
        let first = try makeCompanionAction(counter: 1, recordedAt: ledgerT0)
        try await store.append(second)
        try await store.append(first)
        #expect(try await store.loadRecords() == [first, second])
    }

    @Test("A codec round-trip preserves every sanitized field")
    func codecRoundTrip() async throws {
        let record = try makeCompanionAction()
        #expect(try LedgerCompanionActionCodec.decode(LedgerCompanionActionCodec.encode(record)) == record)
    }

    @Test("An unknown envelope version throws instead of defaulting")
    func unknownVersionThrows() async throws {
        let record = try makeCompanionAction()
        for version in [0, 2, 999] {
            let tampered = try reversioned(LedgerCompanionActionCodec.encode(record), to: version)
            #expect(throws: LedgerStoreError.unknownSchemaVersion(ledger: "companion-action", version: version)) {
                try LedgerCompanionActionCodec.decode(tampered)
            }
        }
    }

    @Test("Closed kinds refuse unknown spellings at construction")
    func closedVocabulary() {
        #expect(throws: LedgerStoreError.self) {
            try LedgerCompanionActionRecord(
                id: UUID(),
                recordedAt: ledgerT0,
                actionDeviceID: ledgerDeviceText,
                actionCounter: 1,
                kindCode: "teleport",
                scopeCode: "globalSystem",
                originRevision: 1,
                segmentUUID: nil,
                causalParents: [],
                leaseGrantedTicks: 1,
                leaseExpiryTicks: 2,
                outcomeCode: "committed",
                reasonCode: "accepted",
            )
        }
    }

    @Test("Replaying an identical record is idempotent")
    func duplicateReplayIdempotent() async throws {
        let store = InMemoryLedgerStores.companionAction(now: { ledgerT0 })
        let record = try makeCompanionAction()
        try await store.append(record)
        try await store.append(record)
        #expect(try await store.loadRecords() == [record])
    }

    @Test("A write reusing an identifier with different facts is refused")
    func conflictingIdentifierRefused() async throws {
        let store = InMemoryLedgerStores.companionAction(now: { ledgerT0 })
        let record = try makeCompanionAction()
        try await store.append(record)
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
            try await store.append(altered)
        }
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Record identifiers derive from retained seeds, never fresh randomness")
    func identifiersDerived() {
        let first = LedgerIdentity.derive(ledger: .companionAction, seed: ledgerSeed, counter: 1)
        #expect(first == LedgerIdentity.derive(ledger: .companionAction, seed: ledgerSeed, counter: 1))
        #expect(first != LedgerIdentity.derive(ledger: .companionAction, seed: ledgerSeed, counter: 2))
        #expect(first != ledgerSeed)
    }

    @Test("Writes prune expired rows and an explicit purge clears the window")
    func retentionPruneAndPurge() async throws {
        #expect(LedgerRetention.policy(for: .companionAction) == .thirtyDays)
        let store = InMemoryLedgerStores.companionAction(now: { ledgerT0 })
        try await store.append(makeCompanionAction(
            counter: 1,
            recordedAt: ledgerT0.addingTimeInterval(-31 * ledgerDay),
        ))
        #expect(try await store.loadRecords() == [])
        let live = try makeCompanionAction(counter: 2, recordedAt: ledgerT0)
        try await store.append(live)
        #expect(await store.purge(asOf: ledgerT0.addingTimeInterval(40 * ledgerDay)) == 1)
        #expect(try await store.loadRecords() == [])
    }

    @Test("A keep-nothing policy stores nothing")
    func keepNothing() async throws {
        let store = InMemoryLedgerStores.companionAction(now: { ledgerT0 }, retention: .keepNothing)
        try await store.append(makeCompanionAction())
        #expect(try await store.loadRecords() == [])
    }

    @Test("Export uses a closed vocabulary in canonical order with selected keys only")
    func exportClosedVocabulary() async throws {
        let store = InMemoryLedgerStores.companionAction(now: { ledgerT0 })
        try await store.append(makeCompanionAction())
        let selection = try LedgerExportSelection<LedgerCompanionActionExportField>(selected: [.outcome, .kind])
        #expect(selection.fields == [.kind, .outcome])
        let text = try #require(try await String(
            data: store.export(selected: selection, format: .json),
            encoding: .utf8,
        ))
        let kindRange = try #require(text.range(of: "\"kind\""))
        let outcomeRange = try #require(text.range(of: "\"outcome\""))
        #expect(kindRange.lowerBound < outcomeRange.lowerBound)
        #expect(!text.contains("causalParents"))
    }

    @Test("Delete removes rows and a failed write preserves data")
    func deleteAndFailurePreserves() async throws {
        let store = InMemoryLedgerStores.companionAction(now: { ledgerT0 })
        let record = try makeCompanionAction()
        try await store.append(record)
        try await store.deleteAllRecords()
        #expect(try await store.loadRecords() == [])
        try await store.append(record)
        store.saveHook = { throw LedgerStoreError.illegalRollback }
        await #expect(throws: LedgerStoreError.illegalRollback) {
            try await store.append(makeCompanionAction(counter: 9))
        }
        store.saveHook = nil
        #expect(try await store.loadRecords() == [record])
    }

    @Test("Encoded rows replay into a fresh store without loss")
    func replayAcrossRelaunch() async throws {
        let first = try makeCompanionAction(counter: 1)
        let second = try makeCompanionAction(counter: 2, recordedAt: ledgerT0.addingTimeInterval(5))
        let payloads = try [first, second].map { try LedgerCompanionActionCodec.encode($0) }
        let reopened = InMemoryLedgerStores.companionAction(now: { ledgerT0 })
        for payload in payloads {
            try await reopened.append(LedgerCompanionActionCodec.decode(payload))
        }
        #expect(try await reopened.loadRecords() == [first, second])
    }
}

@Suite("Ledger retention table")
struct LedgerRetentionTests {
    @Test("Every ledger names a bounded default window")
    func defaultWindows() {
        #expect(LedgerRetention.policy(for: .observation) == .thirtyDays)
        #expect(LedgerRetention.policy(for: .assessment) == .thirtyDays)
        #expect(LedgerRetention.policy(for: .policyDecision) == .ninetyDays)
        #expect(LedgerRetention.policy(for: .correction) == .ninetyDays)
        #expect(LedgerRetention.policy(for: .consentReceipt) == .ninetyDays)
        #expect(LedgerRetention.policy(for: .companionAction) == .thirtyDays)
    }

    @Test("Ledger kinds cover the six versioned stores")
    func sixLedgers() {
        #expect(LedgerKind.allCases.count == 6)
    }
}
