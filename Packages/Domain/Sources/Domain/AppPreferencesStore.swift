/// Persistence seam for the one versioned local preference value.
public protocol AppPreferencesStore {
    /// Loads stored preferences, or nil before first creation.
    func loadPreferences() async throws -> AppPreferences?

    /// Replaces stored preferences without mutating runtime clocks or event history.
    func savePreferences(_ preferences: AppPreferences) async throws

    /// Removes stored preferences so the composition root can restore current defaults.
    func deletePreferences() async throws
}

/// In-memory preferences for deterministic tests and previews.
public final class InMemoryAppPreferencesStore: AppPreferencesStore {
    private var preferences: AppPreferences?

    /// Creates a store with an optional durable-value fixture.
    public init(preferences: AppPreferences? = nil) {
        self.preferences = preferences
    }

    public func loadPreferences() async throws -> AppPreferences? {
        preferences
    }

    public func savePreferences(_ preferences: AppPreferences) async throws {
        self.preferences = preferences
    }

    public func deletePreferences() async throws {
        preferences = nil
    }
}
