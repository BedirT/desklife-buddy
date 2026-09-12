import Domain
import Foundation
import SwiftData
import Testing

@testable import App

/// Fix-forward pin for the production path: same-timestamp rows must load
/// in insertion order. Load fetches sort explicitly by recordedAt with
/// insertion (row-id) order for ties, and the in-memory ordering keeps
/// fetch order for ties instead of re-sorting by identifier.
///
/// Each case inserts against identifier order, so the old uuidString
/// tiebreak would deterministically disagree with the expected order.
@Suite("Ledger persistence: same-timestamp insertion order")
struct LedgerSameTimestampPersistenceTests {
    @Test("Observation same-timestamp rows load in insertion order")
    func observationSameTimestamp() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let a = try ledgerObservation(counter: 1)
        let b = try ledgerObservation(counter: 2)
        let first = a.id.uuidString > b.id.uuidString ? a : b
        let second = first.id == a.id ? b : a
        try await store.appendObservation(first)
        try await store.appendObservation(second)
        #expect(try await store.loadObservations() == [first, second])
    }

    @Test("Consent-receipt same-timestamp rows load in insertion order")
    func consentReceiptSameTimestamp() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let a = try ledgerConsentReceipt(counter: 1, scopeRevision: 2)
        let b = try ledgerConsentReceipt(counter: 2, scopeRevision: 2)
        let first = a.id.uuidString > b.id.uuidString ? a : b
        let second = first.id == a.id ? b : a
        try await store.appendConsentReceipt(first)
        try await store.appendConsentReceipt(second)
        #expect(try await store.loadConsentReceipts() == [first, second])
    }

    @Test("Correction same-timestamp rows load in insertion order")
    func correctionSameTimestamp() async throws {
        let store = try SwiftDataLedgerStore(inMemory: true, now: { ledgerTestT0 })
        let a = try ledgerCorrection(counter: 1)
        let b = try ledgerCorrection(counter: 2)
        let first = a.id.uuidString > b.id.uuidString ? a : b
        let second = first.id == a.id ? b : a
        try await store.appendCorrection(first)
        try await store.appendCorrection(second)
        #expect(try await store.loadCorrections() == [first, second])
    }
}
