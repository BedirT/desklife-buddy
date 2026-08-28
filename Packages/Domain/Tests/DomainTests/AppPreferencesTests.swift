import Foundation
import Testing
@testable import Domain

@Suite("App preferences")
struct AppPreferencesTests {
    @Test("Versioned defaults select Balanced and privacy-minimal local choices")
    func versionedDefaults() {
        let preferences = AppPreferences.defaults

        #expect(AppPreferences.currentFormatVersion == 1)
        #expect(preferences.formatVersion == AppPreferences.currentFormatVersion)
        #expect(preferences.schedule.profile == .balanced)
        #expect(preferences.schedule.workingHoursOnly)
        #expect(preferences.historyRetention == .thirtyDays)
        #expect(preferences.content.preferredMovement == .walkOrEquivalent)
        #expect(preferences.content.showsQuickMovementOption)
        #expect(preferences.context.waitsForLowFrictionMoment)
        #expect(preferences.context.excludedApplicationBundleIDs.isEmpty)
        #expect(preferences.accessibility.presentation == .standard)
        #expect(preferences.accessibility.staticOverlayBrightness == 0.35)
        #expect(preferences.integrations == .disabled)
    }

    @Test("Built-in profiles are stable identifiers and Domain does not resolve their timing")
    func builtInIdentifiers() {
        #expect(ScheduleProfile.gentle.protocolProfileID == .gentle)
        #expect(ScheduleProfile.balanced.protocolProfileID == .balanced)
        #expect(ScheduleProfile.frequentMovement.protocolProfileID == .frequentMovement)
        #expect(ScheduleProfile.researchInformedHighFrequency.protocolProfileID == .researchInformedHighFrequency)
    }

    @Test("Custom timing replaces only visual and movement on a caller-supplied base")
    func customTimingTransformsBase() throws {
        let base = try baseConfiguration()
        let custom = try CustomProtocolTiming(
            visual: OpportunityTiming(
                softDueSeconds: 10,
                targetSeconds: 20,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            ),
            movement: OpportunityTiming(
                softDueSeconds: 40,
                targetSeconds: 50,
                latestPreferredSeconds: 60,
                durationOptionsSeconds: [12, 6],
            ),
        )
        let preferences = try AppPreferences(
            schedule: SchedulePreferences(profile: .custom(custom), headsUpEnabled: false),
            context: ContextPreferences(waitsForLowFrictionMoment: false),
        )

        let projected = preferences.protocolConfiguration(applyingTo: base)

        #expect(projected.visual.targetSeconds == 20)
        #expect(projected.movement.targetSeconds == 50)
        #expect(projected.activityEstimator == base.activityEstimator)
        #expect(projected.recovery == base.recovery)
        #expect(projected.delivery.mergeWindowSeconds == base.delivery.mergeWindowSeconds)
        #expect(projected.delivery.headsUpSecondsBeforeTarget == base.delivery.headsUpSecondsBeforeTarget)
        #expect(projected.delivery.snoozeOptionsSeconds == base.delivery.snoozeOptionsSeconds)
        #expect(projected.delivery.maximumRepeatedEscalations == base.delivery.maximumRepeatedEscalations)
        #expect(projected.delivery.lockoutAllowed == base.delivery.lockoutAllowed)
        #expect(!projected.delivery.headsUpDefault)
        #expect(!projected.delivery.waitForLowFrictionMoment)
    }

    @Test("Built-in selection preserves caller-resolved timing while applying delivery choices")
    func builtInTransformsBase() throws {
        let base = try baseConfiguration()
        let preferences = try AppPreferences(
            schedule: SchedulePreferences(profile: .frequentMovement, headsUpEnabled: false),
            context: ContextPreferences(waitsForLowFrictionMoment: false),
        )

        let projected = preferences.protocolConfiguration(applyingTo: base)

        #expect(projected.visual == base.visual)
        #expect(projected.movement == base.movement)
        #expect(!projected.delivery.headsUpDefault)
        #expect(!projected.delivery.waitForLowFrictionMoment)
    }

    @Test("Custom timing accepts neutral extremes and rejects structurally invalid values")
    func validatesCustomTiming() throws {
        let veryFrequent = try CustomProtocolTiming(
            visual: OpportunityTiming(
                softDueSeconds: 30,
                targetSeconds: 45,
                latestPreferredSeconds: 60,
                durationOptionsSeconds: [10],
            ),
            movement: OpportunityTiming(
                softDueSeconds: 60,
                targetSeconds: 90,
                latestPreferredSeconds: 120,
                durationOptionsSeconds: [30],
            ),
        )
        let projected = try veryFrequent.applying(to: baseConfiguration())

        #expect(projected.visual.targetSeconds == 45)
        #expect(projected.movement.targetSeconds == 90)
        #expect(throws: AppPreferencesValidationError.nonFiniteOrNonPositiveTiming) {
            _ = try OpportunityTiming(
                softDueSeconds: .infinity,
                targetSeconds: 20,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            )
        }
        #expect(throws: AppPreferencesValidationError.invalidOpportunityWindow) {
            _ = try OpportunityTiming(
                softDueSeconds: 20,
                targetSeconds: 10,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            )
        }
    }

    @Test("Schedule profile encoding uses explicit stable tags")
    func stableScheduleProfileCoding() throws {
        #expect(try encodedString(.gentle) == #"{"kind":"gentle"}"#)
        #expect(try encodedString(.balanced) == #"{"kind":"balanced"}"#)
        #expect(try encodedString(.frequentMovement) == #"{"kind":"frequent_movement"}"#)
        #expect(
            try encodedString(.researchInformedHighFrequency)
                == #"{"kind":"research_informed_high_frequency"}"#,
        )

        let custom = try ScheduleProfile.custom(
            CustomProtocolTiming(
                visual: OpportunityTiming(
                    softDueSeconds: 10,
                    targetSeconds: 20,
                    latestPreferredSeconds: 30,
                    durationOptionsSeconds: [5],
                ),
                movement: OpportunityTiming(
                    softDueSeconds: 40,
                    targetSeconds: 50,
                    latestPreferredSeconds: 60,
                    durationOptionsSeconds: [10],
                ),
            ),
        )
        let customObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(custom)) as? [String: Any],
        )
        #expect(customObject["kind"] as? String == "custom")
        #expect(customObject["customTiming"] != nil)
    }

    @Test("Preference decoding rejects unsupported format versions")
    func rejectsUnsupportedFormatVersion() throws {
        let encoded = try JSONEncoder().encode(AppPreferences.defaults)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["formatVersion"] = 2
        let unsupported = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: AppPreferencesValidationError.unsupportedFormatVersion(2)) {
            _ = try JSONDecoder().decode(AppPreferences.self, from: unsupported)
        }
    }

    @Test("Exclusions are trimmed canonical bundle identifiers and invalid values are rejected")
    func validatesBundleIdentifiers() throws {
        let context = try ContextPreferences(
            excludedApplicationBundleIDs: [" com.example.slides ", "com.example.call", "com.example.call"],
        )
        #expect(context.excludedApplicationBundleIDs == ["com.example.call", "com.example.slides"])

        #expect(throws: AppPreferencesValidationError.invalidBundleIdentifier("not a bundle")) {
            _ = try ContextPreferences(excludedApplicationBundleIDs: ["not a bundle"])
        }

        let encoded = try JSONEncoder().encode(ContextPreferences.defaults)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["excludedApplicationBundleIDs"] = ["com.example.valid", "invalid value"]
        let invalidPersisted = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: AppPreferencesValidationError.invalidBundleIdentifier("invalid value")) {
            _ = try JSONDecoder().decode(ContextPreferences.self, from: invalidPersisted)
        }
    }

    @Test("Content context accessibility and integration choices remain explicit values")
    func localChoices() throws {
        let preferences = try AppPreferences(
            schedule: SchedulePreferences(
                profile: .balanced,
                headsUpEnabled: false,
                workingHoursOnly: false,
            ),
            historyRetention: .ninetyDays,
            content: BreakContentPreferences(
                preferredMovement: .seatedActive,
                showsQuickMovementOption: false,
                includesBreathingContent: true,
                standingDeskModeEnabled: true,
            ),
            context: ContextPreferences(
                excludedApplicationBundleIDs: ["com.example.slides", "com.example.call"],
                waitsForLowFrictionMoment: false,
                presentationModeSuppressionEnabled: false,
                idleBehavior: .resetPresentationTimingOnly,
            ),
            accessibility: AccessibilityPreferences(
                presentation: .textOnly,
                staticOverlayBrightness: 0.2,
                timerAnnouncements: .none,
                seatedContentFirst: true,
            ),
            integrations: IntegrationPreferences(
                notificationsEnabled: true,
                calendarBusySuppressionEnabled: true,
                focusFilterEnabled: true,
                launchAtLoginEnabled: true,
            ),
        )

        #expect(!preferences.schedule.workingHoursOnly)
        #expect(preferences.content.preferredMovement == .seatedActive)
        #expect(preferences.context.excludedApplicationBundleIDs == ["com.example.call", "com.example.slides"])
        #expect(preferences.accessibility.presentation == .textOnly)
        #expect(preferences.integrations.calendarBusySuppressionEnabled)
        #expect(try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences)) == preferences)
    }

    @Test("Integration capability reports availability separately from selection")
    func integrationCapabilityStates() {
        #expect(!IntegrationCapabilityState.unavailable.canEnable)
        #expect(IntegrationCapabilityState.available(authorization: .notRequired).canEnable)
        #expect(!IntegrationCapabilityState.available(authorization: .notDetermined).canEnable)
        #expect(!IntegrationCapabilityState.available(authorization: .denied).canEnable)
        #expect(!IntegrationCapabilityState.available(authorization: .revoked).canEnable)
        #expect(IntegrationAuthorizationState.authorized.canEnable)
    }
}

private func encodedString(_ profile: ScheduleProfile) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try #require(String(data: encoder.encode(profile), encoding: .utf8))
}

private func baseConfiguration() throws -> ProtocolConfiguration {
    try ProtocolConfiguration(
        visual: OpportunitySchedule(
            softDueSeconds: 11,
            targetSeconds: 22,
            latestPreferredSeconds: 33,
            durationOptionsSeconds: [4],
        ),
        movement: OpportunitySchedule(
            softDueSeconds: 44,
            targetSeconds: 55,
            latestPreferredSeconds: 66,
            durationOptionsSeconds: [7],
        ),
        activityEstimator: ActivityEstimatorConfiguration(
            recentInputWindowSeconds: 3,
            longIdleResetSeconds: 8,
            wakeUnlockGraceSeconds: 2,
        ),
        delivery: OpportunityDeliveryConfiguration(
            waitForLowFrictionMoment: true,
            mergeWindowSeconds: 9,
            headsUpDefault: true,
            headsUpSecondsBeforeTarget: 6,
            snoozeOptionsSeconds: [13, 17],
            maximumRepeatedEscalations: 0,
            lockoutAllowed: false,
        ),
        recovery: RecoveryConfiguration(
            eligibleAfterSeconds: 70,
            latestTypicalSeconds: 80,
            suggestedDurationMinSeconds: 5,
            suggestedDurationMaxSeconds: 10,
            requiredMovementDeferrals: 1,
        ),
    )
}
