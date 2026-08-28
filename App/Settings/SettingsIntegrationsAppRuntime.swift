import AppKit
import Domain
import ServiceManagement
import SettingsFeature
import UserNotifications

protocol SettingsNotificationAuthorizationClient: AnyObject {
    func notificationSettings() async throws -> HeadsUpNotificationSettings
    func requestAuthorization(options: HeadsUpNotificationAuthorizationOptions) async throws -> Bool
}

final class SettingsIntegrationsAppRuntime {
    private let notifications: any SettingsNotificationAuthorizationClient
    private let authorizationStore: any HeadsUpAuthorizationStore
    private let launchAtLogin: any LaunchAtLoginService
    private let openNotificationSettings: @MainActor () -> Void
    private let openLoginItemsSettings: @MainActor () -> Void
    private var authorizationRequestTask: Task<SettingsIntegrationsRuntime, Never>?

    init(
        notifications: any SettingsNotificationAuthorizationClient,
        authorizationStore: any HeadsUpAuthorizationStore,
        launchAtLogin: any LaunchAtLoginService,
        openNotificationSettings: @escaping @MainActor () -> Void = SystemSettingsOpener.openNotifications,
        openLoginItemsSettings: @escaping @MainActor () -> Void = SystemSettingsOpener.openLoginItems,
    ) {
        self.notifications = notifications
        self.authorizationStore = authorizationStore
        self.launchAtLogin = launchAtLogin
        self.openNotificationSettings = openNotificationSettings
        self.openLoginItemsSettings = openLoginItemsSettings
    }

    static func live() -> SettingsIntegrationsAppRuntime {
        SettingsIntegrationsAppRuntime(
            notifications: UNNotificationAuthorizationClient(),
            authorizationStore: UserDefaultsHeadsUpAuthorizationStore(),
            launchAtLogin: SMAppLaunchAtLoginService(),
        )
    }

    func load() async -> SettingsIntegrationsRuntime {
        await SettingsIntegrationsRuntime(
            notifications: notificationCapability(),
            launchAtLogin: launchAtLoginCapability,
        )
    }

    func requestNotificationAuthorization() async -> SettingsIntegrationsRuntime {
        if let authorizationRequestTask {
            return await authorizationRequestTask.value
        }

        let task = Task { [weak self] in
            guard let self else { return SettingsIntegrationsRuntime.unavailable }
            return await performNotificationAuthorizationRequest()
        }
        authorizationRequestTask = task
        let runtime = await task.value
        authorizationRequestTask = nil
        return runtime
    }

    func actions(
        onRuntimeChange: @escaping @MainActor @Sendable (SettingsIntegrationsRuntime) async -> Void,
    ) -> SettingsIntegrationsActions {
        SettingsIntegrationsActions(
            requestNotificationAuthorization: { [weak self] in
                guard let self else { return }
                await onRuntimeChange(requestNotificationAuthorization())
            },
            openNotificationSettings: { [weak self] in
                Task { @MainActor in
                    self?.openNotificationSettings()
                }
            },
            refresh: { [weak self] in
                guard let self else { return }
                await onRuntimeChange(load())
            },
            openLoginItemsSettings: { [weak self] in
                Task { @MainActor in
                    self?.openLoginItemsSettings()
                }
            },
        )
    }

    var launchAtLoginMutationBoundary: LaunchAtLoginMutationBoundary {
        LaunchAtLoginMutationBoundary(service: launchAtLogin)
    }

    var authorizationMetadataResetBoundary: HeadsUpAuthorizationResetBoundary {
        HeadsUpAuthorizationResetBoundary(store: authorizationStore)
    }

    private func performNotificationAuthorizationRequest() async -> SettingsIntegrationsRuntime {
        var state = authorizationStore.load()
        state.hasPresentedExplainer = true
        state.hasRequestedAuthorization = true
        authorizationStore.save(state)

        do {
            _ = try await notifications.requestAuthorization(options: [.alert])
        } catch {
            return await load()
        }
        return await load()
    }

    private func notificationCapability() async -> IntegrationCapabilityState {
        let settings: HeadsUpNotificationSettings
        do {
            settings = try await notifications.notificationSettings()
        } catch {
            return .unavailable
        }

        var state = authorizationStore.load()
        let capability: IntegrationCapabilityState = switch settings.authorizationStatus {
        case .notDetermined:
            .available(authorization: .notDetermined)
        case .authorized where settings.alertsEnabled:
            .available(authorization: .authorized)
        case .authorized:
            .available(authorization: state.hasBeenAuthorized ? .revoked : .denied)
        case .denied:
            .available(authorization: state.hasBeenAuthorized ? .revoked : .denied)
        case .revoked:
            .available(authorization: .revoked)
        case .provisional:
            .available(authorization: .denied)
        case .unknown:
            .unavailable
        }

        if capability == .available(authorization: .authorized), !state.hasBeenAuthorized {
            state.hasBeenAuthorized = true
            authorizationStore.save(state)
        }
        return capability
    }

    private var launchAtLoginCapability: SettingsLaunchAtLoginState {
        switch launchAtLogin.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        }
    }
}

private final class UNNotificationAuthorizationClient: SettingsNotificationAuthorizationClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func notificationSettings() async throws -> HeadsUpNotificationSettings {
        let settings = await center.notificationSettings()
        return HeadsUpNotificationSettings(
            authorizationStatus: Self.map(settings.authorizationStatus),
            alertsEnabled: settings.alertSetting == .enabled,
        )
    }

    func requestAuthorization(
        options: HeadsUpNotificationAuthorizationOptions,
    ) async throws -> Bool {
        try await center.requestAuthorization(options: Self.map(options))
    }

    private static func map(
        _ status: UNAuthorizationStatus,
    ) -> HeadsUpNotificationAuthorizationStatus {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized:
            .authorized
        case .provisional, .ephemeral:
            .provisional
        @unknown default:
            .unknown
        }
    }

    private static func map(
        _ options: HeadsUpNotificationAuthorizationOptions,
    ) -> UNAuthorizationOptions {
        var mapped: UNAuthorizationOptions = []
        if options.contains(.alert) { mapped.insert(.alert) }
        return mapped
    }
}

private enum SystemSettingsOpener {
    static func openNotifications() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
