import Domain
import Observation

/// Narrow boundary for an explicit Weekly read and its Settings route.
public struct WeeklyRhythmClient {
    private let loadReport: () async throws -> WeeklyRhythmReport
    private let openSchedule: () -> Void
    private let openHistory: () -> Void

    public init(
        load: @escaping () async throws -> WeeklyRhythmReport,
        openScheduleSettings: @escaping () -> Void,
        openHistorySettings: @escaping () -> Void,
    ) {
        loadReport = load
        openSchedule = openScheduleSettings
        openHistory = openHistorySettings
    }

    func load() async throws -> WeeklyRhythmReport {
        try await loadReport()
    }

    func openScheduleSettings() {
        openSchedule()
    }

    func openHistorySettings() {
        openHistory()
    }
}

/// Honest presentation lifecycle for the user-opened Weekly window.
public enum WeeklyRhythmLoadState: Equatable {
    case notLoaded
    case loading
    case loaded(WeeklyRhythmReport)
    case failed
}

@Observable
public final class WeeklyRhythmModel {
    public private(set) var state: WeeklyRhythmLoadState = .notLoaded

    private let client: WeeklyRhythmClient

    public init(client: WeeklyRhythmClient) {
        self.client = client
    }

    public var report: WeeklyRhythmReport? {
        guard case let .loaded(report) = state else { return nil }
        return report
    }

    public func load() async {
        guard state != .loading else { return }
        state = .loading
        do {
            state = try await .loaded(client.load())
        } catch {
            state = .failed
        }
    }

    public func retry() async {
        guard state == .failed else { return }
        await load()
    }

    public func openScheduleSettings() {
        client.openScheduleSettings()
    }

    public func openHistorySettings() {
        client.openHistorySettings()
    }

    public static func preview(_ input: WeeklyRhythmProjectionInput) -> WeeklyRhythmModel {
        let report = WeeklyRhythmProjection.project(input)
        let model = WeeklyRhythmModel(client: WeeklyRhythmClient(
            load: { report },
            openScheduleSettings: {},
            openHistorySettings: {},
        ))
        model.state = .loaded(report)
        return model
    }

    public static func preview(state: WeeklyRhythmLoadState) -> WeeklyRhythmModel {
        let model = WeeklyRhythmModel(client: WeeklyRhythmClient(
            load: { throw PreviewFailure.unavailable },
            openScheduleSettings: {},
            openHistorySettings: {},
        ))
        model.state = state
        return model
    }
}

private enum PreviewFailure: Error {
    case unavailable
}
