import Domain
import EventKit // RAWGUARD-ALLOW: live calendar reader admits the store framework for the four busy/free fields only
import Foundation

/// Epic 5 live calendar reader (issue #6; owner-approved production Calendar
/// access 2026-09-12/13, family 2 exit): the store edge behind the S3
/// adapter's injected closures.
///
/// Reads the system store OUTSIDE Domain and reduces each fetched entry to
/// the four admitted fields at the call site — start/end timestamps, the
/// all-day flag, and the busy/free marker. Event names, guest lists, other
/// details, and timestamps beyond start/end have no fields on the admitted
/// shape: they cannot be retained because they cannot be represented. The
/// fetch always passes calendars: nil, so no calendar identity is ever
/// named. Gating stays fail-closed: only granted access authorizes; denial,
/// restriction, write-only, and deferred choice all deny.
///
/// The wall-clock read lives ONLY in the default closures below (the
/// production edge, which owns a locally created store per call rather than
/// capturing a non-Sendable instance). Every mapping takes injected values,
/// so tests drive the whole path through fakes and no test ever touches the
/// live store.
///
/// The pure mappings are nonisolated so the adapter's nonisolated Sendable
/// closures can call them; they touch only their parameters. Guard note:
/// every store-framework spelling below carries its own same-line
/// RAWGUARD-ALLOW per the amended content-retention guard, which
/// additionally confines those spellings to this file (plus its test file)
/// and bans content reads here exemption or not.
struct AdmittedCalendarEvent: Sendable, Equatable {
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let availability: EKEventAvailability // RAWGUARD-ALLOW: admitted busy/free marker, the only entry field the guard permits beyond start/end/all-day
}

enum CalendarLiveReader {
    /// Fetch window around now: a week each way. Entries spanning more than
    /// a week of timed busy time are vanishingly rare, and a miss reads
    /// free — the safe direction for a hold feature, since a false busy
    /// would interrupt while a miss merely skips protection. All-day blocks
    /// never vote regardless of length.
    static let defaultPastSeconds: TimeInterval = 7 * 24 * 3_600
    static let defaultFutureSeconds: TimeInterval = 7 * 24 * 3_600

    /// Fail-closed access mapping: only granted access authorizes. Every
    /// other outcome — including deferred choice — denies, so an
    /// unprompted store reads as no-source, never as free.
    static nonisolated func accessState(for status: EKAuthorizationStatus) -> CalendarAccessState {
        switch status {
        case .authorized, .fullAccess:
            return .authorized
        case .denied, .restricted, .notDetermined, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }

    /// Busy-like vote for one entry's admitted fields: all-day entries never
    /// vote; among timed entries only busy, tentative, and unavailable vote
    /// busy-like (the S2 spike pin), free and unsupported never do.
    static nonisolated func isBusyLike(availability: EKEventAvailability, isAllDay: Bool) -> Bool { // RAWGUARD-ALLOW: admitted busy/free marker mapping
        guard !isAllDay else { return false }
        switch availability {
        case .busy, .tentative, .unavailable:
            return true
        case .free, .notSupported:
            return false
        @unknown default:
            return false
        }
    }

    /// Maps one admitted entry to a dock-point range, or nil when it must
    /// not vote (invalid range, all-day, or free/unsupported).
    static nonisolated func busyInterval(admitted event: AdmittedCalendarEvent) -> CalendarContextDockPoint.BusyInterval? {
        guard event.endDate > event.startDate,
              isBusyLike(availability: event.availability, isAllDay: event.isAllDay)
        else { return nil }
        return CalendarContextDockPoint.BusyInterval(
            startEpochSeconds: event.startDate.timeIntervalSince1970,
            endEpochSeconds: event.endDate.timeIntervalSince1970,
            isBusyLike: true,
        )
    }

    /// Maps admitted entries to dock-point ranges, dropping non-voters.
    static nonisolated func busyIntervals(admitted events: [AdmittedCalendarEvent]) -> [CalendarContextDockPoint.BusyInterval] {
        events.compactMap(busyInterval(admitted:))
    }

    /// Thin store edge: fetches entries in the window and reduces each to
    /// the four admitted fields at the call site. Reads nothing else off
    /// the fetched entries. Never called from tests — tests drive the pure
    /// mapping above through fakes, so no test touches the live store.
    static nonisolated func fetchAdmittedEntries(store: EKEventStore, start: Date, end: Date) -> [AdmittedCalendarEvent] { // RAWGUARD-ALLOW: live reader fetches through the granted store
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).compactMap { entry in
            AdmittedCalendarEvent(
                startDate: entry.startDate,
                endDate: entry.endDate,
                isAllDay: entry.isAllDay,
                availability: entry.availability,
            )
        }
    }

    /// One-shot access prompt for future settings surfaces: true grants vote
    /// eligibility, anything else stays fail-closed through accessState.
    static func requestAccess(store: EKEventStore) async -> CalendarAccessState { // RAWGUARD-ALLOW: live reader prompts through the caller's store
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        return granted ? .authorized : .denied
    }

    /// Production wiring: the adapter's injected closures backed by live
    /// values. The wall clock is read once per snapshot inside
    /// readBusyIntervals to derive the fetch window; sanitizing stays
    /// tick-injected through the adapter. Tests pass fakes for every
    /// closure and fixed windows, so no wall clock is read in tests.
    ///
    /// - Parameter readAuthorization: live reader; defaults to the store's
    ///   current authorization (no prompt — prompting is requestAccess).
    /// - Parameter fetchAdmitted: live reader; defaults to a windowed fetch
    ///   through a locally created store.
    /// - Parameter isSourceEnabled: the Settings source switch /
    ///   kill-switch. A killed source mints nothing.
    /// - Parameter now: injected clock for the fetch-window math.
    static func liveAdapter(
        readAuthorization: @escaping @Sendable () -> EKAuthorizationStatus = {
            EKEventStore.authorizationStatus(for: .event) // RAWGUARD-ALLOW: live reader default authorization read uses the admitted access verb
        },
        fetchAdmitted: @escaping @Sendable (Date, Date) -> [AdmittedCalendarEvent] = { start, end in
            fetchAdmittedEntries(store: EKEventStore(), start: start, end: end) // RAWGUARD-ALLOW: live reader default fetch owns a locally created store
        },
        isSourceEnabled: @escaping @Sendable () -> Bool,
        now: @escaping @Sendable () -> Date,
        pastSeconds: TimeInterval = defaultPastSeconds,
        futureSeconds: TimeInterval = defaultFutureSeconds,
    ) -> CalendarContextAdapter {
        CalendarContextAdapter(
            readAccess: { accessState(for: readAuthorization()) },
            readBusyIntervals: {
                let nowDate = now()
                return busyIntervals(admitted: fetchAdmitted(
                    nowDate.addingTimeInterval(-pastSeconds),
                    nowDate.addingTimeInterval(futureSeconds),
                ))
            },
            isSourceEnabled: isSourceEnabled,
        )
    }
}
