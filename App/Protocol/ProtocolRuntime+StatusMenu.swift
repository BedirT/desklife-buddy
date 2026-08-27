import Domain
import StatusMenu

extension ProtocolRuntime {
    func handle(_ action: StatusMenuAction) async throws {
        switch action {
        case let .pause(choice):
            try await withLifecycleGate {
                try await pause(choice)
            }
        case .resume:
            try await withLifecycleGate {
                resumeManualSuppression()
            }
        case .toggleWorkingHours:
            try await withLifecycleGate {
                toggleWorkingHoursStatus()
            }
        case let .snooze(duration):
            try await withLifecycleGate {
                try await snooze(duration)
            }
        case .startHeadsUpNow, .openSnoozeOptions, .startVisualReset, .startMovement,
             .openWeeklyRhythm, .openSettings, .quit:
            route(action)
        }
    }

    private func pause(_ choice: StatusMenuPauseChoice) async throws {
        var candidate = engine
        let suppressionReason: SuppressionReason = switch choice {
        case .presenting: .explicitPresentationMode
        case .thirtyMinutes, .oneHour, .restOfDay, .untilResume: .manualPause
        }
        let headsUpEffects = applyHeadsUpSuppression(
            suppressionReason,
            in: &candidate,
        )
        var synchronization: [HeadsUpDeliveryEffect] = []
        if !headsUpEffects.isEmpty {
            synchronization = try await persistProtocolMutation(
                candidate: &candidate,
                drafts: [],
            )
            engine = candidate
        }
        applyPause(choice)
        publish(liveHeadsUp: nil)
        emitHeadsUpEffects(synchronization)
        emitHeadsUpEffects(headsUpEffects)
    }

    private func applyHeadsUpSuppression(
        _ reason: SuppressionReason,
        in candidate: inout ProtocolEngine,
    ) -> [HeadsUpDeliveryEffect] {
        guard let headsUpRuntimePolicy else { return [] }
        var reducer = HeadsUpDeliveryReducer(
            state: candidate.state.headsUpDeliveryState,
            maximumSnoozeReoffers: headsUpRuntimePolicy.maximumSnoozeReoffers,
        )
        let output = reducer.suppress(reason)
        candidate.synchronizeHeadsUpDeliveryState(reducer.state)
        return output.effects
    }
}
