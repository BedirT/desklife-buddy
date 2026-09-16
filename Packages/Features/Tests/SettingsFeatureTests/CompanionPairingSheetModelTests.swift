import Domain
import Foundation
import Testing
@testable import SettingsFeature

/// Mac pairing QR-sheet model (Story A, issue #74), RED-first.
///
/// The sheet renders the live ceremony `qrText`: every transition below runs
/// through `CompanionPairingCeremony`, and the QR text is asserted by
/// round-tripping it through `CompanionQRPayload.decode`, never by comparing
/// against a fixture string. Key bytes, time, and pairing IDs enter through
/// injected closures so the model never calls `Date()`/`UUID()`/randomness
/// itself; persistence enters through throwing closures so Keychain failures
/// surface as the failed phase instead of defaulting past.
@Suite("Companion pairing sheet model")
@MainActor
struct CompanionPairingSheetModelTests {
    private static let pairingID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let keyA = Data(repeating: 0xA5, count: CompanionPairingCeremony.keyLength)
    private static let keyB = Data(repeating: 0x5A, count: CompanionPairingCeremony.keyLength)
    private static let now = Date(timeIntervalSince1970: 1_786_000_000)

    private func makeModel(
        keys: [Data] = [keyA, keyB],
        events: PairingEvents = PairingEvents(),
    ) -> (CompanionPairingSheetModel, KeyBox) {
        let box = KeyBox(keys: keys)
        let model = CompanionPairingSheetModel(
            keyGenerator: { box.next() },
            now: { Self.now },
            pairingIDGenerator: { Self.pairingID },
            onPersist: { try events.didPersist($0) },
            onRevoke: { events.didRevoke($0) },
        )
        return (model, box)
    }

    @Test("Prepare issues a live code bound to the ceremony QR text")
    func prepareIssuesLiveCode() throws {
        let events = PairingEvents()
        let (model, _) = makeModel(events: events)
        #expect(model.phase == .loading)

        model.prepare()

        #expect(model.phase == .showingCode)
        let qrText = try #require(model.qrText)
        let payload = try CompanionQRPayload.decode(qrText)
        #expect(payload.pairingID == Self.pairingID)
        #expect(payload.symmetricKey == Self.keyA)
        #expect(payload.generation == 0)
        #expect(payload.version == CompanionPairingCeremony.qrSchemaVersion)
        #expect(events.saved.count == 1)
        #expect(events.saved[0].pairingID == Self.pairingID)
        #expect(CompanionPairingCeremony.verifies(events.saved[0], key: Self.keyA))
    }

    @Test("Prepare keeps the live code instead of issuing twice")
    func prepareIsIdempotent() throws {
        let (model, box) = makeModel()
        model.prepare()
        let firstQR = try #require(model.qrText)

        model.prepare()

        #expect(model.phase == .showingCode)
        #expect(model.qrText == firstQR)
        #expect(box.issuedCount == 1)
    }

    @Test("Regenerate rotates the key and clears the paired mark")
    func regenerateRotatesKey() throws {
        let events = PairingEvents()
        let (model, _) = makeModel(events: events)
        model.prepare()
        model.notePeerBound(deviceID: "phone-device-uuid")
        #expect(model.phase == .paired)

        model.regenerate()

        #expect(model.phase == .showingCode)
        #expect(model.boundDeviceID == nil)
        let qrText = try #require(model.qrText)
        let payload = try CompanionQRPayload.decode(qrText)
        #expect(payload.symmetricKey == Self.keyB)
        #expect(payload.generation == 1)
        #expect(events.saved.count == 2)
        #expect(CompanionPairingCeremony.verifies(events.saved[1], key: Self.keyB))
        #expect(!CompanionPairingCeremony.verifies(events.saved[1], key: Self.keyA))
    }

    @Test("Regenerate without a live code issues a fresh one")
    func regenerateWithoutCodeIssues() throws {
        let (model, _) = makeModel()
        model.regenerate()
        #expect(model.phase == .showingCode)
        let payload = try CompanionQRPayload.decode(#require(model.qrText))
        #expect(payload.generation == 0)
    }

    @Test("Unpair revokes through the ceremony and clears the code")
    func unpairRevokes() throws {
        let events = PairingEvents()
        let (model, _) = makeModel(events: events)
        model.prepare()

        model.unpair()

        #expect(model.phase == .unpaired)
        #expect(model.qrText == nil)
        #expect(model.boundDeviceID == nil)
        #expect(events.revoked.count == 1)
        #expect(events.revoked[0].revoked)
        #expect(!CompanionPairingCeremony.verifies(events.revoked[0], key: Self.keyA))
    }

    @Test("Prepare after unpair issues a fresh code")
    func prepareAfterUnpairIssuesFresh() throws {
        let (model, box) = makeModel()
        model.prepare()
        model.unpair()

        model.prepare()

        #expect(model.phase == .showingCode)
        #expect(try CompanionQRPayload.decode(#require(model.qrText)).generation == 0)
        #expect(box.issuedCount == 2)
    }

    @Test("Noting a bound peer marks the sheet paired")
    func boundPeerMarksPaired() throws {
        let (model, _) = makeModel()
        model.prepare()

        model.notePeerBound(deviceID: "phone-device-uuid")

        #expect(model.phase == .paired)
        #expect(model.boundDeviceID == "phone-device-uuid")
        #expect(model.qrText != nil)
    }

    @Test("Key-generation failure surfaces the failed phase and retry recovers")
    func keyFailureThenRetry() throws {
        let box = KeyBox(keys: [], fallback: Self.keyA)
        let model = CompanionPairingSheetModel(
            keyGenerator: { try box.nextOrThrow() },
            now: { Self.now },
            pairingIDGenerator: { Self.pairingID },
            onPersist: { _ in },
            onRevoke: { _ in },
        )

        model.prepare()
        #expect(model.phase == .failed)
        #expect(model.qrText == nil)

        box.keys = [Self.keyA]
        model.retry()
        #expect(model.phase == .showingCode)
        #expect(model.qrText != nil)
    }

    @Test("Persist failure surfaces the failed phase and retry restores the code")
    func persistFailureThenRetry() throws {
        let events = PairingEvents()
        events.shouldThrowOnPersist = true
        let (model, _) = makeModel(events: events)
        model.prepare()
        #expect(model.phase == .failed)

        events.shouldThrowOnPersist = false
        model.retry()
        #expect(model.phase == .showingCode)
        #expect(try CompanionQRPayload.decode(#require(model.qrText)).generation == 0)
    }

    @Test("Regenerate failure keeps the previous live code")
    func regenerateFailureKeepsPreviousCode() throws {
        let box = KeyBox(keys: [Self.keyA])
        let model = CompanionPairingSheetModel(
            keyGenerator: { try box.nextOrThrow() },
            now: { Self.now },
            pairingIDGenerator: { Self.pairingID },
            onPersist: { _ in },
            onRevoke: { _ in },
        )
        model.prepare()
        let firstQR = try #require(model.qrText)

        model.regenerate()

        #expect(model.phase == .failed)
        #expect(model.qrText == firstQR)
        #expect(try CompanionQRPayload.decode(#require(model.qrText)).symmetricKey == Self.keyA)
    }

    @Test("Unpair failure retries the revoke instead of re-pairing")
    func unpairFailureRetriesRevoke() throws {
        let events = PairingEvents()
        events.revokeFailuresRemaining = 1
        let (model, box) = makeModel(events: events)
        model.prepare()
        let issuedCount = box.issuedCount

        model.unpair()
        #expect(model.phase == .failed)
        #expect(model.qrText != nil)
        #expect(events.revoked.isEmpty)

        model.retry()

        #expect(model.phase == .unpaired)
        #expect(model.qrText == nil)
        #expect(events.revoked.count == 1)
        #expect(events.revoked[0].revoked)
        #expect(!CompanionPairingCeremony.verifies(events.revoked[0], key: Self.keyA))
        #expect(box.issuedCount == issuedCount)
    }
}

/// Sink for the model's persistence side effects. A class (not captured
/// locals) so `@Sendable` closures stay legal under Swift 6 isolation.
private final class PairingEvents: @unchecked Sendable {
    var saved: [CompanionPairingState] = []
    var revoked: [CompanionPairingState] = []
    var shouldThrowOnPersist = false
    var revokeFailuresRemaining = 0

    struct PersistFailed: Error {}

    struct RevokeFailed: Error {}

    func didPersist(_ state: CompanionPairingState) throws {
        if shouldThrowOnPersist {
            throw PersistFailed()
        }
        saved.append(state)
    }

    func didRevoke(_ state: CompanionPairingState) throws {
        if revokeFailuresRemaining > 0 {
            revokeFailuresRemaining -= 1
            throw RevokeFailed()
        }
        revoked.append(state)
    }
}

private final class KeyBox: @unchecked Sendable {
    var keys: [Data]
    private let fallback: Data?
    private let keyLength: Int
    private(set) var issuedCount = 0

    /// The default key length reads the ceremony constant at the (MainActor)
    /// call site, keeping the nonisolated methods below isolation-clean.
    init(keys: [Data], fallback: Data? = nil, keyLength: Int = CompanionPairingCeremony.keyLength) {
        self.keys = keys
        self.fallback = fallback
        self.keyLength = keyLength
    }

    func next() -> Data {
        issuedCount += 1
        if !keys.isEmpty {
            return keys.removeFirst()
        }
        return fallback ?? Data(repeating: 0xA5, count: keyLength)
    }

    struct KeyExhausted: Error {}

    func nextOrThrow() throws -> Data {
        guard !keys.isEmpty else { throw KeyExhausted() }
        return next()
    }
}
