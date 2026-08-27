import Foundation

public extension ProtocolEngine {
    /// Rotates recovery-session debt after a confirmed unavailable or offline boundary.
    mutating func observeRecoverySession(at date: Date, systemAvailable: Bool) {
        if hasRecoverySessionGap(at: date) {
            rotateSessionScopedState()
        }
        if systemAvailable || sessionScopedStateIsEmpty {
            recoveryLastObservedAt = date
        }
    }

    /// Applies an offline boundary during restore without inferring active use.
    mutating func resumeRecoverySession(at date: Date) {
        guard hasRecoverySessionGap(at: date) else { return }
        rotateSessionScopedState()
        recoveryLastObservedAt = date
    }

    /// Accepts an explicit movement path/duration and records the fact that resets its clock.
    mutating func selectMovement(durationSeconds: TimeInterval) -> ProtocolEngineOutput {
        guard isAcceptedMovementDuration(durationSeconds) else {
            return ProtocolEngineOutput(events: [], presentation: recommendedPresentation())
        }
        return record(
            .breakStarted,
            opportunity: .movement,
            selectedDurationSeconds: durationSeconds,
        )
    }

    /// Lets App reject invalid input before attempting an otherwise empty state-only commit.
    func isAcceptedMovementDuration(_ durationSeconds: TimeInterval) -> Bool {
        durationSeconds.isFinite
            && configuration.movement.durationOptionsSeconds.contains(durationSeconds)
    }

    private func hasRecoverySessionGap(at date: Date) -> Bool {
        guard let recoveryLastObservedAt else { return false }
        let elapsed = date.timeIntervalSince(recoveryLastObservedAt)
        return elapsed.isFinite && elapsed >= configuration.activityEstimator.longIdleResetSeconds
    }

    /// Records a validated snooze and retains the exact wall-clock deadline across restart.
    mutating func snooze(
        _ opportunity: OpportunityType,
        durationSeconds: TimeInterval,
        at date: Date,
    ) -> ProtocolEngineOutput {
        guard configuration.delivery.snoozeOptionsSeconds.contains(durationSeconds),
              opportunity == .visual || opportunity == .movement
        else {
            return ProtocolEngineOutput(events: [], presentation: recommendedPresentation())
        }
        let deadline = date.addingTimeInterval(durationSeconds)
        switch opportunity {
        case .visual:
            visualSnoozeDeadline = deadline
            visualClock.phase = .snoozed
        case .movement:
            movementSnoozeDeadline = deadline
            movementClock.phase = .snoozed
            noteMovementDeferral()
        case .positionChange, .recovery:
            break
        }
        let event = OpportunityEventDraft(
            kind: .snoozed,
            source: .user,
            opportunity: opportunity,
            selectedDurationSeconds: durationSeconds,
        )
        return ProtocolEngineOutput(events: [event], presentation: recommendedPresentation())
    }

    /// Expires retained snoozes without manufacturing elapsed active use or an event fact.
    mutating func resumeExpiredSnoozes(at date: Date) -> ProtocolEngineOutput {
        if let deadline = visualSnoozeDeadline, date >= deadline {
            visualSnoozeDeadline = nil
            visualClock.phase = scheduledPhase(
                for: visualClock,
                schedule: configuration.visual,
                isLowFrictionMoment: true,
            )
        }
        if let deadline = movementSnoozeDeadline, date >= deadline {
            movementSnoozeDeadline = nil
            movementClock.phase = scheduledPhase(
                for: movementClock,
                schedule: configuration.movement,
                isLowFrictionMoment: true,
            )
        }
        return ProtocolEngineOutput(events: [], presentation: recommendedPresentation())
    }

    /// Applies owner-confirmed merged Escape semantics without resetting the unfinished clock.
    mutating func skipMergedSegment(_ opportunity: OpportunityType) -> ProtocolEngineOutput {
        guard opportunity == .visual || opportunity == .movement else {
            return ProtocolEngineOutput(events: [], presentation: recommendedPresentation())
        }
        if opportunity == .visual {
            visualClock.phase = .gracedAfterSuppression
            if movementClock.phase.isPresentable {
                movementClock.phase = .gracedAfterSuppression
            }
        } else {
            noteMovementDeferral()
            movementClock.phase = .gracedAfterSuppression
        }
        let event = OpportunityEventDraft(
            kind: .skipped,
            source: .user,
            opportunity: opportunity,
        )
        return ProtocolEngineOutput(events: [event], presentation: recommendedPresentation())
    }
}

extension ProtocolEngine {
    func recommendedPresentation() -> OpportunityPresentation? {
        if recoveryIsEligible { return .recovery }
        return recommendedActionablePresentation()
    }

    func recommendedActionablePresentation() -> OpportunityPresentation? {
        let visualIsAllowed = !notAppropriateOpportunities.contains(.visual)
        let movementIsAllowed = !notAppropriateOpportunities.contains(.movement)
        let visualPresentable = visualClock.phase.isPresentable && visualIsAllowed
        let movementPresentable = movementClock.phase.isPresentable && movementIsAllowed
        let visualRemaining = max(
            0,
            configuration.visual.targetSeconds - visualClock.accumulatedActiveUseSeconds,
        )
        let movementRemaining = max(
            0,
            configuration.movement.targetSeconds - movementClock.accumulatedActiveUseSeconds,
        )
        let mergeEligible = abs(visualRemaining - movementRemaining) <= configuration.delivery.mergeWindowSeconds
        let mergePhasesEligible = visualClock.phase.isMergeEligible
            && movementClock.phase.isMergeEligible
            && visualIsAllowed
            && movementIsAllowed

        if mergeEligible, mergePhasesEligible, visualPresentable || movementPresentable {
            return .merged
        }
        if movementPresentable { return .movement }
        if visualPresentable { return .visual }
        return nil
    }

    func isValidRecord(
        _ kind: OpportunityEventKind,
        opportunity: OpportunityType?,
        selectedDurationSeconds: TimeInterval?,
    ) -> Bool {
        if kind == .snoozed { return false }
        guard kind == .breakStarted, opportunity == .movement else { return true }
        guard let selectedDurationSeconds else { return true }
        return configuration.movement.durationOptionsSeconds.contains(selectedDurationSeconds)
    }

    private var recoveryIsEligible: Bool {
        guard let recovery = configuration.recovery else { return false }
        return !notAppropriateOpportunities.contains(.movement)
            && movementSnoozeDeadline == nil
            && movementClock.phase != .snoozed
            && !recoveryState.wasOfferedThisSession
            && recoveryState.movementDeferralCount >= recovery.requiredMovementDeferrals
            && recoveryState.accumulatedEligibleActiveUseSeconds >= recovery.eligibleAfterSeconds
    }

    var sessionScopedStateIsEmpty: Bool {
        recoveryState == RecoveryState() && notAppropriateOpportunities.isEmpty
    }

    mutating func rotateSessionScopedState() {
        recoveryState = RecoveryState()
        notAppropriateOpportunities.removeAll()
    }
}

extension OpportunityPhase {
    var isPresentable: Bool {
        switch self {
        case .headsUpPresented, .waitingForLowFrictionMoment, .readyToPresent:
            true
        case .accumulating, .softDue, .running, .snoozed, .suppressed, .gracedAfterSuppression:
            false
        }
    }

    var isMergeEligible: Bool {
        switch self {
        case .accumulating, .softDue, .headsUpPresented,
             .waitingForLowFrictionMoment, .readyToPresent:
            true
        case .running, .snoozed, .suppressed, .gracedAfterSuppression:
            false
        }
    }
}
