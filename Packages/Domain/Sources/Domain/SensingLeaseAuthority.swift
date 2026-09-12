import Foundation

/// Why one sensing lease was rejected. A `nil` verdict admits the evidence;
/// any case rejects it. Cases are structured (never free text) so callers
/// and tests match on meaning, not wording.
///
/// The rejection doubles as the issue-time error: `issue` throws these cases
/// directly, so issue-time and validate-time refusal share one vocabulary.
public enum SensingLeaseRejection: Equatable, Sendable, Error {
    /// The lease names a provider outside the closed registry set.
    case providerMismatch
    /// The provider is not in the closed registry set.
    case unknownProvider
    /// The lease was explicitly revoked. Checked before liveness so
    /// revocation takes immediate effect on otherwise-live leases.
    case explicitlyRevoked
    /// The lease was granted under a retired generation.
    case staleGeneration
    /// The lease is not live at the presented ticks.
    case notLive
    /// The lease revision does not match the presented origin revision: the
    /// lease was issued for a spent revision.
    case leaseRevisionMismatch
    /// The presented origin revision is past the current frontier.
    case staleRevision
    /// The lease epoch does not authorize the presented epoch.
    case epochMismatch
    /// The presented epoch is fenced: every lease bound to it is revoked.
    case fencedEpoch
    /// The presenting device is not the granted device.
    case deviceMismatch
    /// The lease was never issued by this authority. Checked last so
    /// outgrown or expired issued leases keep their specific verdicts even
    /// after pruning drops them from the issued set.
    case notIssued
    /// The epoch is the all-zeroes epoch, which names no real projection.
    case zeroEpoch
}

/// Revocable sensing-lease issuer and validator (Story 3.2).
///
/// Mirrors the Story 2.3 binding rules: leases bind scope revision +
/// generation + epoch, revision advance and epoch fencing revoke implicitly
/// by moving the frontier rather than by locating leases, and validation is
/// the two-stage `lease.scopeRevision == presentedOrigin == currentFrontier`
/// check. New versus 2.3: `revoke` invalidates a live lease immediately, so
/// a provider can be revoked mid-lease rather than only outgrown.
///
/// Issuance provenance is validated, not just field values: the authority
/// tracks every issued lease, and validation requires membership. A forged
/// lease with plausible fields is rejected as `notIssued` without `issue`
/// ever having been called. Expired entries are pruned on every issue and
/// validation, so both tracking sets stay bounded by the 90-second maximum
/// lifetime. Revocation removes the lease from the issued set and records it
/// in the revoked set; reissue clears the revocation and re-admits, so a
/// revoked-then-reissued provider is never denied by its own past.
///
/// Device binding is enforced: the presenting device must equal the granted
/// device. 2.3 retains `grantedDeviceID` without comparing it; this
/// authority compares it because a sensing lease authorizes one installation
/// to present evidence, and a lease presented by any other installation is
/// indistinguishable from a stolen credential.
///
/// Single-owner value: the authority is a struct so every mutation is
/// explicit at the owner's call site. Exactly one owner holds the canonical
/// copy and shares it by explicit pass, never by aliasing — two authority
/// copies diverge (issued sets, revisions, fences), which is the accepted
/// 2.3-coordinator precedent for value-semantic fence state. Story 4 (closed
/// firewall) is the future owner: it will hold the canonical authority and
/// admit evidence through it; until then each test owns its copy.
///
/// All ticks are injected. The authority never reads a clock.
public struct SensingLeaseAuthority: Sendable {
    private let registry: SensingProviderRegistry
    private var generation: CoordinatorGeneration
    private var providerRevisions: [SensingProviderID: UInt64]
    private var boundEpochs: [SensingProviderID: ProjectionEpochID]
    private var fencedEpochs: Set<ProjectionEpochID>
    private var issuedLeases: Set<SensingProviderLease>
    private var revokedLeases: Set<SensingProviderLease>

    /// The all-zeroes epoch names no real projection and is never issued.
    private static let zeroEpochText = "00000000-0000-0000-0000-000000000000"

    /// Creates an authority over the compiled provider set.
    public init() {
        self.init(registry: .compiled)
    }

    /// Creates an authority over an explicit registry. In-module only: the
    /// public surface is the compiled vocabulary, so runtime callers cannot
    /// extend the provider set.
    init(registry: SensingProviderRegistry) {
        self.registry = registry
        generation = .initial
        providerRevisions = [:]
        boundEpochs = [:]
        fencedEpochs = []
        issuedLeases = []
        revokedLeases = []
    }

    /// Test-support hooks (in-module only): currently tracked set sizes.
    internal var issuedCount: Int {
        issuedLeases.count
    }

    internal var revokedCount: Int {
        revokedLeases.count
    }

    /// Issues a lease binding the current generation, the provider's current
    /// scope revision, the presented epoch, and the presenting device.
    /// The first issue for a provider binds that provider to its epoch.
    /// Refuses fenced epochs, epochs conflicting with the provider's binding,
    /// and the all-zeroes epoch at issue time.
    public mutating func issue(
        provider: SensingProviderID,
        epoch: ProjectionEpochID,
        device deviceID: DeviceID,
        lifetimeSeconds: TimeInterval,
        atTicks ticks: TimeInterval,
    ) throws -> SensingProviderLease {
        guard registry.contains(provider) else {
            throw SensingProviderRegistryError.unknownProvider(provider)
        }
        guard !Self.isZeroEpoch(epoch) else {
            throw SensingLeaseRejection.zeroEpoch
        }
        guard !fencedEpochs.contains(epoch) else {
            throw SensingLeaseRejection.fencedEpoch
        }
        if let bound = boundEpochs[provider], bound != epoch {
            throw SensingLeaseRejection.epochMismatch
        }
        let lease = try SensingProviderLease(
            scope: .provider(id: provider, revision: providerRevisions[provider, default: 0]),
            generation: generation,
            grantedDeviceID: deviceID,
            grantedTicks: ticks,
            expiryTicks: ticks + lifetimeSeconds,
            epoch: epoch,
        )
        pruneExpired(atTicks: ticks)
        // Reissue clears a prior revocation of the equal lease: a revoked
        // provider that is issued again must not be denied by its own past.
        revokedLeases.remove(lease)
        issuedLeases.insert(lease)
        if boundEpochs[provider] == nil {
            boundEpochs[provider] = epoch
        }
        return lease
    }

    /// Validates presented evidence against the lease and the current
    /// frontier. Returns `nil` when the evidence is admitted.
    public mutating func validate(
        _ lease: SensingProviderLease,
        for provider: SensingProviderID,
        originRevision: UInt64,
        epoch: ProjectionEpochID,
        presentingDeviceID: DeviceID,
        atTicks ticks: TimeInterval,
    ) -> SensingLeaseRejection? {
        pruneExpired(atTicks: ticks)
        guard lease.scope.providerID == provider else { return .providerMismatch }
        guard registry.contains(provider) else { return .unknownProvider }
        guard !revokedLeases.contains(lease) else { return .explicitlyRevoked }
        guard lease.generation == generation else { return .staleGeneration }
        guard lease.isLive(atTicks: ticks) else { return .notLive }
        // A lease is issued for one scope revision: advancing the revision
        // revokes predecessor leases, so the lease revision must match the
        // presented origin revision exactly.
        guard lease.scope.scopeRevision == originRevision else { return .leaseRevisionMismatch }
        guard originRevision == providerRevisions[provider, default: 0] else { return .staleRevision }
        // A sensing lease is bound to one epoch: it authorizes only evidence
        // naming that epoch, so fencing the epoch revokes every lease bound
        // to it.
        guard lease.epoch == epoch else { return .epochMismatch }
        guard !fencedEpochs.contains(epoch) else { return .fencedEpoch }
        if let bound = boundEpochs[provider], bound != epoch { return .epochMismatch }
        guard lease.grantedDeviceID == presentingDeviceID else { return .deviceMismatch }
        guard issuedLeases.contains(lease) else { return .notIssued }
        return nil
    }

    /// Revokes one lease explicitly with immediate effect, even mid-lease.
    /// Sibling leases are unaffected.
    public mutating func revoke(_ lease: SensingProviderLease) {
        issuedLeases.remove(lease)
        revokedLeases.insert(lease)
    }

    /// Advances the provider's scope revision, implicitly revoking every
    /// predecessor lease bound to an earlier revision.
    public mutating func advanceRevision(for provider: SensingProviderID) {
        providerRevisions[provider, default: 0] &+= 1
    }

    /// Fences the epoch before any successor becomes eligible, implicitly
    /// revoking every lease bound to it regardless of remaining lease time.
    /// Fences survive generation rotation: a fenced epoch never reopens.
    public mutating func fenceEpoch(_ epoch: ProjectionEpochID) {
        fencedEpochs.insert(epoch)
    }

    /// Rotates the session generation, revoking every prior-generation lease.
    /// Clears provider epoch bindings so the new generation can bind fresh
    /// epochs, and drops prior-generation tracking entries. Same-generation
    /// fences are kept, so rebinding under a fenced epoch stays refused
    /// until rotation moves past it.
    public mutating func noteSessionRotation() {
        generation = generation.advanced()
        boundEpochs = [:]
        issuedLeases = Set(issuedLeases.filter { $0.generation == generation })
        revokedLeases = Set(revokedLeases.filter { $0.generation == generation })
    }

    private static func isZeroEpoch(_ epoch: ProjectionEpochID) -> Bool {
        epoch.uuid.uuidString.caseInsensitiveCompare(zeroEpochText) == .orderedSame
    }

    private mutating func pruneExpired(atTicks ticks: TimeInterval) {
        issuedLeases = Set(issuedLeases.filter { $0.expiryTicks > ticks })
        revokedLeases = Set(revokedLeases.filter { $0.expiryTicks > ticks })
    }
}
