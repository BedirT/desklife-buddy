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
    public internal(set) var cycleID: UInt64
    public internal(set) var accumulatedActiveUseSeconds: TimeInterval
    public internal(set) var phase: OpportunityPhase

    /// Creates a clock state for restoration or deterministic testing.
    public init(
        cycleID: UInt64 = 0,
        accumulatedActiveUseSeconds: TimeInterval = 0,
        phase: OpportunityPhase = .accumulating,
    ) {
        self.cycleID = cycleID
        self.accumulatedActiveUseSeconds = max(0, accumulatedActiveUseSeconds)
        self.phase = phase
    }
}

/// One event fact awaiting App-owned identity and wall-clock metadata.
public struct OpportunityEventDraft: Equatable, Sendable, Codable {
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
    public internal(set) var notAppropriateOpportunities: Set<OpportunityType>
    public private(set) var headsUpDeliveryState: HeadsUpDeliveryState
    public private(set) var lastObservationWasLowFriction = false
    var visualSnoozeDeadline: Date?
    var movementSnoozeDeadline: Date?
    var recoveryLastObservedAt: Date?
    private var visualGraceEndsAtUptime: TimeInterval?
    private var movementGraceEndsAtUptime: TimeInterval?
    /// End of the extended-away visual courtesy runway, scoped to the visual
    /// cycle named by `visualCourtesyCycleID`. Any visual reset orphans a stale
    /// record via the cycle check in `activeVisualCourtesyEnd(at:)`, so
    /// completion, skip, and timer paths need no explicit cleanup.
    private var visualCourtesyEndsAtUptime: TimeInterval?
    private var visualCourtesyCycleID: UInt64?

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
        notAppropriateOpportunities: Set<OpportunityType> = [],
        headsUpDeliveryState: HeadsUpDeliveryState = HeadsUpDeliveryState(),
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
        self.notAppropriateOpportunities = Set(
            notAppropriateOpportunities.filter(\.supportsNotAppropriateSuppression),
        )
        self.headsUpDeliveryState = headsUpDeliveryState
    }

    /// Reduces one coarse system observation and returns newly emitted event facts.
    public mutating func observe(
        _ sample: ActivitySample,
        activeSuppressions: Set<SuppressionReason> = [],
        isLowFrictionMoment: Bool = false,
    ) -> ProtocolEngineOutput {
        let assessment = activityEstimator.assess(sample)
        let suppression = SuppressionResolver.resolve(activeReasons: activeSuppressions)
        let effectiveLowFrictionMoment = isLowFrictionMoment || assessment.isShortInputPause
        lastObservationWasLowFriction = effectiveLowFrictionMoment

        if suppression.accumulationPolicy == .continue {
            addVisualSession(assessment.visualSessionSeconds)
            addMovementActiveUse(assessment.movementActiveUseSeconds)
        }

        if assessment.didBeginLikelyNaturalInterruption {
            applyNaturalInterruption(
                at: sample.uptimeSeconds,
                extendedCourtesy: assessment.didBeginExtendedUnavailable,
            )
            return ProtocolEngineOutput(
                events: [OpportunityEventDraft(
                    kind: .likelyNaturalInterruption,
                    source: .systemContext,
                )],
                presentation: nil,
            )
        }

        // Independent extended-away edge: the long-idle onset may have fired
        // long before the unavailable elapsed time crossed the extended
        // threshold. Arming here grants the runway without manufacturing a
        // second interruption fact. A suppression arriving on this sample
        // still wins; the runway is preserved for suppression exit.
        if assessment.didBeginExtendedUnavailable {
            armVisualCourtesy(at: sample.uptimeSeconds)
        }

        if let reason = suppression.reason {
            applySuppression(reason)
            return ProtocolEngineOutput(events: [], presentation: nil)
        }

        exitSuppressionOrUpdatePhases(
            at: sample.uptimeSeconds,
            isLowFrictionMoment: effectiveLowFrictionMoment,
        )
        return ProtocolEngineOutput(events: [], presentation: OpportunityCoordinator.presentation(for: self))
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
            return ProtocolEngineOutput(events: [], presentation: OpportunityCoordinator.presentation(for: self))
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
        return ProtocolEngineOutput(events: [event], presentation: OpportunityCoordinator.presentation(for: self))
    }

    /// Ends the explicit post-suppression grace and recomputes each schedulable phase.
    ///
    /// An armed extended-away courtesy is time-based, not suppression-based, so
    /// an explicit resume leaves the visual runway untouched.
    public mutating func resumeAfterSuppressionGrace() {
        movementGraceEndsAtUptime = nil
        let visualCourtesyArmed = visualCourtesyEndsAtUptime != nil
            && visualCourtesyCycleID == visualClock.cycleID
        if !visualCourtesyArmed {
            visualGraceEndsAtUptime = nil
            if visualClock.phase == .gracedAfterSuppression {
                visualClock.phase = scheduledPhase(
                    for: visualClock,
                    schedule: configuration.visual,
                    isLowFrictionMoment: false,
                )
            }
        }
        if movementClock.phase == .gracedAfterSuppression {
            movementClock.phase = scheduledPhase(
                for: movementClock,
                schedule: configuration.movement,
                isLowFrictionMoment: false,
            )
        }
    }

    /// Synchronizes a separately reduced delivery ledger for the next persisted state snapshot.
    public mutating func synchronizeHeadsUpDeliveryState(_ state: HeadsUpDeliveryState) {
        headsUpDeliveryState = state
    }
}

extension ProtocolEngine {
    mutating func addVisualSession(_ seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
        visualClock.accumulatedActiveUseSeconds += seconds
    }

    mutating func addMovementActiveUse(_ seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
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

    mutating func applyNaturalInterruption(at uptimeSeconds: TimeInterval, extendedCourtesy: Bool = false) {
        if visualClock.phase != .running {
            reset(.visual)
            // The reset fenced the previous cycle, so any pending visual grace
            // belonged to it; the arm below recomputes from this onset.
            visualGraceEndsAtUptime = nil
            if extendedCourtesy {
                armVisualCourtesy(at: uptimeSeconds)
            }
        }
        if movementClock.phase != .running {
            movementClock.phase = .gracedAfterSuppression
            movementGraceEndsAtUptime = uptimeSeconds
                + configuration.activityEstimator.postInterruptionGraceSeconds
        }
        rotateSessionScopedState()
    }

    mutating func armVisualCourtesy(at uptimeSeconds: TimeInterval) {
        guard visualClock.phase != .running, visualClock.phase != .snoozed else { return }
        if case .suppressed = visualClock.phase {
            // A suppressed clock records the runway and picks it up on
            // suppression exit; its phase and deadline stay untouched here.
            let courtesySeconds = configuration.activityEstimator.extendedVisualCourtesySeconds
            guard courtesySeconds > 0 else { return }
            visualCourtesyEndsAtUptime = uptimeSeconds + courtesySeconds
            visualCourtesyCycleID = visualClock.cycleID
            return
        }
        let courtesySeconds = configuration.activityEstimator.extendedVisualCourtesySeconds
        guard courtesySeconds > 0 else { return }
        let courtesyEnd = uptimeSeconds + courtesySeconds
        visualCourtesyEndsAtUptime = courtesyEnd
        visualCourtesyCycleID = visualClock.cycleID
        visualClock.phase = .gracedAfterSuppression
        visualGraceEndsAtUptime = max(
            visualGraceEndsAtUptime ?? uptimeSeconds
                + configuration.activityEstimator.postInterruptionGraceSeconds,
            courtesyEnd,
        )
    }

    /// Orphans an armed visual courtesy runway for a retaining legacy path
    /// that keeps its unfinished cycle. Reset paths orphan via the cycle
    /// check instead. Only an armed-for-current-cycle runway is dropped, and
    /// its extended deadline goes with it so normal grace applies.
    mutating func orphanVisualCourtesyRunway() {
        guard visualCourtesyCycleID == visualClock.cycleID else { return }
        visualCourtesyEndsAtUptime = nil
        visualCourtesyCycleID = nil
        visualGraceEndsAtUptime = nil
    }

    /// Returns the armed extended-away courtesy end for the current visual
    /// cycle, lazily expiring stale records. Visual-cycle-scoped: a reset
    /// bumps `cycleID`, which orphans any prior runway without explicit cleanup.
    mutating func activeVisualCourtesyEnd(at uptimeSeconds: TimeInterval) -> TimeInterval? {
        guard let end = visualCourtesyEndsAtUptime,
              visualCourtesyCycleID == visualClock.cycleID,
              uptimeSeconds < end
        else {
            visualCourtesyEndsAtUptime = nil
            visualCourtesyCycleID = nil
            return nil
        }
        return end
    }

    mutating func exitSuppressionOrUpdatePhases(
        at uptimeSeconds: TimeInterval,
        isLowFrictionMoment: Bool,
    ) {
        if case .suppressed = visualClock.phase {
            visualClock.phase = .gracedAfterSuppression
            let graceEndsAt = uptimeSeconds
                + configuration.activityEstimator.postInterruptionGraceSeconds
            if let courtesyEnd = activeVisualCourtesyEnd(at: uptimeSeconds) {
                visualGraceEndsAtUptime = max(graceEndsAt, courtesyEnd)
            } else {
                visualGraceEndsAtUptime = graceEndsAt
            }
        }
        if case .suppressed = movementClock.phase {
            movementClock.phase = .gracedAfterSuppression
            movementGraceEndsAtUptime = uptimeSeconds
                + configuration.activityEstimator.postInterruptionGraceSeconds
        }

        advanceGrace(
            clock: &visualClock,
            schedule: configuration.visual,
            deadline: &visualGraceEndsAtUptime,
            at: uptimeSeconds,
            isLowFrictionMoment: isLowFrictionMoment,
        )
        advanceGrace(
            clock: &movementClock,
            schedule: configuration.movement,
            deadline: &movementGraceEndsAtUptime,
            at: uptimeSeconds,
            isLowFrictionMoment: isLowFrictionMoment,
        )

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

    func advanceGrace(
        clock: inout OpportunityClockState,
        schedule: OpportunitySchedule,
        deadline: inout TimeInterval?,
        at uptimeSeconds: TimeInterval,
        isLowFrictionMoment: Bool,
    ) {
        guard clock.phase == .gracedAfterSuppression else {
            deadline = nil
            return
        }
        if deadline == nil {
            deadline = uptimeSeconds + configuration.activityEstimator.postInterruptionGraceSeconds
        }
        guard let graceDeadline = deadline, uptimeSeconds >= graceDeadline else { return }
        clock.phase = scheduledPhase(
            for: clock,
            schedule: schedule,
            isLowFrictionMoment: isLowFrictionMoment,
        )
        deadline = nil
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
            applyNaturalInterruption(at: 0)
        case .positionChanged:
            movementClock.phase = .gracedAfterSuppression
        case .notAppropriate:
            if let opportunity, opportunity.supportsNotAppropriateSuppression {
                notAppropriateOpportunities.insert(opportunity)
            }
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
