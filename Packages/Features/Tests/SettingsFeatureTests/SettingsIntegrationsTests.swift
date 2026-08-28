import Domain
import Testing
@testable import SettingsFeature

@Suite("Settings integrations")
struct SettingsIntegrationsTests {
    @Test("Launch at login distinguishes effective enablement from approval-required registration")
    func launchAtLoginEffectiveState() {
        #expect(SettingsLaunchAtLoginState.enabled.isEffectivelyEnabled)
        #expect(!SettingsLaunchAtLoginState.notRegistered.isEffectivelyEnabled)
        #expect(!SettingsLaunchAtLoginState.requiresApproval.isEffectivelyEnabled)
        #expect(!SettingsLaunchAtLoginState.unavailable.isEffectivelyEnabled)
        #expect(SettingsLaunchAtLoginState.notRegistered.canToggle)
        #expect(SettingsLaunchAtLoginState.enabled.canToggle)
        #expect(!SettingsLaunchAtLoginState.requiresApproval.canToggle)
    }

    @Test("Authorized notification edits preserve every sibling preference")
    func notificationMutationIsNarrow() async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.setNotificationsEnabled(
            false,
            capability: .available(authorization: .authorized),
        )

        let saved = try #require(model.preferences)
        #expect(!saved.integrations.notificationsEnabled)
        #expect(saved.integrations.launchAtLoginEnabled == original.integrations.launchAtLoginEnabled)
        #expect(saved.integrations.calendarBusySuppressionEnabled == original.integrations
            .calendarBusySuppressionEnabled)
        #expect(saved.integrations.focusFilterEnabled == original.integrations.focusFilterEnabled)
        expectOnlyIntegrationsChanged(from: original, to: saved)
    }

    @Test("Unavailable notification capability cannot create a dead enabled selection")
    func unavailableNotificationCannotEnable() async throws {
        let original = AppPreferences.defaults
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.setNotificationsEnabled(true, capability: .unavailable)
        await model.setNotificationsEnabled(
            true,
            capability: .available(authorization: .denied),
        )

        #expect(model.preferences == original)
        #expect(client.applyCount == 0)
    }

    @Test("Launch at login requires a live available capability")
    func launchAtLoginRequiresCapability() async throws {
        let original = AppPreferences.defaults
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.setLaunchAtLoginEnabled(true, state: .unavailable)
        await model.setLaunchAtLoginEnabled(true, state: .requiresApproval)
        #expect(client.applyCount == 0)

        await model.setLaunchAtLoginEnabled(
            true,
            state: .notRegistered,
        )

        let saved = try #require(model.preferences)
        #expect(saved.integrations.launchAtLoginEnabled)
        #expect(!saved.integrations.notificationsEnabled)
        #expect(client.applyCount == 1)
        expectOnlyIntegrationsChanged(from: original, to: saved)
    }

    @Test("External launch-at-login truth reconciles a stale persisted selection")
    func launchAtLoginReconciliationIsNarrowAndIdempotent() async throws {
        let base = try nonDefaultPreferences()
        let original = base.applying(.setIntegrations(IntegrationPreferences(
            notificationsEnabled: base.integrations.notificationsEnabled,
            launchAtLoginEnabled: true,
        )))
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.reconcileLaunchAtLoginEnabled(false)
        await model.reconcileLaunchAtLoginEnabled(false)

        let saved = try #require(model.preferences)
        #expect(!saved.integrations.launchAtLoginEnabled)
        #expect(saved.integrations.notificationsEnabled == original.integrations.notificationsEnabled)
        #expect(client.applyCount == 1)
        expectOnlyIntegrationsChanged(from: original, to: saved)
    }
}

private func expectOnlyIntegrationsChanged(from original: AppPreferences, to saved: AppPreferences) {
    #expect(saved.schedule == original.schedule)
    #expect(saved.historyRetention == original.historyRetention)
    #expect(saved.content == original.content)
    #expect(saved.context == original.context)
    #expect(saved.accessibility == original.accessibility)
}
