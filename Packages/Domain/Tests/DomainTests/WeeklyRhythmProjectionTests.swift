import Foundation
import Testing
@testable import Domain

@Suite("Weekly rhythm projection")
struct WeeklyRhythmProjectionTests {
    @Test("Populated history projects descriptive daypart, run, choice, and context facts")
    func populatedFacts() throws {
        let input = WeeklyRhythmFixtures.populated

        let report = WeeklyRhythmProjection.project(input)

        #expect(report.state == .populated)
        #expect(report.estimatedActiveUseSeconds == 13500)
        #expect(report.daypartFacts == expectedPopulatedDaypartFacts)
        let expectedLongest = try EstimatedActiveUseRun(
            startedAt: fixtureDate(day: 18, hour: 18),
            endedAt: fixtureDate(day: 18, hour: 19, minute: 15),
        )
        #expect(report.longestRun == expectedLongest)
        #expect(report.eventFacts.contains(WeeklyEventFact(
            kind: .timerFinished,
            opportunity: .visual,
            count: 1,
        )))
        #expect(report.choiceFacts.contains(WeeklyChoiceFact(
            kind: .breakStarted,
            opportunity: .movement,
            selectedDurationSeconds: 120,
            count: 1,
        )))
        #expect(report.contextFacts == expectedPopulatedContextFacts)
    }

    @Test("Sparse first-week facts remain distinct from empty and history-disabled states")
    func sparseEmptyAndDisabled() {
        #expect(WeeklyRhythmProjection.project(WeeklyRhythmFixtures.sparse).state == .sparse)
        #expect(WeeklyRhythmProjection.project(WeeklyRhythmFixtures.empty).state == .empty)

        let disabled = WeeklyRhythmProjection.project(WeeklyRhythmFixtures.historyDisabled)
        #expect(disabled.state == .historyDisabled)
        #expect(disabled.estimatedActiveUseSeconds == 0)
        #expect(disabled.daypartFacts.isEmpty)
        #expect(disabled.longestRun == nil)
        #expect(disabled.eventFacts.isEmpty)
        #expect(disabled.choiceFacts.isEmpty)
        #expect(disabled.contextFacts.isEmpty)
    }

    @Test("Retention includes its exact boundary and excludes older or future facts")
    func retentionBoundary() throws {
        let now = fixtureDate(day: 31)
        let interval = try WeeklyRhythmInterval(
            startedAt: now.addingTimeInterval(-31 * day),
            endedAt: now.addingTimeInterval(day),
        )
        let boundary = now.addingTimeInterval(-30 * day)
        let beforeBoundary = boundary.addingTimeInterval(-1)
        let afterNow = now.addingTimeInterval(1)
        let input = try WeeklyRhythmProjectionInput(
            interval: interval,
            asOf: now,
            calendar: fixtureCalendar,
            retention: .thirtyDays,
            schedule: SchedulePreferences(profile: .balanced),
            estimatedActiveUseRuns: [
                EstimatedActiveUseRun(startedAt: beforeBoundary, endedAt: boundary.addingTimeInterval(60)),
                EstimatedActiveUseRun(startedAt: afterNow, endedAt: afterNow.addingTimeInterval(60)),
            ],
            events: [
                event(id: 1, kind: .promptPresented, at: beforeBoundary),
                event(id: 2, kind: .promptPresented, at: boundary),
                event(id: 3, kind: .promptPresented, at: afterNow),
            ],
        )

        let report = WeeklyRhythmProjection.project(input)

        #expect(report.estimatedActiveUseSeconds == 60)
        let expectedLongest = try EstimatedActiveUseRun(
            startedAt: boundary,
            endedAt: boundary.addingTimeInterval(60),
        )
        #expect(report.longestRun == expectedLongest)
        #expect(report.eventFacts == [WeeklyEventFact(
            kind: .promptPresented,
            opportunity: .visual,
            count: 1,
        )])
    }

    @Test("A run crossing local dayparts is split without changing its longest-run fact")
    func splitAcrossDayparts() throws {
        let run = try EstimatedActiveUseRun(
            startedAt: fixtureDate(day: 17, hour: 11, minute: 30),
            endedAt: fixtureDate(day: 17, hour: 12, minute: 30),
        )
        let input = WeeklyRhythmProjectionInput(
            interval: WeeklyRhythmFixtures.interval,
            asOf: WeeklyRhythmFixtures.referenceDate,
            calendar: fixtureCalendar,
            retention: .thirtyDays,
            schedule: SchedulePreferences(),
            estimatedActiveUseRuns: [run],
            events: [],
        )

        let report = WeeklyRhythmProjection.project(input)

        #expect(report.daypartFacts == [
            WeeklyDaypartFact(
                day: fixtureDate(day: 17),
                daypart: .morning,
                estimatedActiveUseSeconds: 1800,
            ),
            WeeklyDaypartFact(
                day: fixtureDate(day: 17),
                daypart: .afternoon,
                estimatedActiveUseSeconds: 1800,
            ),
        ])
        #expect(report.longestRun == run)
    }

    @Test("Daypart boundaries follow Vancouver wall time across nonexistent and repeated hours")
    func daylightSavingBoundaries() throws {
        let calendar = vancouverCalendar
        let springForward = try EstimatedActiveUseRun(
            startedAt: isoDate("2025-03-09T01:30:00-08:00"),
            endedAt: isoDate("2025-03-09T05:30:00-07:00"),
        )
        let fallBack = try EstimatedActiveUseRun(
            startedAt: isoDate("2025-11-02T01:30:00-07:00"),
            endedAt: isoDate("2025-11-02T05:30:00-08:00"),
        )

        let springReport = try project(run: springForward, calendar: calendar)
        let fallReport = try project(run: fallBack, calendar: calendar)

        #expect(springReport.daypartFacts.map(\.estimatedActiveUseSeconds) == [9000, 1800])
        #expect(fallReport.daypartFacts.map(\.estimatedActiveUseSeconds) == [16200, 1800])
        #expect(springReport.daypartFacts.map(\.daypart) == [.overnight, .morning])
        #expect(fallReport.daypartFacts.map(\.daypart) == [.overnight, .morning])
    }

    @Test("Overlapping and duplicate active-use runs contribute once")
    func overlappingRuns() throws {
        let first = try EstimatedActiveUseRun(
            startedAt: fixtureDate(day: 17, hour: 9),
            endedAt: fixtureDate(day: 17, hour: 10),
        )
        let overlapping = try EstimatedActiveUseRun(
            startedAt: fixtureDate(day: 17, hour: 9, minute: 30),
            endedAt: fixtureDate(day: 17, hour: 10, minute: 30),
        )
        let input = WeeklyRhythmProjectionInput(
            interval: WeeklyRhythmFixtures.interval,
            asOf: WeeklyRhythmFixtures.referenceDate,
            calendar: fixtureCalendar,
            retention: .thirtyDays,
            schedule: SchedulePreferences(),
            estimatedActiveUseRuns: [first, first, overlapping],
            events: [],
        )

        let report = WeeklyRhythmProjection.project(input)
        let merged = try EstimatedActiveUseRun(
            startedAt: first.startedAt,
            endedAt: overlapping.endedAt,
        )

        #expect(report.estimatedActiveUseSeconds == 5400)
        #expect(report.daypartFacts.map(\.estimatedActiveUseSeconds) == [5400])
        #expect(report.longestRun == merged)
    }

    @Test("Context deferrals remain separated by local daypart and exact reason")
    func contextDayparts() {
        let fixture = WeeklyRhythmFixtures.populated
        let input = WeeklyRhythmProjectionInput(
            interval: fixture.interval,
            asOf: fixture.asOf,
            calendar: fixture.calendar,
            retention: fixture.retention,
            schedule: fixture.schedule,
            estimatedActiveUseRuns: [],
            events: [
                contextEvent(id: 41, day: 17, hour: 10),
                contextEvent(id: 42, day: 18, hour: 11),
                contextEvent(id: 43, day: 18, hour: 18),
            ],
        )

        let report = WeeklyRhythmProjection.project(input)

        #expect(report.contextFacts == [
            WeeklyContextFact(
                kind: .notAppropriate,
                source: .calendarBusyFree,
                opportunity: .movement,
                daypart: .morning,
                count: 2,
            ),
            WeeklyContextFact(
                kind: .notAppropriate,
                source: .calendarBusyFree,
                opportunity: .movement,
                daypart: .evening,
                count: 1,
            ),
        ])
    }

    @Test("Timer completion is not inferred as a user choice or health outcome")
    func noInferredOutcome() {
        let report = WeeklyRhythmProjection.project(WeeklyRhythmFixtures.populated)

        #expect(report.eventFacts.contains { $0.kind == .timerFinished })
        #expect(!report.choiceFacts.contains { $0.kind == .timerFinished })
        #expect(!report.choiceFacts.contains { $0.kind == .promptPresented })
    }

    @Test("Weekly values expose no app names, comparison, score, grade, or streak fields")
    func privacyAndNonJudgmentContract() {
        let report = WeeklyRhythmProjection.project(WeeklyRhythmFixtures.populated)
        let labels = storedPropertyLabels(in: report)
        let forbidden = ["app", "bundle", "comparison", "previous", "score", "grade", "streak", "outcome"]

        #expect(forbidden.allSatisfy { term in
            !labels.contains(where: { $0.localizedCaseInsensitiveContains(term) })
        })
        #expect(!String(describing: report).contains("com.example"))
    }

    @Test("Adjusted schedule fixture reports only the current explicit schedule choices")
    func adjustedSchedule() {
        let report = WeeklyRhythmProjection.project(WeeklyRhythmFixtures.adjustedSchedule)

        #expect(report.schedule == WeeklyScheduleFact(
            profileID: .gentle,
            workingHoursOnly: false,
        ))
    }
}

private let day: TimeInterval = 24 * 60 * 60

private var expectedPopulatedDaypartFacts: [WeeklyDaypartFact] {
    [
        WeeklyDaypartFact(
            day: fixtureDate(day: 17),
            daypart: .morning,
            estimatedActiveUseSeconds: 3600,
        ),
        WeeklyDaypartFact(
            day: fixtureDate(day: 17),
            daypart: .afternoon,
            estimatedActiveUseSeconds: 1800,
        ),
        WeeklyDaypartFact(
            day: fixtureDate(day: 18),
            daypart: .evening,
            estimatedActiveUseSeconds: 4500,
        ),
        WeeklyDaypartFact(
            day: fixtureDate(day: 20),
            daypart: .morning,
            estimatedActiveUseSeconds: 3600,
        ),
    ]
}

private var expectedPopulatedContextFacts: [WeeklyContextFact] {
    [
        WeeklyContextFact(
            kind: .notAppropriate,
            source: .calendarBusyFree,
            opportunity: .movement,
            daypart: .evening,
            count: 1,
        ),
        WeeklyContextFact(
            kind: .likelyNaturalInterruption,
            source: .systemContext,
            opportunity: nil,
            daypart: .morning,
            count: 1,
        ),
    ]
}

private var fixtureCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

private var vancouverCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Vancouver")!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

private func fixtureDate(day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    fixtureCalendar.date(from: DateComponents(
        year: 2026,
        month: 8,
        day: day,
        hour: hour,
        minute: minute,
    ))!
}

private func event(
    id: Int,
    kind: OpportunityEventKind,
    at date: Date,
) -> OpportunityEvent {
    OpportunityEvent(
        id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", id))!,
        kind: kind,
        recordedAt: date,
        source: .localTimer,
        opportunity: .visual,
    )
}

private func contextEvent(id: Int, day: Int, hour: Int) -> OpportunityEvent {
    OpportunityEvent(
        id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", id))!,
        kind: .notAppropriate,
        recordedAt: fixtureDate(day: day, hour: hour),
        source: .calendarBusyFree,
        opportunity: .movement,
    )
}

private func isoDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func project(
    run: EstimatedActiveUseRun,
    calendar: Calendar,
) throws -> WeeklyRhythmReport {
    let dayStart = calendar.startOfDay(for: run.startedAt)
    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
    return try WeeklyRhythmProjection.project(WeeklyRhythmProjectionInput(
        interval: WeeklyRhythmInterval(startedAt: dayStart, endedAt: dayEnd),
        asOf: dayEnd,
        calendar: calendar,
        retention: .thirtyDays,
        schedule: SchedulePreferences(),
        estimatedActiveUseRuns: [run],
        events: [],
    ))
}

private func storedPropertyLabels(in value: Any) -> [String] {
    let mirror = Mirror(reflecting: value)
    return mirror.children.flatMap { child in
        let own = child.label.map { [$0] } ?? []
        return own + storedPropertyLabels(in: child.value)
    }
}
