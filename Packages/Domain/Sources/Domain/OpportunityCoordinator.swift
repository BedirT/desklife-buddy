import Foundation

/// Command/output facade over `ProtocolEngine`.
///
/// The coordinator owns the single opportunity arbitration
/// (`currentPresentation`) and routes every command to its engine reduction.
/// Engine-internal reductions and runtime callers resolve their presentation
/// through this facade, so exactly one arbitration path exists.
public struct OpportunityCoordinator: Sendable {
    /// The reduced engine. Read back after dispatch for persistence.
    public var engine: ProtocolEngine

    /// Creates a facade over an already configured or restored engine.
    public init(engine: ProtocolEngine) {
        self.engine = engine
    }

    /// Routes one command to its engine reduction and returns the same output
    /// the direct engine call would have produced.
    public mutating func dispatch(_ command: OpportunityCoordinatorCommand) -> OpportunityCoordinatorOutput {
        switch command {
        case let .observe(sample, activeSuppressions, isLowFrictionMoment):
            return OpportunityCoordinatorOutput(engine.observe(
                sample,
                activeSuppressions: activeSuppressions,
                isLowFrictionMoment: isLowFrictionMoment,
            ))
        case let .record(kind, opportunity, selectedDurationSeconds, source):
            return OpportunityCoordinatorOutput(engine.record(
                kind,
                opportunity: opportunity,
                selectedDurationSeconds: selectedDurationSeconds,
                source: source,
            ))
        case let .snooze(opportunity, durationSeconds, date):
            return OpportunityCoordinatorOutput(engine.snooze(
                opportunity,
                durationSeconds: durationSeconds,
                at: date,
            ))
        case let .selectMovement(durationSeconds):
            return OpportunityCoordinatorOutput(engine.selectMovement(durationSeconds: durationSeconds))
        case let .skipMergedSegment(opportunity):
            return OpportunityCoordinatorOutput(engine.skipMergedSegment(opportunity))
        case let .resumeExpiredSnoozes(date):
            return OpportunityCoordinatorOutput(engine.resumeExpiredSnoozes(at: date))
        case let .observeRecoverySession(date, systemAvailable):
            engine.observeRecoverySession(at: date, systemAvailable: systemAvailable)
            return OpportunityCoordinatorOutput(events: [], presentation: currentPresentation())
        case let .resumeRecoverySession(date):
            engine.resumeRecoverySession(at: date)
            return OpportunityCoordinatorOutput(events: [], presentation: currentPresentation())
        case .resumeInterruptedBreak:
            engine.resumeInterruptedBreak()
            return OpportunityCoordinatorOutput(events: [], presentation: currentPresentation())
        }
    }

    /// The single interrupting experience the scheduler may offer next.
    ///
    /// This is the only presentation arbitration. Engine reductions resolve
    /// their output presentation through `presentation(for:)`; callers query
    /// the live decision through this method.
    public func currentPresentation() -> OpportunityPresentation? {
        if recoveryIsEligible { return .recovery }
        return actionablePresentation()
    }

    /// Persisted snapshot of the reduced engine for the transaction boundary.
    public var state: ProtocolState { engine.state }

    /// Facade entry for engine-internal reductions resolving their output
    /// presentation without duplicating the arbitration.
    static func presentation(for engine: ProtocolEngine) -> OpportunityPresentation? {
        OpportunityCoordinator(engine: engine).currentPresentation()
    }

    private var recoveryIsEligible: Bool {
        guard let recovery = engine.configuration.recovery else { return false }
        return !engine.notAppropriateOpportunities.contains(.movement)
            && engine.movementSnoozeDeadline == nil
            && engine.movementClock.phase != .snoozed
            && !engine.recoveryState.wasOfferedThisSession
            && engine.recoveryState.movementDeferralCount >= recovery.requiredMovementDeferrals
            && engine.recoveryState.accumulatedEligibleActiveUseSeconds >= recovery.eligibleAfterSeconds
    }

    private func actionablePresentation() -> OpportunityPresentation? {
        let visualIsAllowed = !engine.notAppropriateOpportunities.contains(.visual)
        let movementIsAllowed = !engine.notAppropriateOpportunities.contains(.movement)
        let visualPresentable = engine.visualClock.phase.isPresentable && visualIsAllowed
        let movementPresentable = engine.movementClock.phase.isPresentable && movementIsAllowed
        let visualRemaining = max(
            0,
            engine.configuration.visual.targetSeconds - engine.visualClock.accumulatedActiveUseSeconds,
        )
        let movementRemaining = max(
            0,
            engine.configuration.movement.targetSeconds - engine.movementClock.accumulatedActiveUseSeconds,
        )
        let mergeEligible = abs(visualRemaining - movementRemaining)
            <= engine.configuration.delivery.mergeWindowSeconds
        let mergePhasesEligible = engine.visualClock.phase.isMergeEligible
            && engine.movementClock.phase.isMergeEligible
            && visualIsAllowed
            && movementIsAllowed

        if mergeEligible, mergePhasesEligible, visualPresentable || movementPresentable {
            return .merged
        }
        if movementPresentable { return .movement }
        if visualPresentable { return .visual }
        return nil
    }
}
