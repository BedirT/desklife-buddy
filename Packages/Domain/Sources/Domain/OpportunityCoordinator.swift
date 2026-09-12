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

    /// The canonical action-reducer state. The coordinator owns it alongside
    /// the engine so versioned actions route through one seam.
    public var actionReducer = OpportunityActionReducer()

    /// Creates a facade over an already configured or restored engine.
    public init(engine: ProtocolEngine) {
        self.engine = engine
    }

    /// Routes one command to its engine reduction and returns the same output
    /// the direct engine call would have produced.
    ///
    /// Seam honesty (Story 2.6): `dispatch` performs zero fence checks — no
    /// lease, generation, revision, or committed-Actions validation. The
    /// single-producer dispatch path is the only live producer, so the 2.3
    /// fences are test-verified but not live-enforced here. The future D-043
    /// crash-replay outbox and companion actions MUST route through
    /// `dispatchAction`, the fenced entry point, never through this one.
    ///
    /// When the committed output carries session-rotation evidence (a
    /// likely-natural-interruption fact), the action generation advances too:
    /// pre-rotation offers fence from here on. Outputs are identical to the
    /// direct engine call; only reducer fencing state moves.
    public mutating func dispatch(_ command: OpportunityCoordinatorCommand) -> OpportunityCoordinatorOutput {
        let output: OpportunityCoordinatorOutput
        switch command {
        case let .observe(sample, activeSuppressions, isLowFrictionMoment):
            output = OpportunityCoordinatorOutput(engine.observe(
                sample,
                activeSuppressions: activeSuppressions,
                isLowFrictionMoment: isLowFrictionMoment,
            ))
        case let .record(kind, opportunity, selectedDurationSeconds, source):
            output = OpportunityCoordinatorOutput(engine.record(
                kind,
                opportunity: opportunity,
                selectedDurationSeconds: selectedDurationSeconds,
                source: source,
            ))
        case let .snooze(opportunity, durationSeconds, date):
            output = OpportunityCoordinatorOutput(engine.snooze(
                opportunity,
                durationSeconds: durationSeconds,
                at: date,
            ))
        case let .selectMovement(durationSeconds):
            output = OpportunityCoordinatorOutput(engine.selectMovement(durationSeconds: durationSeconds))
        case let .skipMergedSegment(opportunity):
            output = OpportunityCoordinatorOutput(engine.skipMergedSegment(opportunity))
        case .mergedEscapeDuringVisual:
            let draft = engine.applyMergedEscapeDuringVisual()
            output = OpportunityCoordinatorOutput(events: [draft], presentation: currentPresentation())
        case let .resumeExpiredSnoozes(date):
            output = OpportunityCoordinatorOutput(engine.resumeExpiredSnoozes(at: date))
        case let .observeRecoverySession(date, systemAvailable):
            engine.observeRecoverySession(at: date, systemAvailable: systemAvailable)
            output = OpportunityCoordinatorOutput(events: [], presentation: currentPresentation())
        case let .resumeRecoverySession(date):
            engine.resumeRecoverySession(at: date)
            output = OpportunityCoordinatorOutput(events: [], presentation: currentPresentation())
        case .resumeInterruptedBreak:
            engine.resumeInterruptedBreak()
            output = OpportunityCoordinatorOutput(events: [], presentation: currentPresentation())
        }
        if output.events.contains(where: { $0.kind == .likelyNaturalInterruption }) {
            actionReducer.noteSessionRotation()
        }
        return output
    }

    /// Advances the action generation after an out-of-band session rotation
    /// (for example a restored interruption the coordinator never
    /// dispatched). Dispatched rotation evidence advances automatically.
    public mutating func noteSessionRotation() {
        actionReducer.noteSessionRotation()
    }

    /// Routes one versioned action through the canonical reducer and returns
    /// its auditable receipt plus the single presentation the arbitration
    /// selects next.
    public mutating func dispatchAction(
        _ envelope: OpportunityActionEnvelope,
        atTicks: TimeInterval,
    ) -> OpportunityActionOutput {
        let receipt = actionReducer.reduce(envelope, on: &engine, atTicks: atTicks)
        return OpportunityActionOutput(receipt: receipt, presentation: currentPresentation())
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
