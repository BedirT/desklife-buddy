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
    case recovery
}

/// Observable result of one pure protocol-engine reduction.
public struct ProtocolEngineOutput: Equatable, Sendable {
    public let events: [OpportunityEventDraft]
    public let presentation: OpportunityPresentation?
}

/// Deterministic reducer for independent clocks, holds, and exhaustive event effects.
public struct ProtocolEngine: Sendable {
    let configuration: ProtocolConfiguration
    private var activityEstimator: ActivityEstimator

    public private(set) var profileID: ProtocolProfileID
    public internal(set) var visualClock: OpportunityClockState
    public internal(set) var movementClock: OpportunityClockState
    public internal(set) var recoveryState: RecoveryState
    var visualSnoozeDeadline: Date?
    var movementSnoozeDeadline: Date?
    var recoveryLastObservedAt: Date?

    /// Creates an engine with injected configuration and optional restored clock values.
    public init(
        configuration: ProtocolConfiguration,
        profileID: ProtocolProfileID = .balanced,
        visualClock: OpportunityClockState = OpportunityClockState(),
        movementClock: OpportunityClockState = OpportunityClockState(),
        visualSnoozeDeadline: Date? = nil,
        movementSnoozeDeadline: Date? = nil,
        recoveryState: RecoveryState = RecoveryState(),
        recoveryLastObservedAt: Date? = nil,
    ) {
        self.configuration = configuration
        activityEstimator = ActivityEstimator(configuration: configuration.activityEstimator)
        self.profileID = profileID
        self.visualClock = visualClock
        self.movementClock = movementClock
        self.visualSnoozeDeadline = visualSnoozeDeadline
        self.movementSnoozeDeadline = movementSnoozeDeadline
        self.recoveryState = recoveryState
        self.recoveryLastObservedAt = recoveryLastObservedAt
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

        exitSuppressionOrUpdatePhases(isLowFrictionMoment: isLowFrictionMoment)
        return ProtocolEngineOutput(events: [], presentation: recommendedPresentation())
    }

    /// Applies one canonical event and returns the same distinct fact for persistence.
    public mutating func record(
        _ kind: OpportunityEventKind,
        opportunity: OpportunityType? = nil,
        selectedDurationSeconds: TimeInterval? = nil,
        source: OpportunityEventSource = .user,
    ) -> ProtocolEngineOutput {
        guard isValidRecord(
            kind,
            opportunity: opportunity,
            selectedDurationSeconds: selectedDurationSeconds,
        ) else {
            return ProtocolEngineOutput(events: [], presentation: recommendedPresentation())
        }
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

extension ProtocolEngine {
    mutating func addActiveUse(_ seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
        visualClock.accumulatedActiveUseSeconds += seconds
        movementClock.accumulatedActiveUseSeconds += seconds
        recoveryState.accumulatedEligibleActiveUseSeconds += seconds
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
        visualClock.phase = phaseAfterNaturalInterruption(
            visualClock,
            schedule: configuration.visual,
        )
        movementClock.phase = phaseAfterNaturalInterruption(
            movementClock,
            schedule: configuration.movement,
        )
        recoveryState = RecoveryState()
    }

    func phaseAfterNaturalInterruption(
        _ clock: OpportunityClockState,
        schedule: OpportunitySchedule,
    ) -> OpportunityPhase {
        if clock.phase == .running { return .running }
        if clock.phase == .gracedAfterSuppression {
            return scheduledPhase(
                for: clock,
                schedule: schedule,
                isLowFrictionMoment: true,
            )
        }
        return .gracedAfterSuppression
    }

    mutating func exitSuppressionOrUpdatePhases(
        isLowFrictionMoment: Bool,
    ) {
        if case .suppressed = visualClock.phase {
            visualClock.phase = .gracedAfterSuppression
        }
        if case .suppressed = movementClock.phase {
            movementClock.phase = .gracedAfterSuppression
        }

        updatePhase(
            clock: &visualClock,
            schedule: configuration.visual,
            isLowFrictionMoment: isLowFrictionMoment,
        )
        updatePhase(
            clock: &movementClock,
            schedule: configuration.movement,
            isLowFrictionMoment: isLowFrictionMoment,
        )
    }

    func updatePhase(
        clock: inout OpportunityClockState,
        schedule: OpportunitySchedule,
        isLowFrictionMoment: Bool,
    ) {
        switch clock.phase {
        case .running, .snoozed, .suppressed, .gracedAfterSuppression:
            return
        case .accumulating, .softDue, .headsUpPresented,
             .waitingForLowFrictionMoment, .readyToPresent:
            break
        }

        clock.phase = scheduledPhase(
            for: clock,
            schedule: schedule,
            isLowFrictionMoment: isLowFrictionMoment,
        )
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
            if !configuration.delivery.waitForLowFrictionMoment || isLowFrictionMoment {
                return .readyToPresent
            }
            return .waitingForLowFrictionMoment
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
        if kind == .promptPresented, opportunity == .recovery {
            recoveryState.wasOfferedThisSession = true
        }
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
        case .positionChanged:
            movementClock.phase = .gracedAfterSuppression
        case .notAppropriate:
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
            break
        case .breakStarted:
            applyBreakStarted(
                opportunity: opportunity,
                selectedDurationSeconds: selectedDurationSeconds,
            )
        case .snoozed:
            return false
        default:
            return false
        }
        return true
    }
}
