import Domain
import SettingsFeature
import Testing
@testable import App

@Suite("Settings scene composition", .serialized)
struct SettingsSceneCompositionTests {
    @Test("The Settings scene retains one feature model across asynchronous app startup")
    func stableFeatureModelAcrossStartup() async throws {
        let integrations = makeIntegrationsRuntime(
            notificationSettings: [
                .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            ],
        )
        let appDelegate = AppDelegate()
        appDelegate.settingsIntegrationsRuntime = integrations.runtime
        let scene = appDelegate.makeSettingsSceneModel()
        let featureModel = scene.featureModel

        try await appDelegate.startApplication(arguments: [])
        await scene.load()

        let reopenedScene = appDelegate.makeSettingsSceneModel()
        let balanced = try ProtocolProfiles.configuration(for: .balanced)
        #expect(reopenedScene === scene)
        #expect(reopenedScene.featureModel === featureModel)
        #expect(featureModel.phase == .ready)
        #expect(featureModel.preferences == .defaults)
        #expect(featureModel.appliedConfiguration == balanced)
    }

    @Test("Opening Settings reads live integration status without requesting notification permission")
    func permissionFreeSettingsLoad() async throws {
        let integrations = makeIntegrationsRuntime(
            notificationSettings: [
                .init(authorizationStatus: .denied, alertsEnabled: false),
            ],
            launchAtLoginStatus: .enabled,
        )
        let appDelegate = AppDelegate()
        appDelegate.settingsIntegrationsRuntime = integrations.runtime
        let scene = appDelegate.makeSettingsSceneModel()

        await scene.loadIntegrations()

        #expect(integrations.notifications.settingsReadCount == 1)
        #expect(integrations.notifications.authorizationRequestCount == 0)
        #expect(scene.integrationsRuntime.notifications == .available(authorization: .denied))
        #expect(scene.integrationsRuntime.launchAtLogin == .enabled)
    }

    @Test("Settings injects integration actions that refresh the retained scene state")
    func integrationActionsRefreshSceneState() async throws {
        let integrations = makeIntegrationsRuntime(
            notificationSettings: [
                .init(authorizationStatus: .notDetermined, alertsEnabled: false),
                .init(authorizationStatus: .authorized, alertsEnabled: true),
            ],
        )
        let appDelegate = AppDelegate()
        appDelegate.settingsIntegrationsRuntime = integrations.runtime
        let scene = appDelegate.makeSettingsSceneModel()

        await scene.loadIntegrations()
        await scene.integrationsActions.requestNotificationAuthorization()

        #expect(integrations.notifications.authorizationRequestCount == 1)
        #expect(scene.integrationsRuntime.notifications == .available(authorization: .authorized))
    }

    @Test("The scene's feature client uses the same injected launch-at-login runtime")
    func launchAtLoginUsesInjectedRuntime() async throws {
        let integrations = makeIntegrationsRuntime(
            notificationSettings: [
                .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            ],
        )
        let appDelegate = AppDelegate()
        appDelegate.settingsIntegrationsRuntime = integrations.runtime
        let scene = appDelegate.makeSettingsSceneModel()

        try await appDelegate.startApplication(arguments: [])
        await scene.load()
        await scene.featureModel.setLaunchAtLoginEnabled(
            true,
            state: scene.integrationsRuntime.launchAtLogin,
        )

        #expect(integrations.launchAtLogin.status == .enabled)
        #expect(scene.featureModel.preferences?.integrations.launchAtLoginEnabled == true)
    }

    @Test("Approval-required launch registration is shown off and reconciled without unregistering")
    func approvalRequiredLaunchAtLoginReconciliation() async {
        let integrations = makeIntegrationsRuntime(
            notificationSettings: [
                .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            ],
            launchAtLoginStatus: .requiresApproval,
        )
        let model = SettingsFeatureModel.preview(.integrationsAvailable)
        let scene = SettingsSceneModel(featureModel: model, integrations: integrations.runtime)

        await scene.loadIntegrations()

        #expect(scene.integrationsRuntime.launchAtLogin == .requiresApproval)
        #expect(model.preferences?.integrations.launchAtLoginEnabled == false)
        #expect(integrations.launchAtLogin.status == .requiresApproval)
    }

    @Test("Returning to Settings refreshes both capabilities without prompting")
    func foregroundRefreshIsPermissionFree() async {
        let integrations = makeIntegrationsRuntime(
            notificationSettings: [
                .init(authorizationStatus: .notDetermined, alertsEnabled: false),
                .init(authorizationStatus: .authorized, alertsEnabled: true),
            ],
        )
        let scene = SettingsSceneModel(
            featureModel: .preview(.balanced),
            integrations: integrations.runtime,
        )

        await scene.loadIntegrations()
        integrations.launchAtLogin.status = .enabled
        await scene.refreshIntegrations()

        #expect(scene.integrationsRuntime.notifications == .available(authorization: .authorized))
        #expect(scene.integrationsRuntime.launchAtLogin == .enabled)
        #expect(integrations.notifications.settingsReadCount == 2)
        #expect(integrations.notifications.authorizationRequestCount == 0)
    }
}

@Suite("Settings integration projection refresh", .serialized)
struct SettingsIntegrationsRefreshTests {
    @Test("Entering Integrations refreshes a capability changed by Reset All")
    func integrationsSelectionRefreshesResetState() async {
        let integrations = makeIntegrationsRuntime(
            notificationSettings: [
                .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            ],
            launchAtLoginStatus: .enabled,
        )
        let scene = SettingsSceneModel(
            featureModel: .preview(.balanced),
            integrations: integrations.runtime,
        )
        await scene.loadIntegrations()
        integrations.launchAtLogin.status = .notRegistered

        await scene.selectedSectionDidChange(.integrations)

        #expect(scene.integrationsRuntime.launchAtLogin == .notRegistered)
        #expect(integrations.notifications.settingsReadCount == 2)
        #expect(integrations.notifications.authorizationRequestCount == 0)
    }
}

private func makeIntegrationsRuntime(
    notificationSettings: [HeadsUpNotificationSettings],
    launchAtLoginStatus: LaunchAtLoginServiceStatus = .notRegistered,
) -> (
    runtime: SettingsIntegrationsAppRuntime,
    notifications: SettingsSceneNotificationClient,
    launchAtLogin: SettingsSceneLaunchAtLoginService,
) {
    let notifications = SettingsSceneNotificationClient(settings: notificationSettings)
    let launchAtLogin = SettingsSceneLaunchAtLoginService(status: launchAtLoginStatus)
    return (
        SettingsIntegrationsAppRuntime(
            notifications: notifications,
            authorizationStore: FakeHeadsUpAuthorizationStore(),
            launchAtLogin: launchAtLogin,
        ),
        notifications,
        launchAtLogin,
    )
}

private final class SettingsSceneNotificationClient: SettingsNotificationAuthorizationClient {
    private var settings: [HeadsUpNotificationSettings]
    private(set) var settingsReadCount = 0
    private(set) var authorizationRequestCount = 0

    init(settings: [HeadsUpNotificationSettings]) {
        self.settings = settings
    }

    func notificationSettings() async throws -> HeadsUpNotificationSettings {
        settingsReadCount += 1
        if settings.count > 1 { return settings.removeFirst() }
        return settings.first ?? .init(authorizationStatus: .unknown, alertsEnabled: false)
    }

    func requestAuthorization(
        options: HeadsUpNotificationAuthorizationOptions,
    ) async throws -> Bool {
        authorizationRequestCount += 1
        return true
    }
}

private final class SettingsSceneLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginServiceStatus

    init(status: LaunchAtLoginServiceStatus) {
        self.status = status
    }

    func register() throws {
        status = .enabled
    }

    func unregister() throws {
        status = .notRegistered
    }
}
