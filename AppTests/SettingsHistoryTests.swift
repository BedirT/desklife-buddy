import Domain
import Foundation
import SwiftData
import Testing
@testable import App

@Suite("Settings history")
struct SettingsHistoryTests {
    @Test("Retention is enforced when history is read after long inactivity")
    func retentionOnRead() async throws {
        let clock = MutableSettingsClock(now)
        let store = try SwiftDataSettingsStore(inMemory: true, now: { clock.value })
        try await store.savePreferences(AppPreferences(historyRetention: .thirtyDays))
        try await store.append(event(daysOld: 0, id: 9))
        clock.value = now.addingTimeInterval(31 * 24 * 60 * 60)

        #expect(try await store.loadEvents().isEmpty)
        #expect(try await !String(decoding: store.exportHistory(format: .json), as: UTF8.self)
            .contains("00000000-0000-4000-8000-000000000009"))
    }

    @Test("A failed retention save rolls back pruning until a later successful read")
    func retentionSaveFailureRollsBack() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let clock = MutableSettingsClock(now)
        let failure = HistorySaveFailure()
        let store = try SwiftDataSettingsStore(
            container: container,
            now: { clock.value },
            save: { context in
                if failure.shouldFail { throw HistorySaveFailure.forced }
                try context.save()
            },
        )
        try await store.savePreferences(AppPreferences(historyRetention: .thirtyDays))
        try await store.append(event(daysOld: 0, id: 7))
        clock.value = now.addingTimeInterval(31 * 24 * 60 * 60)
        failure.shouldFail = true

        await #expect(throws: HistorySaveFailure.forced) {
            _ = try await store.loadEvents()
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredOpportunityEvent>()).count == 1)

        failure.shouldFail = false
        #expect(try await store.loadEvents().isEmpty)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Thirty-day retention prunes older events and includes the boundary")
    func retentionPruning() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now })
        try await store.savePreferences(AppPreferences(historyRetention: .thirtyDays))
        try await store.append(event(daysOld: 31, id: 1))
        try await store.append(event(daysOld: 30, id: 2))
        try await store.append(event(daysOld: 1, id: 3))

        try await store.pruneHistory()

        #expect(try await store.loadEvents().map(\.id) == [eventID(2), eventID(3)])
    }

    @Test("Keep nothing stores no future event facts while retaining live state")
    func keepNothing() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now })
        try await store.savePreferences(AppPreferences(historyRetention: .keepNothing))
        let state = ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 700),
        )

        try await store.commit(events: [event(daysOld: 0, id: 1)], state: state)

        #expect(try await store.loadEvents().isEmpty)
        let restored = try #require(try await store.loadState())
        #expect(restored.profileID == state.profileID)
        #expect(restored.visualClock.accumulatedActiveUseSeconds == 700)
    }

    @Test("JSON and CSV exports are stable human-readable projections")
    func humanReadableExport() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now })
        _ = try await store.loadResolvedPreferences()
        try await store.append(event(daysOld: 1, id: 2, kind: .breakStarted, duration: 120))
        try await store.append(event(daysOld: 2, id: 1, kind: .promptPresented))

        let json = try await store.exportHistory(format: .json)
        let csv = try await store.exportHistory(format: .csv)

        #expect(String(decoding: json, as: UTF8.self).contains(#""formatVersion" : 1"#))
        #expect(String(decoding: json, as: UTF8.self).contains("00000000-0000-4000-8000-000000000001"))
        #expect(String(decoding: json, as: UTF8.self).contains("promptPresented"))
        #expect(String(decoding: csv, as: UTF8.self) == """
        id,recordedAt,kind,source,opportunity,selectedDurationSeconds
        00000000-0000-4000-8000-000000000001,2027-01-13T08:00:00.000Z,promptPresented,localTimer,visual,
        00000000-0000-4000-8000-000000000002,2027-01-14T08:00:00.000Z,breakStarted,localTimer,visual,120

        """)
    }

    @Test("CSV export handles very large finite durations without trapping")
    func hugeFiniteDurationExport() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now })
        _ = try await store.loadResolvedPreferences()
        try await store.append(event(
            daysOld: 0,
            id: 8,
            kind: .breakStarted,
            duration: 1e300,
        ))

        let csv = try await String(decoding: store.exportHistory(format: .csv), as: UTF8.self)
        #expect(csv.contains(",1e+300\n"))
    }

    @Test("CSV export does not narrow a rounded Double representation of Int.max")
    func intMaxDurationExport() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now })
        _ = try await store.loadResolvedPreferences()
        let duration = TimeInterval(Int.max)
        try await store.append(event(
            daysOld: 0,
            id: 10,
            kind: .breakStarted,
            duration: duration,
        ))

        let csv = String(decoding: try await store.exportHistory(format: .csv), as: UTF8.self)
        #expect(csv.contains(",\(String(duration))\n"))
    }

    @Test("Delete history preserves preferences and crash-recovery state")
    func historyOnlyDeletion() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now })
        let preferences = AppPreferences(
            schedule: SchedulePreferences(profile: .gentle, workingHoursOnly: false),
            historyRetention: .ninetyDays,
        )
        try await store.savePreferences(preferences)
        let state = ProtocolState(
            profileID: .gentle,
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 321),
        )
        try await store.commit(events: [event(daysOld: 0, id: 1)], state: state)

        try await store.deleteHistory()

        #expect(try await store.loadEvents().isEmpty)
        #expect(try await store.loadPreferences() == preferences)
        let restored = try #require(try await store.loadState())
        #expect(restored.profileID == .gentle)
        #expect(restored.visualClock.accumulatedActiveUseSeconds == 321)
    }

    @Test("Store reset atomically removes history and replaces preferences and state with defaults")
    func resetAll() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let itemContext = ModelContext(container)
        itemContext.insert(StoredItem(
            id: UUID(),
            title: "Legacy harness row",
            isDone: false,
            createdAt: now,
        ))
        try itemContext.save()
        let store = try SwiftDataSettingsStore(container: container, now: { now })
        let preferences = AppPreferences(
            schedule: SchedulePreferences(profile: .frequentMovement, workingHoursOnly: false),
            historyRetention: .ninetyDays,
        )
        try await store.savePreferences(preferences)
        try await store.commit(
            events: [event(daysOld: 0, id: 1)],
            state: ProtocolState(
                profileID: .frequentMovement,
                visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 999),
            ),
        )

        _ = try await store.resetAll(state: ProtocolState())

        #expect(try await store.loadEvents().isEmpty)
        #expect(try await store.loadPreferences() == .defaults)
        let restored = try #require(try await store.loadState())
        #expect(restored.profileID == .balanced)
        #expect(restored.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(restored.movementClock.accumulatedActiveUseSeconds == 0)
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredItem>()).isEmpty)
    }

    @Test("Failed event deletion rolls back every retained history row")
    func deleteAllEventsSaveFailureRollsBack() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let failure = HistorySaveFailure()
        let store = try SwiftDataSettingsStore(container: container, save: { context in
            if failure.shouldFail { throw HistorySaveFailure.forced }
            try context.save()
        })
        _ = try await store.loadResolvedPreferences()
        try await store.append(event(daysOld: 0, id: 11))
        failure.shouldFail = true

        await #expect(throws: HistorySaveFailure.forced) {
            try await store.deleteAllEvents()
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredOpportunityEvent>()).count == 1)
    }

    private func event(
        daysOld: Int,
        id: Int,
        kind: OpportunityEventKind = .skipped,
        duration: TimeInterval? = nil,
    ) -> OpportunityEvent {
        OpportunityEvent(
            id: eventID(id),
            kind: kind,
            recordedAt: now.addingTimeInterval(TimeInterval(-daysOld * 24 * 60 * 60)),
            source: .localTimer,
            opportunity: .visual,
            selectedDurationSeconds: duration,
        )
    }

    private func eventID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
    }
}

private final class MutableSettingsClock {
    var value: Date

    init(_ value: Date) {
        self.value = value
    }
}

private final class HistorySaveFailure {
    static let forced = Forced()
    struct Forced: Error, Equatable {}
    var shouldFail = false
}
