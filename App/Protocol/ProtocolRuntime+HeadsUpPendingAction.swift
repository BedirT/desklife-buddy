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

        let checkpoint = checkpointCoordinator()
        var candidate = checkpoint.engine
        candidate.synchronizeHeadsUpDeliveryState(reducer.state)
        coordinator.engine = candidate
        let opening = pendingActionOpening(action)
        candidate = coordinator.engine
        do {
            let synchronization = try await persistProtocolMutation(
                candidate: &candidate,
                drafts: opening.drafts,
            )
            coordinator.engine = candidate
            lifecycleSession = opening.nextSession
            publish(liveHeadsUp: nil)
            emitHeadsUpEffects(synchronization)
            return action
        } catch {
            restoreCoordinator(checkpoint)
            throw error
        }
    }
    func pendingActionOpening(
        _ action: HeadsUpPendingAction,
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
        let drafts = coordinator.dispatch(.record(
            kind: .breakStarted,
            opportunity: opening.0,
            selectedDurationSeconds: nil,
            source: action.source,
        )).events
        return (drafts, opening.1)
    }
}
