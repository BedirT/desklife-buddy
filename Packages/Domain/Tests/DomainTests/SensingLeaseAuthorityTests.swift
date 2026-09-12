import Foundation
import Testing
@testable import Domain

/// Story 3.2 RED: revocable sensing-lease issuer/validator.
///
/// Mirrors the Story 2.3 opportunity-lease binding rules: leases bind scope
/// revision + generation + epoch, live on the half-open
/// `[grantedTicks, expiryTicks)` interval under a 90-second maximum, and are
/// revoked implicitly by revision advance, generation rotation, and epoch
/// fencing. New versus 2.3: an explicit revocation path invalidates live
/// leases immediately, and device binding is enforced (2.3 retains
/// `grantedDeviceID` without comparing it).
///
/// Fails before implementation: `SensingProviderLease`,
/// `SensingLeaseScope`, and `SensingLeaseAuthority` do not exist yet.
private let sensingDeviceA = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!)
private let sensingDeviceB = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!)
private let sensingEpochA = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000E00A01")!)
private let sensingEpochB = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000E00B02")!)

private func sensingAuthority() throws -> SensingLeaseAuthority {
    try SensingLeaseAuthority(registry: SensingProviderRegistry(descriptors: [
        SensingProviderDescriptor(id: .fakePresence, displayName: "Fake presence"),
    ]))
}

private func issuedLease(
    authority: inout SensingLeaseAuthority,
    epoch: ProjectionEpochID = sensingEpochA,
    device: DeviceID = sensingDeviceA,
    atTicks ticks: TimeInterval = 1_000,
    lifetime: TimeInterval = 60,
) throws -> SensingProviderLease {
    try authority.issue(
        provider: .fakePresence,
        epoch: epoch,
        device: device,
        lifetimeSeconds: lifetime,
        atTicks: ticks,
    )
}

private func acceptedValidation(
    authority: SensingLeaseAuthority,
    lease: SensingProviderLease,
    originRevision: UInt64 = 0,
    epoch: ProjectionEpochID = sensingEpochA,
    device: DeviceID = sensingDeviceA,
    atTicks ticks: TimeInterval = 1_010,
) -> SensingLeaseRejection? {
    // Validation prunes expired entries, so it mutates: verdicts run against
    // a copy, and pruning is pinned through explicit variables instead.
    var copy = authority
    return copy.validate(
        lease,
        for: .fakePresence,
        originRevision: originRevision,
        epoch: epoch,
        presentingDeviceID: device,
        atTicks: ticks,
    )
}

@Suite("Sensing leases: issue, liveness, and binding")
struct SensingProviderLeaseTests {
    @Test("Issued lease binds revision, generation, epoch, and device")
    func issuedLeaseBindsAllFields() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority)
        #expect(lease.scope == .provider(id: .fakePresence, revision: 0))
        #expect(lease.generation == .initial)
        #expect(lease.epoch == sensingEpochA)
        #expect(lease.grantedDeviceID == sensingDeviceA)
        #expect(lease.grantedTicks == 1_000)
        #expect(lease.expiryTicks == 1_060)
        #expect(acceptedValidation(authority: authority, lease: lease) == nil)
    }

    @Test("Liveness is half-open from grant tick to expiry tick")
    func livenessIsHalfOpen() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority)
        #expect(lease.isLive(atTicks: 999.999) == false)
        #expect(lease.isLive(atTicks: 1_000) == true)
        #expect(lease.isLive(atTicks: 1_059.999) == true)
        #expect(lease.isLive(atTicks: 1_060) == false)
        #expect(acceptedValidation(authority: authority, lease: lease, atTicks: 1_060) == .notLive)
    }

    @Test("Lifetime over 90 seconds and non-positive lifetimes are refused")
    func lifetimeBoundsRefused() throws {
        var authority = try sensingAuthority()
        #expect(throws: SensingProviderLeaseError.lifetimeExceedsMaximum(grantedTicks: 1_000, expiryTicks: 1_091)) {
            try authority.issue(
                provider: .fakePresence,
                epoch: sensingEpochA,
                device: sensingDeviceA,
                lifetimeSeconds: 91,
                atTicks: 1_000,
            )
        }
        #expect(throws: SensingProviderLeaseError.expiryNotAfterGrant) {
            try authority.issue(
                provider: .fakePresence,
                epoch: sensingEpochA,
                device: sensingDeviceA,
                lifetimeSeconds: 0,
                atTicks: 1_000,
            )
        }
    }

    @Test("Unknown provider cannot be issued a lease")
    func unknownProviderIssueRefused() throws {
        var authority = try sensingAuthority()
        #expect(throws: SensingProviderRegistryError.unknownProvider(SensingProviderID("unknown-sensor"))) {
            try authority.issue(
                provider: SensingProviderID("unknown-sensor"),
                epoch: sensingEpochA,
                device: sensingDeviceA,
                lifetimeSeconds: 60,
                atTicks: 1_000,
            )
        }
    }

    @Test("Revision advance revokes predecessor leases on both binding stages")
    func revisionAdvanceRevokes() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority)
        authority.advanceRevision(for: .fakePresence)
        // Stage one: the lease revision no longer matches the presented origin.
        #expect(acceptedValidation(authority: authority, lease: lease, originRevision: 1) == .leaseRevisionMismatch)
        // Stage two: the spent origin no longer matches the frontier either.
        #expect(acceptedValidation(authority: authority, lease: lease, originRevision: 0) == .staleRevision)
        // A fresh lease for the new frontier validates.
        let fresh = try issuedLease(authority: &authority, atTicks: 1_010)
        #expect(fresh.scope == .provider(id: .fakePresence, revision: 1))
        #expect(acceptedValidation(authority: authority, lease: fresh, originRevision: 1, atTicks: 1_020) == nil)
    }

    @Test("Generation rotation revokes prior-generation leases")
    func generationRotationRevokes() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority)
        authority.noteSessionRotation()
        #expect(acceptedValidation(authority: authority, lease: lease) == .staleGeneration)
    }

    @Test("Epoch fencing revokes leases bound to the fenced epoch")
    func epochFenceRevokes() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority)
        authority.fenceEpoch(sensingEpochA)
        #expect(acceptedValidation(authority: authority, lease: lease) == .fencedEpoch)
    }

    @Test("Lease epoch must equal the presented epoch")
    func epochMismatchRejected() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority, epoch: sensingEpochA)
        #expect(acceptedValidation(authority: authority, lease: lease, epoch: sensingEpochB) == .epochMismatch)
    }

    @Test("Issuing under an epoch conflicting with the binding is refused")
    func bindingConflictRefusedAtIssue() throws {
        var authority = try sensingAuthority()
        _ = try issuedLease(authority: &authority, epoch: sensingEpochA)
        #expect(throws: SensingLeaseRejection.epochMismatch) {
            try authority.issue(
                provider: .fakePresence,
                epoch: sensingEpochB,
                device: sensingDeviceA,
                lifetimeSeconds: 60,
                atTicks: 1_001,
            )
        }
    }

    @Test("Issuing under a fenced epoch is refused")
    func fencedEpochRefusedAtIssue() throws {
        var authority = try sensingAuthority()
        _ = try issuedLease(authority: &authority, epoch: sensingEpochA)
        authority.fenceEpoch(sensingEpochA)
        #expect(throws: SensingLeaseRejection.fencedEpoch) {
            try authority.issue(
                provider: .fakePresence,
                epoch: sensingEpochA,
                device: sensingDeviceA,
                lifetimeSeconds: 60,
                atTicks: 1_010,
            )
        }
    }

    @Test("Issuing under the all-zeroes epoch is refused")
    func zeroEpochRefusedAtIssue() throws {
        var authority = try sensingAuthority()
        let zero = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(throws: SensingLeaseRejection.zeroEpoch) {
            try authority.issue(
                provider: .fakePresence,
                epoch: zero,
                device: sensingDeviceA,
                lifetimeSeconds: 60,
                atTicks: 1_000,
            )
        }
    }


    @Test("Presenting device must equal the granted device")
    func deviceMismatchRejected() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority, device: sensingDeviceA)
        #expect(acceptedValidation(authority: authority, lease: lease, device: sensingDeviceB) == .deviceMismatch)
    }

    @Test("Lease for the wrong provider is rejected")
    func providerMismatchRejected() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority)
        let rejection = authority.validate(
            lease,
            for: .fakeMotion,
            originRevision: 0,
            epoch: sensingEpochA,
            presentingDeviceID: sensingDeviceA,
            atTicks: 1_010,
        )
        #expect(rejection == .providerMismatch)
    }
}

@Suite("Sensing leases: explicit revocation")
struct SensingLeaseRevocationTests {
    @Test("Explicit revoke invalidates a live lease immediately")
    func explicitRevokeInvalidatesLiveLease() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority)
        #expect(acceptedValidation(authority: authority, lease: lease) == nil)
        authority.revoke(lease)
        #expect(acceptedValidation(authority: authority, lease: lease) == .explicitlyRevoked)
    }

    @Test("Revoked-then-replayed evidence stays rejected")
    func revokedReplayRejected() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority)
        authority.revoke(lease)
        // Replay at a later tick inside the original live window.
        #expect(acceptedValidation(authority: authority, lease: lease, atTicks: 1_030) == .explicitlyRevoked)
        // Replay after the frontier moved: still rejected, never resurrected.
        authority.advanceRevision(for: .fakePresence)
        let replayed = authority.validate(
            lease,
            for: .fakePresence,
            originRevision: 1,
            epoch: sensingEpochA,
            presentingDeviceID: sensingDeviceA,
            atTicks: 1_040,
        )
        #expect(replayed == .explicitlyRevoked)
    }

    @Test("Revoking one lease leaves sibling leases live")
    func revokeIsPerLease() throws {
        var authority = try sensingAuthority()
        let first = try issuedLease(authority: &authority, atTicks: 1_000)
        let second = try issuedLease(authority: &authority, atTicks: 1_001)
        authority.revoke(first)
        #expect(acceptedValidation(authority: authority, lease: first, atTicks: 1_010) == .explicitlyRevoked)
        #expect(acceptedValidation(authority: authority, lease: second, atTicks: 1_010) == nil)
    }
}

@Suite("Sensing leases: issuance provenance")
struct SensingLeaseProvenanceTests {
    @Test("A forged lease with plausible fields is rejected without issue")
    func forgedLeaseWithoutIssueRejected() throws {
        let authority = try sensingAuthority()
        let forged = try SensingProviderLease(
            scope: .provider(id: .fakePresence, revision: 0),
            generation: .initial,
            grantedDeviceID: sensingDeviceA,
            grantedTicks: 1_000,
            expiryTicks: 1_060,
            epoch: sensingEpochA,
        )
        #expect(acceptedValidation(authority: authority, lease: forged) == .notIssued)
    }

    @Test("Reissue after revoke clears the revocation and admits")
    func reissueAfterRevokeAdmits() throws {
        var authority = try sensingAuthority()
        let lease = try issuedLease(authority: &authority)
        authority.revoke(lease)
        #expect(acceptedValidation(authority: authority, lease: lease) == .explicitlyRevoked)
        let renewed = try issuedLease(authority: &authority)
        #expect(renewed == lease)
        #expect(acceptedValidation(authority: authority, lease: renewed) == nil)
    }

    @Test("Expired entries are pruned from both tracking sets")
    func expiredEntriesPruned() throws {
        var authority = try sensingAuthority()
        let first = try issuedLease(authority: &authority, atTicks: 1_000)
        let second = try issuedLease(authority: &authority, atTicks: 1_001)
        authority.revoke(first)
        #expect(authority.issuedCount == 1)
        #expect(authority.revokedCount == 1)
        let verdict = authority.validate(
            second,
            for: .fakePresence,
            originRevision: 0,
            epoch: sensingEpochA,
            presentingDeviceID: sensingDeviceA,
            atTicks: 2_000,
        )
        #expect(verdict == .notLive)
        #expect(authority.issuedCount == 0)
        #expect(authority.revokedCount == 0)
    }
}

@Suite("Sensing leases: rotation and rebinding")
struct SensingLeaseRotationTests {
    @Test("Rotation clears bindings so a new epoch binds after a fence")
    func rotationRebindsNewEpochAfterFence() throws {
        var authority = try sensingAuthority()
        let first = try issuedLease(authority: &authority, atTicks: 1_000)
        authority.fenceEpoch(sensingEpochA)
        #expect(acceptedValidation(authority: authority, lease: first) == .fencedEpoch)
        authority.noteSessionRotation()
        let second = try issuedLease(authority: &authority, epoch: sensingEpochB, atTicks: 1_010)
        #expect(acceptedValidation(authority: authority, lease: second, epoch: sensingEpochB, atTicks: 1_020) == nil)
        #expect(acceptedValidation(authority: authority, lease: first) == .staleGeneration)
    }

    @Test("Same-generation rebind under a fenced epoch stays refused")
    func sameGenerationRebindAfterFenceRefused() throws {
        var authority = try sensingAuthority()
        _ = try issuedLease(authority: &authority, epoch: sensingEpochA)
        authority.fenceEpoch(sensingEpochA)
        #expect(throws: SensingLeaseRejection.epochMismatch) {
            try authority.issue(
                provider: .fakePresence,
                epoch: sensingEpochB,
                device: sensingDeviceA,
                lifetimeSeconds: 60,
                atTicks: 1_010,
            )
        }
    }
}

@Suite("Sensing provider registry: runtime closure")
struct SensingProviderRuntimeClosureTests {
    @Test("A runtime-string provider is inadmissible via the public API")
    func runtimeStringProviderInadmissible() throws {
        let evil = SensingProviderID("runtime-evil")
        let registry = SensingProviderRegistry.compiled
        #expect(registry.contains(evil) == false)
        #expect(throws: SensingProviderRegistryError.unknownProvider(evil)) {
            try registry.descriptor(for: evil)
        }
        var authority = SensingLeaseAuthority()
        #expect(throws: SensingProviderRegistryError.unknownProvider(evil)) {
            try authority.issue(
                provider: evil,
                epoch: sensingEpochA,
                device: sensingDeviceA,
                lifetimeSeconds: 60,
                atTicks: 1_000,
            )
        }
        let forged = try SensingProviderLease(
            scope: .provider(id: evil, revision: 0),
            generation: .initial,
            grantedDeviceID: sensingDeviceA,
            grantedTicks: 1_000,
            expiryTicks: 1_060,
            epoch: sensingEpochA,
        )
        var copy = authority
        let verdict = copy.validate(
            forged,
            for: evil,
            originRevision: 0,
            epoch: sensingEpochA,
            presentingDeviceID: sensingDeviceA,
            atTicks: 1_010,
        )
        #expect(verdict == .unknownProvider)
    }
}
