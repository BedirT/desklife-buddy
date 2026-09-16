import Foundation
import Testing
@testable import Domain

/// Epic 4 closeout Step 3: version and robustness gates.
@Suite("Companion version and robustness")
struct CompanionRobustnessTests {
    private static let phone = "11111111-1111-1111-1111-111111111111"
    private static let mac = "22222222-2222-2222-2222-222222222222"
    private static let t0 = Date(timeIntervalSince1970: 1_786_000_000)

    @Test("Unknown envelope versions refuse instead of defaulting")
    func unknownVersionRefuses() throws {
        let envelope = try CompanionSessionEnvelope(
            senderDeviceID: Self.phone,
            senderSequence: 1,
            issuedAt: Self.t0,
            kind: .countdown,
        )
        let data = try CompanionSessionCodec.encode(envelope)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("envelope must encode as a JSON object")
            return
        }
        json["schemaVersion"] = 999
        let tampered = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: CompanionSessionError.unknownSchemaVersion(999)) {
            try CompanionSessionCodec.decode(tampered)
        }
    }

    @Test("Unknown message kinds refuse instead of defaulting")
    func unknownKindRefuses() throws {
        let envelope = try CompanionSessionEnvelope(
            senderDeviceID: Self.phone,
            senderSequence: 1,
            issuedAt: Self.t0,
            kind: .countdown,
        )
        let data = try CompanionSessionCodec.encode(envelope)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("envelope must encode as a JSON object")
            return
        }
        json["kind"] = "mindRead"
        let tampered = try JSONSerialization.data(withJSONObject: json)
        do {
            _ = try CompanionSessionCodec.decode(tampered)
            Issue.record("decode must refuse open kinds")
        } catch let error as CompanionSessionError {
            #expect(error == .unknownKind("mindRead"))
        }
    }

    @Test("Revoked pairings verify nothing; rotation kills the old key")
    func revokedPairingRejects() throws {
        let key = Data(repeating: 0xA5, count: CompanionPairingCeremony.keyLength)
        let (issued, _) = try CompanionPairingCeremony.issue(key: key, now: Self.t0)
        #expect(CompanionPairingCeremony.verifies(issued, key: key))
        let rotatedKey = Data(repeating: 0x5A, count: CompanionPairingCeremony.keyLength)
        let (rotated, _) = try CompanionPairingCeremony.rotate(issued, key: rotatedKey, now: Self.t0)
        #expect(!CompanionPairingCeremony.verifies(rotated, key: key))
        #expect(CompanionPairingCeremony.verifies(rotated, key: rotatedKey))
        let revoked = CompanionPairingCeremony.revoke(rotated)
        #expect(!CompanionPairingCeremony.verifies(revoked, key: rotatedKey))
    }

    @Test("Stale sequences never move the high-water mark backward")
    func staleSequenceHandled() throws {
        var state = CompanionSessionState()
        let fresh = try CompanionSessionEnvelope(
            senderDeviceID: Self.phone,
            senderSequence: 9,
            issuedAt: Self.t0,
            kind: .countdown,
        )
        let stale = try CompanionSessionEnvelope(
            senderDeviceID: Self.phone,
            senderSequence: 3,
            issuedAt: Self.t0,
            kind: .countdown,
        )
        _ = state.apply(fresh)
        _ = state.apply(stale)
        #expect(state.highWater[Self.phone] == 9)
        #expect(state.messages.count == 2)
    }

    @Test("Watch traffic travels only as a phone-addressed relay hop")
    func watchOnlyViaPhoneRelay() throws {
        do {
            _ = try CompanionSessionEnvelope(
                senderDeviceID: Self.mac,
                senderSequence: 1,
                issuedAt: Self.t0,
                kind: .phase,
                recipientDeviceID: nil,
                relay: .watchViaPhone,
            )
            Issue.record("broadcast watch relay must refuse")
        } catch let error as CompanionSessionError {
            #expect(error == .invalidRelay("watchViaPhone needs a phone recipient"))
        }
        // Phone-addressed relay stays legal.
        _ = try CompanionSessionEnvelope(
            senderDeviceID: Self.mac,
            senderSequence: 2,
            issuedAt: Self.t0,
            kind: .phase,
            recipientDeviceID: Self.phone,
            relay: .watchViaPhone,
        )
    }
}
