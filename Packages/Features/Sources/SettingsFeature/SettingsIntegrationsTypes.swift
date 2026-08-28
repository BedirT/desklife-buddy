import Domain

public struct SettingsIntegrationsRuntime: Equatable, Sendable {
    public let notifications: IntegrationCapabilityState
    public let launchAtLogin: SettingsLaunchAtLoginState

    public init(
        notifications: IntegrationCapabilityState,
        launchAtLogin: SettingsLaunchAtLoginState,
    ) {
        self.notifications = notifications
        self.launchAtLogin = launchAtLogin
    }

    public static let unavailable = SettingsIntegrationsRuntime(
        notifications: .unavailable,
        launchAtLogin: .unavailable,
    )
}

public enum SettingsLaunchAtLoginState: Equatable, Sendable {
    case unavailable
    case notRegistered
    case enabled
    case requiresApproval

    public var isEffectivelyEnabled: Bool { self == .enabled }

    public var canToggle: Bool {
        switch self {
        case .notRegistered, .enabled:
            true
        case .requiresApproval, .unavailable:
            false
        }
    }
}

public struct SettingsIntegrationsActions: Sendable {
    public var requestNotificationAuthorization: @Sendable () async -> Void
    public var openNotificationSettings: @Sendable () -> Void
    public var refresh: @Sendable () async -> Void
    public var openLoginItemsSettings: @Sendable () -> Void

    public init(
        requestNotificationAuthorization: @escaping @Sendable () async -> Void = {},
        openNotificationSettings: @escaping @Sendable () -> Void = {},
        refresh: @escaping @Sendable () async -> Void = {},
        openLoginItemsSettings: @escaping @Sendable () -> Void = {},
    ) {
        self.requestNotificationAuthorization = requestNotificationAuthorization
        self.openNotificationSettings = openNotificationSettings
        self.refresh = refresh
        self.openLoginItemsSettings = openLoginItemsSettings
    }

    public static let none = SettingsIntegrationsActions()
}
