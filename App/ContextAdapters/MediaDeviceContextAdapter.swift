import Domain
import Foundation

/// Epic 5 story S3 (issue #6, gate G4): any-device-busy adapter.
/// Reduces per-device in-use flags to ONE merged boolean (OR) outside
/// Domain and mints a caller-built bus proposal through the Epic 3
/// registry/leases/bus path. Device identity — names, identifiers, models,
/// vendors — and the per-device breakdown never cross the boundary: the
/// reader reports bare booleans, so a merged `true` cannot be traced back
/// to any device.
///
/// Reader dock point: the live reader observes the media-framework
/// read-only device-in-use flag (key-value, no capture session, no
/// samples) and maps each device to its flag. That reader lives with the
/// host wiring, not here — this adapter only ever sees `[Bool]`. The S2
/// spike's open edge still applies: the host must characterize whether
/// device discovery itself interacts with camera/mic consent state on a
/// denied host, and treat denied discovery as not-busy (Unknown, never
/// negative).
enum MediaDeviceDiscovery: Sendable {
    /// Discovery refused or unavailable: emits a denied-quality proposal
    /// (Unknown at fusion), never a reading.
    case denied
    /// Bare per-device in-use flags. Empty means nothing was observed —
    /// no proposal (Unknown), never a vacuous negative vote.
    case flags([Bool])
}

struct MediaDeviceContextAdapter: Sendable {
    /// Independence group declared for fusion (S3): one origin, one vote.
    static let independenceGroupCode = "media-device"

    private let readDiscovery: @Sendable () -> MediaDeviceDiscovery

    init(readDiscovery: @escaping @Sendable () -> MediaDeviceDiscovery) {
        self.readDiscovery = readDiscovery
    }

    /// Sanitized snapshot: any-busy boolean only. Nil when discovery is
    /// denied or nothing was observed.
    func snapshot() -> MediaDeviceSnapshot? {
        guard case let .flags(flags) = readDiscovery(), !flags.isEmpty else { return nil }
        return MediaDeviceSnapshot(isBusy: flags.contains(true))
    }

    /// Sanitized proposal for the bus. Denied discovery mints a
    /// denied-quality proposal carrying `.absent` (ignored by fusion — the
    /// denial, not the reading, is the signal). Empty discovery mints
    /// nothing.
    func proposal(
        observedTicks: TimeInterval,
        timeToLiveSeconds: TimeInterval = 30,
    ) throws -> EvidenceProposal? { // RAWGUARD-ALLOW: S3 adapter mints caller-built bus proposals
        switch readDiscovery() {
        case .denied:
            return try EvidenceProposal( // RAWGUARD-ALLOW: S3 adapter mints caller-built bus proposals
                kind: .ambient,
                source: .mediaDevice,
                reading: .absent,
                quality: .denied,
                confidence: .low,
                coverage: .partial,
                independenceGroup: EvidenceIndependenceGroup(code: Self.independenceGroupCode), // RAWGUARD-ALLOW: S3 adapter declares its fusion group
                observedTicks: observedTicks,
                timeToLiveSeconds: timeToLiveSeconds,
            )
        case let .flags(flags):
            guard !flags.isEmpty else { return nil }
            let isBusy = flags.contains(true)
            return try EvidenceProposal( // RAWGUARD-ALLOW: S3 adapter mints caller-built bus proposals
                kind: .ambient,
                source: .mediaDevice,
                reading: isBusy ? .present : .absent,
                quality: .full,
                confidence: .high,
                coverage: .partial,
                independenceGroup: EvidenceIndependenceGroup(code: Self.independenceGroupCode), // RAWGUARD-ALLOW: S3 adapter declares its fusion group
                observedTicks: observedTicks,
                timeToLiveSeconds: timeToLiveSeconds,
            )
        }
    }
}

/// Sanitized device state: one boolean. No strings, no collections —
/// enforced structurally by SanitizedContextAdapterTests.
struct MediaDeviceSnapshot: Equatable, Sendable {
    let isBusy: Bool
}
