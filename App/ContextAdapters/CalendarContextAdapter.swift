import Domain
import Foundation

/// Epic 5 Calendar adapter (issue #6): selected-calendar busy/free source.
///
/// Production Calendar access is owner-approved (2026-09-12, family 2
/// exit). The system calendar store is read OUTSIDE Domain and reduced
/// here to one sanitized boolean (is now inside a selected busy-like
/// interval?) plus the covering interval's known end ("After this busy
/// time" needs a fresh known end). Interval names, guest lists, locations,
/// and links have no fields on the input shape — they cannot be retained
/// because they cannot be represented. The approved store reader maps the
/// store's busy/free fields to `BusyInterval` values (busy, tentative, and
/// unavailable count as busy-like per the S2 spike pin; free and
/// unsupported never do) and drops everything else at the call site.
///
/// Access-gated and fail-closed: without granted store access the adapter
/// mints nothing — denial reads as no-source (Unknown at fusion), never as
/// free. A disabled source (Settings switch / kill-switch) likewise mints
/// nothing, so revocation drains by lease invalidation plus TTL expiry with
/// no replacement proposals. Ticks are injected: no wall clock is read.
///
/// Guard note: the content-retention guard bans store-framework symbols in
/// product code with no exemptions, so the live store call itself is a
/// named follow-up (guard amendment plus adversarial review). This file
/// owns the gate, the sanitize boundary, and the bus minting, all behind
/// injected closures — the same seam the other S3 adapters use.
enum CalendarAccessState: Sendable {
    /// Store access granted: intervals may be sanitized and minted.
    case authorized
    /// Store access denied, restricted, or not yet granted: fail closed.
    case denied
}

struct CalendarContextAdapter: Sendable {
    /// Independence group declared for fusion: the calendar is its own
    /// origin, independent of the app, device, and declaration groups —
    /// sharing a group with any of them would falsely collapse two
    /// independent votes into one.
    static let independenceGroupCode = CalendarContextDockPoint.independenceGroupCode

    private let readAccess: @Sendable () -> CalendarAccessState
    private let readBusyIntervals: @Sendable () -> [CalendarContextDockPoint.BusyInterval]
    private let isSourceEnabled: @Sendable () -> Bool

    /// - Parameter readAccess: requestAccess-gated store authorization.
    ///   The live reader reports `.authorized` only after the store grants
    ///   access; every other outcome reports `.denied`.
    /// - Parameter readBusyIntervals: bare busy-like ranges in epoch
    ///   seconds, mapped by the reader with all content dropped.
    /// - Parameter isSourceEnabled: the Settings source switch /
    ///   kill-switch. A killed source mints nothing.
    init(
        readAccess: @escaping @Sendable () -> CalendarAccessState,
        readBusyIntervals: @escaping @Sendable () -> [CalendarContextDockPoint.BusyInterval],
        isSourceEnabled: @escaping @Sendable () -> Bool,
    ) {
        self.readAccess = readAccess
        self.readBusyIntervals = readBusyIntervals
        self.isSourceEnabled = isSourceEnabled
    }

    /// Sanitized snapshot: busy boolean plus known end ticks only. Nil when
    /// the source is disabled or access is denied — no-source, never free.
    func snapshot(nowEpochSeconds: TimeInterval) -> CalendarSnapshot? {
        guard isSourceEnabled(), readAccess() == .authorized else { return nil }
        let sanitized = CalendarContextDockPoint.sanitize(
            intervals: readBusyIntervals(),
            nowEpochSeconds: nowEpochSeconds,
            accessDenied: false,
        )
        return CalendarSnapshot(
            isBusy: sanitized.isBusy,
            busyIntervalEndEpochSeconds: sanitized.busyIntervalEndEpochSeconds,
        )
    }

    /// Sanitized proposal for the bus: ambient-kind reading (a lone busy
    /// window stays ambient/menu-only per the single-weak-signal rule),
    /// full quality, high confidence, partial coverage. Nil when there is
    /// nothing to report.
    func proposal(
        observedTicks: TimeInterval,
        nowEpochSeconds: TimeInterval,
        timeToLiveSeconds: TimeInterval = 30,
    ) throws -> EvidenceProposal? { // RAWGUARD-ALLOW: calendar adapter mints caller-built bus proposals
        guard let snapshot = snapshot(nowEpochSeconds: nowEpochSeconds) else { return nil }
        return try EvidenceProposal( // RAWGUARD-ALLOW: calendar adapter mints caller-built bus proposals
            kind: .ambient,
            source: .calendar,
            reading: snapshot.isBusy ? .present : .absent,
            quality: .full,
            confidence: .high,
            coverage: .partial,
            independenceGroup: EvidenceIndependenceGroup(code: Self.independenceGroupCode), // RAWGUARD-ALLOW: calendar adapter declares its fusion group
            observedTicks: observedTicks,
            timeToLiveSeconds: timeToLiveSeconds,
        )
    }
}

/// Sanitized calendar state: one boolean plus end ticks. No strings, no
/// dates, no URLs, no collections — enforced structurally by
/// CalendarContextAdapterTests.
struct CalendarSnapshot: Equatable, Sendable {
    let isBusy: Bool
    let busyIntervalEndEpochSeconds: TimeInterval?
}
