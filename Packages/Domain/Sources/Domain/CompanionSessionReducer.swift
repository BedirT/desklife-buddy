import Foundation

/// What one reducer application observed: a first sighting, or a replay.
public enum CompanionSessionEffect: Equatable, Hashable, Sendable {
    /// The envelope was new and merged into state.
    case delivered(CompanionSessionEnvelope)
    /// The envelope was already merged; state did not move.
    case duplicate(UUID)
}

/// The order-independent convergent session reducer (Epic 4 wave 1).
///
/// State is associate-only observations: a per-sender high-water sequence
/// plus the grow-only set of envelopes keyed by message ID. Merging is
/// insertion into that set and a per-sender max — both commutative and
/// idempotent — so every arrival permutation of the same batch converges
/// to equal state, and duplicates never double-apply.
///
/// Phones never mutate Mac clocks through this reducer: applying an
/// envelope records what a peer reported; Mac clock ledgers are not
/// referenced here and cannot move.
public struct CompanionSessionState: Equatable, Sendable {
    /// Highest per-sender sequence observed so far (observation only).
    public private(set) var highWater: [String: UInt64]
    /// Every envelope merged so far, keyed by message ID (grow-only).
    public private(set) var messages: [UUID: CompanionSessionEnvelope]

    /// Starts from no observations.
    public init() {
        self.highWater = [:]
        self.messages = [:]
    }

    /// Merges one envelope: first sightings deliver, replays report duplicates.
    public mutating func apply(_ envelope: CompanionSessionEnvelope) -> CompanionSessionEffect {
        if messages[envelope.messageID] != nil {
            return .duplicate(envelope.messageID)
        }
        messages[envelope.messageID] = envelope
        highWater[envelope.senderDeviceID, default: 0] = max(
            highWater[envelope.senderDeviceID, default: 0],
            envelope.senderSequence
        )
        return .delivered(envelope)
    }

    /// Projects the newest envelope of one kind: highest sender sequence wins,
    /// ties break on message ID, so the projection is arrival-order independent.
    public func latest(kind: CompanionMessageKind) -> CompanionSessionEnvelope? {
        messages.values
            .filter { $0.kind == kind }
            .max { lhs, rhs in
                if lhs.senderSequence != rhs.senderSequence {
                    return lhs.senderSequence < rhs.senderSequence
                }
                return lhs.messageID.uuidString < rhs.messageID.uuidString
            }
    }
}
