import Foundation

/// Deterministic aggregation of retained facts for the user-initiated weekly reflection.
public enum WeeklyRhythmProjection {
    /// Projects exact source facts while preserving event distinctions and retention boundaries.
    public static func project(_ input: WeeklyRhythmProjectionInput) -> WeeklyRhythmReport {
        let schedule = WeeklyScheduleFact(
            profileID: input.schedule.profile.protocolProfileID,
            workingHoursOnly: input.schedule.workingHoursOnly,
        )
        guard input.retention != .keepNothing else {
            return emptyReport(input: input, state: .historyDisabled, schedule: schedule)
        }

        let range = retainedRange(input)
        let runs = retainedRuns(input.estimatedActiveUseRuns, in: range)
        let events = retainedEvents(input.events, in: range)
        guard !runs.isEmpty || !events.isEmpty else {
            return emptyReport(input: input, state: .empty, schedule: schedule)
        }

        let daypartFacts = aggregateDayparts(runs, calendar: input.calendar)
        let factDays = Set(
            daypartFacts.map(\.day)
                + events.map { input.calendar.startOfDay(for: $0.recordedAt) },
        )
        let state: WeeklyRhythmDataState = factDays.count < 3 ? .sparse : .populated
        return WeeklyRhythmReport(
            interval: input.interval,
            state: state,
            schedule: schedule,
            estimatedActiveUseSeconds: runs.reduce(0) { $0 + $1.durationSeconds },
            daypartFacts: daypartFacts,
            longestRun: longestRun(in: runs),
            eventFacts: aggregateEvents(events),
            choiceFacts: aggregateChoices(events),
            contextFacts: aggregateContexts(events, calendar: input.calendar),
        )
    }
}

private extension WeeklyRhythmProjection {
    struct FactRange {
        let start: Date
        let end: Date
    }

    struct DaypartKey: Hashable {
        let day: Date
        let daypart: WeeklyDaypart
    }

    struct EventKey: Equatable {
        let kind: OpportunityEventKind
        let opportunity: OpportunityType?
    }

    struct ChoiceKey: Equatable {
        let kind: OpportunityEventKind
        let opportunity: OpportunityType?
        let selectedDurationSeconds: TimeInterval?
    }

    struct ContextKey: Equatable {
        let kind: OpportunityEventKind
        let source: OpportunityEventSource
        let opportunity: OpportunityType?
        let daypart: WeeklyDaypart
    }

    static func emptyReport(
        input: WeeklyRhythmProjectionInput,
        state: WeeklyRhythmDataState,
        schedule: WeeklyScheduleFact,
    ) -> WeeklyRhythmReport {
        WeeklyRhythmReport(
            interval: input.interval,
            state: state,
            schedule: schedule,
            estimatedActiveUseSeconds: 0,
            daypartFacts: [],
            longestRun: nil,
            eventFacts: [],
            choiceFacts: [],
            contextFacts: [],
        )
    }

    static func retainedRange(_ input: WeeklyRhythmProjectionInput) -> FactRange {
        let cutoff = input.asOf.addingTimeInterval(-input.retention.retentionDurationSeconds)
        return FactRange(
            start: max(input.interval.startedAt, cutoff),
            end: min(input.interval.endedAt, input.asOf),
        )
    }

    static func retainedRuns(
        _ runs: [EstimatedActiveUseRun],
        in range: FactRange,
    ) -> [EstimatedActiveUseRun] {
        guard range.start < range.end else { return [] }
        let clipped: [EstimatedActiveUseRun] = runs.compactMap { run in
            let start = max(run.startedAt, range.start)
            let end = min(run.endedAt, range.end)
            guard start < end else { return nil }
            return try? EstimatedActiveUseRun(startedAt: start, endedAt: end)
        }
        .sorted {
            if $0.startedAt != $1.startedAt { return $0.startedAt < $1.startedAt }
            return $0.endedAt < $1.endedAt
        }
        return clipped.reduce(into: []) { merged, run in
            guard let last = merged.last, run.startedAt <= last.endedAt else {
                merged.append(run)
                return
            }
            guard let combined = try? EstimatedActiveUseRun(
                startedAt: last.startedAt,
                endedAt: max(last.endedAt, run.endedAt),
            ) else {
                return
            }
            merged[merged.endIndex - 1] = combined
        }
    }

    static func retainedEvents(
        _ events: [OpportunityEvent],
        in range: FactRange,
    ) -> [OpportunityEvent] {
        guard range.start < range.end else { return [] }
        return events
            .filter { $0.recordedAt >= range.start && $0.recordedAt < range.end }
            .sorted {
                if $0.recordedAt != $1.recordedAt { return $0.recordedAt < $1.recordedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    static func aggregateDayparts(
        _ runs: [EstimatedActiveUseRun],
        calendar: Calendar,
    ) -> [WeeklyDaypartFact] {
        var totals: [DaypartKey: TimeInterval] = [:]
        for run in runs {
            var cursor = run.startedAt
            while cursor < run.endedAt {
                let nextBoundary = min(daypartBoundary(after: cursor, calendar: calendar), run.endedAt)
                let key = DaypartKey(
                    day: calendar.startOfDay(for: cursor),
                    daypart: daypart(at: cursor, calendar: calendar),
                )
                totals[key, default: 0] += nextBoundary.timeIntervalSince(cursor)
                cursor = nextBoundary
            }
        }
        return totals.map { key, seconds in
            WeeklyDaypartFact(
                day: key.day,
                daypart: key.daypart,
                estimatedActiveUseSeconds: seconds,
            )
        }
        .sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.daypart.rawValue < $1.daypart.rawValue
        }
    }

    static func daypart(at date: Date, calendar: Calendar) -> WeeklyDaypart {
        switch calendar.component(.hour, from: date) {
        case 5 ..< 12: .morning
        case 12 ..< 17: .afternoon
        case 17 ..< 22: .evening
        default: .overnight
        }
    }

    static func daypartBoundary(after date: Date, calendar: Calendar) -> Date {
        let hour = calendar.component(.hour, from: date)
        let boundaryHour: Int
        let dayOffset: Int
        switch hour {
        case 0 ..< 5:
            boundaryHour = 5
            dayOffset = 0
        case 5 ..< 12:
            boundaryHour = 12
            dayOffset = 0
        case 12 ..< 17:
            boundaryHour = 17
            dayOffset = 0
        case 17 ..< 22:
            boundaryHour = 22
            dayOffset = 0
        default:
            boundaryHour = 0
            dayOffset = 1
        }
        let boundaryDay = calendar.date(byAdding: .day, value: dayOffset, to: date) ?? date
        var components = calendar.dateComponents([.era, .year, .month, .day], from: boundaryDay)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.hour = boundaryHour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    static func longestRun(in runs: [EstimatedActiveUseRun]) -> EstimatedActiveUseRun? {
        runs.max {
            if $0.durationSeconds != $1.durationSeconds {
                return $0.durationSeconds < $1.durationSeconds
            }
            return $0.startedAt > $1.startedAt
        }
    }

    static func aggregateEvents(_ events: [OpportunityEvent]) -> [WeeklyEventFact] {
        var keys: [EventKey] = []
        var counts: [Int] = []
        for event in events {
            let key = EventKey(kind: event.kind, opportunity: event.opportunity)
            if let index = keys.firstIndex(of: key) {
                counts[index] += 1
            } else {
                keys.append(key)
                counts.append(1)
            }
        }
        return zip(keys, counts).map { key, count in
            WeeklyEventFact(kind: key.kind, opportunity: key.opportunity, count: count)
        }
    }

    static func aggregateChoices(_ events: [OpportunityEvent]) -> [WeeklyChoiceFact] {
        let choiceKinds: Set<OpportunityEventKind> = [
            .breakStarted,
            .userDeclaredCompleted,
            .userDeclaredAlreadyMoved,
            .positionChanged,
            .snoozed,
            .skipped,
            .notAppropriate,
        ]
        var keys: [ChoiceKey] = []
        var counts: [Int] = []
        for event in events where event.source == .user && choiceKinds.contains(event.kind) {
            let key = ChoiceKey(
                kind: event.kind,
                opportunity: event.opportunity,
                selectedDurationSeconds: event.selectedDurationSeconds,
            )
            if let index = keys.firstIndex(of: key) {
                counts[index] += 1
            } else {
                keys.append(key)
                counts.append(1)
            }
        }
        return zip(keys, counts).map { key, count in
            WeeklyChoiceFact(
                kind: key.kind,
                opportunity: key.opportunity,
                selectedDurationSeconds: key.selectedDurationSeconds,
                count: count,
            )
        }
    }

    static func aggregateContexts(
        _ events: [OpportunityEvent],
        calendar: Calendar,
    ) -> [WeeklyContextFact] {
        var keys: [ContextKey] = []
        var counts: [Int] = []
        for event in events where event.kind == .notAppropriate || event.kind == .likelyNaturalInterruption {
            let key = ContextKey(
                kind: event.kind,
                source: event.source,
                opportunity: event.opportunity,
                daypart: daypart(at: event.recordedAt, calendar: calendar),
            )
            if let index = keys.firstIndex(of: key) {
                counts[index] += 1
            } else {
                keys.append(key)
                counts.append(1)
            }
        }
        return zip(keys, counts).map { key, count in
            WeeklyContextFact(
                kind: key.kind,
                source: key.source,
                opportunity: key.opportunity,
                daypart: key.daypart,
                count: count,
            )
        }
    }
}
