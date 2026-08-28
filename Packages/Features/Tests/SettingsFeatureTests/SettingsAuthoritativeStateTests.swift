import Domain
import Testing
@testable import SettingsFeature

@Suite("Settings authoritative state")
struct SettingsAuthoritativeStateTests {
    private struct BuiltInCase {
        let choice: SettingsScheduleChoice
        let identifier: ProtocolProfileID
        let configuration: ProtocolConfiguration
    }

    @Test("All Settings choices map explicitly to Domain profile identifiers")
    func explicitProfileMapping() {
        #expect(SettingsScheduleChoice.gentle.protocolProfileID == .gentle)
        #expect(SettingsScheduleChoice.balanced.protocolProfileID == .balanced)
        #expect(SettingsScheduleChoice.frequentMovement.protocolProfileID == .frequentMovement)
        #expect(
            SettingsScheduleChoice.researchInformedHighFrequency.protocolProfileID
                == .researchInformedHighFrequency,
        )
        #expect(SettingsScheduleChoice.custom.protocolProfileID == .custom)
        #expect(SettingsScheduleChoice(profileID: .frequentMovement) == .frequentMovement)
        #expect(
            SettingsScheduleChoice(profileID: .researchInformedHighFrequency)
                == .researchInformedHighFrequency,
        )
    }

    @Test("Load and apply publish the client's exact authoritative preferences and configuration")
    func authoritativeClientState() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let loaded = SettingsFeatureState(preferences: .defaults, configuration: catalog.balanced)
        let authoritativePreferences = AppPreferences(
            schedule: SchedulePreferences(profile: .gentle, headsUpEnabled: false, workingHoursOnly: false),
            historyRetention: .ninetyDays,
            integrations: IntegrationPreferences(notificationsEnabled: true),
        )
        let authoritativeConfiguration = try fixtureConfiguration(visual: 47, movement: 88)
        var receivedMutation: SettingsFeatureMutation?
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { loaded },
                apply: { mutation in
                    receivedMutation = mutation
                    return .applied(SettingsFeatureState(
                        preferences: authoritativePreferences,
                        configuration: authoritativeConfiguration,
                    ))
                },
            ),
            catalog: catalog,
        )

        await model.load()
        await model.selectProfile(SettingsScheduleChoice.gentle)

        #expect(receivedMutation == .setScheduleProfile(.gentle, baseConfiguration: catalog.gentle))
        #expect(model.preferences == authoritativePreferences)
        #expect(model.selectedConfiguration == authoritativeConfiguration)
        #expect(model.visualTimingSummary == "about every 47 min, for 20 s")
        #expect(model.movementTimingSummary == "about every 88 min, suggested 5 min")
    }

    @Test("Loaded built-in summaries use the exact authoritative configuration")
    func loadedExactConfiguration() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let exact = try fixtureConfiguration(visual: 41, movement: 83)
        let preferences = AppPreferences(schedule: SchedulePreferences(profile: .frequentMovement))
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { SettingsFeatureState(preferences: preferences, configuration: exact) },
                apply: { _ in .temporarilyBusy },
            ),
            catalog: catalog,
        )

        await model.load()

        #expect(model.selectedScheduleChoice == .frequentMovement)
        #expect(model.selectedConfiguration == exact)
        #expect(model.visualTimingSummary == "about every 41 min, for 20 s")
        #expect(model.movementTimingSummary == "about every 83 min, suggested 5 min")
    }

    @Test("Every built-in selection publishes its injected timing and summary")
    func everyBuiltInSelection() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let model = SettingsFeatureModel(
            client: TestSettingsClient(preferences: .defaults),
            catalog: catalog,
        )
        await model.load()
        let cases = [
            BuiltInCase(choice: .gentle, identifier: .gentle, configuration: catalog.gentle),
            BuiltInCase(choice: .balanced, identifier: .balanced, configuration: catalog.balanced),
            BuiltInCase(
                choice: .frequentMovement,
                identifier: .frequentMovement,
                configuration: catalog.frequentMovement,
            ),
            BuiltInCase(
                choice: .researchInformedHighFrequency,
                identifier: .researchInformedHighFrequency,
                configuration: catalog.researchInformedHighFrequency,
            ),
        ]

        for testCase in cases {
            await model.selectProfile(testCase.choice)
            #expect(model.selectedProfileID == testCase.identifier)
            #expect(model.selectedConfiguration == testCase.configuration)
            #expect(model.visualTimingSummary != nil)
            #expect(model.movementTimingSummary != nil)
        }
    }

    @Test("Selecting the already-applied built-in keeps its retained configuration snapshot")
    func reselectingAppliedBuiltInIsNoOp() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let retained = try fixtureConfiguration(visual: 41, movement: 83)
        let preferences = AppPreferences(schedule: SchedulePreferences(profile: .balanced))
        let client = TestSettingsClient(preferences: preferences)
        client.configuration = retained
        let model = SettingsFeatureModel(client: client, catalog: catalog)

        await model.load()
        await model.selectProfile(SettingsScheduleChoice.balanced)

        #expect(client.applyCount == 0)
        #expect(model.selectedConfiguration == retained)
        #expect(model.configuration(for: SettingsScheduleChoice.balanced) == retained)
    }

    @Test("Custom timing keeps the exact retained non-timing configuration")
    func customUsesRetainedConfigurationBase() async throws {
        let catalog = try SettingsScheduleCatalog.fixture()
        let timings = try fixtureConfiguration(visual: 41, movement: 83)
        let retained = try ProtocolConfiguration(
            visual: timings.visual,
            movement: timings.movement,
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 12,
                longIdleResetSeconds: 987,
                wakeUnlockGraceSeconds: 34,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: false,
                mergeWindowSeconds: 777,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 99,
                snoozeOptionsSeconds: [42],
                maximumRepeatedEscalations: 0,
                lockoutAllowed: false,
            ),
            recovery: RecoveryConfiguration(
                eligibleAfterSeconds: 4321,
                latestTypicalSeconds: 5432,
                requiredMovementDeferrals: 3,
            ),
        )
        var receivedMutation: SettingsFeatureMutation?
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { SettingsFeatureState(preferences: .defaults, configuration: retained) },
                apply: { mutation in
                    receivedMutation = mutation
                    return .temporarilyBusy
                },
            ),
            catalog: catalog,
        )

        await model.load()
        model.beginCustomEditing()
        await model.applyCustomDraft()

        guard case let .setScheduleProfile(.custom, baseConfiguration) = receivedMutation else {
            Issue.record("Expected a Custom schedule mutation")
            return
        }
        #expect(baseConfiguration.activityEstimator == retained.activityEstimator)
        #expect(baseConfiguration.delivery == retained.delivery)
        #expect(baseConfiguration.recovery == retained.recovery)
    }
}
