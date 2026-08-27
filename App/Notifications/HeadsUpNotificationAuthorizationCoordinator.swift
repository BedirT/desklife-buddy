enum HeadsUpNotificationExplainerChoice: Equatable, Sendable {
    case continueWithNotifications
    case useInAppHeadsUp
}

struct HeadsUpNotificationAuthorizationState: Equatable, Sendable {
    var hasPresentedExplainer = false
    var hasRequestedAuthorization = false
    var usesInAppHeadsUp = false
    var hasBeenAuthorized = false
}

final class HeadsUpAuthorizationCoordinator {
    private let center: any HeadsUpNotificationCenterClient
    private let store: any HeadsUpAuthorizationStore
    private(set) var state: HeadsUpNotificationAuthorizationState
    private(set) var resolvedAuthorizationStatus: HeadsUpNotificationAuthorizationStatus?
    private var explainerSelectionTask: Task<HeadsUpPresentationChannel, Never>?

    init(
        center: any HeadsUpNotificationCenterClient,
        store: any HeadsUpAuthorizationStore = UserDefaultsHeadsUpAuthorizationStore(),
    ) {
        self.center = center
        self.store = store
        state = store.load()
    }

    func selectChannel(
        presentExplainer: @escaping () async -> HeadsUpNotificationExplainerChoice,
    ) async -> HeadsUpPresentationChannel {
        if let explainerSelectionTask {
            return await explainerSelectionTask.value
        }
        guard !state.usesInAppHeadsUp else { return .capsule }

        let settings: HeadsUpNotificationSettings
        do {
            settings = try await center.notificationSettings()
        } catch {
            return .capsule
        }

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
        if let explainerSelectionTask {
            return await explainerSelectionTask.value
        }
        guard !state.hasRequestedAuthorization else { return .capsule }
        guard !state.hasPresentedExplainer else { return .capsule }

        let task = Task {
            await resolveExplainerChoice(presentExplainer: presentExplainer)
        }
        explainerSelectionTask = task
        let channel = await task.value
        explainerSelectionTask = nil
        return channel
    }

    private func resolveExplainerChoice(
        presentExplainer: @escaping () async -> HeadsUpNotificationExplainerChoice,
    ) async -> HeadsUpPresentationChannel {
        let choice = await presentExplainer()
        state.hasPresentedExplainer = true
        switch choice {
        case .useInAppHeadsUp:
            state.usesInAppHeadsUp = true
            store.save(state)
            return .capsule
        case .continueWithNotifications:
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
