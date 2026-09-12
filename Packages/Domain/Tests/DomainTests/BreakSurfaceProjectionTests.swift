import Foundation
import Testing
@testable import Domain

/// Projection-only surfaces: break surfaces render from store receipts and
/// projected values. No presenter reaches past the facade into the
/// engine, clocks, or reducer — the surface input is a value projected from
/// the coordinator-owned configuration, never the engine itself.
@Suite("Break surface projection")
struct BreakSurfaceProjectionTests {
    @Test("Movement durations project the recommended and quick options")
    func movementDurationsProjectTwoOptions() throws {
        let schedule = try OpportunitySchedule(
            softDueSeconds: 3000,
            targetSeconds: 3600,
            latestPreferredSeconds: 4200,
            durationOptionsSeconds: [300, 120],
        )

        let durations = MovementDurations.projected(from: schedule)

        #expect(durations == MovementDurations(recommendedSeconds: 300, quickSeconds: 120))
    }

    @Test("The visual break projects its single open duration")
    func visualDurationProjectsFirstOption() throws {
        let schedule = try OpportunitySchedule(
            softDueSeconds: 1200,
            targetSeconds: 1500,
            latestPreferredSeconds: 1800,
            durationOptionsSeconds: [20],
        )

        #expect(BreakSurfaceProjection.visualDurationSeconds(from: schedule) == 20)
    }

    @Test("Snooze options project the configured delivery values unchanged")
    func snoozeOptionsProjectDeliveryValues() throws {
        let configuration = try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 10,
                targetSeconds: 20,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [20],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: 15,
                targetSeconds: 50,
                latestPreferredSeconds: 60,
                durationOptionsSeconds: [300, 120],
            ),
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 60,
                longIdleResetSeconds: 300,
                wakeUnlockGraceSeconds: 90,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: false,
                mergeWindowSeconds: 60,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 300,
                snoozeOptionsSeconds: [300, 900],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )

        #expect(
            BreakSurfaceProjection.snoozeOptionsSeconds(from: configuration.delivery)
                == [300, 900],
        )
    }

    @Test("The projection carries values only, never engine behavior")
    func projectionIsValueOnly() throws {
        let schedule = try OpportunitySchedule(
            softDueSeconds: 3000,
            targetSeconds: 3600,
            latestPreferredSeconds: 4200,
            durationOptionsSeconds: [300, 120],
        )

        let first = MovementDurations.projected(from: schedule)
        let second = MovementDurations.projected(from: schedule)

        #expect(first == second)
    }
}
