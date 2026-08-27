import Domain
import Foundation
import StatusMenu

enum SettingsRuntimeBusyReason: Equatable {
    case activeBreak
    case headsUpDelivery
    case pendingHeadsUpAction
}

enum SettingsRuntimeMutationResult: Equatable {
    case applied
    case busy(SettingsRuntimeBusyReason)
}

enum ProtocolRuntimeSettingsError: Error, Equatable {
    case persistenceUnavailable
}

extension ProtocolRuntime {
    func reconfigure(
        _ preferences: AppPreferences,
    ) async throws -> SettingsRuntimeMutationResult {
        try await withLifecycleGate {
            if let reason = settingsBusyReason { return .busy(reason) }
            guard let settingsStore = store as? any ProtocolRuntimeSettingsStore else {
                throw ProtocolRuntimeSettingsError.persistenceUnavailable
            }
            let resolved = try settingsStore.resolve(preferences)
            let retained = state.replacingProfile(with: resolved.profileID)
            var candidate = ProtocolEngine(
                configuration: resolved.configuration,
                state: retained,
            )
            let synchronization = synchronizeHeadsUpCycles(in: &candidate)
            try await settingsStore.commitPreferences(resolved, state: candidate.state)
            configuration = resolved.configuration
            self.preferences = resolved.preferences
            engine = candidate
            statusContext = StatusMenuContext(
                estimatedActiveUseSeconds: statusContext.estimatedActiveUseSeconds,
                activeSuppression: statusContext.activeSuppression,
                manualPause: statusContext.manualPause,
                liveHeadsUp: nil,
                workingHoursOnly: preferences.schedule.workingHoursOnly,
            )
            publish(liveHeadsUp: nil)
            onConfigurationChange?(resolved.configuration)
            emitHeadsUpEffects(synchronization)
            return .applied
        }
    }

    func deleteLocalHistory() async throws {
        try await withLifecycleGate {
            guard let settingsStore = store as? any ProtocolRuntimeSettingsStore else {
                throw ProtocolRuntimeSettingsError.persistenceUnavailable
            }
            try await settingsStore.deleteHistory()
        }
    }

    func resetAllLocalData() async throws -> SettingsRuntimeMutationResult {
        try await withLifecycleGate {
            if let reason = settingsBusyReason { return .busy(reason) }
            guard let settingsStore = store as? any ProtocolRuntimeSettingsStore else {
                throw ProtocolRuntimeSettingsError.persistenceUnavailable
            }
            let freshState = ProtocolState()
            let resolved = try await settingsStore.resetAll(state: freshState)
            configuration = resolved.configuration
            preferences = resolved.preferences
            engine = ProtocolEngine(configuration: resolved.configuration, state: freshState)
            pauseUntil = nil
            indefiniteSuppression = nil
            observedSuppressions = []
            statusContext = StatusMenuContext(workingHoursOnly: true)
            publish(liveHeadsUp: nil)
            onConfigurationChange?(resolved.configuration)
            return .applied
        }
    }

    private var settingsBusyReason: SettingsRuntimeBusyReason? {
        if let appOwnedReason = settingsPresentationBusyReason() { return appOwnedReason }
        if lifecycleSession != nil || state.visualClock.phase == .running
            || state.movementClock.phase == .running {
            return .activeBreak
        }
        let deliveryState = engine.state.headsUpDeliveryState
        if deliveryState.pendingAction != nil { return .pendingHeadsUpAction }
        if deliveryState.activeDelivery != nil { return .headsUpDelivery }
        return nil
    }
}

private extension ProtocolState {
    func replacingProfile(with profileID: ProtocolProfileID) -> ProtocolState {
        ProtocolState(
            profileID: profileID,
            visualClock: visualClock,
            movementClock: movementClock,
            visualSnoozeDeadline: visualSnoozeDeadline,
            movementSnoozeDeadline: movementSnoozeDeadline,
            recoveryState: recoveryState,
            recoveryLastObservedAt: recoveryLastObservedAt,
            notAppropriateOpportunities: notAppropriateOpportunities,
            headsUpDeliveryState: headsUpDeliveryState,
        )
    }
}
