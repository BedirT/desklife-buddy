import Domain
import Foundation
import Testing
@testable import SettingsFeature

@Suite("Settings schedule model")
struct SettingsModelTests {
    @Test("Opening Custom does not select it before a successful save")
    func customEditorDoesNotSelect() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { SettingsFeatureState(preferences: .defaults, configuration: catalog.balanced) },
                apply: { _ in .temporarilyBusy },
            ),
            catalog: catalog,
        )
        await model.load()

        await model.selectProfile(SettingsScheduleChoice.custom)

        #expect(model.isCustomEditing)
        #expect(model.selectedScheduleChoice == .balanced)
        #expect(model.selectedProfileID == .balanced)
    }

    @Test("Failed built-in selection from Custom restores the full Custom editing state")
    func customRollback() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let timing = try customTiming(visual: 23, movement: 49)
        let preferences = AppPreferences(schedule: SchedulePreferences(profile: .custom(timing)))
        let exact = preferences.protocolConfiguration(applyingTo: catalog.balanced)
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { SettingsFeatureState(preferences: preferences, configuration: exact) },
                apply: { _ in throw TestFailure.save },
            ),
            catalog: catalog,
        )
        await model.load()

        await model.selectProfile(SettingsScheduleChoice.gentle)

        #expect(model.operationState == .failed)
        #expect(model.preferences == preferences)
        #expect(model.selectedConfiguration == exact)
        #expect(model.selectedScheduleChoice == .custom)
        #expect(model.isCustomEditing)
        #expect(model.customDraft == CustomScheduleDraft(timing: timing))
    }

    @Test("Reload fully rebuilds derived Custom state when durable selection changes")
    func reloadRebuildsCustomState() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let timing = try customTiming(visual: 23, movement: 49)
        let customPreferences = AppPreferences(schedule: SchedulePreferences(profile: .custom(timing)))
        let builtInPreferences = AppPreferences(schedule: SchedulePreferences(profile: .gentle))
        let states = ReloadStates([
            SettingsFeatureState(
                preferences: customPreferences,
                configuration: customPreferences.protocolConfiguration(applyingTo: catalog.balanced),
            ),
            SettingsFeatureState(preferences: builtInPreferences, configuration: catalog.gentle),
        ])
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(load: { states.next() }, apply: { _ in .temporarilyBusy }),
            catalog: catalog,
        )

        await model.load()
        #expect(model.isCustomEditing)
        await model.load()

        #expect(model.selectedScheduleChoice == .gentle)
        #expect(!model.isCustomEditing)
        #expect(!model.isAdvancedScheduleExpanded)
        #expect(model.customDraft == CustomScheduleDraft(configuration: catalog.gentle))
    }

    @Test("Valid finite extreme Custom timings produce overflow-safe summaries")
    func extremeCustomSummaries() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let timing = try CustomProtocolTiming(
            visual: OpportunityTiming(
                softDueSeconds: 0.9e300,
                targetSeconds: 1e300,
                latestPreferredSeconds: 1.1e300,
                durationOptionsSeconds: [1e299],
            ),
            movement: OpportunityTiming(
                softDueSeconds: 1.2e300,
                targetSeconds: 1.3e300,
                latestPreferredSeconds: 1.4e300,
                durationOptionsSeconds: [1e299, 0.5e299],
            ),
        )
        let preferences = AppPreferences(schedule: SchedulePreferences(profile: .custom(timing)))
        let exact = preferences.protocolConfiguration(applyingTo: catalog.balanced)
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { SettingsFeatureState(preferences: preferences, configuration: exact) },
                apply: { _ in .temporarilyBusy },
            ),
            catalog: catalog,
        )

        await model.load()

        #expect(model.visualTimingSummary?.contains("about every") == true)
        #expect(model.movementTimingSummary?.contains("suggested") == true)
    }

    @Test("A narrow mutation merges into the client's latest durable preferences")
    func narrowMutationPreservesConcurrentDurableChange() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let client = TestSettingsClient(preferences: .defaults)
        let model = SettingsFeatureModel(client: client, catalog: catalog)
        await model.load()
        client.preferences = client.preferences.applying(.setSchedule(SchedulePreferences(
            profile: .balanced,
            headsUpEnabled: true,
            workingHoursOnly: false,
        )))

        await model.selectProfile(SettingsScheduleChoice.gentle)

        #expect(model.selectedProfileID == .gentle)
        #expect(model.preferences?.schedule.workingHoursOnly == false)
    }

    @Test("Sidebar selection is deterministic")
    func sidebarSelection() async throws {
        let model = try SettingsFeatureModel(client: TestSettingsClient(preferences: .defaults), catalog: .fixture())
        await model.load()

        model.select(.accessibility)

        #expect(model.selectedSection == .accessibility)
    }

    @Test("Sidebar arrow movement follows screen order and stops at each boundary")
    func sidebarArrowMovement() async throws {
        let model = try SettingsFeatureModel(client: TestSettingsClient(preferences: .defaults), catalog: .fixture())
        await model.load()

        model.moveSidebarSelection(by: -1)
        #expect(model.selectedSection == .schedule)

        model.moveSidebarSelection(by: 1)
        #expect(model.selectedSection == .breakContent)

        model.select(.safetyAndSupport)
        model.moveSidebarSelection(by: 1)
        #expect(model.selectedSection == .safetyAndSupport)
    }

    @Test("Load exposes persisted preferences and derived timing summaries")
    func loadAndSummaries() async throws {
        let client = TestSettingsClient(preferences: .defaults)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())

        await model.load()

        #expect(model.phase == .ready)
        #expect(model.selectedProfileID == .balanced)
        #expect(model.visualTimingSummary == "about every 25 min, for 20 s")
        #expect(model.movementTimingSummary == "about every 60 min, suggested 5 min")
        #expect(model.headsUpSummary == "About 45 seconds")
    }
}

extension SettingsModelTests {
    @Test("Every schedule mutation preserves unrelated preference aggregates")
    func scheduleMutationsPreserveUnrelatedPreferences() async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.selectProfile(SettingsScheduleChoice.gentle)
        await model.setHeadsUpEnabled(false)
        await model.setWorkingHoursOnly(false)
        await model.setWaitsForLowFrictionMoment(false)

        let saved = try #require(model.preferences)
        #expect(saved.schedule.profile == .gentle)
        #expect(saved.schedule.headsUpEnabled == false)
        #expect(saved.schedule.workingHoursOnly == false)
        #expect(saved.context.waitsForLowFrictionMoment == false)
        #expect(saved.historyRetention == original.historyRetention)
        #expect(saved.content == original.content)
        #expect(saved.accessibility == original.accessibility)
        #expect(saved.integrations == original.integrations)
        #expect(saved.context.excludedApplicationBundleIDs == original.context.excludedApplicationBundleIDs)
        #expect(saved.context.presentationModeSuppressionEnabled == original.context.presentationModeSuppressionEnabled)
    }

    @Test("Custom draft validates through Domain and applies display-unit edits")
    func customValidationAndApply() async throws {
        let client = TestSettingsClient(preferences: .defaults)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.selectProfile(SettingsScheduleChoice.custom)
        model.editCustomField(.visualTarget, value: nil)
        #expect(model.customValidation == .incomplete)
        #expect(model.canApplyCustom == false)

        model.editCustomField(.visualSoftDue, value: 18)
        model.editCustomField(.visualTarget, value: 22)
        model.editCustomField(.visualLatestPreferred, value: 28)
        model.editCustomField(.visualDuration, value: 30)
        model.editCustomField(.movementSoftDue, value: 45)
        model.editCustomField(.movementTarget, value: 52)
        model.editCustomField(.movementLatestPreferred, value: 58)
        model.editCustomField(.movementSuggestedDuration, value: 4)
        model.editCustomField(.movementQuickDuration, value: 2)
        #expect(model.customValidation == .valid)

        await model.applyCustomDraft()

        guard case let .custom(timing) = model.preferences?.schedule.profile else {
            Issue.record("Expected custom timing")
            return
        }
        #expect(timing.visual.targetSeconds == 22 * 60)
        #expect(timing.visual.durationOptionsSeconds == [30])
        #expect(timing.movement.targetSeconds == 52 * 60)
        #expect(timing.movement.durationOptionsSeconds == [4 * 60, 2 * 60])
    }

    @Test("Custom structural validation represents partial, non-finite, non-positive, and unordered edits")
    func customStructuralValidation() async throws {
        let model = try SettingsFeatureModel(client: TestSettingsClient(preferences: .defaults), catalog: .fixture())
        await model.load()
        await model.selectProfile(SettingsScheduleChoice.custom)

        model.editCustomField(.visualSoftDue, value: nil)
        #expect(model.customValidation == .incomplete)
        #expect(model.customIssue(for: .visualSoftDue) == .required)
        #expect(model.customIssue(for: .visualTarget) == nil)
        model.editCustomField(.visualSoftDue, value: .infinity)
        #expect(model.customValidation == .nonFiniteOrNonPositive)
        #expect(model.customIssue(for: .visualSoftDue) == .positiveFinite)
        model.editCustomField(.visualSoftDue, value: 0)
        #expect(model.customValidation == .nonFiniteOrNonPositive)
        model.editCustomField(.visualSoftDue, value: 30)
        model.editCustomField(.visualTarget, value: 25)
        #expect(model.customValidation == .invalidWindow)
        #expect(model.customIssue(for: .visualSoftDue) == .orderedWindow)
        #expect(model.customIssue(for: .movementTarget) == nil)
    }

    @Test("Selecting Custom seeds every exact field and preserves a retained Custom draft")
    func customSeedingAndPreservation() async throws {
        let model = try SettingsFeatureModel(client: TestSettingsClient(preferences: .defaults), catalog: .fixture())
        await model.load()
        await model.selectProfile(SettingsScheduleChoice.gentle)
        await model.selectProfile(SettingsScheduleChoice.custom)

        #expect(model.customDraft.visualSoftDueMinutes == 25)
        #expect(model.customDraft.visualTargetMinutes == 30)
        #expect(model.customDraft.visualLatestPreferredMinutes == 35)
        #expect(model.customDraft.movementSuggestedDurationMinutes == 5)
        #expect(model.customDraft.movementQuickDurationMinutes == 2)

        model.editCustomField(.visualTarget, value: 31)
        await model.selectProfile(SettingsScheduleChoice.balanced)
        await model.selectProfile(SettingsScheduleChoice.custom)
        #expect(model.customDraft.visualTargetMinutes == 31)
    }

    @Test("Custom advisories use injected high-frequency and disabled thresholds")
    func customAdvisories() async throws {
        let model = try SettingsFeatureModel(
            client: TestSettingsClient(preferences: .defaults),
            catalog: .fixture(effectivelyDisabledThresholdSeconds: 7200),
        )
        await model.load()
        await model.selectProfile(SettingsScheduleChoice.custom)

        model.editCustomField(.movementSoftDue, value: 15)
        model.editCustomField(.movementTarget, value: 20)
        model.editCustomField(.movementLatestPreferred, value: 25)
        #expect(model.scheduleAdvisories == [.veryFrequent([.movement])])

        model.editCustomField(.visualSoftDue, value: 10)
        model.editCustomField(.visualTarget, value: 15)
        model.editCustomField(.visualLatestPreferred, value: 20)
        model.editCustomField(.movementSoftDue, value: 110)
        model.editCustomField(.movementTarget, value: 120)
        model.editCustomField(.movementLatestPreferred, value: 130)
        #expect(model.scheduleAdvisories.contains(.veryFrequent([.visual])))
        #expect(model.scheduleAdvisories.contains(.effectivelyDisabled([.movement])))
        #expect(model.canApplyCustom)

        model.editCustomField(.visualSoftDue, value: 20)
        model.editCustomField(.visualTarget, value: 25)
        model.editCustomField(.visualLatestPreferred, value: 30)
        model.editCustomField(.movementSoftDue, value: 40)
        model.editCustomField(.movementTarget, value: 45)
        model.editCustomField(.movementLatestPreferred, value: 50)
        #expect(model.scheduleAdvisories.isEmpty)
    }

    @Test("Failed optimistic apply restores preferences and retry applies the same candidate")
    func rollbackAndRetry() async throws {
        let client = TestSettingsClient(
            preferences: .defaults,
            results: [.failure(TestFailure.save), .success(.applied)],
        )
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.selectProfile(SettingsScheduleChoice.gentle)

        #expect(model.operationState == .failed)
        #expect(model.selectedProfileID == .balanced)
        #expect(model.canRetryLastChange)

        await model.retryLastChange()

        #expect(model.operationState == .idle)
        #expect(model.selectedProfileID == .gentle)
        #expect(client.applyCount == 2)
    }

    @Test("Busy apply restores the last applied value and remains retryable")
    func temporarilyBusy() async throws {
        let client = TestSettingsClient(
            preferences: .defaults,
            results: [.success(.temporarilyBusy)],
        )
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.setHeadsUpEnabled(false)

        #expect(model.operationState == .temporarilyBusy)
        #expect(model.preferences?.schedule.headsUpEnabled == true)
        #expect(model.canRetryLastChange)
    }

    @Test("A second edit is gated while an apply is in flight")
    func inFlightGating() async throws {
        let client = SuspendedSettingsClient(preferences: .defaults)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        let first = Task { await model.selectProfile(SettingsScheduleChoice.gentle) }
        await client.waitUntilApplying()
        await model.selectProfile(SettingsScheduleChoice.frequentMovement)
        #expect(model.selectedProfileID == .gentle)
        #expect(client.applyCount == 1)

        client.finish(with: .applied)
        await first.value
        #expect(model.operationState == .idle)
        #expect(model.selectedProfileID == .gentle)
    }

    @Test("Load failure is retryable")
    func loadFailure() async throws {
        let client = TestSettingsClient(preferences: .defaults, loadError: TestFailure.load)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())

        await model.load()
        #expect(model.phase == .loadFailed)

        client.loadError = nil
        await model.load()
        #expect(model.phase == .ready)
    }
}
