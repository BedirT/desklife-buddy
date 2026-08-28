import Domain
import Foundation
import SettingsFeature
import Testing
@testable import App

@Suite("Settings integrations App runtime")
struct SettingsIntegrationsAppRuntimeTests {
    @Test(
        "Reading notification capability never prompts and maps live authorization",
        arguments: [
            NotificationCapabilityFixture(
                settings: .init(authorizationStatus: .notDetermined, alertsEnabled: false),
                wasAuthorized: false,
                expected: .available(authorization: .notDetermined),
            ),
            NotificationCapabilityFixture(
                settings: .init(authorizationStatus: .authorized, alertsEnabled: true),
                wasAuthorized: false,
                expected: .available(authorization: .authorized),
            ),
            NotificationCapabilityFixture(
                settings: .init(authorizationStatus: .denied, alertsEnabled: false),
                wasAuthorized: false,
                expected: .available(authorization: .denied),
            ),
            NotificationCapabilityFixture(
                settings: .init(authorizationStatus: .denied, alertsEnabled: false),
                wasAuthorized: true,
                expected: .available(authorization: .revoked),
            ),
            NotificationCapabilityFixture(
                settings: .init(authorizationStatus: .authorized, alertsEnabled: false),
                wasAuthorized: true,
                expected: .available(authorization: .revoked),
            ),
            NotificationCapabilityFixture(
                settings: .init(authorizationStatus: .provisional, alertsEnabled: true),
                wasAuthorized: false,
                expected: .available(authorization: .denied),
            ),
            NotificationCapabilityFixture(
                settings: .init(authorizationStatus: .unknown, alertsEnabled: false),
                wasAuthorized: false,
                expected: .unavailable,
            ),
        ],
    )
    func notificationCapability(fixture: NotificationCapabilityFixture) async {
        let center = FakeHeadsUpNotificationCenter(settings: [fixture.settings])
        let authorizationStore = FakeHeadsUpAuthorizationStore()
        authorizationStore.state.hasBeenAuthorized = fixture.wasAuthorized
        let launchAtLogin = FakeLaunchAtLoginService(status: .notRegistered)
        let adapter = SettingsIntegrationsAppRuntime(
            notifications: center,
            authorizationStore: authorizationStore,
            launchAtLogin: launchAtLogin,
        )

        let runtime = await adapter.load()

        #expect(runtime.notifications == fixture.expected)
        #expect(center.settingsReadCount == 1)
        #expect(center.authorizationRequestCount == 0)
    }

    @Test("A notification settings read failure reports unavailable without prompting")
    func notificationReadFailure() async {
        let center = FakeHeadsUpNotificationCenter(settings: [])
        center.settingsError = SettingsIntegrationsTestError.notification
        let adapter = SettingsIntegrationsAppRuntime(
            notifications: center,
            authorizationStore: FakeHeadsUpAuthorizationStore(),
            launchAtLogin: FakeLaunchAtLoginService(status: .enabled),
        )

        let runtime = await adapter.load()

        #expect(runtime.notifications == .unavailable)
        #expect(runtime.launchAtLogin == .enabled)
        #expect(center.authorizationRequestCount == 0)
    }

    @Test("An explicit notification setup requests alerts once and refreshes live state")
    func requestNotificationAuthorization() async {
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .authorized, alertsEnabled: true),
        ])
        let authorizationStore = FakeHeadsUpAuthorizationStore()
        let adapter = SettingsIntegrationsAppRuntime(
            notifications: center,
            authorizationStore: authorizationStore,
            launchAtLogin: FakeLaunchAtLoginService(status: .notRegistered),
        )

        let runtime = await adapter.requestNotificationAuthorization()

        #expect(center.authorizationRequestCount == 1)
        #expect(center.requestedOptions == [.alert])
        #expect(center.settingsReadCount == 1)
        #expect(runtime.notifications == .available(authorization: .authorized))
        #expect(authorizationStore.state.hasPresentedExplainer)
        #expect(authorizationStore.state.hasRequestedAuthorization)
        #expect(authorizationStore.state.hasBeenAuthorized)
        #expect(!authorizationStore.state.usesInAppHeadsUp)
    }

    @Test("A failed explicit notification request remains recoverable and does not claim authorization")
    func requestNotificationAuthorizationFailure() async {
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        center.authorizationError = SettingsIntegrationsTestError.notification
        let authorizationStore = FakeHeadsUpAuthorizationStore()
        let adapter = SettingsIntegrationsAppRuntime(
            notifications: center,
            authorizationStore: authorizationStore,
            launchAtLogin: FakeLaunchAtLoginService(status: .notRegistered),
        )

        let runtime = await adapter.requestNotificationAuthorization()

        #expect(runtime.notifications == .available(authorization: .notDetermined))
        #expect(authorizationStore.state.hasPresentedExplainer)
        #expect(authorizationStore.state.hasRequestedAuthorization)
        #expect(!authorizationStore.state.hasBeenAuthorized)
    }

    @Test("Feature actions refresh and route both System Settings recovery actions")
    func featureActions() async {
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .denied, alertsEnabled: false),
        ])
        var openedSettings = 0
        var openedLoginItems = 0
        let adapter = SettingsIntegrationsAppRuntime(
            notifications: center,
            authorizationStore: FakeHeadsUpAuthorizationStore(),
            launchAtLogin: FakeLaunchAtLoginService(status: .notRegistered),
            openNotificationSettings: { openedSettings += 1 },
            openLoginItemsSettings: { openedLoginItems += 1 },
        )
        var refreshedRuntime: SettingsIntegrationsRuntime?
        let actions = adapter.actions { refreshedRuntime = $0 }

        await actions.requestNotificationAuthorization()
        actions.openNotificationSettings()
        await actions.refresh()
        actions.openLoginItemsSettings()
        await Task.yield()

        #expect(center.authorizationRequestCount == 1)
        #expect(openedSettings == 1)
        #expect(openedLoginItems == 1)
        #expect(refreshedRuntime != nil)
    }

    @Test(
        "Launch at login capability is available when Service Management can address the main app",
        arguments: [
            LaunchCapabilityFixture(status: .notRegistered, expected: .notRegistered),
            LaunchCapabilityFixture(status: .enabled, expected: .enabled),
            LaunchCapabilityFixture(status: .requiresApproval, expected: .requiresApproval),
            LaunchCapabilityFixture(status: .notFound, expected: .unavailable),
        ],
    )
    func launchCapability(fixture: LaunchCapabilityFixture) async {
        let adapter = SettingsIntegrationsAppRuntime(
            notifications: FakeHeadsUpNotificationCenter(settings: [
                .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            ]),
            authorizationStore: FakeHeadsUpAuthorizationStore(),
            launchAtLogin: FakeLaunchAtLoginService(status: fixture.status),
        )

        #expect(await adapter.load().launchAtLogin == fixture.expected)
    }
}

@Suite("Settings launch-at-login mutation boundary")
struct SettingsLaunchAtLoginMutationBoundaryTests {
    @Test("Enabling registers before preferences acknowledge the selection")
    func enable() async throws {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let boundary = LaunchAtLoginMutationBoundary(service: service)
        let expectedState = try SettingsFeatureState.preview()
        var order: [String] = []
        service.onEvent = { order.append($0) }

        let result = try await boundary.apply(enabled: true) {
            order.append("persist")
            return .applied(expectedState)
        }

        #expect(result == .applied(expectedState))
        #expect(order == ["register", "persist"])
        #expect(service.status == .enabled)
    }

    @Test("Disabling unregisters before preferences acknowledge the selection")
    func disable() async throws {
        let service = FakeLaunchAtLoginService(status: .enabled)
        let boundary = LaunchAtLoginMutationBoundary(service: service)
        let expectedState = try SettingsFeatureState.preview()
        var order: [String] = []
        service.onEvent = { order.append($0) }

        let result = try await boundary.apply(enabled: false) {
            order.append("persist")
            return .applied(expectedState)
        }

        #expect(result == .applied(expectedState))
        #expect(order == ["unregister", "persist"])
        #expect(service.status == .notRegistered)
    }

    @Test("A busy runtime restores the prior system registration")
    func busyRollback() async throws {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let boundary = LaunchAtLoginMutationBoundary(service: service)

        let result = try await boundary.apply(enabled: true) { .temporarilyBusy }

        #expect(result == .temporarilyBusy)
        #expect(service.events == ["register", "unregister"])
        #expect(service.status == .notRegistered)
    }

    @Test("A persistence failure restores the prior system registration")
    func persistenceFailureRollback() async {
        let service = FakeLaunchAtLoginService(status: .enabled)
        let boundary = LaunchAtLoginMutationBoundary(service: service)

        await #expect(throws: SettingsIntegrationsTestError.persistence) {
            _ = try await boundary.apply(enabled: false) {
                throw SettingsIntegrationsTestError.persistence
            }
        }

        #expect(service.events == ["unregister", "register"])
        #expect(service.status == .enabled)
    }

    @Test("A system registration failure never persists an enabled selection")
    func registrationFailure() async {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.registerError = SettingsIntegrationsTestError.service
        let boundary = LaunchAtLoginMutationBoundary(service: service)
        var persisted = false

        await #expect(throws: SettingsIntegrationsTestError.service) {
            _ = try await boundary.apply(enabled: true) {
                persisted = true
                return .temporarilyBusy
            }
        }

        #expect(!persisted)
        #expect(service.status == .notRegistered)
    }

    @Test("A compensation failure is surfaced instead of claiming a quiet rollback")
    func rollbackFailure() async {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.unregisterError = SettingsIntegrationsTestError.service
        let boundary = LaunchAtLoginMutationBoundary(service: service)

        await #expect(throws: LaunchAtLoginMutationError.rollbackFailed) {
            _ = try await boundary.apply(enabled: true) { .temporarilyBusy }
        }

        #expect(service.status == .enabled)
    }
}

@Suite("Settings integrations App adapter wiring")
struct SettingsIntegrationsAppAdapterWiringTests {
    @Test("The launch-at-login mutation registers the system service and persists one preference")
    func launchAtLoginAppliesThroughBoundary() async throws {
        let poison = PostCommitProjectionPoison()
        let store = try SwiftDataSettingsStore(inMemory: true, save: { context in
            try context.save()
            guard poison.shouldPoison else { return }
            context.insert(StoredOpportunityEvent(
                id: UUID(),
                schemaVersion: 1,
                appendSequence: 1,
                kind: "invalid-post-commit-kind",
                recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
                source: OpportunityEventSource.localTimer.rawValue,
                opportunity: OpportunityType.visual.rawValue,
                selectedDurationSeconds: nil,
            ))
        })
        let resolved = try await store.loadResolvedPreferences()
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            initialPreferences: resolved.preferences,
        )
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let client = settingsClient(runtime: runtime, store: store, service: service)
        poison.shouldPoison = true

        let result = try await client.apply(.setLaunchAtLoginEnabled(true))

        guard case let .applied(state) = result else {
            Issue.record("Expected launch-at-login preference to be applied")
            return
        }
        #expect(state.preferences.integrations.launchAtLoginEnabled)
        #expect(runtime.preferences?.integrations.launchAtLoginEnabled == true)
        #expect(try await store.loadPreferences()?.integrations.launchAtLoginEnabled == true)
        #expect(service.events == ["register"])
    }

    @Test("A busy runtime compensates the system registration and keeps the preference disabled")
    func launchAtLoginBusyCompensates() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true)
        let resolved = try await store.loadResolvedPreferences()
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            initialPreferences: resolved.preferences,
        )
        try await runtime.handleVisualReset(.opened)
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let client = settingsClient(runtime: runtime, store: store, service: service)

        let result = try await client.apply(.setLaunchAtLoginEnabled(true))

        #expect(result == .temporarilyBusy)
        #expect(runtime.preferences?.integrations.launchAtLoginEnabled == false)
        #expect(try await store.loadPreferences()?.integrations.launchAtLoginEnabled == false)
        #expect(service.events == ["register", "unregister"])
    }

    @Test("External launch-at-login reconciliation persists effective status without mutating the service")
    func launchAtLoginExternalReconciliation() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true)
        let resolved = try await store.loadResolvedPreferences()
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            initialPreferences: resolved.preferences,
        )
        let service = FakeLaunchAtLoginService(status: .enabled)
        let client = settingsClient(runtime: runtime, store: store, service: service)

        let result = try await client.apply(.reconcileLaunchAtLoginEnabled(true))

        guard case let .applied(state) = result else {
            Issue.record("Expected external launch-at-login status to be reconciled")
            return
        }
        #expect(state.preferences.integrations.launchAtLoginEnabled)
        #expect(runtime.preferences?.integrations.launchAtLoginEnabled == true)
        #expect(try await store.loadPreferences()?.integrations.launchAtLoginEnabled == true)
        #expect(service.events.isEmpty)
    }

    @Test("Reset All disables Launch at Login and then persists defaults")
    func resetAllDisablesLaunchAtLogin() async throws {
        let preferences = AppPreferences(
            integrations: IntegrationPreferences(launchAtLoginEnabled: true),
        )
        let store = try SwiftDataSettingsStore(inMemory: true)
        let resolved = try await store.saveResolvedPreferences(preferences)
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            initialPreferences: resolved.preferences,
        )
        let service = FakeLaunchAtLoginService(status: .enabled)
        let authorizationStore = FakeHeadsUpAuthorizationStore()
        authorizationStore.state = HeadsUpNotificationAuthorizationState(
            hasPresentedExplainer: true,
            hasRequestedAuthorization: true,
            usesInAppHeadsUp: true,
            hasBeenAuthorized: true,
        )
        let client = settingsClient(
            runtime: runtime,
            store: store,
            service: service,
            authorizationStore: authorizationStore,
        )

        let result = try await client.resetAll()

        guard case let .acknowledged(state) = result else {
            Issue.record("Expected Reset All to be acknowledged")
            return
        }
        #expect(state.preferences == .defaults)
        #expect(service.status == .notRegistered)
        #expect(service.events == ["unregister"])
        #expect(authorizationStore.state == HeadsUpNotificationAuthorizationState())
        #expect(try await store.loadPreferences() == .defaults)
    }

    @Test("A busy Reset All restores Launch at Login and preserves preferences")
    func resetAllBusyRestoresLaunchAtLogin() async throws {
        let preferences = AppPreferences(
            integrations: IntegrationPreferences(launchAtLoginEnabled: true),
        )
        let store = try SwiftDataSettingsStore(inMemory: true)
        let resolved = try await store.saveResolvedPreferences(preferences)
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            initialPreferences: resolved.preferences,
        )
        try await runtime.handleVisualReset(.opened)
        let service = FakeLaunchAtLoginService(status: .enabled)
        let authorizationStore = FakeHeadsUpAuthorizationStore()
        let previousAuthorizationState = HeadsUpNotificationAuthorizationState(
            hasPresentedExplainer: true,
            hasRequestedAuthorization: true,
            usesInAppHeadsUp: false,
            hasBeenAuthorized: true,
        )
        authorizationStore.state = previousAuthorizationState
        let client = settingsClient(
            runtime: runtime,
            store: store,
            service: service,
            authorizationStore: authorizationStore,
        )

        let result = try await client.resetAll()

        #expect(result == .temporarilyBusy)
        #expect(service.status == .enabled)
        #expect(service.events == ["unregister", "register"])
        #expect(authorizationStore.state == previousAuthorizationState)
        #expect(try await store.loadPreferences() == preferences)
    }

    @Test("A Reset All persistence failure restores Launch at Login")
    func resetAllPersistenceFailureRestoresLaunchAtLogin() async throws {
        let failure = ResetAllSaveFailure()
        let preferences = AppPreferences(
            integrations: IntegrationPreferences(launchAtLoginEnabled: true),
        )
        let store = try SwiftDataSettingsStore(inMemory: true, save: { context in
            if failure.shouldFail { throw SettingsIntegrationsTestError.persistence }
            try context.save()
        })
        let resolved = try await store.saveResolvedPreferences(preferences)
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            initialPreferences: resolved.preferences,
        )
        let service = FakeLaunchAtLoginService(status: .enabled)
        let authorizationStore = FakeHeadsUpAuthorizationStore()
        let previousAuthorizationState = HeadsUpNotificationAuthorizationState(
            hasPresentedExplainer: true,
            hasRequestedAuthorization: true,
            usesInAppHeadsUp: true,
            hasBeenAuthorized: true,
        )
        authorizationStore.state = previousAuthorizationState
        let client = settingsClient(
            runtime: runtime,
            store: store,
            service: service,
            authorizationStore: authorizationStore,
        )
        failure.shouldFail = true

        await #expect(throws: SettingsIntegrationsTestError.persistence) {
            _ = try await client.resetAll()
        }

        #expect(service.status == .enabled)
        #expect(service.events == ["unregister", "register"])
        #expect(authorizationStore.state == previousAuthorizationState)
        failure.shouldFail = false
        #expect(try await store.loadPreferences() == preferences)
    }

    @Test("A Reset All unregister failure leaves persistence untouched")
    func resetAllUnregisterFailureDoesNotPersist() async throws {
        let preferences = AppPreferences(
            integrations: IntegrationPreferences(launchAtLoginEnabled: true),
        )
        let store = try SwiftDataSettingsStore(inMemory: true)
        let resolved = try await store.saveResolvedPreferences(preferences)
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            initialPreferences: resolved.preferences,
        )
        let service = FakeLaunchAtLoginService(status: .enabled)
        service.unregisterError = SettingsIntegrationsTestError.service
        let authorizationStore = FakeHeadsUpAuthorizationStore()
        let previousAuthorizationState = HeadsUpNotificationAuthorizationState(
            hasPresentedExplainer: true,
            hasRequestedAuthorization: true,
            usesInAppHeadsUp: false,
            hasBeenAuthorized: true,
        )
        authorizationStore.state = previousAuthorizationState
        let client = settingsClient(
            runtime: runtime,
            store: store,
            service: service,
            authorizationStore: authorizationStore,
        )

        await #expect(throws: SettingsIntegrationsTestError.service) {
            _ = try await client.resetAll()
        }

        #expect(service.status == .enabled)
        #expect(service.events == ["unregister"])
        #expect(authorizationStore.state == previousAuthorizationState)
        #expect(try await store.loadPreferences() == preferences)
    }

    private func settingsClient(
        runtime: ProtocolRuntime,
        store: SwiftDataSettingsStore,
        service: FakeLaunchAtLoginService,
        authorizationStore: FakeHeadsUpAuthorizationStore? = nil,
    ) -> SettingsFeatureClient {
        SettingsFeatureAppAdapter(
            runtime: { runtime },
            store: { store },
            chooseExportDestination: { _, _ in nil },
            writeExportData: { _, _, _ in },
            launchAtLoginMutationBoundary: LaunchAtLoginMutationBoundary(service: service),
            authorizationMetadataResetBoundary: authorizationStore.map {
                HeadsUpAuthorizationResetBoundary(store: $0)
            },
        ).client
    }
}

struct NotificationCapabilityFixture: Sendable, CustomTestStringConvertible {
    let settings: HeadsUpNotificationSettings
    let wasAuthorized: Bool
    let expected: IntegrationCapabilityState

    var testDescription: String {
        "\(settings.authorizationStatus)-alerts-\(settings.alertsEnabled)-prior-\(wasAuthorized)"
    }
}

struct LaunchCapabilityFixture: Sendable, CustomTestStringConvertible {
    let status: LaunchAtLoginServiceStatus
    let expected: SettingsLaunchAtLoginState

    var testDescription: String { "\(status)" }
}

private enum SettingsIntegrationsTestError: Error, Equatable {
    case notification
    case persistence
    case service
}

private final class FakeLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginServiceStatus
    var registerError: Error?
    var unregisterError: Error?
    var onEvent: ((String) -> Void)?
    private(set) var events: [String] = []

    init(status: LaunchAtLoginServiceStatus) {
        self.status = status
    }

    func register() throws {
        events.append("register")
        onEvent?("register")
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        events.append("unregister")
        onEvent?("unregister")
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}

private final class ResetAllSaveFailure {
    var shouldFail = false
}

private final class PostCommitProjectionPoison {
    var shouldPoison = false
}

private extension SettingsFeatureState {
    static func preview() throws -> Self {
        try SettingsFeatureState(
            preferences: .defaults,
            configuration: ProtocolProfiles.configuration(for: .balanced),
        )
    }
}

extension FakeHeadsUpNotificationCenter: SettingsNotificationAuthorizationClient {}
