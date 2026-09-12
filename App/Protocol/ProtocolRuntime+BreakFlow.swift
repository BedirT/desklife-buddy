import BreakFlow
import Domain
import Foundation

enum BreakFlowRuntimeError: Error, Equatable {
    case unsupportedExactDeadline
    case unsupportedAction
}

extension ProtocolRuntime {
    func handleBreakFlow(_ action: BreakFlowAction) async throws {
        try await withLifecycleGate {
            switch action {
            case let .snooze(scope, durationSeconds):
                try await reduceBreakFlowSnooze(scope: scope, durationSeconds: durationSeconds)
            case .snoozeUntil:
                throw BreakFlowRuntimeError.unsupportedExactDeadline
            case .pauseOneHour:
                applyPause(.oneHour)
                lifecycleSession = nil
                publish(liveHeadsUp: nil)
            case let .notAppropriate(scope):
                try await reduceBreakFlowNotAppropriate(scope: scope)
            case let .skip(scope):
                try await reduceBreakFlowSkip(scope: scope)
            case .acknowledgementFinished, .chooseRecovery, .dismissRecovery:
                throw BreakFlowRuntimeError.unsupportedAction
            }
        }
    }

    private func reduceBreakFlowSnooze(
        scope: BreakScope,
        durationSeconds: TimeInterval,
    ) async throws {
        let actionDate = now()
        try await commitBreakFlow(recordedAt: actionDate) {
            var drafts: [OpportunityEventDraft] = []
            for opportunity in opportunities(for: scope) {
                let output = coordinator.dispatch(.snooze(
                    opportunity: opportunity,
                    durationSeconds: durationSeconds,
                    at: actionDate,
                ))
                guard output.events.count == 1 else {
                    throw ProtocolLifecycleError.invalidSnoozeDuration
                }
                drafts += output.events
            }
            var candidate = coordinator.engine
            mirrorBreakFlowSnoozeInHeadsUpLedger(
                scope: scope,
                deadline: actionDate.addingTimeInterval(durationSeconds),
                candidate: &candidate,
            )
            coordinator.engine = candidate
            return drafts
        }
    }

    private func reduceBreakFlowNotAppropriate(scope: BreakScope) async throws {
        let actionDate = now()
        try await commitBreakFlow(recordedAt: actionDate) {
            var drafts: [OpportunityEventDraft] = []
            for opportunity in opportunities(for: scope) {
                drafts += coordinator.dispatch(.record(
                    kind: .notAppropriate,
                    opportunity: opportunity,
                    selectedDurationSeconds: nil,
                    source: .user,
                )).events
            }
            return drafts
        }
    }

    private func reduceBreakFlowSkip(scope: BreakScope) async throws {
        // Escape-during-visual (active visual segment, or no session yet)
        // takes the canonical D-043 `merged.escape_during_visual` effect
        // (fresh visual + fresh movement + one deferral + one skip); the
        // movement-segment path keeps the legacy retaining route.
        let command: OpportunityCoordinatorCommand = switch scope {
        case .visual:
            .record(kind: .skipped, opportunity: .visual, selectedDurationSeconds: nil, source: .user)
        case .movement:
            .record(kind: .skipped, opportunity: .movement, selectedDurationSeconds: nil, source: .user)
        case .merged:
            switch lifecycleSession {
            case .merged(segment: .visual, selectedDuration: _): .mergedEscapeDuringVisual
            case .merged(segment: .movement, selectedDuration: _): .skipMergedSegment(.movement)
            case nil: .mergedEscapeDuringVisual
            case .movement:
                throw ProtocolLifecycleError.noActiveSession
            }
        }
        try await commitBreakFlow {
            coordinator.dispatch(command).events
        }
    }

    /// Single choke point for every BreakFlow mutation (Story 2.6 F1):
    /// snapshots the owned coordinator before the first dispatch and restores
    /// engine + fence on any throw, so a failed store write retries from
    /// identical state instead of double-applying.
    private func commitBreakFlow(
        recordedAt: Date? = nil,
        dispatching: () throws -> [OpportunityEventDraft],
    ) async throws {
        let checkpoint = checkpointCoordinator()
        do {
            let drafts = try dispatching()
            var candidate = coordinator.engine
            let synchronization = try await persistProtocolMutation(
                candidate: &candidate,
                drafts: drafts,
                recordedAt: recordedAt,
            )
            coordinator.engine = candidate
            lifecycleSession = nil
            publish(liveHeadsUp: nil)
            emitHeadsUpEffects(synchronization)
        } catch {
            restoreCoordinator(checkpoint)
            throw error
        }
    }

    private func opportunities(for scope: BreakScope) -> [OpportunityType] {
        switch scope {
        case .visual: [.visual]
        case .movement: [.movement]
        case .merged: [.visual, .movement]
        }
    }

    private func mirrorBreakFlowSnoozeInHeadsUpLedger(
        scope: BreakScope,
        deadline: Date,
        candidate: inout ProtocolEngine,
    ) {
        guard let headsUpRuntimePolicy else { return }
        var reducer = HeadsUpDeliveryReducer(
            state: candidate.state.headsUpDeliveryState,
            maximumSnoozeReoffers: headsUpRuntimePolicy.maximumSnoozeReoffers,
        )
        let clocks: [HeadsUpClock] = switch scope {
        case .visual: [.visual]
        case .movement: [.movement]
        case .merged: [.visual, .movement]
        }
        reducer.snoozePreviouslyPresentedClocks(clocks, until: deadline)
        candidate.synchronizeHeadsUpDeliveryState(reducer.state)
    }
}
