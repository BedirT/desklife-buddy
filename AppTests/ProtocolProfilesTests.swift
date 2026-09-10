import Domain
import Testing
@testable import App

@Suite("Machine-readable protocol profiles")
struct ProtocolProfilesTests {
    @Test("Balanced profile combines research defaults with the runtime timing amendment")
    func balancedProfile() throws {
        let configuration = try ProtocolProfiles.configuration(for: .balanced)

        #expect(configuration.visual.softDueSeconds == 1200)
        #expect(configuration.visual.targetSeconds == 1500)
        #expect(configuration.visual.latestPreferredSeconds == 1590)
        #expect(configuration.visual.durationOptionsSeconds == [20])
        #expect(configuration.movement.softDueSeconds == 3000)
        #expect(configuration.movement.targetSeconds == 3600)
        #expect(configuration.movement.latestPreferredSeconds == 4200)
        #expect(configuration.movement.durationOptionsSeconds == [300, 120])
        #expect(configuration.activityEstimator.recentInputWindowSeconds == 60)
        #expect(configuration.activityEstimator.longIdleResetSeconds == 300)
        #expect(configuration.activityEstimator.wakeUnlockGraceSeconds == 90)
        #expect(configuration.activityEstimator.lowFrictionInputPauseSeconds == 5)
        #expect(configuration.activityEstimator.postInterruptionGraceSeconds == 60)
        #expect(configuration.activityEstimator.maximumSampleGapSeconds == 90)
        #expect(configuration.delivery.mergeWindowSeconds == 300)
        #expect(configuration.delivery.headsUpSecondsBeforeTarget == 45)
        #expect(configuration.delivery.snoozeOptionsSeconds == [300, 600, 900])
        #expect(configuration.delivery.maximumRepeatedEscalations == 1)
        #expect(configuration.recovery?.eligibleAfterSeconds == 5400)
        #expect(configuration.recovery?.requiredMovementDeferrals == 2)
        #expect(configuration.recovery?.maximumOffersPerSession == 1)
    }

    @Test("Every built-in profile is projected and custom remains user-supplied")
    func profileCoverage() throws {
        for profile in ProtocolProfileID.builtInCases {
            _ = try ProtocolProfiles.configuration(for: profile)
        }

        #expect(throws: ProtocolProfileLoadingError.self) {
            _ = try ProtocolProfiles.configuration(for: .custom)
        }
    }
}
