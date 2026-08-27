/// Domain boundary used to prove the different effects of history deletion and full reset.
public struct LocalDataSnapshot: Equatable, Sendable {
    public let preferences: AppPreferences
    public let history: [OpportunityEvent]

    /// Creates the local values affected by Settings destructive operations.
    public init(preferences: AppPreferences, history: [OpportunityEvent]) {
        self.preferences = preferences
        self.history = history
    }

    /// Applies an explicit destructive operation without conflating its deletion boundary.
    public func applying(_ operation: LocalDataOperation) -> LocalDataSnapshot {
        switch operation {
        case .deleteHistory:
            LocalDataSnapshot(preferences: preferences, history: [])
        case .resetAll:
            LocalDataSnapshot(preferences: .defaults, history: [])
        }
    }
}

/// Destructive Settings operations whose scopes must remain visibly different.
public enum LocalDataOperation: Equatable, Sendable {
    case deleteHistory
    case resetAll
}
