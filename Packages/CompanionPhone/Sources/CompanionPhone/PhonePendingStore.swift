import Foundation

/// Durable snapshot of the one unsent terminal intent.
///
/// Delivery is at-least-once: the snapshot survives kill/relaunch, and the
/// Mac-side reducer dedups replays by message ID, so a replayed intent can
/// never double-apply. Together that preserves exactly-one-fact across app
/// death. The snapshot carries NO key material — only IDs, counters, and the
/// codec-encoded intent envelope — so group-shared storage is safe.
public struct PhonePendingSnapshot: Codable, Hashable, Sendable {
    /// Snapshot schema version; readers refuse unknown versions by failing decode.
    public static let schemaVersion = 1

    public let version: Int
    public let pairingID: UUID
    public let generation: UInt64
    public let deviceID: UUID
    public let knownRevision: UInt64?
    public let claimRaw: String
    public let intentMessageID: UUID
    public let intentEnvelope: Data
    public let recipientDeviceID: String?
    public let nextSequence: UInt64
    public let nextCounter: UInt64

    public init(
        pairingID: UUID,
        generation: UInt64,
        deviceID: UUID,
        knownRevision: UInt64?,
        claimRaw: String,
        intentMessageID: UUID,
        intentEnvelope: Data,
        recipientDeviceID: String?,
        nextSequence: UInt64,
        nextCounter: UInt64,
    ) {
        version = Self.schemaVersion
        self.pairingID = pairingID
        self.generation = generation
        self.deviceID = deviceID
        self.knownRevision = knownRevision
        self.claimRaw = claimRaw
        self.intentMessageID = intentMessageID
        self.intentEnvelope = intentEnvelope
        self.recipientDeviceID = recipientDeviceID
        self.nextSequence = nextSequence
        self.nextCounter = nextCounter
    }
}

/// Durable-pending seam: production persists to the App Group, tests and
/// previews stay in memory. No secrets ever enter this store.
public protocol PhonePendingStore: Sendable {
    func load() throws -> PhonePendingSnapshot?
    mutating func save(_ snapshot: PhonePendingSnapshot) throws
    mutating func clear() throws
}

/// Fail-loud durable-pending errors: the App Group suite missing means the
/// intent is NOT durable, so production throws instead of pretending.
public enum PhonePendingStoreError: Error, Equatable, Sendable {
    /// `UserDefaults(suiteName:)` returned nil: the group is missing or the
    /// app is not entitled to it. Saving or loading against `nil` would
    /// silently drop the exactly-one terminal intent.
    case suiteUnavailable

    /// The guard every durable store calls: nil suite throws, a resolved
    /// suite passes through. Pure so the phone test suite pins it directly.
    public static func requireSuite(_ defaults: UserDefaults?) throws -> UserDefaults {
        guard let defaults else { throw suiteUnavailable }
        return defaults
    }
}

/// The in-memory pending store: previews and tests, never production state.
public struct InMemoryPendingStore: PhonePendingStore {
    private var snapshot: PhonePendingSnapshot?

    public init() {}

    public func load() throws -> PhonePendingSnapshot? {
        snapshot
    }

    public mutating func save(_ snapshot: PhonePendingSnapshot) throws {
        self.snapshot = snapshot
    }

    public mutating func clear() throws {
        snapshot = nil
    }
}
