import Foundation

/// Revision-bearing scope for one sensing lease (Story 3.2).
///
/// Mirrors `LeaseScope`: the lease authorizes exactly one provider at one
/// scope revision, so advancing the revision revokes predecessor leases.
public enum SensingLeaseScope: Equatable, Hashable, Sendable {
    case provider(id: SensingProviderID, revision: UInt64)

    /// The provider this scope authorizes.
    public var providerID: SensingProviderID {
        switch self {
        case let .provider(id, _):
            id
        }
    }

    /// The scope revision the lease was issued for.
    public var scopeRevision: UInt64 {
        switch self {
        case let .provider(_, revision):
            revision
        }
    }
}

extension SensingLeaseScope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case provider
        case revision
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        guard kind == "provider" else {
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "SensingLeaseScope requires kind 'provider'",
            )
        }
        let id = try container.decode(SensingProviderID.self, forKey: .provider)
        let revision = try container.decode(UInt64.self, forKey: .revision)
        self = .provider(id: id, revision: revision)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("provider", forKey: .kind)
        switch self {
        case let .provider(id, revision):
            try container.encode(id, forKey: .provider)
            try container.encode(revision, forKey: .revision)
        }
    }
}

/// Lease validation failures. The authority rejects the evidence; it never
/// admits lease-violating work.
public enum SensingProviderLeaseError: Error, Equatable {
    /// The lease lives longer than the 90-second maximum.
    case lifetimeExceedsMaximum(grantedTicks: TimeInterval, expiryTicks: TimeInterval)
    /// The lease expires no later than it is granted.
    case expiryNotAfterGrant
}

/// One authority-issued sensing lease of at most 90 monotonic seconds.
///
/// Mirrors `OpportunityLease`: injected monotonic grant/expiry ticks, the
/// 90-second maximum, and half-open liveness. Two deliberate hardenings
/// versus 2.3: the epoch is non-optional (every sensing lease authorizes
/// exactly one epoch, closing the unenforced "global leases carry no epoch"
/// gap), and the granted device is compared at validation (2.3 retains
/// `grantedDeviceID` without comparing it).
public struct SensingProviderLease: Equatable, Hashable, Sendable {
    /// Contract maximum: one lease never exceeds 90 monotonic seconds.
    public static let maximumLifetimeSeconds: TimeInterval = 90

    public let scope: SensingLeaseScope
    public let generation: CoordinatorGeneration
    public let grantedDeviceID: DeviceID
    public let grantedTicks: TimeInterval
    public let expiryTicks: TimeInterval
    public let epoch: ProjectionEpochID

    /// Issues a lease from injected monotonic ticks, enforcing the maximum.
    public init(
        scope: SensingLeaseScope,
        generation: CoordinatorGeneration,
        grantedDeviceID: DeviceID,
        grantedTicks: TimeInterval,
        expiryTicks: TimeInterval,
        epoch: ProjectionEpochID,
    ) throws {
        guard expiryTicks > grantedTicks else {
            throw SensingProviderLeaseError.expiryNotAfterGrant
        }
        guard expiryTicks - grantedTicks <= SensingProviderLease.maximumLifetimeSeconds else {
            throw SensingProviderLeaseError.lifetimeExceedsMaximum(
                grantedTicks: grantedTicks,
                expiryTicks: expiryTicks,
            )
        }
        self.scope = scope
        self.generation = generation
        self.grantedDeviceID = grantedDeviceID
        self.grantedTicks = grantedTicks
        self.expiryTicks = expiryTicks
        self.epoch = epoch
    }

    /// A lease is live from its grant tick up to, but excluding, its expiry
    /// tick: the exact `elapsed >= deadline` edge ends liveness.
    public func isLive(atTicks ticks: TimeInterval) -> Bool {
        ticks >= grantedTicks && ticks < expiryTicks
    }
}

extension SensingProviderLease: Codable {
    private enum CodingKeys: String, CodingKey {
        case scope
        case generation
        case grantedDeviceID
        case grantedTicks
        case expiryTicks
        case epoch
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let scope = try container.decode(SensingLeaseScope.self, forKey: .scope)
        let generation = try container.decode(CoordinatorGeneration.self, forKey: .generation)
        let grantedDeviceID = try container.decode(DeviceID.self, forKey: .grantedDeviceID)
        let grantedTicks = try container.decode(TimeInterval.self, forKey: .grantedTicks)
        let expiryTicks = try container.decode(TimeInterval.self, forKey: .expiryTicks)
        let epoch = try container.decode(ProjectionEpochID.self, forKey: .epoch)
        try self.init(
            scope: scope,
            generation: generation,
            grantedDeviceID: grantedDeviceID,
            grantedTicks: grantedTicks,
            expiryTicks: expiryTicks,
            epoch: epoch,
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scope, forKey: .scope)
        try container.encode(generation, forKey: .generation)
        try container.encode(grantedDeviceID, forKey: .grantedDeviceID)
        try container.encode(grantedTicks, forKey: .grantedTicks)
        try container.encode(expiryTicks, forKey: .expiryTicks)
        try container.encode(epoch, forKey: .epoch)
    }
}
