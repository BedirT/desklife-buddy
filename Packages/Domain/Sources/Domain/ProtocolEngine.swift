import Foundation

/// Presentation lifecycle for one independent opportunity clock.
public enum OpportunityPhase: Equatable, Sendable {
    case accumulating
    case softDue
    case headsUpPresented
    case waitingForLowFrictionMoment
    case readyToPresent
    case running
    case snoozed
    case suppressed(SuppressionReason)
    case gracedAfterSuppression
}

/// Current accumulated estimate and presentation phase for one opportunity.
public struct OpportunityClockState: Equatable, Sendable {
    public internal(set) var accumulatedActiveUseSeconds: TimeInterval
    public internal(set) var phase: OpportunityPhase

    /// Creates a clock state for restoration or deterministic testing.
    public init(
        accumulatedActiveUseSeconds: TimeInterval = 0,
        phase: OpportunityPhase = .accumulating,
    ) {
        self.accumulatedActiveUseSeconds = max(0, accumulatedActiveUseSeconds)
        self.phase = phase
    }
}

/// One event fact awaiting App-owned identity and wall-clock metadata.
public struct OpportunityEventDraft: Equatable, Sendable {
    public let kind: OpportunityEventKind
    public let source: OpportunityEventSource
    public let opportunity: OpportunityType?
    public let selectedDurationSeconds: TimeInterval?

    /// Creates a privacy-minimized event without generating metadata inside logic.
    public init(
        kind: OpportunityEventKind,
        source: OpportunityEventSource,
        opportunity: OpportunityType? = nil,
        selectedDurationSeconds: TimeInterval? = nil,
    ) {
        self.kind = kind
        self.source = source
        self.opportunity = opportunity
        self.selectedDurationSeconds = selectedDurationSeconds
    }
}

/// The single interrupting experience the scheduler may offer next.
public enum OpportunityPresentation: Equatable, Sendable {
    case visual
    case movement
    case merged
}

/// Observable result of one pure protocol-engine reduction.
public struct ProtocolEngineOutput: Equatable, Sendable {
    public let events: [OpportunityEventDraft]
    public let presentation: OpportunityPresentation?
}

/// Deterministic reducer for independent clocks, holds, and exhaustive event effects.
public struct ProtocolEngine: Sendable {
    private let configuration: ProtocolConfiguration
    private var activityEstimator: ActivityEstimator

    public private(set) var visualClock: OpportunityClockState
    public private(set) var movementClock: OpportunityClockState

    /// Creates an engine with injected configuration and optional restored clock values.
    public init(
        configuration: ProtocolConfiguration,
        visualClock: OpportunityClockState = OpportunityClockState(),
        movementClock: OpportunityClockState = OpportunityClockState(),
    ) {
        self.configuration = configuration
        activityEstimator = ActivityEstimator(configuration: configuration.activityEstimator)
        self.visualClock = visualClock
        self.movementClock = movementClock
    }

    /// Reduces one coarse system observation and returns newly emitted event facts.
    public mutating func observe(
        _ sample: ActivitySample,
        activeSuppressions: Set<SuppressionReason> = [],
        isLowFrictionMoment: Bool = false,
    ) -> ProtocolEngineOutput {
        let assessment = activityEstimator.assess(sample)
        let suppression = SuppressionResolver.resolve(activeReasons: activeSuppressions)

        if suppression.accumulationPolicy == .continue {
            addActiveUse(assessment.accumulatedSeconds)
        }

        if assessment.didBeginLikelyNaturalInterruption {
            applyNaturalInterruption()
            return ProtocolEngineOutput(
                events: [OpportunityEventDraft(
                    kind: .likelyNaturalInterruption,
                    source: .systemContext,
                )],
                presentation: nil,
            )
        }

        if let reason = suppression.reason {
            applySuppression(reason)
            return ProtocolEngineOutput(events: [], presentation: nil)
        }

        let events = exitSuppressionOrUpdatePhases(isLowFrictionMoment: isLowFrictionMoment)
        return ProtocolEngineOutput(events: events, presentation: recommendedPresentation())
    }

    /// Applies one canonical event and returns the same distinct fact for persistence.
    public mutating func record(
        _ kind: OpportunityEventKind,
        opportunity: OpportunityType? = nil,
        selectedDurationSeconds: TimeInterval? = nil,
        source: OpportunityEventSource = .user,
    ) -> ProtocolEngineOutput {
        applyEventEffect(
            kind,
            opportunity: opportunity,
            selectedDurationSeconds: selectedDurationSeconds,
        )
        let event = OpportunityEventDraft(
            kind: kind,
            source: source,
            opportunity: opportunity,
            selectedDurationSeconds: selectedDurationSeconds,
        )
        return ProtocolEngineOutput(events: [event], presentation: recommendedPresentation())
    }

    /// Ends the explicit post-suppression grace and recomputes each schedulable phase.
    public mutating func resumeAfterSuppressionGrace() {
        if visualClock.phase == .gracedAfterSuppression {
            visualClock.phase = scheduledPhase(
                for: visualClock,
                schedule: configuration.visual,
                isLowFrictionMoment: false,
            )
        }
        if movementClock.phase == .gracedAfterSuppression {
            movementClock.phase = scheduledPhase(
                for: movementClock,
                schedule: configuration.movement,
                isLowFrictionMoment: false,
            )
        }
    }
}

private extension ProtocolEngine {
    mutating func addActiveUse(_ seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
        visualClock.accumulatedActiveUseSeconds += seconds
        movementClock.accumulatedActiveUseSeconds += seconds
    }

    mutating func applySuppression(_ reason: SuppressionReason) {
        if visualClock.phase != .running {
            visualClock.phase = .suppressed(reason)
        }
        if movementClock.phase != .running {
            movementClock.phase = .suppressed(reason)
        }
    }

    mutating func applyNaturalInterruption() {
        if visualClock.phase != .running {
            visualClock.phase = .gracedAfterSuppression
        }
        if movementClock.phase != .running {
            movementClock.phase = .gracedAfterSuppression
        }
    }

    mutating func exitSuppressionOrUpdatePhases(
        isLowFrictionMoment: Bool,
    ) -> [OpportunityEventDraft] {
        if case .suppressed = visualClock.phase {
            visualClock.phase = .gracedAfterSuppression
        }
        if case .suppressed = movementClock.phase {
            movementClock.phase = .gracedAfterSuppression
        }

        var events: [OpportunityEventDraft] = []
        events += updatePhase(
            clock: &visualClock,
            schedule: configuration.visual,
            opportunity: .visual,
            isLowFrictionMoment: isLowFrictionMoment,
        )
        events += updatePhase(
            clock: &movementClock,
            schedule: configuration.movement,
            opportunity: .movement,
            isLowFrictionMoment: isLowFrictionMoment,
        )
        return events
    }

    func updatePhase(
        clock: inout OpportunityClockState,
        schedule: OpportunitySchedule,
        opportunity: OpportunityType,
        isLowFrictionMoment: Bool,
    ) -> [OpportunityEventDraft] {
        switch clock.phase {
        case .running, .snoozed, .suppressed, .gracedAfterSuppression:
            return []
        case .accumulating, .softDue, .headsUpPresented,
             .waitingForLowFrictionMoment, .readyToPresent:
            break
        }

        let previousPhase = clock.phase
        clock.phase = scheduledPhase(
            for: clock,
            schedule: schedule,
            isLowFrictionMoment: isLowFrictionMoment,
        )
        guard previousPhase != .headsUpPresented, clock.phase == .headsUpPresented else {
            return []
        }
        return [OpportunityEventDraft(
            kind: .promptPresented,
            source: .localTimer,
            opportunity: opportunity,
        )]
    }

    func scheduledPhase(
        for clock: OpportunityClockState,
        schedule: OpportunitySchedule,
        isLowFrictionMoment: Bool,
    ) -> OpportunityPhase {
        let elapsed = clock.accumulatedActiveUseSeconds
        if elapsed >= schedule.latestPreferredSeconds {
            return .readyToPresent
        }
        if elapsed >= schedule.targetSeconds {
            return isLowFrictionMoment ? .readyToPresent : .waitingForLowFrictionMoment
        }
        if elapsed >= schedule.targetSeconds - configuration.delivery.headsUpSecondsBeforeTarget {
            return .headsUpPresented
        }
        if elapsed >= schedule.softDueSeconds {
            return .softDue
        }
        return .accumulating
    }

    mutating func applyEventEffect(
        _ kind: OpportunityEventKind,
        opportunity: OpportunityType?,
        selectedDurationSeconds: TimeInterval?,
    ) {
        if applyLifecycleEffect(
            kind,
            opportunity: opportunity,
            selectedDurationSeconds: selectedDurationSeconds,
        ) {
            return
        }
        if applyCompletionEffect(kind, opportunity: opportunity) {
            return
        }

        switch kind {
        case .likelyNaturalInterruption:
            applyNaturalInterruption()
        case .positionChanged, .notAppropriate:
            break
        case .promptPresented, .breakStarted, .timerFinished,
             .userDeclaredCompleted, .userDeclaredAlreadyMoved, .snoozed, .skipped:
            break
        }
    }

    mutating func applyLifecycleEffect(
        _ kind: OpportunityEventKind,
        opportunity: OpportunityType?,
        selectedDurationSeconds: TimeInterval?,
    ) -> Bool {
        switch kind {
        case .promptPresented:
            setPhase(.headsUpPresented, for: opportunity)
        case .breakStarted:
            applyBreakStarted(
                opportunity: opportunity,
                selectedDurationSeconds: selectedDurationSeconds,
            )
        case .snoozed:
            setPhase(.snoozed, for: opportunity)
        default:
            return false
        }
        return true
    }

    mutating func applyCompletionEffect(
        _ kind: OpportunityEventKind,
        opportunity: OpportunityType?,
    ) -> Bool {
        switch kind {
        case .timerFinished:
            if opportunity == .visual { reset(.visual) }
        case .userDeclaredCompleted:
            if let opportunity { reset(opportunity) }
        case .userDeclaredAlreadyMoved:
            reset(.movement)
        case .skipped:
            if let opportunity { reset(opportunity) }
        default:
            return false
        }
        return true
    }

    mutating func applyBreakStarted(
        opportunity: OpportunityType?,
        selectedDurationSeconds: TimeInterval?,
    ) {
        let isAcceptedMovementStart = opportunity == .movement
            && selectedDurationSeconds.map(
                configuration.movement.durationOptionsSeconds.contains,
            ) == true
        if isAcceptedMovementStart {
            reset(.movement)
        }
        setPhase(.running, for: opportunity)
    }

    mutating func reset(_ opportunity: OpportunityType) {
        switch opportunity {
        case .visual:
            visualClock = OpportunityClockState()
        case .movement:
            movementClock = OpportunityClockState()
        case .positionChange, .recovery:
            break
        }
    }

    mutating func setPhase(_ phase: OpportunityPhase, for opportunity: OpportunityType?) {
        switch opportunity {
        case .visual:
            visualClock.phase = phase
        case .movement:
            movementClock.phase = phase
        case .positionChange, .recovery, nil:
            break
        }
    }

    func recommendedPresentation() -> OpportunityPresentation? {
        let visualReady = visualClock.phase == .readyToPresent
        let movementReady = movementClock.phase == .readyToPresent
        let visualRemaining = max(
            0,
            configuration.visual.targetSeconds - visualClock.accumulatedActiveUseSeconds,
        )
        let movementRemaining = max(
            0,
            configuration.movement.targetSeconds - movementClock.accumulatedActiveUseSeconds,
        )
        let mergeEligible = abs(visualRemaining - movementRemaining) <= configuration.delivery.mergeWindowSeconds

        if mergeEligible, visualReady || movementReady {
            return .merged
        }
        if movementReady { return .movement }
        if visualReady { return .visual }
        return nil
    }
}
