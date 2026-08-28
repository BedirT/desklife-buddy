import Domain
import Foundation
import Testing
@testable import App

@Suite("Weekly estimated active-use persistence")
struct WeeklyActiveUsePersistenceTests {
    @Test("Adjacent observations merge into one retained run")
    func mergesAdjacentRuns() async throws {
        let store = try SwiftDataProtocolStore(inMemory: true, now: { Self.date(hour: 10) })
        try await store.savePreferences(.defaults)
        try await store.appendEstimatedActiveUseRun(Self.run(hour: 9, minute: 0, seconds: 300))
        try await store.appendEstimatedActiveUseRun(Self.run(hour: 9, minute: 5, seconds: 300))

        let runs = try await store.loadEstimatedActiveUseRuns()

        #expect(runs.count == 1)
        #expect(runs.first?.startedAt == Self.date(hour: 9))
        #expect(runs.first?.endedAt == Self.date(hour: 9, minute: 10))
    }

    @Test("A real gap remains visible instead of being inferred as active use")
    func preservesGaps() async throws {
        let store = try SwiftDataProtocolStore(inMemory: true, now: { Self.date(hour: 10) })
        try await store.savePreferences(.defaults)
        try await store.appendEstimatedActiveUseRun(Self.run(hour: 9, minute: 0, seconds: 300))
        try await store.appendEstimatedActiveUseRun(Self.run(hour: 9, minute: 6, seconds: 300))

        #expect(try await store.loadEstimatedActiveUseRuns().count == 2)
    }

    @Test("Keep nothing stores no estimated active-use history")
    func historyDisabled() async throws {
        let store = try SwiftDataProtocolStore(inMemory: true, now: { Self.date(hour: 10) })
        try await store.savePreferences(AppPreferences(historyRetention: .keepNothing))

        try await store.appendEstimatedActiveUseRun(Self.run(hour: 9, minute: 0, seconds: 300))

        #expect(try await store.loadEstimatedActiveUseRuns().isEmpty)
    }

    private static func run(
        hour: Int,
        minute: Int,
        seconds: TimeInterval,
    ) throws -> EstimatedActiveUseRun {
        let start = date(hour: hour, minute: minute)
        return try EstimatedActiveUseRun(
            startedAt: start,
            endedAt: start.addingTimeInterval(seconds),
        )
    }

    private static func date(hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 24,
            hour: hour,
            minute: minute,
        ))!
    }
}

@Suite("Weekly active-use runtime capture")
struct WeeklyActiveUseRuntimeTests {
    @Test("Only the estimator's positive active-use interval is retained")
    func recordsEstimatedInterval() async throws {
        let store = WeeklyActiveUseRuntimeStore()
        var wallClock = Date(timeIntervalSinceReferenceDate: 1000)
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { wallClock },
            makeID: { UUID(uuidString: "00000000-0000-4000-8000-000000000001")! },
        )

        try await runtime.observe(.active(uptimeSeconds: 100, secondsSinceInput: 0))
        wallClock = wallClock.addingTimeInterval(5)
        try await runtime.observe(.active(uptimeSeconds: 105, secondsSinceInput: 0))

        #expect(store.runs.count == 1)
        #expect(store.runs.first?.durationSeconds == 5)
        #expect(store.runs.first?.endedAt == wallClock)
    }
}

private final class WeeklyActiveUseRuntimeStore: ProtocolRuntimeStore {
    var runs: [EstimatedActiveUseRun] = []

    func loadState() async throws -> ProtocolState? { nil }

    func commit(events: [OpportunityEvent], state: ProtocolState) async throws {}

    func commit(
        events: [OpportunityEvent],
        state: ProtocolState,
        estimatedActiveUseRun: EstimatedActiveUseRun?,
    ) async throws {
        if let estimatedActiveUseRun {
            runs.append(estimatedActiveUseRun)
        }
    }
}
