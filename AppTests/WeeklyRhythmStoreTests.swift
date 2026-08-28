import Domain
import Foundation
import Testing
@testable import App

@Suite("Weekly rhythm store")
struct WeeklyRhythmStoreTests {
    @Test("Adapter joins retained preferences, aggregate runs, and event facts deterministically")
    func populatedRead() async throws {
        let fixture = WeeklyRhythmFixtures.populated
        let persistence = try SwiftDataSettingsStore(
            inMemory: true,
            now: { fixture.asOf },
        )
        try await persistence.savePreferences(AppPreferences(schedule: fixture.schedule))
        for event in fixture.events {
            try await persistence.append(event)
        }
        let store = WeeklyRhythmStore(
            store: persistence,
            loadEstimatedActiveUseRuns: { fixture.estimatedActiveUseRuns },
        )

        let report = try await store.load(
            interval: fixture.interval,
            asOf: fixture.asOf,
            calendar: fixture.calendar,
        )

        #expect(report == WeeklyRhythmProjection.project(fixture))
        #expect(report.state == .populated)
        #expect(report.contextFacts.map(\.daypart) == [.evening, .morning])
    }

    @Test("Keep nothing returns history-disabled without querying absent history sources")
    func historyDisabledShortCircuit() async throws {
        let loads = WeeklyLoadCounts()
        let fixture = WeeklyRhythmFixtures.historyDisabled
        let store = WeeklyRhythmStore(
            loadPreferences: {
                AppPreferences(historyRetention: .keepNothing)
            },
            loadEvents: {
                loads.eventLoads += 1
                return fixture.events
            },
            loadEstimatedActiveUseRuns: {
                loads.runLoads += 1
                return fixture.estimatedActiveUseRuns
            },
        )

        let report = try await store.load(
            interval: fixture.interval,
            asOf: fixture.asOf,
            calendar: fixture.calendar,
        )

        #expect(report.state == .historyDisabled)
        #expect(loads.eventLoads == 0)
        #expect(loads.runLoads == 0)
    }

    @Test("Application exclusions never enter the weekly read value")
    func excludesApplicationNames() async throws {
        let preferences = try AppPreferences(
            context: ContextPreferences(
                excludedApplicationBundleIDs: ["com.example.private-client"],
            ),
        )
        let fixture = WeeklyRhythmFixtures.sparse
        let store = WeeklyRhythmStore(
            loadPreferences: { preferences },
            loadEvents: { fixture.events },
            loadEstimatedActiveUseRuns: { fixture.estimatedActiveUseRuns },
        )

        let report = try await store.load(
            interval: fixture.interval,
            asOf: fixture.asOf,
            calendar: fixture.calendar,
        )

        #expect(!String(describing: report).contains("com.example.private-client"))
        #expect(report.contextFacts.isEmpty)
    }

    @Test("Adapter propagates source failure instead of fabricating an empty week")
    func sourceFailure() async throws {
        let store = WeeklyRhythmStore(
            loadPreferences: { .defaults },
            loadEvents: { throw WeeklyReadFailure.forced },
            loadEstimatedActiveUseRuns: { [] },
        )

        await #expect(throws: WeeklyReadFailure.forced) {
            _ = try await store.load(
                interval: WeeklyRhythmFixtures.interval,
                asOf: WeeklyRhythmFixtures.referenceDate,
                calendar: WeeklyRhythmFixtures.populated.calendar,
            )
        }
    }
}

private final class WeeklyLoadCounts {
    var eventLoads = 0
    var runLoads = 0
}

private enum WeeklyReadFailure: Error {
    case forced
}
