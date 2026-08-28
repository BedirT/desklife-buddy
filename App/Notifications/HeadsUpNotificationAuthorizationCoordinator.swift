enum HeadsUpNotificationExplainerChoice: Equatable, Sendable {
    case continueWithNotifications
    case useInAppHeadsUp
    case cancelled
}

struct HeadsUpNotificationAuthorizationState: Equatable, Sendable {
    var hasPresentedExplainer = false
    var hasRequestedAuthorization = false
    var usesInAppHeadsUp = false
    var hasBeenAuthorized = false
}

final class HeadsUpAuthorizationCoordinator {
    private struct PendingChannelSelection {
        let generation: Int
        let task: Task<HeadsUpPresentationChannel, Never>
    }

    private let center: any HeadsUpNotificationCenterClient
    private let store: any HeadsUpAuthorizationStore
    private(set) var state: HeadsUpNotificationAuthorizationState
    private(set) var resolvedAuthorizationStatus: HeadsUpNotificationAuthorizationStatus?
    private var channelSelectionTask: PendingChannelSelection?
    private var channelSelectionGeneration = 0
    private var nextChannelWaiterID = 0
    private var channelWaiterGenerations: [Int: Int] = [:]

    init(
        center: any HeadsUpNotificationCenterClient,
        store: any HeadsUpAuthorizationStore = UserDefaultsHeadsUpAuthorizationStore(),
    ) {
        self.center = center
        self.store = store
        state = store.load()
    }

    func automaticDeliveryChannel() -> HeadsUpPresentationChannel {
        .capsule
    }

    func requestNotificationChannel(
        presentExplainer: @escaping () async -> HeadsUpNotificationExplainerChoice,
    ) async -> HeadsUpPresentationChannel {
        if let channelSelectionTask {
            return await waitForChannelSelection(channelSelectionTask)
        }
        guard !state.usesInAppHeadsUp else { return .capsule }

        channelSelectionGeneration &+= 1
        let generation = channelSelectionGeneration
        let task = Task<HeadsUpPresentationChannel, Never> {
            await resolveChannel(presentExplainer: presentExplainer)
        }
        let selection = PendingChannelSelection(generation: generation, task: task)
        channelSelectionTask = selection
        return await waitForChannelSelection(selection)
    }

    private func resolveChannel(
        presentExplainer: @escaping () async -> HeadsUpNotificationExplainerChoice,
    ) async -> HeadsUpPresentationChannel {
        let settings: HeadsUpNotificationSettings
        do {
            settings = try await center.notificationSettings()
        } catch {
            return .capsule
        }
        guard !Task.isCancelled else { return .capsule }

        let status = resolvedStatus(for: settings.authorizationStatus)
        resolvedAuthorizationStatus = status
        switch status {
        case .authorized:
            recordAuthorization()
            return settings.alertsEnabled ? .notification : .capsule
        case .notDetermined:
            return await resolveNotDetermined(presentExplainer: presentExplainer)
        case .denied, .revoked, .provisional, .unknown:
            return .capsule
        }
    }

    private func resolveNotDetermined(
        presentExplainer: @escaping () async -> HeadsUpNotificationExplainerChoice,
    ) async -> HeadsUpPresentationChannel {
        guard !state.hasRequestedAuthorization else { return .capsule }
        guard !state.hasPresentedExplainer else { return .capsule }

        return await resolveExplainerChoice(presentExplainer: presentExplainer)
    }

    private func waitForChannelSelection(
        _ selection: PendingChannelSelection,
    ) async -> HeadsUpPresentationChannel {
        nextChannelWaiterID &+= 1
        let waiterID = nextChannelWaiterID
        channelWaiterGenerations[waiterID] = selection.generation

        return await withTaskCancellationHandler {
            let channel = await selection.task.value
            channelWaiterGenerations[waiterID] = nil
            if channelSelectionTask?.generation == selection.generation {
                channelSelectionTask = nil
            }
            return channel
        } onCancel: {
            Task { [weak self] in
                await self?.cancelChannelWaiter(
                    waiterID,
                    generation: selection.generation,
                )
            }
        }
    }

    private func cancelChannelWaiter(_ waiterID: Int, generation: Int) {
        guard channelWaiterGenerations.removeValue(forKey: waiterID) == generation else {
            return
        }
        let hasLiveWaiter = channelWaiterGenerations.values.contains(generation)
        guard !hasLiveWaiter,
              let selection = channelSelectionTask,
              selection.generation == generation
        else {
            return
        }
        selection.task.cancel()
    }

    private func resolveExplainerChoice(
        presentExplainer: @escaping () async -> HeadsUpNotificationExplainerChoice,
    ) async -> HeadsUpPresentationChannel {
        let choice = await presentExplainer()
        switch choice {
        case .useInAppHeadsUp:
            state.hasPresentedExplainer = true
            state.usesInAppHeadsUp = true
            store.save(state)
            return .capsule
        case .continueWithNotifications:
            state.hasPresentedExplainer = true
            state.hasRequestedAuthorization = true
            store.save(state)
            do {
                _ = try await center.requestAuthorization(options: [.alert])
                let refreshed = try await center.notificationSettings()
                let status = resolvedStatus(for: refreshed.authorizationStatus)
                resolvedAuthorizationStatus = status
                guard status == .authorized,
                      refreshed.alertsEnabled
                else {
                    return .capsule
                }
                recordAuthorization()
                return .notification
            } catch {
                return .capsule
            }
        case .cancelled:
            return .capsule
        }
    }

    private func resolvedStatus(
        for status: HeadsUpNotificationAuthorizationStatus,
    ) -> HeadsUpNotificationAuthorizationStatus {
        if status == .denied, state.hasBeenAuthorized {
            return .revoked
        }
        return status
    }

    private func recordAuthorization() {
        guard !state.hasBeenAuthorized else { return }
        state.hasBeenAuthorized = true
        store.save(state)
    }
}
