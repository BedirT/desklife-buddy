import Foundation

// NON-SHIPPING SPIKE — Epic 5 story S2 (issue #6).
// Stand-in for what the public EventKit API exposes per event, mirroring
// the SDK fields verified against MacOSX26.5.sdk:
//   EventKit/EKEvent.h: `startDate`, `endDate` (via EKCalendarItem),
//     `availability: EKEventAvailability` (Busy/Free/Tentative/
//     Unavailable/NotSupported), plus content fields the sanitizer drops:
//     `title`, `location`, attendees (`EKParticipant`), `url`, organizer.
// The probe NEVER instantiates EKEventStore (that would read the owner's
// real calendar into memory and need a TCC prompt). The ceiling below is
// established from the header surface + docs, not from live data.

/// Raw shape mirroring the EKEvent fields a production adapter COULD see.
public struct RawCalendarEvent: Sendable {
    public let startDate: Date
    public let endDate: Date
    public let availability: RawAvailability
    public let title: String?
    public let location: String?
    public let organizerName: String?
    public let attendeeNames: [String]
    public let url: URL?

    public init(
        startDate: Date, endDate: Date, availability: RawAvailability,
        title: String?, location: String?, organizerName: String?,
        attendeeNames: [String], url: URL?
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.availability = availability
        self.title = title
        self.location = location
        self.organizerName = organizerName
        self.attendeeNames = attendeeNames
        self.url = url
    }
}

/// Mirrors EKEventAvailability (EventKit/EKEvent.h:16-21).
public enum RawAvailability: Sendable {
    case busy
    case free
    case tentative
    case unavailable
    case notSupported
}

/// Sanitized output: busy/free + known end ONLY. No String, no URL, no
/// collection members — enforced structurally by ContextSpikeBoundaryTests.
public struct CalendarBusySnapshot: Equatable, Sendable {
    /// Whether `now` falls inside a selected-calendar busy interval.
    public let isBusy: Bool
    /// End of the covering busy interval ("After this busy time" needs a
    /// fresh known end). Nil unless `isBusy`.
    public let busyIntervalEnd: Date?
}

/// SPIKE (a) — Selected Calendar busy/free + known end.
///
/// VERDICT: VIABLE + ceiling.
/// - Ceiling: per-selected-calendar busy/free boolean + interval end,
///   derived from `EKEvent.startDate/endDate/availability` via
///   `EKEventStore.predicateForEvents(withStart:end:calendars:)`.
///   Titles, locations, organizers, attendees, URLs never leave the
///   adapter; stale/denied/unsupported emits free-with-no-end (unknown,
///   never negative).
/// - Cost: on-demand predicate fetch around `now` (no streaming, no
///   background polling); EventKit notifies via `EKEventStoreChanged`
///   notification for refresh-on-change.
/// - Denial/revocation: `EKEntityType.event` authorization required —
///   production adapter needs the owner approval gate (family 2 exit).
///   Denied/restricted → no events → free-with-no-end, feature row
///   honestly absent per INTERACTION_SPEC §11.
/// - Open S3 question (not answered here): tentative/unavailable mapping
///   is pinned to busy below; S3 adapter review may narrow it.
public enum CalendarBusyFreeProbe {
    public static func sanitize(
        events: [RawCalendarEvent],
        now: @escaping () -> Date
    ) -> CalendarBusySnapshot {
        let at = now()
        let coveringEnds = events
            .filter { $0.startDate <= at && at < $0.endDate && $0.isBusyLike }
            .map(\.endDate)
        guard let earliestEnd = coveringEnds.min() else {
            return CalendarBusySnapshot(isBusy: false, busyIntervalEnd: nil)
        }
        return CalendarBusySnapshot(isBusy: true, busyIntervalEnd: earliestEnd)
    }
}

extension RawCalendarEvent {
    /// Tentative/unavailable count as busy (conservative; S3 may narrow).
    /// NotSupported/free never do.
    fileprivate var isBusyLike: Bool {
        switch availability {
        case .busy, .tentative, .unavailable:
            return true
        case .free, .notSupported:
            return false
        }
    }
}
