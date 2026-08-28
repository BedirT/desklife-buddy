import Domain
import Testing
@testable import SettingsFeature

@Suite("Settings break content")
struct SettingsBreakContentTests {
    @Test("Load exposes every persisted break-content value")
    func loadExposesPersistedContent() async throws {
        let expected = BreakContentPreferences(
            preferredMovement: .seatedActive,
            showsQuickMovementOption: false,
            includesBreathingContent: true,
            standingDeskModeEnabled: true,
        )
        let model = try SettingsFeatureModel(
            client: TestSettingsClient(preferences: AppPreferences(content: expected)),
            catalog: .fixture(),
        )

        await model.load()

        #expect(model.breakContentPreferences == expected)
    }

    @Test(
        "Each equal-status preferred movement choice is independently saveable",
        arguments: PreferredMovementContent.allCases,
    )
    func preferredMovementChoices(choice: PreferredMovementContent) async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.setPreferredMovement(choice)

        let saved = try #require(model.breakContentPreferences)
        #expect(saved.preferredMovement == choice)
        #expect(saved.showsQuickMovementOption == original.content.showsQuickMovementOption)
        #expect(saved.includesBreathingContent == original.content.includesBreathingContent)
        #expect(saved.standingDeskModeEnabled == original.content.standingDeskModeEnabled)
        #expect(model.selectedConfiguration == client.configuration)
    }

    @Test("Quick, breathing, and standing choices mutate independently")
    func independentContentToggles() async throws {
        let original = BreakContentPreferences(
            preferredMovement: .mixed,
            showsQuickMovementOption: true,
            includesBreathingContent: false,
            standingDeskModeEnabled: false,
        )
        let client = TestSettingsClient(preferences: AppPreferences(content: original))
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.setShowsQuickMovementOption(false)
        #expect(model.breakContentPreferences == BreakContentPreferences(
            preferredMovement: .mixed,
            showsQuickMovementOption: false,
            includesBreathingContent: false,
            standingDeskModeEnabled: false,
        ))

        await model.setIncludesBreathingContent(true)
        #expect(model.breakContentPreferences == BreakContentPreferences(
            preferredMovement: .mixed,
            showsQuickMovementOption: false,
            includesBreathingContent: true,
            standingDeskModeEnabled: false,
        ))

        await model.setStandingDeskModeEnabled(true)
        #expect(model.breakContentPreferences == BreakContentPreferences(
            preferredMovement: .mixed,
            showsQuickMovementOption: false,
            includesBreathingContent: true,
            standingDeskModeEnabled: true,
        ))
    }

    @Test("A narrow content mutation preserves concurrent content and unrelated preference changes")
    func narrowMutationPreservesLatestDurablePreferences() async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        let concurrentlyChangedContent = BreakContentPreferences(
            preferredMovement: .mixed,
            showsQuickMovementOption: true,
            includesBreathingContent: false,
            standingDeskModeEnabled: false,
        )
        client.preferences = client.preferences
            .applying(.setHistoryRetention(.thirtyDays))
            .applying(.setContent(concurrentlyChangedContent))

        await model.setPreferredMovement(.positionChangeOnly)

        let saved = try #require(model.preferences)
        #expect(saved.content == BreakContentPreferences(
            preferredMovement: .positionChangeOnly,
            showsQuickMovementOption: true,
            includesBreathingContent: false,
            standingDeskModeEnabled: false,
        ))
        #expect(saved.historyRetention == .thirtyDays)
        #expect(saved.schedule == original.schedule)
        #expect(saved.context == original.context)
        #expect(saved.accessibility == original.accessibility)
        #expect(saved.integrations == original.integrations)
    }

    @Test("A busy content save rolls back and retries the exact mutation")
    func temporarilyBusyRollbackAndExactRetry() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let original = AppPreferences(content: BreakContentPreferences(includesBreathingContent: false))
        let savedPreferences = original.applying(.setContent(BreakContentPreferences(
            preferredMovement: original.content.preferredMovement,
            showsQuickMovementOption: original.content.showsQuickMovementOption,
            includesBreathingContent: true,
            standingDeskModeEnabled: original.content.standingDeskModeEnabled,
        )))
        var received: [SettingsFeatureMutation] = []
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { SettingsFeatureState(preferences: original, configuration: catalog.balanced) },
                apply: { mutation in
                    received.append(mutation)
                    if received.count == 1 { return .temporarilyBusy }
                    return .applied(SettingsFeatureState(
                        preferences: savedPreferences,
                        configuration: catalog.balanced,
                    ))
                },
            ),
            catalog: catalog,
        )
        await model.load()

        await model.setIncludesBreathingContent(true)

        #expect(model.operationState == .temporarilyBusy)
        #expect(model.breakContentPreferences == original.content)
        #expect(model.canRetryLastChange)

        await model.retryLastChange()

        let expected = SettingsFeatureMutation.setIncludesBreathingContent(true)
        #expect(received == [expected, expected])
        #expect(model.operationState == .idle)
        #expect(model.breakContentPreferences == savedPreferences.content)
    }

    @Test("A failed content save rolls back and retries the exact mutation")
    func failedRollbackAndExactRetry() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let original = AppPreferences(content: BreakContentPreferences(preferredMovement: .walkOrEquivalent))
        let savedPreferences = original.applying(.setContent(BreakContentPreferences(
            preferredMovement: .seatedActive,
            showsQuickMovementOption: original.content.showsQuickMovementOption,
            includesBreathingContent: original.content.includesBreathingContent,
            standingDeskModeEnabled: original.content.standingDeskModeEnabled,
        )))
        var received: [SettingsFeatureMutation] = []
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { SettingsFeatureState(preferences: original, configuration: catalog.balanced) },
                apply: { mutation in
                    received.append(mutation)
                    if received.count == 1 { throw TestFailure.save }
                    return .applied(SettingsFeatureState(
                        preferences: savedPreferences,
                        configuration: catalog.balanced,
                    ))
                },
            ),
            catalog: catalog,
        )
        await model.load()

        await model.setPreferredMovement(.seatedActive)

        #expect(model.operationState == .failed)
        #expect(model.breakContentPreferences == original.content)
        #expect(model.canRetryLastChange)

        await model.retryLastChange()

        let expected = SettingsFeatureMutation.setPreferredMovement(.seatedActive)
        #expect(received == [expected, expected])
        #expect(model.operationState == .idle)
        #expect(model.breakContentPreferences == savedPreferences.content)
    }

    @Test("A second content edit is gated while the first apply is in flight")
    func applyingGate() async throws {
        let client = SuspendedSettingsClient(preferences: .defaults)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        let first = Task { await model.setPreferredMovement(.mixed) }
        await client.waitUntilApplying()

        await model.setShowsQuickMovementOption(false)

        #expect(model.operationState == .applying)
        #expect(model.breakContentPreferences?.preferredMovement == .mixed)
        #expect(model.breakContentPreferences?.showsQuickMovementOption == true)
        #expect(client.applyCount == 1)

        client.finish(with: .applied)
        await first.value

        #expect(model.operationState == .idle)
        #expect(model.breakContentPreferences?.preferredMovement == .mixed)
        #expect(model.breakContentPreferences?.showsQuickMovementOption == true)
    }

    @Test("Content-library identity is stable and detail selection is read-only")
    func contentLibrarySelectionDoesNotPersist() async throws {
        let client = TestSettingsClient(preferences: .defaults)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()
        let preferencesBeforeSelection = model.preferences
        let identifiers = model.contentLibraryItems.map(\.id)
        let expectedIdentifiers = [
            "V01", "V02", "V03", "V04", "V05",
            "M01", "M02", "M03", "M04", "M05",
            "L01", "L02", "L03", "L04", "L05", "L06",
            "P01", "P02", "P03", "P04",
            "B01", "B02",
        ]

        #expect(Set(identifiers).count == identifiers.count)
        #expect(identifiers == expectedIdentifiers)

        model.selectContentLibraryItem(id: "M02")

        #expect(model.selectedContentLibraryItemID == "M02")
        #expect(model.preferences == preferencesBeforeSelection)
        #expect(client.applyCount == 0)

        model.selectContentLibraryItem(id: "not-a-library-item")
        #expect(model.selectedContentLibraryItemID == "M02")
        #expect(client.applyCount == 0)
    }
}
