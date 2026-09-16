import Domain
import Foundation
import Testing

@testable import CompanionPhone

/// Story B (issue #74) red-first: phone scans QR, pairs, runs a portable
/// countdown, reconciles terminally, and delivers exactly one fact through
/// the outbox. Written before `PhoneBreakSession` exists.
@Suite("Phone break session")
@MainActor
struct PhoneBreakSessionTests {
    private static let pairingID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let phoneID = UUID(uuidString: "22222222-2222-3333-4444-555555555555")!
    private static let macID = UUID(uuidString: "33333333-2222-3333-4444-555555555555")!
    private static let keyA = Data(repeating: 0xA5, count: CompanionPairingCeremony.keyLength)
    private static let now = Date(timeIntervalSince1970: 1_786_000_000)

    /// Reference-shared wrapper: the in-memory key store is a struct, so a
    /// bare copy would hide the session's saves from the test's handle.
    @MainActor private final class SharedKeyStore: PhoneKeyStoring {
        var backing = InMemoryPhoneKeyStore()

        func save(_ key: Data, pairingID: UUID) throws {
            try backing.save(key, pairingID: pairingID)
        }

        func load(pairingID: UUID) throws -> Data {
            try backing.load(pairingID: pairingID)
        }

        func delete(pairingID: UUID) throws {
            try backing.delete(pairingID: pairingID)
        }
    }

    private func makeModel() -> (PhoneBreakSession, SharedKeyStore) {
        let store = SharedKeyStore()
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            keyStore: store,
            now: { Self.now },
            uuid: { UUID() },
        )
        return (model, store)
    }

    private func countdownData(
        totalTicks: TimeInterval = 300,
        originRevision: UInt64 = 7,
        sequence: UInt64 = 1,
    ) throws -> Data {
        let snapshot = PortableCountdownSnapshot(
            totalTicks: totalTicks,
            originWall: Self.now,
            originRevision: originRevision,
            phaseHint: .breakWindow,
        )
        let envelope = try CompanionSessionEnvelope(
            senderDeviceID: Self.macID.uuidString,
            senderSequence: sequence,
            issuedAt: Self.now,
            kind: .countdown,
            payload: snapshot.encode(),
        )
        return try CompanionSessionCodec.encode(envelope)
    }

    private func pair(_ model: PhoneBreakSession) throws {
        let (_, qrText) = try CompanionPairingCeremony.issue(
            pairingID: Self.pairingID,
            key: Self.keyA,
            now: Self.now,
        )
        model.scan(qrText)
    }

    @Test("Scanning the Mac QR decodes the ceremony payload and pairs")
    func qrDecodePairsSession() throws {
        let (model, store) = makeModel()
        try pair(model)

        #expect(model.phase == .paired)
        #expect(model.pairingID == Self.pairingID)
        #expect(model.pairingError == nil)
        #expect(try store.load(pairingID: Self.pairingID) == Self.keyA)
    }

    @Test("A QR payload with an unknown version throws instead of pairing")
    func unknownQRVersionThrows() throws {
        let (model, _) = makeModel()
        let (_, qrText) = try CompanionPairingCeremony.issue(
            pairingID: Self.pairingID,
            key: Self.keyA,
            now: Self.now,
        )
        model.scan(qrText.replacingOccurrences(of: "\"version\":1", with: "\"version\":999"))

        #expect(model.phase == .unpaired)
        #expect(model.pairingID == nil)
        #expect(model.pairingError == .unsupportedVersion)
    }

    @Test("The countdown is monotonic, clamped, and never negative")
    func countdownIsMonotonicAndClamped() throws {
        let (model, _) = makeModel()
        try pair(model)
        try model.receive(countdownData())

        #expect(model.phase == .countingDown)
        #expect(model.remaining == 300)
        model.advance(by: 120)
        #expect(model.remaining == 180)
        #expect(!model.isOverdue)
        model.advance(by: 400)
        #expect(model.remaining == 0)
        #expect(model.isOverdue)
    }

    @Test("A stale revision never moves the countdown backward")
    func staleRevisionIgnored() throws {
        let (model, _) = makeModel()
        try pair(model)
        try model.receive(countdownData(originRevision: 7, sequence: 1))
        model.advance(by: 60)
        try model.receive(countdownData(originRevision: 5, sequence: 2))

        #expect(model.remaining == 240)
    }

    @Test("Finishing reconciles to exactly one product fact in the outbox")
    func reconcileYieldsExactlyOneFact() throws {
        let (model, _) = makeModel()
        try pair(model)
        try model.receive(countdownData())

        try model.finish(.completed)

        #expect(model.phase == .finished(.completed))
        let settlement = try #require(model.lastSettlement)
        #expect(settlement.productFacts.count == 1)
        #expect(model.pendingSends == 1)
        #expect(model.certainty == .remotePending)
        #expect(!model.certainty.claimsReceipt)
    }

    @Test("A failed flush keeps every entry in order for retry")
    func outboxKeepsOrderAcrossFailedFlush() async throws {
        let (model, _) = makeModel()
        try pair(model)
        try model.receive(countdownData())
        try model.finish(.completed)

        let failing = InMemoryFakeTransport()
        failing.failNextSends = 10
        let blocked = try await model.flush(transport: failing)
        #expect(blocked.delivered == 0)
        #expect(blocked.remaining == 1)
        #expect(model.pendingSends == 1)

        let retry = try await model.flush(transport: InMemoryFakeTransport())
        #expect(retry.delivered == 1)
        #expect(retry.remaining == 0)
        #expect(model.pendingSends == 0)
    }

    @Test("Certainty never claims receipt before a matching transport ack")
    func certaintyNeverClaimsReceiptBeforeAck() throws {
        let (model, _) = makeModel()
        try pair(model)
        #expect(model.certainty == .localPending)
        try model.receive(countdownData())
        #expect(model.certainty == .localPending)
        try model.finish(.skipped)
        #expect(model.certainty == .remotePending)
        #expect(!model.certainty.claimsReceipt)

        let stranger = try CompanionSessionEnvelope(
            senderDeviceID: Self.macID.uuidString,
            senderSequence: 9,
            issuedAt: Self.now,
            kind: .receipt,
            payload: PhoneReceiptPayload(messageID: UUID()).encode(),
        )
        try model.receive(CompanionSessionCodec.encode(stranger))
        #expect(model.certainty == .remotePending)

        let ackedID = try #require(model.lastIntentMessageID)
        let ack = try CompanionSessionEnvelope(
            senderDeviceID: Self.macID.uuidString,
            senderSequence: 10,
            issuedAt: Self.now,
            kind: .receipt,
            payload: PhoneReceiptPayload(messageID: ackedID).encode(),
        )
        try model.receive(CompanionSessionCodec.encode(ack))
        #expect(model.certainty == .acknowledged)
        #expect(model.certainty.claimsReceipt)
    }

    @Test("Undecodable bytes are dropped without moving state")
    func undecodableBytesDropped() throws {
        let (model, _) = makeModel()
        try pair(model)
        model.receive(Data("not-a-session-envelope".utf8))

        #expect(model.droppedEnvelopes == 1)
        #expect(model.phase == .paired)
        #expect(model.remaining == nil)
    }
}
