import Domain
import Foundation

extension ProtocolRuntime {
    func completePersistedHeadsUpAction(
        _ id: HeadsUpDeliveryID,
        kind: HeadsUpPendingActionKind,
        opportunity: HeadsUpOpportunityID,
    ) async throws -> HeadsUpPendingAction? {
        let policy = try requiredHeadsUpRuntimePolicy()
        guard let action = engine.state.headsUpDeliveryState.pendingAction,
              action.id == id,
              action.kind == kind,
              action.opportunity == opportunity,
              kind != .openBreak || lifecycleSession == nil
        else {
            return nil
        }

        var reducer = HeadsUpDeliveryReducer(
            state: engine.state.headsUpDeliveryState,
            maximumSnoozeReoffers: policy.maximumSnoozeReoffers,
        )
        guard reducer.completePendingAction(id, kind: kind) == action else {
            return nil
        }

        var candidate = engine
        candidate.synchronizeHeadsUpDeliveryState(reducer.state)
        let opening = pendingActionOpening(action, candidate: &candidate)
        let synchronization = try await persistProtocolMutation(
            candidate: &candidate,
            drafts: opening.drafts,
        )
        engine = candidate
        lifecycleSession = opening.nextSession
        publish(liveHeadsUp: nil)
        emitHeadsUpEffects(synchronization)
        return action
    }

    func pendingActionOpening(
        _ action: HeadsUpPendingAction,
        candidate: inout ProtocolEngine,
    ) -> (drafts: [OpportunityEventDraft], nextSession: LifecycleSession?) {
        guard action.kind == .openBreak else {
            return ([], lifecycleSession)
        }
        let opening: (OpportunityType, LifecycleSession?) = switch action.opportunity {
        case .visual:
            (.visual, nil)
        case .movement:
            (.movement, .movement(selectedDuration: nil))
        case .merged:
            (.visual, .merged(segment: .visual, selectedDuration: nil))
        }
        let drafts = candidate.record(
            .breakStarted,
            opportunity: opening.0,
            source: action.source,
        ).events
        return (drafts, opening.1)
    }
}
