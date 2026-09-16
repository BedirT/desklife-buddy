import Foundation

/// Errors the companion session seam refuses to default past.
public enum CompanionSessionError: Error, Equatable, Hashable, Sendable {
    /// An envelope or QR payload carrying an unknown schema version.
    case unknownSchemaVersion(Int)
    /// An envelope carrying a message kind outside the closed vocabulary.
    case unknownKind(String)
    /// A sender identifier that is not a device UUID string.
    case invalidSenderDevice(String)
    /// A pairing key with an unexpected length.
    case invalidKeyLength(Int)
    /// A relay hop without the recipient it must address (watch relays phone-bound only).
    case invalidRelay(String)
    /// A session payload over the wire cap.
    case payloadTooLarge(Int)
    /// QR text that is not decodable UTF-8.
    case invalidQRText
}

///
/// The envelope is association metadata only: identity (message, sender,
/// per-sender sequence), a closed kind, an optional direct recipient, an
/// optional watch-relay hop, and an opaque payload. It carries no clock
/// mutations — phones observe and relay; only the Mac owns its clocks.
public struct CompanionSessionEnvelope: Equatable, Hashable, Sendable, Codable {
    /// Wire cap for the opaque payload: sessions carry hints, never content.
    public static let maximumPayloadBytes = 64 * 1024

    public let schemaVersion: Int
    public let messageID: UUID
    public let senderDeviceID: String
    public let senderSequence: UInt64
    public let issuedAt: Date
    public let kind: CompanionMessageKind
    public let recipientDeviceID: String?
    public let relay: CompanionRelayHop?
    public let payload: Data

    /// Creates an envelope, refusing open kinds, non-device senders, and oversized payloads.
    public init(
        messageID: UUID = UUID(),
        senderDeviceID: String,
        senderSequence: UInt64,
        issuedAt: Date,
        kind: CompanionMessageKind,
        recipientDeviceID: String? = nil,
        relay: CompanionRelayHop? = nil,
        payload: Data = Data(),
    ) throws {
        guard UUID(uuidString: senderDeviceID) != nil else {
            throw CompanionSessionError.invalidSenderDevice(senderDeviceID)
        }
        if let recipientDeviceID {
            guard UUID(uuidString: recipientDeviceID) != nil else {
                throw CompanionSessionError.invalidSenderDevice(recipientDeviceID)
            }
        }
        if relay == .watchViaPhone, recipientDeviceID == nil {
            throw CompanionSessionError.invalidRelay("watchViaPhone needs a phone recipient")
        }
        guard payload.count <= Self.maximumPayloadBytes else {
            throw CompanionSessionError.payloadTooLarge(payload.count)
        }
        schemaVersion = CompanionSessionCodec.schemaVersion
        self.messageID = messageID
        self.senderDeviceID = senderDeviceID
        self.senderSequence = senderSequence
        self.issuedAt = issuedAt
        self.kind = kind
        self.recipientDeviceID = recipientDeviceID
        self.relay = relay
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case messageID
        case senderDeviceID
        case senderSequence
        case issuedAt
        case kind
        case recipientDeviceID
        case relay
        case payload
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == CompanionSessionCodec.schemaVersion else {
            throw CompanionSessionError.unknownSchemaVersion(version)
        }
        let kindRaw = try container.decode(String.self, forKey: .kind)
        guard let kind = CompanionMessageKind(rawValue: kindRaw) else {
            throw CompanionSessionError.unknownKind(kindRaw)
        }
        // Reuse init validation so decoded envelopes meet the same bar as built ones.
        try self.init(
            messageID: container.decode(UUID.self, forKey: .messageID),
            senderDeviceID: container.decode(String.self, forKey: .senderDeviceID),
            senderSequence: container.decode(UInt64.self, forKey: .senderSequence),
            issuedAt: container.decode(Date.self, forKey: .issuedAt),
            kind: kind,
            recipientDeviceID: container.decodeIfPresent(String.self, forKey: .recipientDeviceID),
            relay: container.decodeIfPresent(CompanionRelayHop.self, forKey: .relay),
            payload: container.decode(Data.self, forKey: .payload),
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(messageID, forKey: .messageID)
        try container.encode(senderDeviceID, forKey: .senderDeviceID)
        try container.encode(senderSequence, forKey: .senderSequence)
        try container.encode(issuedAt, forKey: .issuedAt)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encodeIfPresent(recipientDeviceID, forKey: .recipientDeviceID)
        try container.encodeIfPresent(relay, forKey: .relay)
        try container.encode(payload, forKey: .payload)
    }
}

/// The version seam for session envelopes: deterministic encode, strict decode.
public enum CompanionSessionCodec {
    /// The only envelope schema version this build reads or writes.
    public static let schemaVersion = 1

    /// Encodes an envelope with sorted keys so identical envelopes byte-match.
    public static func encode(_ envelope: CompanionSessionEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(envelope)
    }

    /// Decodes an envelope, throwing on unknown versions or open kinds.
    public static func decode(_ data: Data) throws -> CompanionSessionEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(CompanionSessionEnvelope.self, from: data)
    }
}
