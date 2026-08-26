import Testing
@testable import Domain

@Suite("Protocol configuration")
struct ProtocolConfigurationTests {
    @Test("Configuration preserves independently injected visual and movement schedules")
    func preservesSchedules() throws {
        let configuration = try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 10,
                targetSeconds: 20,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: 40,
                targetSeconds: 50,
                latestPreferredSeconds: 60,
                durationOptionsSeconds: [12, 6],
            ),
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 4,
                longIdleResetSeconds: 9,
                wakeUnlockGraceSeconds: 3,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: true,
                mergeWindowSeconds: 7,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 2,
                snoozeOptionsSeconds: [3, 6, 9],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )

        #expect(configuration.visual.targetSeconds == 20)
        #expect(configuration.movement.durationOptionsSeconds == [12, 6])
        #expect(configuration.activityEstimator.longIdleResetSeconds == 9)
        #expect(configuration.delivery.snoozeOptionsSeconds == [3, 6, 9])
        #expect(configuration.delivery.waitForLowFrictionMoment)
        #expect(!configuration.delivery.lockoutAllowed)
    }

    @Test("Invalid timing order is rejected")
    func rejectsInvalidTimingOrder() {
        #expect(throws: ProtocolConfigurationError.self) {
            _ = try OpportunitySchedule(
                softDueSeconds: 20,
                targetSeconds: 10,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            )
        }
    }

    @Test("Estimator thresholds must keep recent input below long idle")
    func rejectsOverlappingEstimatorThresholds() {
        #expect(throws: ProtocolConfigurationError.self) {
            _ = try ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 10,
                longIdleResetSeconds: 10,
                wakeUnlockGraceSeconds: 3,
            )
        }
    }
}
