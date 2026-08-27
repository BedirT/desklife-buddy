import Domain
import Foundation

struct HeadsUpRuntimePolicy: Equatable, Sendable {
    let maximumSnoozeReoffers: Int

    init(maximumSnoozeReoffers: Int) {
        precondition(maximumSnoozeReoffers >= 0)
        self.maximumSnoozeReoffers = maximumSnoozeReoffers
    }
}

enum HeadsUpRuntimeError: Error, Equatable {
    case policyNotConfigured
}

struct HeadsUpRuntimeObservationOutput {
    let effects: [HeadsUpDeliveryEffect]
    let retiringDeliveryID: HeadsUpDeliveryID?
}

enum HeadsUpRuntimeEffect: Equatable, Sendable {
    case reserve(HeadsUpDeliveryReservation)
    case updateCountdown(
        HeadsUpDeliveryID,
        HeadsUpCountdownMark,
        targetAt: Date
    )
    case updateTiming(HeadsUpDeliveryID, targetAt: Date)
    case land(HeadsUpDeliveryID)
    case openBreak(
        HeadsUpDeliveryID,
        opportunity: HeadsUpOpportunityID,
        source: OpportunityEventSource
    )
    case holdThenRetract(HeadsUpDeliveryID, SuppressionReason)
    case snooze(HeadsUpDeliveryID, clocks: [HeadsUpClock], until: Date)
    case skip(HeadsUpDeliveryID, opportunity: HeadsUpOpportunityID)
    case openMoreOptions(HeadsUpDeliveryID, opportunity: HeadsUpOpportunityID)
    case cancel(HeadsUpDeliveryID)
    case cancelPendingAction(HeadsUpPendingAction)
}

extension ProtocolRuntime {
    @discardableResult
    func completeHeadsUpPendingAction(
        _ id: HeadsUpDeliveryID,
        kind: HeadsUpPendingActionKind,
        opportunity: HeadsUpOpportunityID,
    ) async throws -> HeadsUpPendingAction? {
        try await withLifecycleGate {
            try await completePersistedHeadsUpAction(
                id,
                kind: kind,
                opportunity: opportunity,
            )
        }
    }

    func observeHeadsUp(_ snapshot: HeadsUpDeliverySnapshot) async throws {
        try await withLifecycleGate {
            let policy = try requiredHeadsUpRuntimePolicy()
            guard snapshot.currentVisualCycleID == engine.state.visualClock.cycleID,
                  snapshot.currentMovementCycleID == engine.state.movementClock.cycleID
            else {
                return
            }
            var reducer = HeadsUpDeliveryReducer(
                state: engine.state.headsUpDeliveryState,
                maximumSnoozeReoffers: policy.maximumSnoozeReoffers,
            )
            let retiringDeliveryID = reducer.state.activeDelivery?.id
            let output = reducer.observe(
                snapshot,
                proposedDeliveryID: HeadsUpDeliveryID(rawValue: makeID()),
            )
            var candidate = engine
            candidate.synchronizeHeadsUpDeliveryState(reducer.state)

            guard candidate.state != engine.state || !output.effects.isEmpty
            else {
                return
            }
            let synchronization = try await persistProtocolMutation(
                candidate: &candidate,
                drafts: [],
            )
            engine = candidate
            publish(liveHeadsUp: livePresentation(in: candidate))
            emitHeadsUpEffects(synchronization)
            emitHeadsUpEffects(
                output.effects,
                retiringDeliveryID: retiringDeliveryID,
            )
        }
    }

    func acknowledgeHeadsUpPresented(
        _ id: HeadsUpDeliveryID,
        channel: HeadsUpDeliveryChannel,
    ) async throws {
        try await withLifecycleGate {
            let policy = try requiredHeadsUpRuntimePolicy()
            var reducer = HeadsUpDeliveryReducer(
                state: engine.state.headsUpDeliveryState,
                maximumSnoozeReoffers: policy.maximumSnoozeReoffers,
            )
            var deferredSynchronization: [HeadsUpDeliveryEffect] = []

            if reducer.state.activeDelivery?.phase == .reserved {
                let pending = reducer.acknowledgePresented(id, channel: channel)
                guard !pending.events.isEmpty else { return }
                var pendingCandidate = engine
                pendingCandidate.synchronizeHeadsUpDeliveryState(reducer.state)
                deferredSynchronization = try await persistProtocolMutation(
                    candidate: &pendingCandidate,
                    drafts: pending.events,
                )
                engine = pendingCandidate
            }

            reducer = HeadsUpDeliveryReducer(
                state: engine.state.headsUpDeliveryState,
                maximumSnoozeReoffers: policy.maximumSnoozeReoffers,
            )
            guard reducer.acknowledgePromptFact(id) else { return }
            var acknowledgedCandidate = engine
            acknowledgedCandidate.synchronizeHeadsUpDeliveryState(reducer.state)
            let synchronization = try await persistProtocolMutation(
                candidate: &acknowledgedCandidate,
                drafts: [],
            )
            engine = acknowledgedCandidate
            publish(liveHeadsUp: livePresentation(in: acknowledgedCandidate))
            emitHeadsUpEffects(deferredSynchronization)
            emitHeadsUpEffects(synchronization)
            onHeadsUpPromptFactReady?(id)
        }
    }

    func respondToHeadsUp(
        _ id: HeadsUpDeliveryID,
        response: HeadsUpDeliveryResponse,
    ) async throws {
        try await withLifecycleGate {
            let policy = try requiredHeadsUpRuntimePolicy()
            guard let active = engine.state.headsUpDeliveryState.activeDelivery,
                  active.id == id,
                  active.phase == .presented,
                  active.promptFactStatus == .acknowledged
            else {
                return
            }
            let actionDate = now()

            var reducer = HeadsUpDeliveryReducer(
                state: engine.state.headsUpDeliveryState,
                maximumSnoozeReoffers: policy.maximumSnoozeReoffers,
            )
            let output = reducer.respond(id, response: response)
            var candidate = engine
            candidate.synchronizeHeadsUpDeliveryState(reducer.state)
            let drafts = try applyHeadsUpResponseEffects(
                output.effects,
                candidate: &candidate,
                actionDate: actionDate,
            )

            let synchronization = try await persistProtocolMutation(
                candidate: &candidate,
                drafts: drafts,
                recordedAt: actionDate,
            )
            engine = candidate
            publish(liveHeadsUp: nil)
            emitHeadsUpEffects(synchronization)
            emitHeadsUpEffects(
                output.effects,
                retiringDeliveryID: active.id,
            )
            onHeadsUpSettled?(id, response)
        }
    }
}

extension ProtocolRuntime {
    func reduceHeadsUpObservation(
        in candidate: inout ProtocolEngine,
        observedAt: Date,
        isLowFrictionMoment: Bool,
        suppressionReason: SuppressionReason?,
    ) -> HeadsUpRuntimeObservationOutput {
        guard let headsUpRuntimePolicy else {
            return HeadsUpRuntimeObservationOutput(effects: [], retiringDeliveryID: nil)
        }
        var reducer = HeadsUpDeliveryReducer(
            state: candidate.state.headsUpDeliveryState,
            maximumSnoozeReoffers: headsUpRuntimePolicy.maximumSnoozeReoffers,
        )
        let retiringDeliveryID = reducer.state.activeDelivery?.id
        let output: HeadsUpDeliveryOutput
        if let snapshot = candidate.actionableHeadsUpSnapshot(
            observedAt: observedAt,
            isLowFrictionMoment: isLowFrictionMoment,
            suppressionReason: suppressionReason,
        ) {
            output = reducer.observe(
                snapshot,
                proposedDeliveryID: HeadsUpDeliveryID(rawValue: makeID()),
            )
        } else {
            output = reducer.synchronizeCycles(
                visualCycleID: candidate.state.visualClock.cycleID,
                movementCycleID: candidate.state.movementClock.cycleID,
            )
        }
        candidate.synchronizeHeadsUpDeliveryState(reducer.state)
        return HeadsUpRuntimeObservationOutput(
            effects: output.effects,
            retiringDeliveryID: retiringDeliveryID,
        )
    }

    func requiredHeadsUpRuntimePolicy() throws -> HeadsUpRuntimePolicy {
        guard let headsUpRuntimePolicy else {
            throw HeadsUpRuntimeError.policyNotConfigured
        }
        return headsUpRuntimePolicy
    }

    func synchronizeHeadsUpCycles(
        in candidate: inout ProtocolEngine,
    ) -> [HeadsUpDeliveryEffect] {
        guard let headsUpRuntimePolicy else { return [] }
        var reducer = HeadsUpDeliveryReducer(
            state: candidate.state.headsUpDeliveryState,
            maximumSnoozeReoffers: headsUpRuntimePolicy.maximumSnoozeReoffers,
        )
        let output = reducer.synchronizeCycles(
            visualCycleID: candidate.state.visualClock.cycleID,
            movementCycleID: candidate.state.movementClock.cycleID,
        )
        candidate.synchronizeHeadsUpDeliveryState(reducer.state)
        return output.effects
    }

    func persistProtocolMutation(
        candidate: inout ProtocolEngine,
        drafts: [OpportunityEventDraft],
        recordedAt: Date? = nil,
    ) async throws -> [HeadsUpDeliveryEffect] {
        let synchronization = synchronizeHeadsUpCycles(in: &candidate)
        try await persist(drafts, state: candidate.state, recordedAt: recordedAt)
        return synchronization
    }

    func prepareRestoredHeadsUpDelivery(
        in candidate: inout ProtocolEngine,
    ) -> HeadsUpActiveDelivery? {
        guard let policy = headsUpRuntimePolicy,
              let active = candidate.state.headsUpDeliveryState.activeDelivery
        else {
            return nil
        }
        guard active.promptFactStatus == .pending else { return active }

        var reducer = HeadsUpDeliveryReducer(
            state: candidate.state.headsUpDeliveryState,
            maximumSnoozeReoffers: policy.maximumSnoozeReoffers,
        )
        guard reducer.acknowledgePromptFact(active.id) else { return active }
        candidate.synchronizeHeadsUpDeliveryState(reducer.state)
        return reducer.state.activeDelivery
    }

    func publishRestoredHeadsUpDelivery(_ active: HeadsUpActiveDelivery?) {
        guard headsUpRuntimePolicy != nil else { return }
        if let pendingAction = engine.state.headsUpDeliveryState.pendingAction {
            emitHeadsUpPendingAction(pendingAction)
        }
        guard let active else { return }
        switch active.phase {
        case .reserved:
            onHeadsUpEffect?(.reserve(HeadsUpDeliveryReservation(
                id: active.id,
                opportunity: active.opportunity,
                countdownMark: active.countdownMark,
                targetAt: active.targetAt,
            )))
        case .presented:
            onHeadsUpRestoredDelivery?(active)
            if active.promptFactStatus == .acknowledged {
                onHeadsUpPromptFactReady?(active.id)
            }
        }
    }

    func emitHeadsUpEffects(
        _ effects: [HeadsUpDeliveryEffect],
        retiringDeliveryID: HeadsUpDeliveryID? = nil,
    ) {
        if effects.contains(where: { effect in
            if case .openBreak = effect { return true }
            return false
        }), let retiringDeliveryID {
            onHeadsUpEffect?(.cancel(retiringDeliveryID))
        }
        for effect in effects {
            guard let effect = runtimeEffect(effect) else { continue }
            onHeadsUpEffect?(effect)
        }
    }

    func runtimeEffect(
        _ effect: HeadsUpDeliveryEffect,
    ) -> HeadsUpRuntimeEffect? {
        switch effect {
        case let .openBreak(opportunity):
            pendingRuntimeEffect(kind: .openBreak, opportunity: opportunity)
        case let .openMoreOptions(_, opportunity):
            pendingRuntimeEffect(kind: .openMoreOptions, opportunity: opportunity)
        case let .cancelPendingAction(action):
            .cancelPendingAction(action)
        default:
            immediateRuntimeEffect(effect)
        }
    }

    func immediateRuntimeEffect(
        _ effect: HeadsUpDeliveryEffect,
    ) -> HeadsUpRuntimeEffect? {
        switch effect {
        case let .reserve(reservation): .reserve(reservation)
        case let .updateCountdown(id, mark, targetAt):
            .updateCountdown(id, mark, targetAt: targetAt)
        case let .updateTiming(id, targetAt): .updateTiming(id, targetAt: targetAt)
        case let .land(id): .land(id)
        case let .holdThenRetract(id, reason): .holdThenRetract(id, reason)
        case let .snooze(id, clocks, deadline): .snooze(id, clocks: clocks, until: deadline)
        case let .skip(id, opportunity): .skip(id, opportunity: opportunity)
        case let .cancel(id): .cancel(id)
        case .openBreak, .openMoreOptions, .cancelPendingAction: nil
        }
    }

    func pendingRuntimeEffect(
        kind: HeadsUpPendingActionKind,
        opportunity: HeadsUpOpportunityID,
    ) -> HeadsUpRuntimeEffect? {
        guard let action = engine.state.headsUpDeliveryState.pendingAction,
              action.kind == kind,
              action.opportunity == opportunity
        else {
            return nil
        }
        return switch action.kind {
        case .openBreak:
            .openBreak(action.id, opportunity: action.opportunity, source: action.source)
        case .openMoreOptions:
            .openMoreOptions(action.id, opportunity: action.opportunity)
        }
    }

    func emitHeadsUpPendingAction(_ action: HeadsUpPendingAction) {
        let effect: HeadsUpRuntimeEffect = switch action.kind {
        case .openBreak:
            .openBreak(action.id, opportunity: action.opportunity, source: action.source)
        case .openMoreOptions:
            .openMoreOptions(action.id, opportunity: action.opportunity)
        }
        onHeadsUpEffect?(effect)
    }

    func livePresentation(in candidate: ProtocolEngine) -> OpportunityPresentation? {
        guard let opportunity = candidate.state.headsUpDeliveryState.activeDelivery?.opportunity
        else {
            return nil
        }
        return switch opportunity {
        case .visual: .visual
        case .movement: .movement
        case .merged: .merged
        }
    }

    func publishedHeadsUpPresentation(
        schedulerPresentation: OpportunityPresentation?,
        in candidate: ProtocolEngine,
    ) -> OpportunityPresentation? {
        guard headsUpRuntimePolicy != nil else { return schedulerPresentation }
        let deliveryState = candidate.state.headsUpDeliveryState
        if deliveryState.pendingAction != nil { return nil }
        return livePresentation(in: candidate) ?? schedulerPresentation
    }

}
