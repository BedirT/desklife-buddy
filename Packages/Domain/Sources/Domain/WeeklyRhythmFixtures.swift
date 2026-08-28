import Foundation

/// Frozen privacy-safe inputs shared by weekly tests, Previews, and owner visual review.
public enum WeeklyRhythmFixtures {
    /// End of the fixed Monday-through-Sunday review interval in UTC.
    public static let referenceDate = date(day: 24)

    /// Fixed seven-day interval used by every weekly direction.
    public static let interval = makeInterval()

    /// Representative retained facts across several days and generic context sources.
    public static let populated = input(
        runs: [
            run(day: 17, hour: 9, duration: 3600),
            run(day: 17, hour: 14, duration: 1800),
            run(day: 18, hour: 18, duration: 4500),
            run(day: 20, hour: 10, duration: 3600),
        ],
        events: [
            event(EventFixture(
                id: 1,
                day: 17,
                hour: 10,
                kind: .promptPresented,
                source: .localTimer,
                opportunity: .visual,
                duration: nil,
            )),
            event(EventFixture(
                id: 2,
                day: 17,
                hour: 10,
                kind: .timerFinished,
                source: .localTimer,
                opportunity: .visual,
                duration: nil,
            )),
            event(EventFixture(
                id: 3,
                day: 18,
                hour: 18,
                kind: .breakStarted,
                source: .user,
                opportunity: .movement,
                duration: 120,
            )),
            event(EventFixture(
                id: 4,
                day: 18,
                hour: 19,
                kind: .notAppropriate,
                source: .calendarBusyFree,
                opportunity: .movement,
                duration: nil,
            )),
            event(EventFixture(
                id: 5,
                day: 20,
                hour: 11,
                kind: .likelyNaturalInterruption,
                source: .systemContext,
                opportunity: nil,
                duration: nil,
            )),
        ],
    )

    /// First-week input with facts on only one local day.
    public static let sparse = input(
        runs: [run(day: 22, hour: 10, duration: 1800)],
        events: [
            event(EventFixture(
                id: 20,
                day: 22,
                hour: 10,
                kind: .promptPresented,
                source: .localTimer,
                opportunity: .visual,
                duration: nil,
            )),
        ],
    )

    /// Enabled history with no facts in the selected interval.
    public static let empty = input(runs: [], events: [])

    /// Keep-nothing input remains disabled even if a caller accidentally supplies source facts.
    public static let historyDisabled = input(
        retention: .keepNothing,
        runs: [run(day: 22, hour: 10, duration: 1800)],
        events: [
            event(EventFixture(
                id: 30,
                day: 22,
                hour: 10,
                kind: .promptPresented,
                source: .localTimer,
                opportunity: .visual,
                duration: nil,
            )),
        ],
    )

    /// Explicitly gentler, all-hours schedule used by the future adjustment presentation state.
    public static let adjustedSchedule = input(
        schedule: SchedulePreferences(profile: .gentle, workingHoursOnly: false),
        runs: sparse.estimatedActiveUseRuns,
        events: sparse.events,
    )
}

private extension WeeklyRhythmFixtures {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func makeInterval() -> WeeklyRhythmInterval {
        do {
            return try WeeklyRhythmInterval(startedAt: date(day: 17), endedAt: referenceDate)
        } catch {
            preconditionFailure("Weekly fixture interval failed validation")
        }
    }

    static func input(
        retention: HistoryRetentionPolicy = .thirtyDays,
        schedule: SchedulePreferences = SchedulePreferences(),
        runs: [EstimatedActiveUseRun],
        events: [OpportunityEvent],
    ) -> WeeklyRhythmProjectionInput {
        WeeklyRhythmProjectionInput(
            interval: interval,
            asOf: referenceDate,
            calendar: calendar,
            retention: retention,
            schedule: schedule,
            estimatedActiveUseRuns: runs,
            events: events,
        )
    }

    static func run(day: Int, hour: Int, duration: TimeInterval) -> EstimatedActiveUseRun {
        let start = date(day: day, hour: hour)
        do {
            return try EstimatedActiveUseRun(
                startedAt: start,
                endedAt: start.addingTimeInterval(duration),
            )
        } catch {
            preconditionFailure("Weekly fixture run failed validation")
        }
    }

    static func event(_ fixture: EventFixture) -> OpportunityEvent {
        OpportunityEvent(
            id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", fixture.id))!,
            kind: fixture.kind,
            recordedAt: date(day: fixture.day, hour: fixture.hour),
            source: fixture.source,
            opportunity: fixture.opportunity,
            selectedDurationSeconds: fixture.duration,
        )
    }

    static func date(day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
        ))!
    }
}

private struct EventFixture {
    let id: Int
    let day: Int
    let hour: Int
    let kind: OpportunityEventKind
    let source: OpportunityEventSource
    let opportunity: OpportunityType?
    var duration: TimeInterval?
}
