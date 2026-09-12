import Domain
import Foundation

/// Epic 5 story S3 (issue #6, gate G4): declared-filter adapter.
///
/// There is no public sensor API for Focus-filter state on macOS that a
/// third-party host may poll — so this adapter reads no sensor at all. It
/// carries the USER'S OWN declaration (the selected filter is active:
/// true / false / unknown) plus the source-enabled switch, reduces both to
/// one sanitized boolean, and mints a caller-built bus proposal through
/// the Epic 3 registry/leases/bus path. It never claims depth: active means
/// "the selected filter is on", never deep work, never availability, never
/// attention.
///
/// A disabled source or an unknown declaration yields no snapshot and no
/// proposal — Unknown, never a negative vote. Declaration-backed state
/// always outranks inference downstream (S4 fusion rule, G1 gate).
struct FocusContextAdapter: Sendable {
    /// Independence group declared for fusion (S3): the declaration is its
    /// own origin, independent of the frontmost-app and media-device
    /// groups — sharing a group with either would falsely collapse two
    /// independent votes into one.
    static let independenceGroupCode = "focus-filter"

    private let readDeclaredActive: @Sendable () -> Bool?
    private let isSourceEnabled: @Sendable () -> Bool

    /// - Parameter readDeclaredActive: the user's declaration (nil =
    ///   unknown). Sensor-free by construction.
    /// - Parameter isSourceEnabled: the Settings source switch.
    init(
        readDeclaredActive: @escaping @Sendable () -> Bool?,
        isSourceEnabled: @escaping @Sendable () -> Bool,
    ) {
        self.readDeclaredActive = readDeclaredActive
        self.isSourceEnabled = isSourceEnabled
    }

    /// Sanitized snapshot: filter-active boolean only. Nil when the source
    /// is off or the declaration is unknown.
    func snapshot() -> FocusSnapshot? {
        guard isSourceEnabled(), let declared = readDeclaredActive() else { return nil }
        return FocusSnapshot(isFilterActive: declared)
    }

    /// Sanitized proposal for the bus: binary reading, full quality, high
    /// confidence, partial coverage. Nil when there is nothing to report.
    func proposal(
        observedTicks: TimeInterval,
        timeToLiveSeconds: TimeInterval = 30,
    ) throws -> EvidenceProposal? { // RAWGUARD-ALLOW: S3 adapter mints caller-built bus proposals
        guard let snapshot = snapshot() else { return nil }
        return try EvidenceProposal( // RAWGUARD-ALLOW: S3 adapter mints caller-built bus proposals
            kind: .presence,
            source: .focusFilter,
            reading: snapshot.isFilterActive ? .present : .absent,
            quality: .full,
            confidence: .high,
            coverage: .partial,
            independenceGroup: EvidenceIndependenceGroup(code: Self.independenceGroupCode), // RAWGUARD-ALLOW: S3 adapter declares its fusion group
            observedTicks: observedTicks,
            timeToLiveSeconds: timeToLiveSeconds,
        )
    }
}

/// Sanitized Focus state: one boolean. No strings, no collections —
/// enforced structurally by SanitizedContextAdapterTests.
struct FocusSnapshot: Equatable, Sendable {
    let isFilterActive: Bool
}
