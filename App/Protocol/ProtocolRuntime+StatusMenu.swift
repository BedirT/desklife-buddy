import Domain
import StatusMenu

extension ProtocolRuntime {
    @discardableResult
    func handle(_ action: StatusMenuAction) async throws -> SettingsRuntimeMutationResult? {
        switch action {
        case let .pause(choice):
            try await withLifecycleGate {
                try await pause(choice)
            }
            return nil
        case .resume:
            try await withLifecycleGate {
                resumeManualSuppression()
            }
            return nil
        case .toggleWorkingHours:
            guard let preferences else {
                throw ProtocolRuntimeSettingsError.persistenceUnavailable
            }
            let schedule = SchedulePreferences(
                profile: preferences.schedule.profile,
                headsUpEnabled: preferences.schedule.headsUpEnabled,
                workingHoursOnly: !preferences.schedule.workingHoursOnly,
            )
            return try await reconfigure(AppPreferences(
                schedule: schedule,
                historyRetention: preferences.historyRetention,
                content: preferences.content,
                context: preferences.context,
                accessibility: preferences.accessibility,
                integrations: preferences.integrations,
            ))
        case let .snooze(duration):
            try await withLifecycleGate {
                try await snooze(duration)
            }
            return nil
        case .startHeadsUpNow, .openSnoozeOptions, .startVisualReset, .startMovement:
            try await withLifecycleGate {
                route(action)
            }
            return nil
        case .openWeeklyRhythm, .openSettings, .quit:
            route(action)
            return nil
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

    func applyHeadsUpSuppression(
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
