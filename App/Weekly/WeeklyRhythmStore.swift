import Domain
import Foundation

/// App-owned join over preference, event, and aggregate-run read sources for one weekly query.
final class WeeklyRhythmStore {
    typealias PreferencesLoader = () async throws -> AppPreferences
    typealias EventsLoader = () async throws -> [OpportunityEvent]
    typealias ActiveUseRunsLoader = () async throws -> [EstimatedActiveUseRun]

    private let loadPreferences: PreferencesLoader
    private let loadEvents: EventsLoader
    private let loadEstimatedActiveUseRuns: ActiveUseRunsLoader

    /// Creates an isolated read adapter without granting mutation, network, or presentation capability.
    init(
        loadPreferences: @escaping PreferencesLoader,
        loadEvents: @escaping EventsLoader,
        loadEstimatedActiveUseRuns: @escaping ActiveUseRunsLoader,
    ) {
        self.loadPreferences = loadPreferences
        self.loadEvents = loadEvents
        self.loadEstimatedActiveUseRuns = loadEstimatedActiveUseRuns
    }

    /// Reads retained settings and opportunity events from the shared local SwiftData store.
    convenience init(
        store: SwiftDataProtocolStore,
        loadEstimatedActiveUseRuns: @escaping ActiveUseRunsLoader,
    ) {
        self.init(
            loadPreferences: {
                try await store.loadResolvedPreferences().preferences
            },
            loadEvents: {
                try await store.loadEvents()
            },
            loadEstimatedActiveUseRuns: loadEstimatedActiveUseRuns,
        )
    }

    /// Loads exact retained facts and delegates every descriptive aggregation to Domain.
    func load(
        interval: WeeklyRhythmInterval,
        asOf: Date,
        calendar: Calendar,
    ) async throws -> WeeklyRhythmReport {
        let preferences = try await loadPreferences()
        guard preferences.historyRetention != .keepNothing else {
            return WeeklyRhythmProjection.project(WeeklyRhythmProjectionInput(
                interval: interval,
                asOf: asOf,
                calendar: calendar,
                retention: .keepNothing,
                schedule: preferences.schedule,
                estimatedActiveUseRuns: [],
                events: [],
            ))
        }
        let events = try await loadEvents()
        let runs = try await loadEstimatedActiveUseRuns()
        return WeeklyRhythmProjection.project(WeeklyRhythmProjectionInput(
            interval: interval,
            asOf: asOf,
            calendar: calendar,
            retention: preferences.historyRetention,
            schedule: preferences.schedule,
            estimatedActiveUseRuns: runs,
            events: events,
        ))
    }
}
