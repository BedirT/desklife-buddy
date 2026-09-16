import Domain
import Foundation
import Testing

@testable import CompanionPhone

/// Repair round 1 (issue #74): kill-safe delivery, retry, idempotency,
/// revision discipline, re-pair reset, receive gating, and wire strictness.
/// Each test fails before its fix (compile break or behavior) and pins it after.
@Suite("Phone repair round 1")
@MainActor
struct PhoneRepairTests {
    private static let pairingID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let otherPairingID = UUID(uuidString: "AAAAAAAA-2222-3333-4444-555555555555")!
    private static let phoneID = UUID(uuidString: "22222222-2222-3333-4444-555555555555")!
    private static let macID = UUID(uuidString: "33333333-2222-3333-4444-555555555555")!
    private static let keyA = Data(repeating: 0xA5, count: CompanionPairingCeremony.keyLength)
    private static let keyB = Data(repeating: 0x5A, count: CompanionPairingCeremony.keyLength)
    private static let now = Date(timeIntervalSince1970: 1_786_000_000)

    @MainActor private final class FailingPendingStore: PhonePendingStore {
        var backing = InMemoryPendingStore()
        var failSave = false
        var failClear = false

        enum StoreFailure: Error {
            case saveFailed
            case clearFailed
        }

        init(failSave: Bool = false) {
            self.failSave = failSave
        }

        func load() throws -> PhonePendingSnapshot? {
            try backing.load()
        }

        func save(_ snapshot: PhonePendingSnapshot) throws {
            if failSave {
                throw StoreFailure.saveFailed
            }
            try backing.save(snapshot)
        }

        func clear() throws {
            if failClear {
                throw StoreFailure.clearFailed
            }
            try backing.clear()
        }
    }

    @MainActor private final class TogglingTransport: CompanionTransport {
        var isUp = false
        private(set) var sent: [Data] = []

        func send(_ data: Data, to recipientDeviceID: String?) async throws {
            guard isUp else {
                throw CompanionTransportError.injectedFailure
            }
            sent.append(data)
        }
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

    private func pair(_ model: PhoneBreakSession, pairingID: UUID? = nil, key: Data? = nil) throws {
        let (_, qrText) = try CompanionPairingCeremony.issue(
            pairingID: pairingID ?? Self.pairingID,
            key: key ?? Self.keyA,
            now: Self.now,
        )
        model.scan(qrText)
    }

    @Test("Kill between finish and flush loses nothing: relaunch recovers the same intent")
    func killRelaunchPreservesExactlyOneFact() async throws {
        let store = FailingPendingStore()
        let first = PhoneBreakSession(
            deviceID: Self.phoneID,
            keyStore: InMemoryPhoneKeyStore(),
            pendingStore: store,
            now: { Self.now },
            uuid: { UUID() },
        )
        try pair(first)
        try first.receive(countdownData())
        try first.finish(.completed)
        let intentID = try #require(first.lastIntentMessageID)

        let second = PhoneBreakSession(
            pendingStore: store,
            now: { Self.now },
            uuid: { UUID() },
        )
        #expect(second.phase == .finished(.completed))
        #expect(second.pairingID == Self.pairingID)
        #expect(second.lastIntentMessageID == intentID)
        #expect(second.pendingSends == 1)
        #expect(second.certainty == .remotePending)

        let transport = InMemoryFakeTransport()
        let result = try await second.flush(transport: transport)
        #expect(result.delivered == 1)
        #expect(second.pendingSends == 0)
        let envelope = try CompanionSessionCodec.decode(transport.sent[0].data)
        #expect(envelope.messageID == intentID)
        #expect(envelope.kind == .intent)
        #expect(envelope.senderDeviceID == Self.phoneID.uuidString)
    }

    @Test("Offline finish redelivers on reconnect without duplicating")
    func reconnectFlushes() async throws {
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            now: { Self.now },
            uuid: { UUID() },
        )
        try pair(model)
        try model.receive(countdownData())
        try model.finish(.completed)

        let transport = TogglingTransport()
        let blocked = try await model.flush(transport: transport)
        #expect(blocked.delivered == 0)
        #expect(model.pendingSends == 1)

        transport.isUp = true
        let delivered = try await model.flush(transport: transport)
        #expect(delivered.delivered == 1)
        #expect(model.pendingSends == 0)
        #expect(transport.sent.count == 1)
    }

    @Test("Double finish enqueues exactly one intent and keeps the first claim")
    func doubleFinishEnqueuesOne() throws {
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            now: { Self.now },
            uuid: { UUID() },
        )
        try pair(model)
        try model.receive(countdownData())
        try model.finish(.completed)
        let intentID = try #require(model.lastIntentMessageID)

        try model.finish(.skipped)

        #expect(model.phase == .finished(.completed))
        #expect(model.lastIntentMessageID == intentID)
        #expect(model.pendingSends == 1)
        let settlement = try #require(model.lastSettlement)
        #expect(settlement.productFacts.count == 1)
        #expect(settlement.losers.isEmpty)
    }

    @Test("An equal-revision rebroadcast preserves elapsed instead of rewinding")
    func equalRevisionPreservesElapsed() throws {
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            now: { Self.now },
            uuid: { UUID() },
        )
        try pair(model)
        try model.receive(countdownData(originRevision: 7, sequence: 1))
        model.advance(by: 60)
        try model.receive(countdownData(originRevision: 7, sequence: 2))

        #expect(model.remaining == 240)
    }

    @Test("Post-finish countdowns never overwrite the latched deadline")
    func postFinishLatchesDeadline() throws {
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            now: { Self.now },
            uuid: { UUID() },
        )
        try pair(model)
        try model.receive(countdownData(originRevision: 7, sequence: 1))
        try model.finish(.completed)
        try model.receive(countdownData(totalTicks: 900, originRevision: 8, sequence: 2))

        #expect(model.phase == .finished(.completed))
        #expect(model.deadline?.totalTicks == 300)
    }

    @Test("Re-pairing to a different pairing lands on paired with a clean slate")
    func repairSetsPaired() throws {
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            now: { Self.now },
            uuid: { UUID() },
        )
        try pair(model)
        try model.receive(countdownData())
        try pair(model, pairingID: Self.otherPairingID, key: Self.keyB)

        #expect(model.phase == .paired)
        #expect(model.pairingID == Self.otherPairingID)
        #expect(model.deadline == nil)
        #expect(model.remaining == nil)
        #expect(model.pendingSends == 0)
    }

    @Test("Pre-pair bytes are gated: nothing seeds the session before pairing")
    func receiveGatedUnpaired() throws {
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            now: { Self.now },
            uuid: { UUID() },
        )
        try model.receive(countdownData())

        #expect(model.droppedEnvelopes == 1)
        #expect(model.deadline == nil)
        #expect(model.phase == .unpaired)

        try pair(model)
        #expect(model.phase == .paired)
        #expect(model.deadline == nil)
    }

    @Test("A QR key with the wrong length never pairs")
    func shortKeyRejected() throws {
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            now: { Self.now },
            uuid: { UUID() },
        )
        let shortKey = Data("short".utf8).base64EncodedString()
        model.scan(
            "{\"generation\":0,\"issuedAt\":1786000000,"
                + "\"pairingID\":\"11111111-2222-3333-4444-555555555555\","
                + "\"symmetricKey\":\"\(shortKey)\",\"version\":1}",
        )

        #expect(model.phase == .unpaired)
        #expect(model.pairingID == nil)
        #expect(model.pairingError == .invalidQR)
    }

    @Test("Out-of-range wire countdowns are dropped without moving state")
    func absurdTotalTicksDropped() throws {
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            now: { Self.now },
            uuid: { UUID() },
        )
        try pair(model)
        try model.receive(countdownData(totalTicks: -5, sequence: 1))
        try model.receive(countdownData(totalTicks: 1e300, sequence: 2))

        #expect(model.droppedEnvelopes == 2)
        #expect(model.deadline == nil)
        #expect(model.phase == .paired)
    }

    @Test("A persist failure surfaces instead of pretending the intent is safe")
    func persistFailureThrows() throws {
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            pendingStore: FailingPendingStore(failSave: true),
            now: { Self.now },
            uuid: { UUID() },
        )
        try pair(model)
        try model.receive(countdownData())

        #expect(throws: FailingPendingStore.StoreFailure.self) {
            try model.finish(.completed)
        }
        // Persist runs before enqueue: the throw left no orphaned intent
        // behind and no half-finished state, so a later retry cannot duplicate.
        #expect(model.pendingSends == 0)
        #expect(model.lastIntentMessageID == nil)
        #expect(model.phase == .countingDown)
        #expect(model.certainty == .localPending)
    }

    @Test("A nil App Group suite fails loud instead of running non-durable")
    func nilSuiteThrowsSuiteUnavailable() {
        #expect(throws: PhonePendingStoreError.suiteUnavailable) {
            _ = try PhonePendingStoreError.requireSuite(nil)
        }
    }

    @Test("A resolved suite passes the fail-loud guard through")
    func resolvedSuitePassesGuard() throws {
        let defaults = try PhonePendingStoreError.requireSuite(.standard)
        #expect(defaults == .standard)
    }

    @Test("A clear failure on drain re-queues instead of vanishing the intent")
    func clearFailureRequeues() async throws {
        let store = FailingPendingStore()
        let model = PhoneBreakSession(
            deviceID: Self.phoneID,
            pendingStore: store,
            now: { Self.now },
            uuid: { UUID() },
        )
        try pair(model)
        try model.receive(countdownData())
        try model.finish(.completed)
        store.failClear = true

        do {
            _ = try await model.flush(transport: InMemoryFakeTransport())
            Issue.record("expected the failed durable clear to throw")
        } catch {
            #expect(error is FailingPendingStore.StoreFailure)
        }
        #expect(model.pendingSends == 1)
    }
}
