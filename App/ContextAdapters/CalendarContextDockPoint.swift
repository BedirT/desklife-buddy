import Foundation

/// Epic 5 story S3 (issue #6): calendar DOCK POINT — not an adapter.
///
/// Production calendar access is pending owner approval (family 2 exit,
/// still open). Until the owner approves, NO production code may read the
/// system calendar store, import its framework, or request its
/// authorization — and this file does none of those. It defines ONLY the
/// sanitized boundary the future approved reader must reduce to, so the
/// ceiling proven by the S2 spike is pinned in product code without
/// touching any protected API:
///
/// - Input: busy-like intervals as bare epoch-second ranges plus a denial
///   flag. Entry titles, locations, organizers, guest lists, and links
///   have no fields here — they cannot be retained because they cannot be
///   represented.
/// - Output: busy/free boolean plus the covering interval's known end
///   ("After this busy time" needs a fresh known end), or free-with-no-end
///   for outside/denied/unsupported (Unknown, never negative).
///
/// Approval-gated follow-ups (do NOT land here without the owner exit):
///  1. A store reader mapping the system's busy/free fields to
///     `BusyInterval` values (titles and guests dropped at the call site).
///  2. A registry provider plus bus-source vocabulary pair and the proposal
///     minting that rides the Epic 3 registry/leases/bus path with
///     independence group "calendar".
///  3. The tentative/unavailable mapping review the spike left open.
enum CalendarContextDockPoint {
    /// Independence group reserved for the future adapter (S4 fusion):
    /// the calendar is its own origin, independent of the app, device,
    /// and declaration groups.
    static let independenceGroupCode = "calendar"

    /// One busy-like interval in epoch seconds. The busy-like judgment
    /// (busy/tentative/unavailable vs free/unsupported) is made by the
    /// future approved reader; this shape carries only its verdict.
    struct BusyInterval: Sendable {
        let startEpochSeconds: TimeInterval
        let endEpochSeconds: TimeInterval
        let isBusyLike: Bool
    }

    /// Sanitized calendar state: booleans plus epoch-second ticks only. No
    /// strings, no dates, no URLs, no collections — enforced structurally
    /// by SanitizedContextAdapterTests.
    struct Snapshot: Equatable, Sendable {
        let isBusy: Bool
        let busyIntervalEndEpochSeconds: TimeInterval?
        let accessDenied: Bool
    }

    /// Reduces intervals to the sanitized snapshot. Denied access yields
    /// free-with-denial; no covering busy-like interval yields
    /// free-with-no-end.
    static func sanitize(
        intervals: [BusyInterval],
        nowEpochSeconds: TimeInterval,
        accessDenied: Bool,
    ) -> Snapshot {
        guard !accessDenied else {
            return Snapshot(isBusy: false, busyIntervalEndEpochSeconds: nil, accessDenied: true)
        }
        let coveringEnds = intervals
            .filter { $0.isBusyLike && $0.startEpochSeconds <= nowEpochSeconds && nowEpochSeconds < $0.endEpochSeconds }
            .map(\.endEpochSeconds)
        guard let earliestEnd = coveringEnds.min() else {
            return Snapshot(isBusy: false, busyIntervalEndEpochSeconds: nil, accessDenied: false)
        }
        return Snapshot(isBusy: true, busyIntervalEndEpochSeconds: earliestEnd, accessDenied: false)
    }
}
