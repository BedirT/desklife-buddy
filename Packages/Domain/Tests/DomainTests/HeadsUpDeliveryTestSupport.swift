import Foundation
import Testing
@testable import Domain

extension HeadsUpDeliveryTests {
    func acknowledgedReducer(
        _ opportunity: HeadsUpOpportunityID,
        id deliveryID: HeadsUpDeliveryID,
        maximumReoffers: Int = 2,
    ) -> HeadsUpDeliveryReducer {
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: maximumReoffers)
        _ = reducer.observe(snapshot(opportunity, target: 45), proposedDeliveryID: deliveryID)
        _ = reducer.acknowledgePresented(deliveryID, channel: .notification)
        _ = reducer.acknowledgePromptFact(deliveryID)
        return reducer
    }

    func snapshot(
        _ opportunity: HeadsUpOpportunityID,
        target: TimeInterval,
        latest: TimeInterval = 600,
        observedAt: Date? = nil,
        headsUpEnabled: Bool = true,
        headsUpLeadSeconds: TimeInterval = 45,
        waitsForLowFrictionMoment: Bool = true,
        lowFriction: Bool = false,
        suppression: SuppressionReason? = nil,
        currentVisualCycleID: UInt64? = nil,
        currentMovementCycleID: UInt64? = nil,
    ) -> HeadsUpDeliverySnapshot {
        let cycles = currentCycles(for: opportunity)
        return HeadsUpDeliverySnapshot(
            opportunity: opportunity,
            currentVisualCycleID: currentVisualCycleID ?? cycles.visual,
            currentMovementCycleID: currentMovementCycleID ?? cycles.movement,
            observedAt: observedAt ?? start,
            secondsUntilTarget: target,
            secondsUntilLatest: latest,
            headsUpEnabled: headsUpEnabled,
            headsUpLeadSeconds: headsUpLeadSeconds,
            waitsForLowFrictionMoment: waitsForLowFrictionMoment,
            isLowFrictionMoment: lowFriction,
            suppressionReason: suppression,
        )
    }

    func currentCycles(for opportunity: HeadsUpOpportunityID) -> (visual: UInt64, movement: UInt64) {
        switch opportunity {
        case let .visual(cycleID):
            (cycleID, 0)
        case let .movement(cycleID):
            (0, cycleID)
        case let .merged(visualCycleID, movementCycleID):
            (visualCycleID, movementCycleID)
        }
    }

    func id(_ value: Int) -> HeadsUpDeliveryID {
        HeadsUpDeliveryID(rawValue: UUID(
            uuidString: String(format: "00000000-0000-0000-0000-%012d", value),
        )!)
    }

    func configuration() throws -> ProtocolConfiguration {
        try ProtocolConfiguration(
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
                recentInputWindowSeconds: 60,
                longIdleResetSeconds: 300,
                wakeUnlockGraceSeconds: 90,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: true,
                mergeWindowSeconds: 5,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 45,
                snoozeOptionsSeconds: [3, 6, 9],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )
    }
}
