import Domain
import Testing
@testable import SettingsFeature

@Suite("Settings edge cases")
struct SettingsEdgeCaseTests {
    @Test("Subnormal timings stay nonzero and oversized minute edits identify the field")
    func bothTimingExtremesRemainRepresentable() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let tiny = Double.leastNonzeroMagnitude
        let timing = try CustomProtocolTiming(
            visual: OpportunityTiming(
                softDueSeconds: tiny,
                targetSeconds: tiny,
                latestPreferredSeconds: tiny,
                durationOptionsSeconds: [tiny],
            ),
            movement: OpportunityTiming(
                softDueSeconds: tiny,
                targetSeconds: tiny,
                latestPreferredSeconds: tiny,
                durationOptionsSeconds: [tiny, tiny],
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

        #expect(model.customDraft.visualTargetMinutes != 0)
        #expect(model.visualTimingSummary?.contains("E-") == true)
        model.editCustomField(.visualTarget, value: .greatestFiniteMagnitude)
        #expect(model.customValidation == .valueTooLarge)
        #expect(model.customIssue(for: .visualTarget) == .valueTooLarge)
    }

    @Test("Saving untouched Custom timing extremes preserves every exact second value")
    func untouchedTimingExtremeRoundTripsAreExact() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        for value in [Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude] {
            let timing = try CustomProtocolTiming(
                visual: OpportunityTiming(
                    softDueSeconds: value,
                    targetSeconds: value,
                    latestPreferredSeconds: value,
                    durationOptionsSeconds: [value],
                ),
                movement: OpportunityTiming(
                    softDueSeconds: value,
                    targetSeconds: value,
                    latestPreferredSeconds: value,
                    durationOptionsSeconds: [value, value],
                ),
            )
            let preferences = AppPreferences(schedule: SchedulePreferences(profile: .custom(timing)))
            let client = TestSettingsClient(preferences: preferences)
            client.configuration = preferences.protocolConfiguration(applyingTo: catalog.balanced)
            let model = SettingsFeatureModel(client: client, catalog: catalog)

            await model.load()
            await model.applyCustomDraft()

            guard case let .custom(savedTiming) = model.preferences?.schedule.profile else {
                Issue.record("Expected custom timing")
                return
            }
            #expect(savedTiming == timing)
            #expect(client.applyCount == 1)
        }
    }

    @Test("Editing one Custom field keeps every untouched canonical second exact")
    func oneFieldEditPreservesOtherCanonicalValues() throws {
        let tiny = Double.leastNonzeroMagnitude
        let timing = try CustomProtocolTiming(
            visual: OpportunityTiming(
                softDueSeconds: tiny,
                targetSeconds: tiny,
                latestPreferredSeconds: tiny,
                durationOptionsSeconds: [tiny],
            ),
            movement: OpportunityTiming(
                softDueSeconds: tiny,
                targetSeconds: tiny,
                latestPreferredSeconds: tiny,
                durationOptionsSeconds: [tiny, tiny],
            ),
        )
        var draft = CustomScheduleDraft(timing: timing)

        draft.set(.visualDuration, to: 30)
        let updated = try draft.timing()

        #expect(updated.visual.softDueSeconds == tiny)
        #expect(updated.visual.targetSeconds == tiny)
        #expect(updated.visual.latestPreferredSeconds == tiny)
        #expect(updated.visual.durationOptionsSeconds == [30])
        #expect(updated.movement == timing.movement)
    }

    @Test("Unparseable and overflowing text remain visible and disable Custom saving")
    func invalidFieldTextCannotSaveStaleValues() async throws {
        let client = TestSettingsClient(preferences: .defaults)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()
        model.beginCustomEditing()

        model.editCustomFieldText(.visualTarget, text: "not a number")

        #expect(model.customFieldText(for: .visualTarget) == "not a number")
        #expect(model.customIssue(for: .visualTarget) == .invalidNumber)
        #expect(!model.canApplyCustom)
        await model.applyCustomDraft()
        #expect(client.applyCount == 0)

        model.editCustomFieldText(.visualTarget, text: "1e999")

        #expect(model.customFieldText(for: .visualTarget) == "1e999")
        #expect(!model.canApplyCustom)

        model.editCustomFieldText(.visualTarget, text: "26")
        #expect(model.canApplyCustom)
        await model.applyCustomDraft()

        guard case let .custom(savedTiming) = model.preferences?.schedule.profile else {
            Issue.record("Expected custom timing")
            return
        }
        #expect(savedTiming.visual.targetSeconds == 26 * 60)
        #expect(client.applyCount == 1)
    }

    @Test("Editing Custom after failure invalidates the old retry and saves the visible draft")
    func editAfterFailureUsesCurrentDraft() async throws {
        let client = TestSettingsClient(
            preferences: .defaults,
            results: [.failure(TestFailure.save), .success(.applied)],
        )
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()
        model.beginCustomEditing()

        model.editCustomField(.visualTarget, value: 26)
        await model.applyCustomDraft()

        #expect(model.operationState == .failed)
        #expect(model.canRetryLastChange)

        model.editCustomField(.visualTarget, value: 27)

        #expect(model.operationState == .idle)
        #expect(!model.canRetryLastChange)

        await model.applyCustomDraft()

        guard case let .custom(timing) = model.preferences?.schedule.profile else {
            Issue.record("Expected custom timing")
            return
        }
        #expect(timing.visual.targetSeconds == 27 * 60)
        #expect(client.applyCount == 2)
    }
}
