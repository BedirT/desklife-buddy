import Domain
import Foundation
import StatusMenu

enum SettingsRuntimeBusyReason: Equatable {
    case activeBreak
    case headsUpDelivery
    case pendingHeadsUpAction
}

enum SettingsRuntimeMutationResult: Equatable {
    case applied(SettingsRuntimeMutationAcknowledgement)
    case busy(SettingsRuntimeBusyReason)
}

struct SettingsRuntimeMutationAcknowledgement: Equatable {
    let resolvedPreferences: ResolvedAppPreferences
    let retainedHistoryCount: Int
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
            var savedState = candidate.state
            savedState.coordinatorFence = coordinator.actionReducer.fenceState
            let retainedHistoryCount = try await settingsStore.commitPreferences(
                resolved,
                state: savedState,
            )
            configuration = resolved.configuration
            self.preferences = resolved.preferences
            coordinator.engine = candidate
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
            return .applied(SettingsRuntimeMutationAcknowledgement(
                resolvedPreferences: resolved,
                retainedHistoryCount: retainedHistoryCount,
            ))
        }
    }

    func deleteLocalHistory() async throws -> SettingsRuntimeMutationAcknowledgement {
        try await withLifecycleGate {
            guard let settingsStore = store as? any ProtocolRuntimeSettingsStore else {
                throw ProtocolRuntimeSettingsError.persistenceUnavailable
            }
            guard let preferences else {
                throw ProtocolRuntimeSettingsError.persistenceUnavailable
            }
            let resolved = ResolvedAppPreferences(
                preferences: preferences,
                configuration: configuration,
            )
            try await settingsStore.deleteHistory()
            return SettingsRuntimeMutationAcknowledgement(
                resolvedPreferences: resolved,
                retainedHistoryCount: 0,
            )
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
            coordinator = OpportunityCoordinator(engine: ProtocolEngine(
                configuration: resolved.configuration,
                state: freshState,
            ))
            preferences = resolved.preferences
            pauseUntil = nil
            indefiniteSuppression = nil
            observedSuppressions = []
            statusContext = StatusMenuContext(workingHoursOnly: true)
            publish(liveHeadsUp: nil)
            onConfigurationChange?(resolved.configuration)
            return .applied(SettingsRuntimeMutationAcknowledgement(
                resolvedPreferences: resolved,
                retainedHistoryCount: 0,
            ))
        }
    }

    private var settingsBusyReason: SettingsRuntimeBusyReason? {
        if let appOwnedReason = settingsPresentationBusyReason() { return appOwnedReason }
        if lifecycleSession != nil || state.visualClock.phase == .running
            || state.movementClock.phase == .running
        {
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
