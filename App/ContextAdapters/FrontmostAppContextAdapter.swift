import AppKit
import Domain
import Foundation

/// Epic 5 story S3 (issue #6, gate G4): selected-app-active adapter.
///
/// Reads the frontmost application OUTSIDE Domain, reduces it to one
/// sanitized boolean (is the user-selected bundle frontmost?), and mints a
/// caller-built bus proposal through the Epic 3 registry/leases/bus path.
/// The public workspace API exposes no per-window text, no window content,
/// activation history — there is nothing to retain beyond the boolean, and
/// the adapter keeps it that way: app display names, process identifiers,
/// and launch dates never leave `readFrontmostBundleID`'s return value.
///
/// Ceiling (from the S2 spike): `frontmostApplication.bundleIdentifier ==
/// <selected>` refreshed on activation notifications. No polling, no
/// permission, no revocation path. A nil frontmost app (login window, no
/// GUI session) yields no snapshot and no proposal — Unknown, never a
/// negative vote.
struct FrontmostAppContextAdapter: Sendable {
    /// Independence group declared for fusion (S3): one origin, one vote.
    static let independenceGroupCode = "bundle-app"

    private let selectedBundleIdentifier: String
    private let readFrontmostBundleID: @Sendable () -> String?

    /// - Parameter selectedBundleIdentifier: user-selected rule target
    ///   (configuration, not observation — the observed bundle ID is
    ///   compared and dropped, never stored).
    /// - Parameter readFrontmostBundleID: live reader; defaults to the
    ///   public workspace frontmost-application query.
    init(
        selectedBundleIdentifier: String,
        readFrontmostBundleID: @escaping @Sendable () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
    ) {
        self.selectedBundleIdentifier = selectedBundleIdentifier
        self.readFrontmostBundleID = readFrontmostBundleID
    }

    /// Sanitized snapshot: selected-active boolean only. Nil when no GUI
    /// session is observable.
    func snapshot() -> FrontmostAppSnapshot? {
        guard let observed = readFrontmostBundleID() else { return nil }
        return FrontmostAppSnapshot(isSelectedActive: observed == selectedBundleIdentifier)
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
            source: .frontmostApp,
            reading: snapshot.isSelectedActive ? .present : .absent,
            quality: .full,
            confidence: .high,
            coverage: .partial,
            independenceGroup: EvidenceIndependenceGroup(code: Self.independenceGroupCode), // RAWGUARD-ALLOW: S3 adapter declares its fusion group
            observedTicks: observedTicks,
            timeToLiveSeconds: timeToLiveSeconds,
        )
    }
}

/// Sanitized frontmost-app state: one boolean. No strings, no dates, no
/// collections — enforced structurally by SanitizedContextAdapterTests.
struct FrontmostAppSnapshot: Equatable, Sendable {
    let isSelectedActive: Bool
}
