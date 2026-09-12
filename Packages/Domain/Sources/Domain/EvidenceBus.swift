import Foundation

/// How one bus admission resolved (Story 3.3).
public enum EvidenceAdmission: Equatable, Sendable {
    case admitted
    case rejected(EvidenceAdmissionRejection)
}

/// Why one bus admission was refused (Story 3.3).
///
/// Structured, never free text, so callers and tests match on meaning.
public enum EvidenceAdmissionRejection: Equatable, Sendable {
    /// The presenting lease was refused by the held authority.
    case leaseRejected(SensingLeaseRejection)
    /// The proposal's source does not match the lease provider.
    case sourceMismatch
    /// The proposal was already stale at the admission ticks.
    case stale
}

/// Bounded expiring in-memory evidence bus (Story 3.3, F1/F2/F5/F7).
///
/// A value-semantic FIFO with a named capacity: over-capacity admission
/// drops the oldest atom and increments `droppedCount`, so drops are
/// auditable and never silent. Entries expire on a monotonic TTL: reads
/// filter lazily via `live(atTicks:)` and `purgeExpired(atTicks:)` drops
/// the expired explicitly, and `admit` purges expired entries before
/// appending or evicting (F7), so dead atoms never evict live ones.
///
/// The bus HOLDS its own `SensingLeaseAuthority` (F1): admission validates
/// against the held copy, and every bus method that touches the frontier
/// mutates the held copy in place. There is no per-call authority
/// parameter, so callers can never present a stale copy — admission and
/// fusion always see the same frontier. The bus mints sequential atom IDs
/// on admission (F5) and stamps admission provenance on every atom (F2),
/// which fusion re-validates: post-admit revocation or expiry un-votes.
///
/// Single-owner invariant (residual): whoever holds the bus owns the
/// authority — authority copies diverge by design (the accepted 2.3
/// precedent), so exactly one owner holds the canonical bus and shares it
/// by explicit pass, never by aliasing. Story 4 (closed firewall) is the
/// future owner; until then each test owns its bus.
///
/// Class 0: the bus is memory-only. It owns no store protocol, exposes no
/// snapshot, and nothing on this surface is `Codable` — bus contents must
/// never enter `ProtocolState`, `CoordinatorFenceState`,
/// `OpportunityEventStore`, `HistoryExport`, logs, or analytics.
public struct EvidenceBus: Sendable {
    /// Named capacity: the maximum stored atoms. Fixed at construction.
    public let capacity: Int
    /// The held lease authority: admission and fusion validate against this
    /// copy. Module-visible so fusion (same module) shares the frontier;
    /// callers mutate it only through the bus methods below.
    var authority: SensingLeaseAuthority
    /// Auditable drop counter: every drop-oldest eviction increments it.
    public private(set) var droppedCount: Int = 0
    /// Stored atoms in admission (arrival) order. Oldest first.
    private var atoms: [EvidenceAtom] = []
    /// Next bus-minted atom sequence. Monotonic per bus; never reused, even
    /// across purges — IDs are unique for the bus lifetime.
    private var nextSequence: UInt64 = 0

    public init(capacity: Int, authority: SensingLeaseAuthority) {
        precondition(capacity > 0, "EvidenceBus capacity must be positive")
        self.capacity = capacity
        self.authority = authority
    }

    /// Currently stored atoms, including not-yet-purged expired ones.
    public var count: Int { atoms.count }

    /// Whether no atoms are stored.
    public var isEmpty: Bool { atoms.isEmpty }

    /// Admits one proposal under a live lease, minting identity and
    /// stamping provenance. Rejections store nothing.
    public mutating func admit(
        _ proposal: EvidenceProposal,
        lease: SensingProviderLease,
        for provider: SensingProviderID,
        originRevision: UInt64,
        epoch: ProjectionEpochID,
        presentingDeviceID: DeviceID,
        atTicks ticks: TimeInterval
    ) -> EvidenceAdmission {
        if let rejection = authority.validate(
            lease,
            for: provider,
            originRevision: originRevision,
            epoch: epoch,
            presentingDeviceID: presentingDeviceID,
            atTicks: ticks
        ) {
            return .rejected(.leaseRejected(rejection))
        }
        guard proposal.source.providerID == provider else {
            return .rejected(.sourceMismatch)
        }
        guard ticks >= proposal.observedTicks,
              ticks < proposal.observedTicks + proposal.timeToLiveSeconds
        else {
            return .rejected(.stale)
        }
        // Expired entries leave before append/evict: dead atoms never evict
        // live ones and never consume the drop budget.
        purgeExpired(atTicks: ticks)
        let atom = EvidenceAtom(
            id: EvidenceAtomID(sequence: nextSequence),
            kind: proposal.kind,
            source: proposal.source,
            reading: proposal.reading,
            quality: proposal.quality,
            confidence: proposal.confidence,
            coverage: proposal.coverage,
            independenceGroup: proposal.independenceGroup,
            observedTicks: proposal.observedTicks,
            timeToLiveSeconds: proposal.timeToLiveSeconds,
            provenance: EvidenceProvenance(
                lease: lease,
                provider: provider,
                originRevision: originRevision,
                epoch: epoch,
                presentingDeviceID: presentingDeviceID,
                admittedTicks: ticks
            )
        )
        nextSequence &+= 1
        atoms.append(atom)
        while atoms.count > capacity {
            atoms.removeFirst()
            droppedCount += 1
        }
        return .admitted
    }

    /// Revokes one lease against the held authority with immediate effect,
    /// even mid-lease. Fusion re-validates provenance, so the revoked
    /// lease's atoms stop voting at once; stored atoms are untouched.
    public mutating func revoke(_ lease: SensingProviderLease) {
        authority.revoke(lease)
    }

    /// Advances one provider's scope revision on the held authority,
    /// implicitly revoking predecessor leases at fusion time.
    public mutating func advanceRevision(for provider: SensingProviderID) {
        authority.advanceRevision(for: provider)
    }

    /// Live atoms at the presented ticks, in admission order. Lazy: expired
    /// atoms are filtered, not removed — call `purgeExpired` to drop them.
    /// Liveness here is TTL only; lease-provenance liveness is enforced by
    /// fusion, not storage.
    public func live(atTicks ticks: TimeInterval) -> [EvidenceAtom] {
        atoms.filter { $0.isLive(atTicks: ticks) }
    }

    /// Drops expired atoms. Returns the removed count for audit.
    @discardableResult
    public mutating func purgeExpired(atTicks ticks: TimeInterval) -> Int {
        let stored = atoms.count
        atoms.removeAll { !$0.isLive(atTicks: ticks) }
        return stored - atoms.count
    }

    /// Whether any atom of the kind is stored, live or not. Fusion uses
    /// this to tell missing (nothing ever stored) from stale (stored but
    /// nothing votable).
    func containsEvidence(of kind: EvidenceKind) -> Bool {
        atoms.contains { $0.kind == kind }
    }
}

extension EvidenceBus: CustomDebugStringConvertible {
    /// Redacted (F6): capacity, counts, and drop budget only. No atom
    /// contents — a log capture sees the bus breathing, never its claims.
    public var debugDescription: String {
        "EvidenceBus(capacity: \(capacity), stored: \(count), dropped: \(droppedCount))"
    }
}
