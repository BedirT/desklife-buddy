import Domain

extension SettingsFeatureModel {
    func optimisticIntegrationsState(
        for mutation: SettingsFeatureMutation,
        preferences: AppPreferences,
        base: ProtocolConfiguration,
    ) -> (AppPreferences, ProtocolConfiguration)? {
        let current = preferences.integrations
        let integrations: IntegrationPreferences
        switch mutation {
        case let .setNotificationsEnabled(enabled):
            integrations = IntegrationPreferences(
                notificationsEnabled: enabled,
                calendarBusySuppressionEnabled: current.calendarBusySuppressionEnabled,
                focusFilterEnabled: current.focusFilterEnabled,
                launchAtLoginEnabled: current.launchAtLoginEnabled,
            )
        case let .setLaunchAtLoginEnabled(enabled),
             let .reconcileLaunchAtLoginEnabled(enabled):
            integrations = IntegrationPreferences(
                notificationsEnabled: current.notificationsEnabled,
                calendarBusySuppressionEnabled: current.calendarBusySuppressionEnabled,
                focusFilterEnabled: current.focusFilterEnabled,
                launchAtLoginEnabled: enabled,
            )
        default:
            return nil
        }
        return (preferences.applying(.setIntegrations(integrations)), base)
    }
}
