import Domain
import Foundation

/// Closed phase hints the phone accepts inside a `.countdown` payload.
///
/// The Mac owns the clocks; the hint only selects countdown copy, never
/// behavior. Unknown hints throw instead of defaulting.
public enum PhonePhaseHint: String, Codable, Hashable, Sendable, CaseIterable {
    /// A break window is running on the Mac.
    case breakWindow
    /// The next break is armed but not running.
    case armed
    /// The session is in recovery after a break.
    case recovering
}

/// The portable countdown snapshot the phone accepts on the wire.
///
/// Mirrors the Domain portable-time contract: duration + wall anchor +
/// revision. The wall anchor is audit context only — the phone derives its
/// countdown from its own monotonic elapsed count, never from this date.
public struct PortableCountdownSnapshot: Codable, Hashable, Sendable {
    /// Portable countdown length, owned by the Mac session.
    public let totalTicks: TimeInterval
    /// Wall anchor for audit display only; never reconstructed into countdown time.
    public let originWall: Date
    /// Session revision this snapshot belongs to; older revisions are stale.
    public let originRevision: UInt64
    /// Which countdown copy to show.
    public let phaseHint: PhonePhaseHint

    public init(totalTicks: TimeInterval, originWall: Date, originRevision: UInt64, phaseHint: PhonePhaseHint) {
        self.totalTicks = totalTicks
        self.originWall = originWall
        self.originRevision = originRevision
        self.phaseHint = phaseHint
    }

    /// Encodes with the session's date strategy so Mac and phone byte-agree.
    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self)
    }

    /// Decodes strictly: unknown phase hints and malformed dates throw.
    public static func decode(_ data: Data) throws -> PortableCountdownSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(PortableCountdownSnapshot.self, from: data)
    }
}
/// Wire errors the phone refuses to default past.
public enum PhoneWireError: Error, Equatable, Hashable, Sendable {
    /// A terminal intent carrying a claim outside the closed set.
    case unknownClaim(String)
}

/// The single terminal intent the phone sends back to the Mac.
///
/// One action, one claim; the Mac reconciles it through the one
/// `CompanionTerminalReconciliation` path and commits at most one fact.
/// The claim travels as its raw string so unknown claims throw in
/// `toAction` instead of decoding into a default.
public struct TerminalIntentPayload: Codable, Hashable, Sendable {
    public let actionID: UUID
    public let deviceID: String
    public let counter: UInt64
    public let claimRaw: String
    public let originRevision: UInt64

    public init(action: CompanionTerminalAction) {
        self.actionID = action.id
        self.deviceID = action.deviceID
        self.counter = action.counter
        self.claimRaw = action.claim.rawValue
        self.originRevision = action.originRevision
    }

    /// Builds the action this payload carries, refusing open claims.
    public func toAction() throws -> CompanionTerminalAction {
        guard let claim = CompanionTerminalClaim(rawValue: claimRaw) else {
            throw PhoneWireError.unknownClaim(claimRaw)
        }
        return CompanionTerminalAction(
            id: actionID,
            deviceID: deviceID,
            counter: counter,
            claim: claim,
            originRevision: originRevision,
        )
    }

    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> TerminalIntentPayload {
        try JSONDecoder().decode(TerminalIntentPayload.self, from: data)
    }
}

/// A settlement receipt: the Mac acknowledging one phone intent.
///
/// Receipts carry the acked envelope message ID so the phone only leaves
/// `remotePending` for the intent that was actually acknowledged.
public struct PhoneReceiptPayload: Codable, Hashable, Sendable {
    /// The `.intent` envelope message ID being acknowledged.
    public let messageID: UUID

    public init(messageID: UUID) {
        self.messageID = messageID
    }

    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> PhoneReceiptPayload {
        try JSONDecoder().decode(PhoneReceiptPayload.self, from: data)
    }
}
