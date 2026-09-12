import Foundation

/// Closed fake evidence-kind vocabulary (Story 3.3).
///
/// Deliberately separate from the ten `OpportunityEvent` product facts: the
/// trust platform owns its own evidence contracts, and test/fake evidence is
/// sanitized scalars only. Domain never imports sensing frameworks.
public enum EvidenceKind: String, Equatable, Hashable, Sendable, CaseIterable {
    case presence
    case motion
    case ambient
}

/// Closed fake source vocabulary (Story 3.3).
///
/// Each source maps to exactly one story-2 registry provider so bus admission
/// can cross-check the atom's claimed source against the presenting lease.
public enum EvidenceSource: String, Equatable, Hashable, Sendable, CaseIterable {
    case fakePresence
    case fakeMotion
    case fakeAmbient

    /// The registry provider this source claims to be.
    public var providerID: SensingProviderID {
        switch self {
        case .fakePresence: .fakePresence
        case .fakeMotion: .fakeMotion
        case .fakeAmbient: .fakeAmbient
        }
    }

    /// Canonical bytes for deterministic ordering.
    var code: String { rawValue }
}

/// Evidence quality (Story 3.3).
///
/// Only `.full` contributes a reading. `.degraded` and `.denied` contribute
/// Unknown: weak evidence is never a negative vote and never contradicts.
/// `fusionRank` aligns representative selection with the closed Unknown
/// precedence (F8): a group holding any denied atom counts as denied, so
/// denied outranks degraded even though neither votes.
public enum EvidenceQuality: String, Equatable, Hashable, Sendable, CaseIterable {
    case full
    case degraded
    case denied

    /// Representative rank, ascending: qualified first, then denied, then
    /// degraded — mirroring the denied-over-degraded Unknown precedence.
    var fusionRank: Int {
        switch self {
        case .full: 0
        case .denied: 1
        case .degraded: 2
        }
    }

    /// Whether this quality contributes a reading to fusion.
    var isQualified: Bool { self == .full }
}

/// Evidence confidence (Story 3.3).
///
/// A closed three-step vocabulary. Fusion never invents finer grades and
/// never inflates past the best representative: correlated signals cap at
/// their max.
public enum EvidenceConfidence: String, Equatable, Hashable, Sendable, CaseIterable {
    case low
    case medium
    case high

    var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }
}

/// Evidence coverage (Story 3.3).
///
/// How much of the assessed situation the atom claims to cover. A closed
/// two-step vocabulary; ranks only break ties in the total order.
public enum EvidenceCoverage: String, Equatable, Hashable, Sendable, CaseIterable {
    case partial
    case full

    var rank: Int {
        switch self {
        case .partial: 0
        case .full: 1
        }
    }
}

/// Independence group (Story 3.3, F3).
///
/// Explicit producer-supplied correlation identity: atoms sharing a group
/// are correlated signals from one origin (one frame, one context window)
/// and fuse as a single vote. Never inferred from source, provider, or
/// identity — the producer declares it, or the atoms are independent.
///
/// Codes normalize at construction (trim + POSIX casefold) so spoof-split
/// casings (`" Frame-1"` vs `"frame-1"`) cannot fork one origin into two
/// votes. Group minting itself is story-4 ownership: the closed firewall
/// will restrict groups to provider-registered values; until then the bus
/// trusts the normalized code.
///
/// Residual invariant: normalization is syntactic, not registry-backed —
/// two producers claiming one code still correlate. Story 4 closes that.
public struct EvidenceIndependenceGroup: Equatable, Hashable, Sendable {
    public let code: String

    public init(code: String) {
        self.code = code.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    /// Fake group for tests: first correlated origin.
    public static let fakeAlpha = EvidenceIndependenceGroup(code: "fake-alpha")
    /// Fake group for tests: second independent origin.
    public static let fakeBeta = EvidenceIndependenceGroup(code: "fake-beta")
    /// Fake group for tests: third independent origin.
    public static let fakeGamma = EvidenceIndependenceGroup(code: "fake-gamma")
}

/// Why fusion produced Unknown (Story 3.3).
///
/// Closed vocabulary with a fixed precedence: contradiction, denied,
/// degraded, stale, missing. Callers match on meaning, never wording.
public enum EvidenceFailureReason: String, Equatable, Hashable, Sendable, CaseIterable {
    /// No atoms were available at all.
    case missing
    /// Atoms existed but none were live and provenanced at fusion ticks.
    case stale
    /// The best available evidence was explicitly denied.
    case denied
    /// The best available evidence was degraded below usability.
    case degraded
    /// Qualified independent groups disagreed: no average, no winner.
    case contradictory
}

/// One proposal's binary reading (Story 3.3).
///
/// Proposals are binary; Unknown lives only in the fused output, never in a
/// proposal. A degraded/denied proposal still carries its last reading, but
/// fusion ignores it: weak evidence never votes.
public enum EvidenceReading: String, Equatable, Hashable, Sendable, CaseIterable {
    case present
    case absent
}

/// Identity for one evidence atom (Story 3.3, F5).
///
/// A bus-minted admission sequence, never a caller UUID: the bus assigns
/// `0, 1, 2, …` in admission order, so IDs are unique without randomness
/// and double as the final tiebreak in the deterministic total order.
/// Construction is module-internal — only the bus mints IDs, so duplicate
/// or colliding caller IDs are impossible outside the module.
public struct EvidenceAtomID: Equatable, Hashable, Sendable {
    public let sequence: UInt64

    init(sequence: UInt64) {
        self.sequence = sequence
    }
}

/// Why one evidence proposal was refused before admission (Story 3.3, F4).
public enum EvidenceProposalError: Error, Equatable, Sendable {
    /// TTL is NaN or infinite: expiry would be undefined.
    case nonFiniteTTL
    /// TTL is zero or negative: the atom could never be live.
    case nonPositiveTTL
    /// TTL exceeds the documented bus maximum.
    case ttlExceedsMaximum(limit: TimeInterval)
}

/// One caller-built evidence proposal (Story 3.3, F2/F4).
///
/// The only caller-constructible evidence shape: sanitized scalars with a
/// throwing initializer that rejects non-finite, non-positive, and over-max
/// TTLs (throw, never clamp). The bus converts an admitted proposal into an
/// `EvidenceAtom` carrying bus-minted identity plus admission provenance;
/// callers can never construct atoms directly.
public struct EvidenceProposal: Equatable, Hashable, Sendable {
    /// Bus maximum TTL: 300 monotonic seconds (5 minutes).
    ///
    /// Documented choice: far above the 90-second story-2 lease maximum so
    /// lease-provenance expiry — not TTL — is the usual un-vote path, while
    /// the bus stays bounded and fusion inputs stay relevant. The bus holds
    /// at most `capacity` atoms regardless, so this bounds relevance, not
    /// memory.
    public static let maximumTimeToLiveSeconds: TimeInterval = 300

    public let kind: EvidenceKind
    public let source: EvidenceSource
    public let reading: EvidenceReading
    public let quality: EvidenceQuality
    public let confidence: EvidenceConfidence
    public let coverage: EvidenceCoverage
    public let independenceGroup: EvidenceIndependenceGroup
    public let observedTicks: TimeInterval
    public let timeToLiveSeconds: TimeInterval

    public init(
        kind: EvidenceKind,
        source: EvidenceSource,
        reading: EvidenceReading,
        quality: EvidenceQuality,
        confidence: EvidenceConfidence,
        coverage: EvidenceCoverage,
        independenceGroup: EvidenceIndependenceGroup,
        observedTicks: TimeInterval,
        timeToLiveSeconds: TimeInterval,
    ) throws {
        guard timeToLiveSeconds.isFinite else {
            throw EvidenceProposalError.nonFiniteTTL
        }
        guard timeToLiveSeconds > 0 else {
            throw EvidenceProposalError.nonPositiveTTL
        }
        guard timeToLiveSeconds <= Self.maximumTimeToLiveSeconds else {
            throw EvidenceProposalError.ttlExceedsMaximum(limit: Self.maximumTimeToLiveSeconds)
        }
        self.kind = kind
        self.source = source
        self.reading = reading
        self.quality = quality
        self.confidence = confidence
        self.coverage = coverage
        self.independenceGroup = independenceGroup
        self.observedTicks = observedTicks
        self.timeToLiveSeconds = timeToLiveSeconds
    }
}

/// Admission provenance for one evidence atom (Story 3.3, F2).
///
/// Bound at admission and re-validated at every fusion: the lease identity,
/// the presenting provider, origin revision, epoch, device, and admission
/// ticks. Post-admit revocation, expiry, revision advance, or epoch fencing
/// un-votes the atom at fusion time — gating ends at neither admission nor
/// storage. Construction is module-internal: provenance is bus-stamped.
public struct EvidenceProvenance: Equatable, Hashable, Sendable {
    public let lease: SensingProviderLease
    public let provider: SensingProviderID
    public let originRevision: UInt64
    public let epoch: ProjectionEpochID
    public let presentingDeviceID: DeviceID
    public let admittedTicks: TimeInterval

    init(
        lease: SensingProviderLease,
        provider: SensingProviderID,
        originRevision: UInt64,
        epoch: ProjectionEpochID,
        presentingDeviceID: DeviceID,
        admittedTicks: TimeInterval,
    ) {
        self.lease = lease
        self.provider = provider
        self.originRevision = originRevision
        self.epoch = epoch
        self.presentingDeviceID = presentingDeviceID
        self.admittedTicks = admittedTicks
    }
}

/// One sanitized evidence atom (Story 3.3, F2).
///
/// A pure non-`Codable` value: Class 0, memory-only, never persisted,
/// exported, logged, or transported. Atoms are bus-issued only — the
/// initializer is module-internal and the bus is the sole constructor —
/// so every atom carries minted identity plus stamped provenance.
/// Freshness is monotonic: the atom is live on the half-open
/// `[observedTicks, expiryTicks)` interval with injected ticks.
public struct EvidenceAtom: Equatable, Hashable, Sendable {
    public let id: EvidenceAtomID
    public let kind: EvidenceKind
    public let source: EvidenceSource
    public let reading: EvidenceReading
    public let quality: EvidenceQuality
    public let confidence: EvidenceConfidence
    public let coverage: EvidenceCoverage
    public let independenceGroup: EvidenceIndependenceGroup
    public let observedTicks: TimeInterval
    public let timeToLiveSeconds: TimeInterval
    public let provenance: EvidenceProvenance

    init(
        id: EvidenceAtomID,
        kind: EvidenceKind,
        source: EvidenceSource,
        reading: EvidenceReading,
        quality: EvidenceQuality,
        confidence: EvidenceConfidence,
        coverage: EvidenceCoverage,
        independenceGroup: EvidenceIndependenceGroup,
        observedTicks: TimeInterval,
        timeToLiveSeconds: TimeInterval,
        provenance: EvidenceProvenance,
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.reading = reading
        self.quality = quality
        self.confidence = confidence
        self.coverage = coverage
        self.independenceGroup = independenceGroup
        self.observedTicks = observedTicks
        self.timeToLiveSeconds = timeToLiveSeconds
        self.provenance = provenance
    }

    /// Monotonic expiry: observation plus TTL.
    public var expiryTicks: TimeInterval { observedTicks + timeToLiveSeconds }

    /// Liveness is half-open from observation up to, but excluding, expiry:
    /// the exact `ticks >= expiryTicks` edge ends freshness.
    public func isLive(atTicks ticks: TimeInterval) -> Bool {
        ticks >= observedTicks && ticks < expiryTicks
    }
}

extension EvidenceAtom: CustomDebugStringConvertible {
    /// Redacted (F6): kind, source, and ticks only. The reading payload —
    /// present/absent — never appears in debug output, so a log capture can
    /// never leak what the evidence claimed.
    public var debugDescription: String {
        "EvidenceAtom(kind: \(kind), source: \(source), observedTicks: \(observedTicks), expiryTicks: \(expiryTicks))"
    }
}
