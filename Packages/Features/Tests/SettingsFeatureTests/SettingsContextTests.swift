import Domain
import Foundation
import Testing
@testable import SettingsFeature

@Suite("Settings context and exclusions")
struct SettingsContextTests {
    @Test("Load exposes canonical bundle identifiers and the sole read-only idle behavior")
    func loadCanonicalContext() async throws {
        let context = try ContextPreferences(
            excludedApplicationBundleIDs: [
                " org.example.Meeting ",
                "com.example.Editor",
                "com.example.Editor",
            ],
            waitsForLowFrictionMoment: false,
            presentationModeSuppressionEnabled: true,
        )
        let preferences = AppPreferences(context: context)
        let model = try SettingsFeatureModel(
            client: TestSettingsClient(preferences: preferences),
            catalog: .fixture(),
        )

        await model.load()

        #expect(model.excludedApplicationBundleIDs == ["com.example.Editor", "org.example.Meeting"])
        #expect(model.idleBehavior == .resetPresentationTimingOnly)
    }

    @Test("An exclusion can be added and removed without replacing context")
    func addAndRemoveExclusion() async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.addExcludedApplicationBundleID("org.example.Meeting")

        var saved = try #require(model.preferences)
        #expect(saved.context.excludedApplicationBundleIDs == ["com.example.Editor", "org.example.Meeting"])
        #expect(saved.context.waitsForLowFrictionMoment == original.context.waitsForLowFrictionMoment)
        #expect(saved.context.presentationModeSuppressionEnabled == original.context.presentationModeSuppressionEnabled)
        #expect(saved.context.idleBehavior == .resetPresentationTimingOnly)

        await model.removeExcludedApplicationBundleID("com.example.Editor")

        saved = try #require(model.preferences)
        #expect(saved.context.excludedApplicationBundleIDs == ["org.example.Meeting"])
        #expect(saved.context.waitsForLowFrictionMoment == original.context.waitsForLowFrictionMoment)
        #expect(saved.context.presentationModeSuppressionEnabled == original.context.presentationModeSuppressionEnabled)
        #expect(saved.context.idleBehavior == .resetPresentationTimingOnly)
        #expect(client.applyCount == 2)
    }

    @Test("Adding an existing canonical exclusion is a no-op")
    func duplicateExclusionIsNoOp() async throws {
        let context = try ContextPreferences(excludedApplicationBundleIDs: ["com.example.Editor"])
        let client = TestSettingsClient(preferences: AppPreferences(context: context))
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.addExcludedApplicationBundleID("  com.example.Editor  ")

        #expect(model.excludedApplicationBundleIDs == ["com.example.Editor"])
        #expect(client.applyCount == 0)
        #expect(model.operationState == .idle)
    }

    @Test("An invalid bundle identifier is rejected before calling the client")
    func invalidExclusionIsRejected() async throws {
        let client = TestSettingsClient(preferences: .defaults)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.addExcludedApplicationBundleID("not a bundle identifier")

        #expect(model.excludedApplicationBundleIDs.isEmpty)
        #expect(client.applyCount == 0)
        #expect(model.operationState == .idle)
    }

    @Test("Low-friction and explicit-presentation edits preserve every context sibling")
    func contextTogglesPreserveSiblings() async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.setWaitsForLowFrictionMoment(false)
        await model.setPresentationModeSuppressionEnabled(true)

        let saved = try #require(model.preferences)
        #expect(saved.context.excludedApplicationBundleIDs == original.context.excludedApplicationBundleIDs)
        #expect(saved.context.waitsForLowFrictionMoment == false)
        #expect(saved.context.presentationModeSuppressionEnabled == true)
        #expect(saved.context.idleBehavior == .resetPresentationTimingOnly)
        assertUnrelatedPreferences(saved, equal: original)
    }

    @Test("A narrow exclusion add merges with concurrent context and unrelated durable changes")
    func exclusionAddPreservesConcurrentChanges() async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        let concurrentContext = try ContextPreferences(
            excludedApplicationBundleIDs: ["com.example.Editor", "org.example.Concurrent"],
            waitsForLowFrictionMoment: false,
            presentationModeSuppressionEnabled: true,
            idleBehavior: .resetPresentationTimingOnly,
        )
        let concurrentContent = BreakContentPreferences(
            preferredMovement: .positionChangeOnly,
            showsQuickMovementOption: true,
            includesBreathingContent: false,
            standingDeskModeEnabled: false,
        )
        client.preferences = client.preferences
            .applying(.setContext(concurrentContext))
            .applying(.setContent(concurrentContent))

        await model.addExcludedApplicationBundleID("org.example.Requested")

        let saved = try #require(model.preferences)
        #expect(saved.context.excludedApplicationBundleIDs == [
            "com.example.Editor",
            "org.example.Concurrent",
            "org.example.Requested",
        ])
        #expect(saved.context.waitsForLowFrictionMoment == false)
        #expect(saved.context.presentationModeSuppressionEnabled == true)
        #expect(saved.context.idleBehavior == .resetPresentationTimingOnly)
        #expect(saved.content == concurrentContent)
        #expect(saved.schedule == original.schedule)
        #expect(saved.historyRetention == original.historyRetention)
        #expect(saved.accessibility == original.accessibility)
        #expect(saved.integrations == original.integrations)
    }

    @Test("A busy exclusion add rolls back and retries the exact operation")
    func busyExclusionRollsBackAndRetriesExactly() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let original = try nonDefaultPreferences()
        let expectedPreferences = try preferences(
            original,
            excludedApplicationBundleIDs: ["com.example.Editor", "org.example.Meeting"],
        )
        let expectedState = state(expectedPreferences, base: catalog.balanced)
        var attempts: [SettingsFeatureMutation] = []
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { state(original, base: catalog.balanced) },
                apply: { mutation in
                    attempts.append(mutation)
                    return attempts.count == 1 ? .temporarilyBusy : .applied(expectedState)
                },
            ),
            catalog: catalog,
        )
        await model.load()

        await model.addExcludedApplicationBundleID("org.example.Meeting")

        #expect(model.preferences == original)
        #expect(model.operationState == .temporarilyBusy)
        #expect(model.canRetryLastChange)

        await model.retryLastChange()

        let expectedMutation = SettingsFeatureMutation.addExcludedApplicationBundleID("org.example.Meeting")
        #expect(attempts == [expectedMutation, expectedMutation])
        #expect(model.preferences == expectedPreferences)
        #expect(model.operationState == .idle)
    }

    @Test("A failed presentation edit rolls back and retries the exact operation")
    func failedPresentationEditRollsBackAndRetriesExactly() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let original = try nonDefaultPreferences()
        let expectedPreferences = try preferences(original, presentationModeSuppressionEnabled: true)
        let expectedState = state(expectedPreferences, base: catalog.balanced)
        var attempts: [SettingsFeatureMutation] = []
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { state(original, base: catalog.balanced) },
                apply: { mutation in
                    attempts.append(mutation)
                    if attempts.count == 1 { throw TestFailure.save }
                    return .applied(expectedState)
                },
            ),
            catalog: catalog,
        )
        await model.load()

        await model.setPresentationModeSuppressionEnabled(true)

        #expect(model.preferences == original)
        #expect(model.operationState == .failed)
        #expect(model.canRetryLastChange)

        await model.retryLastChange()

        let expectedMutation = SettingsFeatureMutation.setPresentationModeSuppressionEnabled(true)
        #expect(attempts == [expectedMutation, expectedMutation])
        #expect(model.preferences == expectedPreferences)
        #expect(model.operationState == .idle)
    }
}

private func preferences(
    _ original: AppPreferences,
    excludedApplicationBundleIDs: [String]? = nil,
    presentationModeSuppressionEnabled: Bool? = nil,
) throws -> AppPreferences {
    let current = original.context
    let context = try ContextPreferences(
        excludedApplicationBundleIDs: excludedApplicationBundleIDs ?? current.excludedApplicationBundleIDs,
        waitsForLowFrictionMoment: current.waitsForLowFrictionMoment,
        presentationModeSuppressionEnabled: presentationModeSuppressionEnabled
            ?? current.presentationModeSuppressionEnabled,
        idleBehavior: current.idleBehavior,
    )
    return original.applying(.setContext(context))
}

private func state(_ preferences: AppPreferences, base: ProtocolConfiguration) -> SettingsFeatureState {
    SettingsFeatureState(
        preferences: preferences,
        configuration: preferences.protocolConfiguration(applyingTo: base),
    )
}

private func assertUnrelatedPreferences(_ actual: AppPreferences, equal original: AppPreferences) {
    #expect(actual.schedule == original.schedule)
    #expect(actual.historyRetention == original.historyRetention)
    #expect(actual.content == original.content)
    #expect(actual.accessibility == original.accessibility)
    #expect(actual.integrations == original.integrations)
}
