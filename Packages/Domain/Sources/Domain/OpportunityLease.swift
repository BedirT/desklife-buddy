import Foundation

/// Scope-compatible coordinator leases for Story 2.3.
///
/// Opportunity commands carry OpportunityID plus opportunity revision; global,
/// system, and schedule commands carry the stable GlobalStateID plus global
/// revision. A running opportunity is named only through optional expected
/// compare-and-fence metadata, never as the global command identity.
public enum LeaseScope: Equatable, Hashable, Sendable {
    case opportunity(id: OpportunityID, revision: UInt64)
    case global(id: GlobalStateID, revision: UInt64)
}

extension LeaseScope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case opportunityID
        case globalStateID
        case revision
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        let revision = try container.decode(UInt64.self, forKey: .revision)
        switch kind {
        case "opportunity":
            let id = try container.decode(OpportunityID.self, forKey: .opportunityID)
            self = .opportunity(id: id, revision: revision)
        case "global":
            let global = try container.decode(GlobalStateID.self, forKey: .globalStateID)
            self = .global(id: global, revision: revision)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "LeaseScope kind must be opportunity or global",
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .opportunity(id, revision):
            try container.encode("opportunity", forKey: .kind)
            try container.encode(id, forKey: .opportunityID)
            try container.encode(revision, forKey: .revision)
        case let .global(id, revision):
            try container.encode("global", forKey: .kind)
            try container.encode(id, forKey: .globalStateID)
            try container.encode(revision, forKey: .revision)
        }
    }
}

/// Lease validation failures. The coordinator rejects the command; it never
/// commits a lease-violating effect.
public enum OpportunityLeaseError: Error, Equatable {
    /// The lease lives longer than the 90-second coordinator maximum.
    case lifetimeExceedsMaximum(grantedTicks: TimeInterval, expiryTicks: TimeInterval)
    /// The lease expires no later than it is granted.
    case expiryNotAfterGrant
}

/// One coordinator-issued projection lease of at most 90 monotonic seconds.
/// Effect-bearing nonterminal commands require a live lease tagged with
/// exactly one registered scope; the coordinator commits and acknowledges
/// atomically, so no provisional effect exists to roll back.
///
/// An opportunity lease is bound to one projection epoch: it authorizes only
/// actions naming that epoch, so fencing the epoch on closure revokes every
/// lease bound to it. A lease is likewise bound to the scope revision it was
/// issued for: advancing the revision revokes predecessor leases. Global
/// leases are projection-agnostic and carry no epoch.
public struct OpportunityLease: Equatable, Hashable, Sendable {
    /// Contract maximum: one lease never exceeds 90 monotonic seconds.
    public static let maximumLifetimeSeconds: TimeInterval = 90

    public let scope: LeaseScope
    public let generation: CoordinatorGeneration
    public let grantedDeviceID: DeviceID
    public let grantedTicks: TimeInterval
    public let expiryTicks: TimeInterval
    public let projectionEpoch: ProjectionEpochID?

    /// Issues a lease from injected monotonic ticks, enforcing the maximum.
    public init(
        scope: LeaseScope,
        generation: CoordinatorGeneration,
        grantedDeviceID: DeviceID,
        grantedTicks: TimeInterval,
        expiryTicks: TimeInterval,
        projectionEpoch: ProjectionEpochID? = nil,
    ) throws {
        guard expiryTicks > grantedTicks else {
            throw OpportunityLeaseError.expiryNotAfterGrant
        }
        guard expiryTicks - grantedTicks <= OpportunityLease.maximumLifetimeSeconds else {
            throw OpportunityLeaseError.lifetimeExceedsMaximum(
                grantedTicks: grantedTicks,
                expiryTicks: expiryTicks,
            )
        }
        self.scope = scope
        self.generation = generation
        self.grantedDeviceID = grantedDeviceID
        self.grantedTicks = grantedTicks
        self.expiryTicks = expiryTicks
        self.projectionEpoch = projectionEpoch
    }

    /// A lease is live from its grant tick up to, but excluding, its expiry
    /// tick: the exact `elapsed >= deadline` edge ends liveness.
    public func isLive(atTicks ticks: TimeInterval) -> Bool {
        ticks >= grantedTicks && ticks < expiryTicks
    }
}

extension OpportunityLease: Codable {
    private enum CodingKeys: String, CodingKey {
        case scope
        case generation
        case grantedDeviceID
        case grantedTicks
        case expiryTicks
        case projectionEpoch
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            scope: container.decode(LeaseScope.self, forKey: .scope),
            generation: container.decode(CoordinatorGeneration.self, forKey: .generation),
            grantedDeviceID: container.decode(DeviceID.self, forKey: .grantedDeviceID),
            grantedTicks: container.decode(TimeInterval.self, forKey: .grantedTicks),
            expiryTicks: container.decode(TimeInterval.self, forKey: .expiryTicks),
            projectionEpoch: container.decodeIfPresent(ProjectionEpochID.self, forKey: .projectionEpoch),
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scope, forKey: .scope)
        try container.encode(generation, forKey: .generation)
        try container.encode(grantedDeviceID, forKey: .grantedDeviceID)
        try container.encode(grantedTicks, forKey: .grantedTicks)
        try container.encode(expiryTicks, forKey: .expiryTicks)
        try container.encodeIfPresent(projectionEpoch, forKey: .projectionEpoch)
    }
}
