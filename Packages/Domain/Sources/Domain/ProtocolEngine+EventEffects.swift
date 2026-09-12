import Foundation

extension ProtocolEngine {
    mutating func applyCompletionEffect(
        _ kind: OpportunityEventKind,
        opportunity: OpportunityType?,
    ) -> Bool {
        switch kind {
        case .timerFinished:
            applyTimerFinished(opportunity)
        case .userDeclaredCompleted:
            applyDeclaredCompletion(opportunity)
        case .userDeclaredAlreadyMoved:
            resetMovement(clearingRecoveryDebt: true)
        case .skipped:
            applySkip(opportunity)
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
            resetMovement(clearingRecoveryDebt: true)
        }
        setPhase(.running, for: opportunity)
    }

    mutating func reset(_ opportunity: OpportunityType) {
        switch opportunity {
        case .visual:
            visualClock = OpportunityClockState(cycleID: visualClock.cycleID &+ 1)
            visualSnoozeDeadline = nil
        case .movement:
            resetMovement(clearingRecoveryDebt: true)
        case .positionChange, .recovery:
            break
        }
    }

    mutating func resetMovement(clearingRecoveryDebt: Bool) {
        movementClock = OpportunityClockState(cycleID: movementClock.cycleID &+ 1)
        movementSnoozeDeadline = nil
        guard clearingRecoveryDebt else { return }
        recoveryState = RecoveryState(
            wasOfferedThisSession: recoveryState.wasOfferedThisSession,
        )
    }

    mutating func noteMovementDeferral() {
        recoveryState.movementDeferralCount += 1
    }

    /// Applies merged Escape-during-visual for the canonical action reducer: a
    /// fresh visual cycle and a fresh movement cycle with one deferral and one
    /// skip. Existing merged-Escape callers keep their retaining semantics;
    /// only the reducer routes through this shared effect.
    mutating func applyMergedEscapeDuringVisual() -> OpportunityEventDraft {
        reset(.visual)
        noteMovementDeferral()
        resetMovement(clearingRecoveryDebt: false)
        return OpportunityEventDraft(
            kind: .skipped,
            source: .user,
            opportunity: .visual,
            selectedDurationSeconds: nil,
        )
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

    private mutating func applyTimerFinished(_ opportunity: OpportunityType?) {
        if opportunity == .visual {
            reset(.visual)
        } else if opportunity == .movement {
            // The elapsed movement surface is also a real break in the visual session,
            // without manufacturing a visual-completion event.
            reset(.visual)
            movementClock.phase = .gracedAfterSuppression
        }
    }

    private mutating func applyDeclaredCompletion(_ opportunity: OpportunityType?) {
        if opportunity == .movement {
            resetMovement(clearingRecoveryDebt: true)
        } else if let opportunity {
            reset(opportunity)
        }
    }

    private mutating func applySkip(_ opportunity: OpportunityType?) {
        if opportunity == .movement {
            noteMovementDeferral()
            resetMovement(clearingRecoveryDebt: false)
        } else if let opportunity {
            reset(opportunity)
        }
    }
}
