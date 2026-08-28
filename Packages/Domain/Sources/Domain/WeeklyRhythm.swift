import Foundation

/// Invalid deterministic time ranges rejected before a weekly read is projected.
public enum WeeklyRhythmValidationError: Error, Equatable {
    case invalidInterval
    case invalidActiveUseRun
}

/// A caller-selected reporting range with an exclusive end.
public struct WeeklyRhythmInterval: Equatable, Sendable {
    public let startedAt: Date
    public let endedAt: Date

    /// Creates a finite, non-empty reporting range without consulting the wall clock.
    public init(startedAt: Date, endedAt: Date) throws {
        guard startedAt.timeIntervalSinceReferenceDate.isFinite,
              endedAt.timeIntervalSinceReferenceDate.isFinite,
              startedAt < endedAt
        else {
            throw WeeklyRhythmValidationError.invalidInterval
        }
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

/// One already-estimated span of active computer interaction, not a claim about sitting or work.
public struct EstimatedActiveUseRun: Equatable, Sendable {
    public let startedAt: Date
    public let endedAt: Date

    /// Creates an observed aggregate span without deriving it from opportunity events.
    public init(startedAt: Date, endedAt: Date) throws {
        guard startedAt.timeIntervalSinceReferenceDate.isFinite,
              endedAt.timeIntervalSinceReferenceDate.isFinite,
              startedAt < endedAt
        else {
            throw WeeklyRhythmValidationError.invalidActiveUseRun
        }
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// The estimated active-use duration represented by this exact span.
    public var durationSeconds: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}

/// Coarse local-time buckets used to describe when retained active-use facts occurred.
public enum WeeklyDaypart: Int, CaseIterable, Equatable, Sendable {
    case overnight
    case morning
    case afternoon
    case evening
}

/// Estimated active-use duration for one local day and coarse daypart.
public struct WeeklyDaypartFact: Equatable, Sendable {
    public let day: Date
    public let daypart: WeeklyDaypart
    public let estimatedActiveUseSeconds: TimeInterval

    /// Creates an already aggregated descriptive time bucket.
    public init(
        day: Date,
        daypart: WeeklyDaypart,
        estimatedActiveUseSeconds: TimeInterval,
    ) {
        self.day = day
        self.daypart = daypart
        self.estimatedActiveUseSeconds = estimatedActiveUseSeconds
    }
}

/// Count of one exact canonical event kind and opportunity pair.
public struct WeeklyEventFact: Equatable, Sendable {
    public let kind: OpportunityEventKind
    public let opportunity: OpportunityType?
    public let count: Int

    /// Creates a neutral count without combining event kinds into completion semantics.
    public init(kind: OpportunityEventKind, opportunity: OpportunityType?, count: Int) {
        self.kind = kind
        self.opportunity = opportunity
        self.count = count
    }
}

/// Count of one explicit user-authored event and its exact selected duration, when present.
public struct WeeklyChoiceFact: Equatable, Sendable {
    public let kind: OpportunityEventKind
    public let opportunity: OpportunityType?
    public let selectedDurationSeconds: TimeInterval?
    public let count: Int

    /// Creates a choice count without assigning success or health-outcome meaning.
    public init(
        kind: OpportunityEventKind,
        opportunity: OpportunityType?,
        selectedDurationSeconds: TimeInterval?,
        count: Int,
    ) {
        self.kind = kind
        self.opportunity = opportunity
        self.selectedDurationSeconds = selectedDurationSeconds
        self.count = count
    }
}

/// Count of an exact privacy-minimized context event, generic source, and local daypart.
public struct WeeklyContextFact: Equatable, Sendable {
    public let kind: OpportunityEventKind
    public let source: OpportunityEventSource
    public let opportunity: OpportunityType?
    public let daypart: WeeklyDaypart
    public let count: Int

    /// Creates a local-time context count that cannot carry application or Calendar content names.
    public init(
        kind: OpportunityEventKind,
        source: OpportunityEventSource,
        opportunity: OpportunityType?,
        daypart: WeeklyDaypart,
        count: Int,
    ) {
        self.kind = kind
        self.source = source
        self.opportunity = opportunity
        self.daypart = daypart
        self.count = count
    }
}

/// Current explicit schedule selections included only as adjustment context.
public struct WeeklyScheduleFact: Equatable, Sendable {
    public let profileID: ProtocolProfileID
    public let workingHoursOnly: Bool

    /// Creates a current-choice fact without comparing it with an earlier schedule.
    public init(profileID: ProtocolProfileID, workingHoursOnly: Bool) {
        self.profileID = profileID
        self.workingHoursOnly = workingHoursOnly
    }
}

/// Honest availability of the retained facts for the selected reporting interval.
public enum WeeklyRhythmDataState: Equatable, Sendable {
    case historyDisabled
    case empty
    case sparse
    case populated
}

/// Pure input to the weekly read projection; storage and presentation remain separate.
public struct WeeklyRhythmProjectionInput: Sendable {
    public let interval: WeeklyRhythmInterval
    public let asOf: Date
    public let calendar: Calendar
    public let retention: HistoryRetentionPolicy
    public let schedule: SchedulePreferences
    public let estimatedActiveUseRuns: [EstimatedActiveUseRun]
    public let events: [OpportunityEvent]

    /// Creates deterministic projection input from already observed and retained source facts.
    public init(
        interval: WeeklyRhythmInterval,
        asOf: Date,
        calendar: Calendar,
        retention: HistoryRetentionPolicy,
        schedule: SchedulePreferences,
        estimatedActiveUseRuns: [EstimatedActiveUseRun],
        events: [OpportunityEvent],
    ) {
        self.interval = interval
        self.asOf = asOf
        self.calendar = calendar
        self.retention = retention
        self.schedule = schedule
        self.estimatedActiveUseRuns = estimatedActiveUseRuns
        self.events = events
    }
}

/// Descriptive weekly facts with no scores, comparisons, application names, or inferred outcomes.
public struct WeeklyRhythmReport: Equatable, Sendable {
    public let interval: WeeklyRhythmInterval
    public let state: WeeklyRhythmDataState
    public let schedule: WeeklyScheduleFact
    public let estimatedActiveUseSeconds: TimeInterval
    public let daypartFacts: [WeeklyDaypartFact]
    public let longestRun: EstimatedActiveUseRun?
    public let eventFacts: [WeeklyEventFact]
    public let choiceFacts: [WeeklyChoiceFact]
    public let contextFacts: [WeeklyContextFact]

    /// Creates one immutable read result for formatting by a future Weekly feature.
    public init(
        interval: WeeklyRhythmInterval,
        state: WeeklyRhythmDataState,
        schedule: WeeklyScheduleFact,
        estimatedActiveUseSeconds: TimeInterval,
        daypartFacts: [WeeklyDaypartFact],
        longestRun: EstimatedActiveUseRun?,
        eventFacts: [WeeklyEventFact],
        choiceFacts: [WeeklyChoiceFact],
        contextFacts: [WeeklyContextFact],
    ) {
        self.interval = interval
        self.state = state
        self.schedule = schedule
        self.estimatedActiveUseSeconds = estimatedActiveUseSeconds
        self.daypartFacts = daypartFacts
        self.longestRun = longestRun
        self.eventFacts = eventFacts
        self.choiceFacts = choiceFacts
        self.contextFacts = contextFacts
    }
}
