import Domain
import Foundation
import SwiftData
import Testing
@testable import App

@Suite("Settings persistence")
struct SettingsStoreTests {
    @Test("Fresh storage installs versioned Balanced preferences with the exact generated snapshot")
    func freshDefaults() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true)
        let generated = try ProtocolProfiles.configuration(for: .balanced)

        let resolved = try await store.loadResolvedPreferences()

        #expect(resolved.preferences == .defaults)
        #expect(resolved.configuration == generated)
        #expect(resolved.profileID == .balanced)
        #expect(try await store.loadPreferences() == .defaults)
    }

    @Test("Every local preference and custom configuration survives store reconstruction")
    func customRoundTripAndRestart() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "settings-store-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "settings.store")
        let preferences = try customPreferences()
        let expected: ResolvedAppPreferences

        do {
            let container = try AppModelContainer.make(url: storeURL)
            let store = try SwiftDataSettingsStore(container: container)
            expected = try await store.saveResolvedPreferences(preferences)
            try await store.commitPreferences(
                expected,
                state: ProtocolState(
                    profileID: .custom,
                    visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 77),
                ),
            )
        }

        let reopened = try SwiftDataSettingsStore(
            container: AppModelContainer.make(url: storeURL),
        )
        let restored = try await reopened.loadResolvedPreferences()

        #expect(restored == expected)
        #expect(restored.preferences.schedule.workingHoursOnly == false)
        #expect(restored.configuration.visual.targetSeconds == 222)
        #expect(restored.configuration.movement.targetSeconds == 555)
        let state = try #require(try await reopened.loadState())
        #expect(state.profileID == .custom)
        #expect(state.visualClock.accumulatedActiveUseSeconds == 77)

        let prepared = try await AppDelegate().prepareRuntime(
            baseStore: reopened,
            runtimeStore: reopened,
            headsUpPolicy: nil,
        )
        let restartedRuntime = prepared.runtime
        try await restartedRuntime.restore()
        #expect(restartedRuntime.configuration == expected.configuration)
        #expect(restartedRuntime.state.profileID == .custom)
        #expect(restartedRuntime.state.visualClock.accumulatedActiveUseSeconds == 77)
        #expect(restartedRuntime.statusContext.workingHoursOnly == false)
        restartedRuntime.engine.resumeAfterSuppressionGrace()
        try await restartedRuntime.observe(ActivitySample(
            uptimeSeconds: 10,
            secondsSinceInput: 0,
            systemAwake: true,
            sessionActive: true,
            screenLocked: false,
        ))
        try await restartedRuntime.observe(ActivitySample(
            uptimeSeconds: 160,
            secondsSinceInput: 0,
            systemAwake: true,
            sessionActive: true,
            screenLocked: false,
        ))
        #expect(restartedRuntime.state.visualClock.accumulatedActiveUseSeconds == 227)
        #expect(restartedRuntime.state.visualClock.phase == .readyToPresent)
    }

    @Test("A retained built-in snapshot remains authoritative after generated defaults change")
    func retainedSnapshotIsAuthoritative() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let preferences = AppPreferences(
            schedule: SchedulePreferences(profile: .gentle),
        )
        let chosen = try ProtocolProfiles.configuration(for: .frequentMovement)
        try context.insert(StoredAppPreferences(
            key: "current",
            schemaVersion: 1,
            preferencesPayload: SettingsPayloadCodec.encode(preferences),
            configurationPayload: SettingsPayloadCodec.encode(chosen),
        ))
        try context.save()

        let store = try SwiftDataSettingsStore(container: container)
        let restored = try await store.loadResolvedPreferences()

        #expect(restored.preferences.schedule.profile == .gentle)
        #expect(restored.configuration == chosen)

        let edited = AppPreferences(
            schedule: SchedulePreferences(
                profile: .gentle,
                headsUpEnabled: true,
                workingHoursOnly: false,
            ),
            historyRetention: .ninetyDays,
        )
        let reconfigured = try await store.saveResolvedPreferences(edited)
        #expect(reconfigured.configuration.visual == chosen.visual)
        #expect(reconfigured.configuration.movement == chosen.movement)
        #expect(reconfigured.preferences.schedule.workingHoursOnly == false)
    }

    @Test("A pre-Settings store migrates its retained built-in profile into the first exact snapshot")
    func legacyProfileMigration() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let protocolStore = try SwiftDataProtocolStore(container: container)
        try await protocolStore.saveState(ProtocolState(
            profileID: .frequentMovement,
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 123),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 456),
        ))

        let store = try SwiftDataSettingsStore(container: container)
        let generated = try ProtocolProfiles.configuration(for: .frequentMovement)
        let migrated = try await store.loadResolvedPreferences()

        #expect(migrated.profileID == .frequentMovement)
        #expect(migrated.preferences.schedule.profile == .frequentMovement)
        #expect(migrated.configuration == generated)
        #expect(try await protocolStore.loadState()?.visualClock.accumulatedActiveUseSeconds == 123)
    }

    @Test("A file-backed pre-Settings schema reopens additively and retains its migrated snapshot")
    func fileBackedLegacyProfileMigration() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "settings-legacy-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "settings.store")
        try ProtocolStateStoreTests().seedLegacyProtocolStore(at: storeURL)

        let first = try SwiftDataSettingsStore(
            container: AppModelContainer.make(url: storeURL),
            now: { Date(timeIntervalSince1970: 30 * 24 * 60 * 60) },
        )
        let migrated = try await first.loadResolvedPreferences()
        let generated = try ProtocolProfiles.configuration(for: .frequentMovement)
        #expect(migrated.profileID == .frequentMovement)
        #expect(migrated.configuration == generated)
        #expect(try await first.loadState()?.visualClock.accumulatedActiveUseSeconds == 111)
        #expect(try await first.loadEvents().map(\.recordedAt) == [Date(timeIntervalSince1970: 0)])

        let reopened = try SwiftDataSettingsStore(
            container: AppModelContainer.make(url: storeURL),
        )
        #expect(try await reopened.loadResolvedPreferences() == migrated)
    }

    @Test("Preference and protocol state commit atomically")
    func atomicPreferenceAndStateCommit() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true)
        let original = try await store.loadResolvedPreferences()
        let changed = AppPreferences(
            schedule: SchedulePreferences(profile: .gentle, workingHoursOnly: false),
        )
        let resolved = try store.resolve(changed)
        let mismatched = ProtocolState(profileID: .balanced)

        await #expect(throws: SettingsPersistenceError.profileStateMismatch) {
            try await store.commitPreferences(resolved, state: mismatched)
        }

        #expect(try await store.loadResolvedPreferences() == original)
        #expect(try await store.loadState() == nil)
    }

    @Test("Public preference-only saves cannot diverge from retained runtime state")
    func preferenceOnlySaveRejectsRetainedState() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true)
        let original = try await store.loadResolvedPreferences()
        try await store.saveState(ProtocolState())

        await #expect(throws: SettingsPersistenceError.runtimeStateRequiresAtomicCommit) {
            try await store.savePreferences(AppPreferences(
                schedule: SchedulePreferences(profile: .gentle),
            ))
        }

        #expect(try await store.loadResolvedPreferences() == original)
        #expect(try await store.loadState()?.profileID == .balanced)
    }

    @Test("Every state write must match the retained preference profile")
    func stateWriteMatchesPreferences() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true)
        _ = try await store.loadResolvedPreferences()

        await #expect(throws: SettingsPersistenceError.profileStateMismatch) {
            try await store.saveState(ProtocolState(profileID: .gentle))
        }
        #expect(try await store.loadState() == nil)
    }

    @Test("Preferences cannot be deleted while runtime state is retained")
    func preferenceDeleteRejectsRetainedState() async throws {
        let store = try SwiftDataSettingsStore(inMemory: true)
        _ = try await store.loadResolvedPreferences()
        try await store.saveState(ProtocolState())

        await #expect(throws: SettingsPersistenceError.runtimeStateRequiresAtomicCommit) {
            try await store.deletePreferences()
        }
        #expect(try await store.loadPreferences() == .defaults)
        let state = try #require(try await store.loadState())
        #expect(state.profileID == .balanced)
        #expect(state.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(state.movementClock.accumulatedActiveUseSeconds == 0)
    }

    @Test("Failed state save and deletion both roll back their context mutations")
    func stateSaveFailuresRollBack() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let failure = SettingsSaveFailure()
        let store = try SwiftDataSettingsStore(container: container, save: { context in
            if failure.shouldFail { throw SettingsSaveFailure.forced }
            try context.save()
        })
        _ = try await store.loadResolvedPreferences()
        failure.shouldFail = true
        await #expect(throws: SettingsSaveFailure.forced) {
            try await store.saveState(ProtocolState())
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredProtocolState>()).isEmpty)

        failure.shouldFail = false
        try await store.saveState(ProtocolState())
        failure.shouldFail = true
        await #expect(throws: SettingsSaveFailure.forced) {
            try await store.deleteState()
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredProtocolState>()).count == 1)
    }

    @Test("A failed default migration rolls back its inserted preferences row")
    func migrationSaveFailureRollsBack() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let failure = SettingsSaveFailure()
        failure.shouldFail = true
        let store = try SwiftDataSettingsStore(container: container, save: { context in
            if failure.shouldFail { throw SettingsSaveFailure.forced }
            try context.save()
        })

        await #expect(throws: SettingsSaveFailure.forced) {
            _ = try await store.loadResolvedPreferences()
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredAppPreferences>()).isEmpty)

        failure.shouldFail = false
        #expect(try await store.loadResolvedPreferences().preferences == .defaults)
    }
}

private final class SettingsSaveFailure {
    static let forced = Forced()
    struct Forced: Error, Equatable {}
    var shouldFail = false
}

private func customPreferences() throws -> AppPreferences {
    try AppPreferences(
        schedule: SchedulePreferences(
            profile: .custom(CustomProtocolTiming(
                visual: OpportunityTiming(
                    softDueSeconds: 111,
                    targetSeconds: 222,
                    latestPreferredSeconds: 333,
                    durationOptionsSeconds: [20],
                ),
                movement: OpportunityTiming(
                    softDueSeconds: 444,
                    targetSeconds: 555,
                    latestPreferredSeconds: 666,
                    durationOptionsSeconds: [120, 300],
                ),
            )),
            headsUpEnabled: false,
            workingHoursOnly: false,
        ),
        historyRetention: .ninetyDays,
        content: BreakContentPreferences(preferredMovement: .mixed),
        context: ContextPreferences(waitsForLowFrictionMoment: false),
        accessibility: AccessibilityPreferences(presentation: .textOnly),
        integrations: IntegrationPreferences(notificationsEnabled: true),
    )
}
