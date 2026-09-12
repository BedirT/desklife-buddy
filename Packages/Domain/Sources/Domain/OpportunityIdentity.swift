import Foundation

/// Versioned action/identity contract for Story 2.3 (D-043 machine-readable
/// `timing_runtime_v2.yaml` identities + protocol §17.5).
///
/// These types wrap raw scheduler values — they migrate, never recast:
/// every `ClockCycleID` carries the exact `UInt64` engine counter and every
/// UUID wrapper encodes lowercase hyphenated RFC 4122 text. Clock effects
/// and facts stay in the existing engine reductions; this file owns
/// identity, leases, generations, and fences only.
public enum ClockCycleScope: String, Codable, Hashable, Sendable, CaseIterable {
    case visual
    case movement
    case position
    case recovery
}

/// Versioned identity for one independent schedule cycle.
///
/// Version 1 migrates the raw `OpportunityClockState.cycleID` counter: the
/// identity is stable through due, heads-up, held, snoozed, running, and
/// relaunch states, and only a fresh-cycle effect advances it.
public struct ClockCycleID: Equatable, Hashable, Sendable {
    /// Contract version of this identity encoding.
    public static let identityVersion: UInt64 = 1

    public let version: UInt64
    public let scope: ClockCycleScope
    public let rawValue: UInt64

    public init(version: UInt64 = ClockCycleID.identityVersion, scope: ClockCycleScope, rawValue: UInt64) {
        self.version = version
        self.scope = scope
        self.rawValue = rawValue
    }

    /// The unstarted counter every scheduler begins with.
    public static func initial(scope: ClockCycleScope) -> ClockCycleID {
        ClockCycleID(scope: scope, rawValue: 0)
    }

    public var isInitial: Bool { rawValue == 0 }

    /// Advances exactly like the engine counter, wrapping instead of trapping.
    public func advanced() -> ClockCycleID {
        ClockCycleID(version: version, scope: scope, rawValue: rawValue &+ 1)
    }

    /// Projects the migrated counter back onto the engine clock.
    public func cycleIDForEngine() -> UInt64 { rawValue }
}

extension ClockCycleID: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case scope
        case rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(UInt64.self, forKey: .version) ?? ClockCycleID.identityVersion
        scope = try container.decode(ClockCycleScope.self, forKey: .scope)
        rawValue = try container.decode(UInt64.self, forKey: .rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(scope, forKey: .scope)
        try container.encode(rawValue, forKey: .rawValue)
    }
}

/// Lowercase hyphenated RFC 4122 text shared by every UUID identity.
func lowercaseUUIDText(_ uuid: UUID) -> String {
    uuid.uuidString.lowercased()
}

/// Identity for one coordinated offer. Created when the arbiter selects one
/// or more due clock cycles; closed when its terminal candidate settles.
public struct OpportunityID: Equatable, Hashable, Sendable {
    public let uuid: UUID

    /// Wraps an injected UUID without generating identity inside the reducer.
    public init(_ uuid: UUID) {
        self.uuid = uuid
    }
}

extension OpportunityID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let uuid = UUID(uuidString: text) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "OpportunityID requires lowercase hyphenated RFC 4122 text",
            )
        }
        self.uuid = uuid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(lowercaseUUIDText(uuid))
    }
}

/// Stable identity for one installation coordinator state. Names the
/// scheduling/evidence state; its monotonically increasing revision is the
/// concurrency identity for commands no single OpportunityID owns.
public struct GlobalStateID: Equatable, Hashable, Sendable {
    public let uuid: UUID

    /// Wraps an injected UUID without generating identity inside the reducer.
    public init(_ uuid: UUID) {
        self.uuid = uuid
    }
}

extension GlobalStateID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let uuid = UUID(uuidString: text) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "GlobalStateID requires lowercase hyphenated RFC 4122 text",
            )
        }
        self.uuid = uuid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(lowercaseUUIDText(uuid))
    }
}

/// Restart-safe causal authority for the coordinator. Not elapsed time: every
/// action and lease names the exact generation it originated in, and a
/// committed generation fence makes all lower-generation actions ineligible.
public struct CoordinatorGeneration: Equatable, Hashable, Comparable, Sendable {
    public let rawValue: UInt64

    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// The generation a fresh coordinator starts in.
    public static let initial = CoordinatorGeneration(0)

    public func advanced() -> CoordinatorGeneration {
        CoordinatorGeneration(rawValue &+ 1)
    }

    public static func < (lhs: CoordinatorGeneration, rhs: CoordinatorGeneration) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension CoordinatorGeneration: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(UInt64.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Identity for one opportunity projection within a coordinator generation.
/// Revoked on every opportunity closure before any successor becomes eligible.
public struct ProjectionEpochID: Equatable, Hashable, Sendable {
    public let uuid: UUID

    /// Wraps an injected UUID without generating identity inside the reducer.
    public init(uuid: UUID) {
        self.uuid = uuid
    }
}

extension ProjectionEpochID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let uuid = UUID(uuidString: text) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "ProjectionEpochID requires lowercase hyphenated RFC 4122 text",
            )
        }
        self.uuid = uuid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(lowercaseUUIDText(uuid))
    }
}

/// Installation-scoped device identity. Locally generated, never vendor or
/// account identity.
public struct DeviceID: Equatable, Hashable, Sendable {
    public let uuid: UUID

    /// Wraps a locally generated UUID without reading vendor identity.
    public init(uuid: UUID) {
        self.uuid = uuid
    }
}

extension DeviceID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let uuid = UUID(uuidString: text) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "DeviceID requires lowercase hyphenated RFC 4122 text",
            )
        }
        self.uuid = uuid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(lowercaseUUIDText(uuid))
    }
}

/// Identity for one user, system, or companion action. A duplicate ActionID
/// replays the original outcome or truthful settlement receipt without
/// reapplying effects.
public struct ActionID: Equatable, Hashable, Sendable {
    public let uuid: UUID
    public let deviceID: DeviceID
    public let counter: UInt64

    /// Creates an action identity from injected origin values only.
    public init(uuid: UUID, deviceID: DeviceID, counter: UInt64) {
        self.uuid = uuid
        self.deviceID = deviceID
        self.counter = counter
    }
}

extension ActionID: Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case deviceID
        case counter
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .uuid)
        guard let uuid = UUID(uuidString: text) else {
            throw DecodingError.dataCorruptedError(
                forKey: .uuid,
                in: container,
                debugDescription: "ActionID requires lowercase hyphenated RFC 4122 text",
            )
        }
        self.uuid = uuid
        deviceID = try container.decode(DeviceID.self, forKey: .deviceID)
        counter = try container.decode(UInt64.self, forKey: .counter)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lowercaseUUIDText(uuid), forKey: .uuid)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(counter, forKey: .counter)
    }
}

/// Identity for one automatic hold/release/shift/merge/schedule-restart
/// decision. Belongs only to the scheduling-decision ledger, never
/// substituted for an ActionID or a product completion fact.
public struct DecisionID: Equatable, Hashable, Sendable {
    public let uuid: UUID

    /// Wraps an injected UUID without generating identity inside the reducer.
    public init(_ uuid: UUID) {
        self.uuid = uuid
    }
}

extension DecisionID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let uuid = UUID(uuidString: text) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "DecisionID requires lowercase hyphenated RFC 4122 text",
            )
        }
        self.uuid = uuid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(lowercaseUUIDText(uuid))
    }
}
