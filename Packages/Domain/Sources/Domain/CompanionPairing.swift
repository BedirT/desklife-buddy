import Foundation

/// The QR pairing ceremony's pure state machine (Epic 4 wave 1, owner gates Q2/Q6).
///
/// Pairing shares one symmetric key via a Mac-shown QR code the phone scans.
/// Re-pair rotates the key (new key, generation bump, old key dies);
/// unpair revokes it (no key verifies). Keys and time enter through
/// parameters so tests pin them; production generates key bytes in the
/// platform adapter and passes them in. Keychain persistence lives in the
/// platform adapter (`App/Companion/CompanionKeychainStore.swift`), not here.
public struct CompanionPairingState: Equatable, Hashable, Sendable {
    /// Stable pairing identity across rotations; revocation ends it.
    public let pairingID: UUID
    /// Bumps by one on every rotation; issue starts at zero.
    public let generation: UInt64
    /// The currently valid symmetric key (32 bytes).
    public let key: Data
    /// Set by unpair; a revoked state verifies nothing.
    public let revoked: Bool
}

/// The text payload carried by the pairing QR code (versioned JSON).
public struct CompanionQRPayload: Equatable, Hashable, Sendable, Codable {
    public let version: Int
    public let pairingID: UUID
    public let symmetricKey: Data
    public let generation: UInt64
    public let issuedAt: Date

    private enum CodingKeys: String, CodingKey {
        case version
        case pairingID
        case symmetricKey
        case generation
        case issuedAt
    }

    /// Decodes QR text, throwing on unknown versions instead of defaulting.
    public static func decode(_ text: String) throws -> CompanionQRPayload {
        guard let data = text.data(using: .utf8) else {
            throw CompanionSessionError.invalidQRText
        }
        struct VersionProbe: Decodable {
            let version: Int
        }
        let probe = try JSONDecoder().decode(VersionProbe.self, from: data)
        guard probe.version == CompanionPairingCeremony.qrSchemaVersion else {
            throw CompanionSessionError.unknownSchemaVersion(probe.version)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(CompanionQRPayload.self, from: data)
    }

    /// Encodes this payload as deterministic QR text.
    public func encode() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}

/// Pure issue / rotate / revoke transitions plus key verification.
public enum CompanionPairingCeremony {
    /// The only QR schema version this build reads or writes.
    public static let qrSchemaVersion = 1
    /// Symmetric key length in bytes (256-bit scope).
    public static let keyLength = 32

    /// Issues a fresh pairing: generation zero, unrevoked, with QR text.
    public static func issue(
        pairingID: UUID = UUID(),
        key: Data,
        now: Date
    ) throws -> (state: CompanionPairingState, qrText: String) {
        try checkedKey(key)
        let state = CompanionPairingState(
            pairingID: pairingID,
            generation: 0,
            key: key,
            revoked: false
        )
        return (state, try qrText(for: state, now: now))
    }

    /// Re-pairs: new key, generation + 1, unrevoked, with fresh QR text.
    /// The old key stops verifying the moment this returns.
    public static func rotate(
        _ state: CompanionPairingState,
        key: Data,
        now: Date
    ) throws -> (state: CompanionPairingState, qrText: String) {
        try checkedKey(key)
        let next = CompanionPairingState(
            pairingID: state.pairingID,
            generation: state.generation + 1,
            key: key,
            revoked: false
        )
        return (next, try qrText(for: next, now: now))
    }

    /// Unpairs: marks revoked; no key verifies afterwards.
    public static func revoke(_ state: CompanionPairingState) -> CompanionPairingState {
        CompanionPairingState(
            pairingID: state.pairingID,
            generation: state.generation,
            key: state.key,
            revoked: true
        )
    }

    /// Whether this key is the live one: exact bytes and not revoked.
    public static func verifies(_ state: CompanionPairingState, key: Data) -> Bool {
        !state.revoked && state.key == key
    }

    private static func qrText(for state: CompanionPairingState, now: Date) throws -> String {
        try CompanionQRPayload(
            version: qrSchemaVersion,
            pairingID: state.pairingID,
            symmetricKey: state.key,
            generation: state.generation,
            issuedAt: now
        ).encode()
    }

    private static func checkedKey(_ key: Data) throws {
        guard key.count == keyLength else {
            throw CompanionSessionError.invalidKeyLength(key.count)
        }
    }
}
