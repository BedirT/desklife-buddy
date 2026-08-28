import SettingsFeature

struct HeadsUpAuthorizationResetBoundary {
    private let store: any HeadsUpAuthorizationStore

    init(store: any HeadsUpAuthorizationStore) {
        self.store = store
    }

    func reset(
        persist: () async throws -> SettingsDestructiveResult,
    ) async throws -> SettingsDestructiveResult {
        let result = try await persist()
        if case .acknowledged = result {
            store.resetAppOwnedMetadata()
        }
        return result
    }
}
