import Domain
import Testing
@testable import SettingsFeature

@Suite("Settings accessibility")
struct SettingsAccessibilityTests {
    @Test("Every presentation choice preserves its accessibility siblings and unrelated preferences")
    func presentationChoicesAreNarrow() async throws {
        let original = try nonDefaultPreferences()

        for presentation in AccessibleBreakPresentation.allCases {
            let client = TestSettingsClient(preferences: original)
            let model = try SettingsFeatureModel(client: client, catalog: .fixture())
            await model.load()

            await model.setAccessibleBreakPresentation(presentation)

            let saved = try #require(model.preferences)
            #expect(saved.accessibility.presentation == presentation)
            #expect(
                saved.accessibility.staticOverlayBrightness
                    == original.accessibility.staticOverlayBrightness,
            )
            #expect(saved.accessibility.timerAnnouncements == original.accessibility.timerAnnouncements)
            #expect(saved.accessibility.seatedContentFirst == original.accessibility.seatedContentFirst)
            expectOnlyAccessibilityChanged(from: original, to: saved)
        }
    }

    @Test("Static overlay brightness accepts both exact endpoints")
    func brightnessEndpointsAreExact() async throws {
        for brightness in [0.0, 1.0] {
            let original = try nonDefaultPreferences()
            let client = TestSettingsClient(preferences: original)
            let model = try SettingsFeatureModel(client: client, catalog: .fixture())
            await model.load()

            await model.setStaticOverlayBrightness(brightness)

            let saved = try #require(model.preferences)
            #expect(saved.accessibility.staticOverlayBrightness == brightness)
            #expect(saved.accessibility.presentation == original.accessibility.presentation)
            #expect(saved.accessibility.timerAnnouncements == original.accessibility.timerAnnouncements)
            #expect(saved.accessibility.seatedContentFirst == original.accessibility.seatedContentFirst)
            #expect(client.applyCount == 1)
        }
    }

    @Test("Invalid or nonfinite brightness never reaches persistence")
    func invalidBrightnessIsRejectedBeforeApply() async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        for brightness in [-0.01, 1.01, Double.nan, Double.infinity, -Double.infinity] {
            await model.setStaticOverlayBrightness(brightness)
        }

        #expect(model.preferences == original)
        #expect(client.preferences == original)
        #expect(client.applyCount == 0)
        #expect(model.operationState == .idle)
        #expect(!model.canRetryLastChange)
    }

    @Test("Coarse and no-announcement choices preserve every sibling")
    func announcementChoicesAreCoarseOrNone() async throws {
        let original = try nonDefaultPreferences()

        for announcements in TimerAnnouncementPreference.allCases {
            let client = TestSettingsClient(preferences: original)
            let model = try SettingsFeatureModel(client: client, catalog: .fixture())
            await model.load()

            await model.setTimerAnnouncements(announcements)

            let saved = try #require(model.preferences)
            #expect(saved.accessibility.timerAnnouncements == announcements)
            #expect(saved.accessibility.presentation == original.accessibility.presentation)
            #expect(
                saved.accessibility.staticOverlayBrightness
                    == original.accessibility.staticOverlayBrightness,
            )
            #expect(saved.accessibility.seatedContentFirst == original.accessibility.seatedContentFirst)
            expectOnlyAccessibilityChanged(from: original, to: saved)
        }
    }

    @Test("Seated-first is independent of break-content movement preferences")
    func seatedFirstDoesNotRewriteBreakContent() async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.setSeatedContentFirst(false)

        let saved = try #require(model.preferences)
        #expect(saved.accessibility.seatedContentFirst == false)
        #expect(saved.accessibility.presentation == original.accessibility.presentation)
        #expect(
            saved.accessibility.staticOverlayBrightness
                == original.accessibility.staticOverlayBrightness,
        )
        #expect(saved.accessibility.timerAnnouncements == original.accessibility.timerAnnouncements)
        #expect(saved.content == original.content)
        expectOnlyAccessibilityChanged(from: original, to: saved)
    }

    @Test("Accessibility edits merge into the latest durable state")
    func mutationPreservesUnrelatedAndConcurrentChanges() async throws {
        let original = try nonDefaultPreferences()
        let client = TestSettingsClient(preferences: original)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        let concurrentContent = BreakContentPreferences(
            preferredMovement: .walkOrEquivalent,
            showsQuickMovementOption: true,
            includesBreathingContent: false,
            standingDeskModeEnabled: false,
        )
        let concurrentAccessibility = try AccessibilityPreferences(
            presentation: .staticPresentation,
            staticOverlayBrightness: 0.125,
            timerAnnouncements: .coarseMilestones,
            seatedContentFirst: false,
        )
        client.preferences = original
            .applying(.setContent(concurrentContent))
            .applying(.setAccessibility(concurrentAccessibility))

        await model.setSeatedContentFirst(true)

        let saved = try #require(model.preferences)
        #expect(saved.content == concurrentContent)
        #expect(saved.accessibility.presentation == .staticPresentation)
        #expect(saved.accessibility.staticOverlayBrightness == 0.125)
        #expect(saved.accessibility.timerAnnouncements == .coarseMilestones)
        #expect(saved.accessibility.seatedContentFirst)
        #expect(saved.schedule == original.schedule)
        #expect(saved.historyRetention == original.historyRetention)
        #expect(saved.context == original.context)
        #expect(saved.integrations == original.integrations)
    }

    @Test("Busy accessibility save rolls back and retries the exact mutation")
    func busyRollbackAndExactRetry() async throws {
        let original = try nonDefaultPreferences()
        let catalog = try SettingsScheduleCatalog.fixture()
        let expectedAccessibility = try AccessibilityPreferences(
            presentation: .standard,
            staticOverlayBrightness: original.accessibility.staticOverlayBrightness,
            timerAnnouncements: original.accessibility.timerAnnouncements,
            seatedContentFirst: original.accessibility.seatedContentFirst,
        )
        let expectedPreferences = original.applying(.setAccessibility(expectedAccessibility))
        let expectedState = SettingsFeatureState(
            preferences: expectedPreferences,
            configuration: expectedPreferences.protocolConfiguration(applyingTo: catalog.balanced),
        )
        var attempts: [SettingsFeatureMutation] = []
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: {
                    SettingsFeatureState(
                        preferences: original,
                        configuration: original.protocolConfiguration(applyingTo: catalog.balanced),
                    )
                },
                apply: { mutation in
                    attempts.append(mutation)
                    return attempts.count == 1 ? .temporarilyBusy : .applied(expectedState)
                },
            ),
            catalog: catalog,
        )
        await model.load()

        await model.setAccessibleBreakPresentation(.standard)

        #expect(model.preferences == original)
        #expect(model.operationState == .temporarilyBusy)
        #expect(model.canRetryLastChange)

        await model.retryLastChange()

        let saved = try #require(model.preferences)
        #expect(saved.accessibility.presentation == .standard)
        #expect(
            saved.accessibility.staticOverlayBrightness
                == original.accessibility.staticOverlayBrightness,
        )
        #expect(saved.accessibility.timerAnnouncements == original.accessibility.timerAnnouncements)
        #expect(saved.accessibility.seatedContentFirst == original.accessibility.seatedContentFirst)
        #expect(model.operationState == .idle)
        #expect(!model.canRetryLastChange)
        let expectedMutation = SettingsFeatureMutation.setAccessibleBreakPresentation(.standard)
        #expect(attempts == [expectedMutation, expectedMutation])
    }

    @Test("Failed accessibility save rolls back and retries the exact endpoint brightness")
    func failureRollbackAndExactRetry() async throws {
        let original = try nonDefaultPreferences()
        let catalog = try SettingsScheduleCatalog.fixture()
        let expectedAccessibility = try AccessibilityPreferences(
            presentation: original.accessibility.presentation,
            staticOverlayBrightness: 0,
            timerAnnouncements: original.accessibility.timerAnnouncements,
            seatedContentFirst: original.accessibility.seatedContentFirst,
        )
        let expectedPreferences = original.applying(.setAccessibility(expectedAccessibility))
        let expectedState = SettingsFeatureState(
            preferences: expectedPreferences,
            configuration: expectedPreferences.protocolConfiguration(applyingTo: catalog.balanced),
        )
        var attempts: [SettingsFeatureMutation] = []
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: {
                    SettingsFeatureState(
                        preferences: original,
                        configuration: original.protocolConfiguration(applyingTo: catalog.balanced),
                    )
                },
                apply: { mutation in
                    attempts.append(mutation)
                    if attempts.count == 1 { throw TestFailure.save }
                    return .applied(expectedState)
                },
            ),
            catalog: catalog,
        )
        await model.load()

        await model.setStaticOverlayBrightness(0)

        #expect(model.preferences == original)
        #expect(model.operationState == .failed)
        #expect(model.canRetryLastChange)

        await model.retryLastChange()

        let saved = try #require(model.preferences)
        #expect(saved.accessibility.staticOverlayBrightness == 0)
        #expect(saved.accessibility.presentation == original.accessibility.presentation)
        #expect(saved.accessibility.timerAnnouncements == original.accessibility.timerAnnouncements)
        #expect(saved.accessibility.seatedContentFirst == original.accessibility.seatedContentFirst)
        #expect(model.operationState == .idle)
        #expect(!model.canRetryLastChange)
        let expectedMutation = SettingsFeatureMutation.setStaticOverlayBrightness(0)
        #expect(attempts == [expectedMutation, expectedMutation])
    }

    @Test("Accessibility preferences save through the existing silent settings client")
    func accessibilityRequiresNoSoundMutationOrCapability() async throws {
        let client = TestSettingsClient(preferences: .defaults)
        let model = try SettingsFeatureModel(client: client, catalog: .fixture())
        await model.load()

        await model.setAccessibleBreakPresentation(.textOnly)
        await model.setStaticOverlayBrightness(0.6)
        await model.setTimerAnnouncements(.none)
        await model.setSeatedContentFirst(true)

        let expected = try AccessibilityPreferences(
            presentation: .textOnly,
            staticOverlayBrightness: 0.6,
            timerAnnouncements: .none,
            seatedContentFirst: true,
        )
        #expect(client.applyCount == 4)
        #expect(model.preferences?.accessibility == expected)
    }
}

private func expectOnlyAccessibilityChanged(from original: AppPreferences, to saved: AppPreferences) {
    #expect(saved.schedule == original.schedule)
    #expect(saved.historyRetention == original.historyRetention)
    #expect(saved.content == original.content)
    #expect(saved.context == original.context)
    #expect(saved.integrations == original.integrations)
}
