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
        let request = try HistoryExportRequest(
            format: .json,
            selectedFields: Set(HistoryExportField.allCases),
        )
        #expect(try await !String(decoding: store.exportHistory(request: request), as: UTF8.self)
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

    @Test("JSON schema v2 and CSV export only the request's canonically ordered selected fields")
    func humanReadableExport() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now })
        _ = try await store.loadResolvedPreferences()
        try await store.append(event(daysOld: 1, id: 2, kind: .breakStarted, duration: 120))
        try await store.append(event(daysOld: 2, id: 1, kind: .promptPresented))

        let jsonRequest = try HistoryExportRequest(
            format: .json,
            selectedFields: [.selectedDurationSeconds, .id, .opportunity],
        )
        let csvRequest = try HistoryExportRequest(
            format: .csv,
            selectedFields: [.selectedDurationSeconds, .id, .kind],
        )
        let json = try await store.exportHistory(request: jsonRequest)
        let csv = try await store.exportHistory(request: csvRequest)
        let object = try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])
        let records = try #require(object["records"] as? [[String: Any]])

        #expect(object["formatVersion"] as? Int == 2)
        #expect(object["fields"] as? [String] == ["id", "opportunity", "selectedDurationSeconds"])
        #expect(records.count == 2)
        #expect(Set(records[0].keys) == ["id", "opportunity", "selectedDurationSeconds"])
        #expect(records[0]["opportunity"] as? String == "visual")
        #expect(records[0]["selectedDurationSeconds"] is NSNull)
        #expect(records[0]["kind"] == nil)
        #expect(String(decoding: csv, as: UTF8.self) == """
        id,kind,selectedDurationSeconds
        00000000-0000-4000-8000-000000000001,promptPresented,
        00000000-0000-4000-8000-000000000002,breakStarted,120

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

        let request = try HistoryExportRequest(
            format: .csv,
            selectedFields: [.selectedDurationSeconds],
        )
        let csv = try await String(decoding: store.exportHistory(request: request), as: UTF8.self)
        #expect(csv == "selectedDurationSeconds\n1e+300\n")
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

        let request = try HistoryExportRequest(
            format: .csv,
            selectedFields: [.selectedDurationSeconds],
        )
        let csv = try await String(decoding: store.exportHistory(request: request), as: UTF8.self)
        #expect(csv == "selectedDurationSeconds\n\(String(duration))\n")
    }

    @Test("Delete history removes opportunity and active-use history while preserving preferences and state")
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
        try await store.appendEstimatedActiveUseRun(EstimatedActiveUseRun(
            startedAt: now.addingTimeInterval(-300),
            endedAt: now,
        ))

        try await store.deleteHistory()

        #expect(try await store.loadEvents().isEmpty)
        #expect(try await store.loadEstimatedActiveUseRuns().isEmpty)
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
        itemContext.insert(StoredOnboardingCompletion(
            key: "completion",
            schemaVersion: 1,
            outcome: "started",
            completedAt: now,
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
        try await store.appendEstimatedActiveUseRun(EstimatedActiveUseRun(
            startedAt: now.addingTimeInterval(-300),
            endedAt: now,
        ))

        _ = try await store.resetAll(state: ProtocolState())

        #expect(try await store.loadEvents().isEmpty)
        #expect(try await store.loadEstimatedActiveUseRuns().isEmpty)
        #expect(try await store.loadPreferences() == .defaults)
        let restored = try #require(try await store.loadState())
        #expect(restored.profileID == .balanced)
        #expect(restored.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(restored.movementClock.accumulatedActiveUseSeconds == 0)
        let inspection = ModelContext(container)
        #expect(try inspection.fetch(FetchDescriptor<StoredItem>()).isEmpty)
        let onboarding = try #require(
            try inspection.fetch(FetchDescriptor<StoredOnboardingCompletion>()).first,
        )
        #expect(onboarding.outcome == "started")
        #expect(onboarding.completedAt == now)
    }

    @Test("Loading settings removes legacy harness rows while preserving onboarding completion")
    func legacyHarnessCleanupPreservesOnboardingCompletion() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.insert(StoredItem(
            id: UUID(),
            title: "Legacy harness row",
            isDone: false,
            createdAt: now,
        ))
        context.insert(StoredOnboardingCompletion(
            key: "completion",
            schemaVersion: 1,
            outcome: "started",
            completedAt: now,
        ))
        try context.save()
        let store = try SwiftDataSettingsStore(container: container, now: { now })

        _ = try await store.loadResolvedPreferences()

        let inspection = ModelContext(container)
        #expect(try inspection.fetch(FetchDescriptor<StoredItem>()).isEmpty)
        let onboarding = try #require(
            try inspection.fetch(FetchDescriptor<StoredOnboardingCompletion>()).first,
        )
        #expect(onboarding.outcome == "started")
        #expect(onboarding.completedAt == now)
    }

    @Test("App schema has only disclosed durable models plus the cleanup-only harness model")
    func privacySchemaInventory() {
        let entityNames = Set(AppModelContainer.schema.entities.map(\.name))

        #expect(entityNames == [
            "StoredItem",
            "StoredOpportunityEvent",
            "StoredEstimatedActiveUseRun",
            "StoredProtocolState",
            "StoredAppPreferences",
            "StoredOnboardingCompletion",
            "StoredLedgerObservation",
            "StoredLedgerAssessment",
            "StoredLedgerPolicyDecision",
            "StoredLedgerCorrection",
            "StoredLedgerConsentReceipt",
            "StoredLedgerCompanionAction",
            "StoredRuleProposal",
        ])
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
