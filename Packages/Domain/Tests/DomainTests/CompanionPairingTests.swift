import Foundation
import Testing
@testable import Domain

/// Epic 4 wave 1 RED-first: the QR pairing ceremony must rotate the shared
/// key on re-pair (old key dies) and revoke it on unpair. Written before the
/// ceremony existed, so every test below failed on the unguarded base.
@Suite("Companion QR pairing ceremony")
struct CompanionPairingTests {
    private static let t0 = Date(timeIntervalSince1970: 1_786_000_000)
    private static let keyA = Data(repeating: 0xA5, count: 32)
    private static let keyB = Data(repeating: 0x5A, count: 32)

    @Test("Issued pairing verifies with its own key and round-trips its QR text")
    func issueVerifiesAndRoundTripsQR() throws {
        let (state, qrText) = try CompanionPairingCeremony.issue(key: Self.keyA, now: Self.t0)

        #expect(CompanionPairingCeremony.verifies(state, key: Self.keyA))
        #expect(!CompanionPairingCeremony.verifies(state, key: Self.keyB))
        #expect(try CompanionQRPayload.decode(qrText).symmetricKey == Self.keyA)
    }

    @Test("Re-pair rotates the key: generation bumps and the old key stops verifying")
    func repairRotatesKey() throws {
        let (first, _) = try CompanionPairingCeremony.issue(key: Self.keyA, now: Self.t0)
        let (second, secondQR) = try CompanionPairingCeremony.rotate(first, key: Self.keyB, now: Self.t0)

        #expect(second.generation == first.generation + 1)
        #expect(second.pairingID == first.pairingID)
        #expect(CompanionPairingCeremony.verifies(second, key: Self.keyB))
        #expect(!CompanionPairingCeremony.verifies(second, key: Self.keyA))
        #expect(try CompanionQRPayload.decode(secondQR).symmetricKey == Self.keyB)
        #expect(try CompanionQRPayload.decode(secondQR).generation == second.generation)
    }

    @Test("Unpair revokes: no key verifies afterwards")
    func unpairRevokes() throws {
        let (issued, _) = try CompanionPairingCeremony.issue(key: Self.keyA, now: Self.t0)
        let revoked = CompanionPairingCeremony.revoke(issued)

        #expect(revoked.revoked)
        #expect(!CompanionPairingCeremony.verifies(revoked, key: Self.keyA))
        #expect(!CompanionPairingCeremony.verifies(revoked, key: Self.keyB))
    }

    @Test("A QR payload with an unknown version throws instead of defaulting")
    func unknownQRVersionThrows() throws {
        let (_, qrText) = try CompanionPairingCeremony.issue(key: Self.keyA, now: Self.t0)
        let tampered = qrText.replacingOccurrences(of: "\"version\":1", with: "\"version\":999")
        #expect(throws: CompanionSessionError.self) {
            try CompanionQRPayload.decode(tampered)
        }
    }
}
