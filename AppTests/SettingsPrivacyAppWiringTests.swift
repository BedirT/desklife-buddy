import Domain
import Foundation
import SettingsFeature
import SwiftData
import Testing
@testable import App

// swiftlint:disable file_length

@Suite("Settings privacy App startup composition")
struct SettingsPrivacyAppStartupCompositionTests {
    @Test("The stable Settings client is truthful before startup and uses the retained store afterward")
    func startupRaceAndRetainedStore() async throws {
        let appDelegate = AppDelegate()
        let client = appDelegate.makeSettingsFeatureClient(
            chooseExportDestination: { _, _ in nil },
            writeExportData: { _, _, _ in },
        )

        await #expect(throws: SettingsPrivacyClientError.unavailable) {
            _ = try await client.load()
        }

        try await appDelegate.startApplication(arguments: [])

        #expect(appDelegate.settingsStore != nil)
        let loaded = try await client.load()
        let balanced = try ProtocolProfiles.configuration(for: .balanced)
        #expect(loaded.preferences == AppPreferences.defaults)
        #expect(loaded.configuration == balanced)
        #expect(loaded.retainedHistoryCount == 0)
    }
}

@Suite("Settings privacy App composition")
struct SettingsPrivacyAppCompositionTests {
    @Test("Ninety-day retention travels through runtime and prunes only events older than its boundary")
    func ninetyDayRetentionUsesRuntimeAndPrunes() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now })
        let resolved = try await store.loadResolvedPreferences()
        insertStoredEvent(daysOld: 91, id: 1, now: now, into: store.context)
        insertStoredEvent(daysOld: 90, id: 2, now: now, into: store.context)
        try store.context.save()
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            initialPreferences: resolved.preferences,
        )
        let client = makePrivacyClient(runtime: { runtime }, store: { store })

        let result = try await client.apply(.setHistoryRetention(.ninetyDays))

        let applied = try #require(result.appliedState)
        #expect(applied.preferences.historyRetention == .ninetyDays)
        #expect(applied.retainedHistoryCount == 1)
        #expect(runtime.preferences?.historyRetention == .ninetyDays)
        #expect(try await store.loadEvents().map(\.id) == [eventID(2)])
    }

    @Test("Applied settings acknowledge the retained count from the commit transaction")
    func appliedSettingsUseTransactionalRetainedCount() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now })
        let resolved = try await store.loadResolvedPreferences()
        insertStoredEvent(daysOld: 91, id: 1, now: now, into: store.context)
        insertStoredEvent(daysOld: 1, id: 2, now: now, into: store.context)
        try store.context.save()
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            initialPreferences: resolved.preferences,
        )
        let client = makePrivacyClient(runtime: { runtime }, store: { store })

        let result = try await client.apply(.setHistoryRetention(.ninetyDays))

        let applied = try #require(result.appliedState)
        #expect(applied.retainedHistoryCount == 1)
        #expect(try await store.loadEvents().map(\.id) == [eventID(2)])
    }

    @Test("Cancelling the export destination is quiet and writes nothing")
    func exportDestinationCancellation() async throws {
        let fixture = try await PrivacyRuntimeFixture()
        let request = try HistoryExportRequest(
            format: .json,
            selectedFields: [.id, .kind],
        )
        var writes = 0
        let client = makePrivacyClient(
            runtime: { fixture.runtime },
            store: { fixture.store },
            chooseExportDestination: { receivedRequest, suggestedName in
                #expect(receivedRequest == request)
                #expect(suggestedName == "Break History.json")
                return nil
            },
            writeExportData: { _, _, _ in writes += 1 },
        )

        let result = try await client.exportHistory(request)

        #expect(result == .cancelled)
        #expect(writes == 0)
    }

    @Test(
        "Export normalizes the chosen extension and atomically writes the store's exact bytes",
        arguments: [
            ExportFixture(
                format: .json,
                expectedExtension: "json",
            ),
            ExportFixture(
                format: .csv,
                expectedExtension: "csv",
            ),
        ],
    )
    func exportExtensionAndExactAtomicBytes(fixture: ExportFixture) async throws {
        let runtimeFixture = try await PrivacyRuntimeFixture()
        try await runtimeFixture.store.append(opportunityEvent(id: 7, recordedAt: runtimeFixture.now))
        let request = try HistoryExportRequest(
            format: fixture.format,
            selectedFields: [.id, .source, .selectedDurationSeconds],
        )
        let expectedData = try await runtimeFixture.store.exportHistory(request: request)
        let selectedURL = URL(fileURLWithPath: "/not-written/Break History")
        var captured: ExportWrite?
        let client = makePrivacyClient(
            runtime: { runtimeFixture.runtime },
            store: { runtimeFixture.store },
            chooseExportDestination: { receivedRequest, suggestedName in
                #expect(receivedRequest == request)
                #expect(suggestedName.hasSuffix(".\(fixture.expectedExtension)"))
                return selectedURL
            },
            writeExportData: { data, url, options in
                captured = ExportWrite(data: data, url: url, options: options)
            },
        )

        let result = try await client.exportHistory(request)

        let write = try #require(captured)
        #expect(write.url.pathExtension == fixture.expectedExtension)
        #expect(write.url.deletingPathExtension() == selectedURL)
        #expect(write.data == expectedData)
        #expect(write.options == .atomic)
        #expect(result == .saved(destinationName: "Break History.\(fixture.expectedExtension)"))
    }

    @Test("A destination write failure never returns export success")
    func exportWriteFailure() async throws {
        let fixture = try await PrivacyRuntimeFixture()
        let request = try HistoryExportRequest(
            format: .json,
            selectedFields: [.id],
        )
        let client = makePrivacyClient(
            runtime: { fixture.runtime },
            store: { fixture.store },
            chooseExportDestination: { _, _ in
                URL(fileURLWithPath: "/not-written/Break History.json")
            },
            writeExportData: { _, _, _ in throw PrivacyAppTestFailure.write },
        )

        await #expect(throws: PrivacyAppTestFailure.write) {
            _ = try await client.exportHistory(request)
        }
    }
}

@Suite("Settings privacy App destructive wiring")
struct SettingsPrivacyAppDestructiveTests {
    @Test("Delete-history save failure preserves the event and never acknowledges deletion")
    func deleteHistorySaveFailurePreservesData() async throws {
        let failure = PrivacySaveFailure()
        let fixture = try await PrivacyRuntimeFixture(save: { context in
            if failure.shouldFail { throw PrivacyAppTestFailure.save }
            try context.save()
        })
        try await fixture.store.append(opportunityEvent(id: 8, recordedAt: fixture.now))
        let client = makePrivacyClient(runtime: { fixture.runtime }, store: { fixture.store })
        failure.shouldFail = true

        await #expect(throws: PrivacyAppTestFailure.save) {
            _ = try await client.deleteHistory()
        }

        failure.shouldFail = false
        #expect(try await fixture.store.loadEvents().map(\.id) == [eventID(8)])
        #expect(fixture.runtime.preferences == fixture.resolved.preferences)
        #expect(fixture.runtime.state == ProtocolState())
    }

    @Test("Reset persistence failure does not publish defaults into runtime or storage")
    func resetSaveFailureDoesNotPublish() async throws {
        let failure = PrivacySaveFailure()
        let preferences = AppPreferences(
            schedule: SchedulePreferences(profile: .gentle, workingHoursOnly: false),
            historyRetention: .ninetyDays,
        )
        let retainedState = ProtocolState(
            profileID: .gentle,
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 321),
        )
        let fixture = try await PrivacyRuntimeFixture(
            preferences: preferences,
            retainedState: retainedState,
            save: { context in
                if failure.shouldFail { throw PrivacyAppTestFailure.save }
                try context.save()
            },
        )
        let client = makePrivacyClient(runtime: { fixture.runtime }, store: { fixture.store })
        let stateBeforeReset = fixture.runtime.state
        failure.shouldFail = true

        await #expect(throws: PrivacyAppTestFailure.save) {
            _ = try await client.resetAll()
        }

        #expect(fixture.runtime.preferences == preferences)
        #expect(fixture.runtime.state == stateBeforeReset)
        failure.shouldFail = false
        #expect(try await fixture.store.loadPreferences() == preferences)
        #expect(try await fixture.store.loadState() == stateBeforeReset)
    }

    @Test("Runtime delete maps to an acknowledged Feature result while preserving preferences and clocks")
    func deleteHistoryMapsAcknowledgedState() async throws {
        let retainedState = ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 444),
        )
        let fixture = try await PrivacyRuntimeFixture(retainedState: retainedState)
        try await fixture.store.append(opportunityEvent(id: 9, recordedAt: fixture.now))
        let client = makePrivacyClient(runtime: { fixture.runtime }, store: { fixture.store })
        let stateBeforeDeletion = fixture.runtime.state

        let result = try await client.deleteHistory()

        let state = try #require(result.acknowledgedState)
        #expect(state.preferences == fixture.resolved.preferences)
        #expect(state.configuration == fixture.resolved.configuration)
        #expect(state.retainedHistoryCount == 0)
        #expect(try await fixture.store.loadEvents().isEmpty)
        #expect(fixture.runtime.state == stateBeforeDeletion)
    }

    @Test("Runtime reset maps applied and busy outcomes to the exact Feature results")
    func resetMapsAppliedAndBusy() async throws {
        let idle = try await PrivacyRuntimeFixture(
            preferences: AppPreferences(
                schedule: SchedulePreferences(profile: .gentle, workingHoursOnly: false),
            ),
            retainedState: ProtocolState(
                profileID: .gentle,
                visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 222),
            ),
        )
        let idleClient = makePrivacyClient(runtime: { idle.runtime }, store: { idle.store })

        let appliedResult = try await idleClient.resetAll()

        let applied = try #require(appliedResult.acknowledgedState)
        let balanced = try ProtocolProfiles.configuration(for: .balanced)
        #expect(applied.preferences == .defaults)
        #expect(applied.configuration == balanced)
        #expect(applied.retainedHistoryCount == 0)
        #expect(idle.runtime.state == ProtocolState())

        let busy = try await PrivacyRuntimeFixture()
        try await busy.runtime.handleVisualReset(.opened)
        let runningState = busy.runtime.state
        let busyClient = makePrivacyClient(runtime: { busy.runtime }, store: { busy.store })

        #expect(try await busyClient.resetAll() == .temporarilyBusy)
        #expect(busy.runtime.state == runningState)
    }
}

#if DEBUG
    @Suite("Settings privacy verification-store wiring")
    struct SettingsPrivacyVerificationStoreTests {
        @Test("Heads-Up verification forwards the runtime Settings persistence contract")
        func verificationStoreForwardsSettingsStore() throws {
            let base = try SwiftDataSettingsStore(inMemory: true)
            let tracing = HeadsUpVerificationRuntimeStore(base: base)

            #expect((tracing as Any) is any ProtocolRuntimeSettingsStore)
        }
    }
#endif

private struct PrivacyRuntimeFixture {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store: SwiftDataSettingsStore
    let resolved: ResolvedAppPreferences
    let runtime: ProtocolRuntime

    init(
        preferences: AppPreferences = .defaults,
        retainedState: ProtocolState? = nil,
        save: ((ModelContext) throws -> Void)? = nil,
    ) async throws {
        let now = now
        let store = try SwiftDataSettingsStore(inMemory: true, now: { now }, save: save)
        let resolved = try await store.saveResolvedPreferences(preferences)
        if let retainedState {
            try await store.commitPreferences(resolved, state: retainedState)
        }
        let runtime = ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            profileID: resolved.profileID,
            initialPreferences: resolved.preferences,
            now: { now },
        )
        if retainedState != nil { try await runtime.restore() }
        self.store = store
        self.resolved = resolved
        self.runtime = runtime
    }
}

struct ExportFixture: Sendable, CustomTestStringConvertible {
    let format: HistoryExportFormat
    let expectedExtension: String

    var testDescription: String { expectedExtension }
}

private struct ExportWrite {
    let data: Data
    let url: URL
    let options: Data.WritingOptions
}

private enum PrivacyAppTestFailure: Error, Equatable {
    case save
    case write
}

private final class PrivacySaveFailure {
    var shouldFail = false
}

private func makePrivacyClient(
    runtime: @escaping () -> ProtocolRuntime?,
    store: @escaping () -> SwiftDataSettingsStore?,
    chooseExportDestination: @escaping @MainActor (
        HistoryExportRequest,
        String,
    ) async throws -> URL? = { _, _ in nil },
    writeExportData: @escaping (Data, URL, Data.WritingOptions) throws -> Void = { _, _, _ in },
) -> SettingsFeatureClient {
    SettingsFeatureAppAdapter(
        runtime: runtime,
        store: store,
        chooseExportDestination: chooseExportDestination,
        writeExportData: writeExportData,
    ).client
}

private func insertStoredEvent(
    daysOld: Int,
    id: Int,
    now: Date,
    into context: ModelContext,
) {
    context.insert(StoredOpportunityEvent(
        id: eventID(id),
        schemaVersion: 1,
        appendSequence: Int64(id),
        kind: OpportunityEventKind.skipped.rawValue,
        recordedAt: now.addingTimeInterval(TimeInterval(-daysOld * 24 * 60 * 60)),
        source: OpportunityEventSource.localTimer.rawValue,
        opportunity: OpportunityType.visual.rawValue,
        selectedDurationSeconds: nil,
    ))
}

private func opportunityEvent(id: Int, recordedAt: Date) -> OpportunityEvent {
    OpportunityEvent(
        id: eventID(id),
        kind: .breakStarted,
        recordedAt: recordedAt,
        source: .localTimer,
        opportunity: .visual,
        selectedDurationSeconds: 120,
    )
}

private func eventID(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
}

private extension SettingsApplyResult {
    var appliedState: SettingsFeatureState? {
        guard case let .applied(state) = self else { return nil }
        return state
    }
}

private extension SettingsDestructiveResult {
    var acknowledgedState: SettingsFeatureState? {
        guard case let .acknowledged(state) = self else { return nil }
        return state
    }
}
