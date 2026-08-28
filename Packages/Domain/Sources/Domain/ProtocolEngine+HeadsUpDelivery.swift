import Foundation

public extension ProtocolEngine {
    /// Repairs a crash-interrupted break to restart grace without inferring offline elapsed use.
    mutating func resumeInterruptedBreak() {
        if visualClock.phase == .running {
            visualClock.phase = .gracedAfterSuppression
        }
        if movementClock.phase == .running {
            movementClock.phase = .gracedAfterSuppression
        }
    }

    /// Projects one actionable non-recovery delivery from this exact reduced candidate.
    func actionableHeadsUpSnapshot(
        observedAt: Date,
        isLowFrictionMoment: Bool,
        suppressionReason: SuppressionReason?,
    ) -> HeadsUpDeliverySnapshot? {
        let opportunity = headsUpDeliveryState.activeDelivery?.opportunity
            ?? headsUpDeliveryState.pendingAction?.opportunity
            ?? recommendedPresentation().flatMap {
                HeadsUpOpportunityID(
                    presentation: $0,
                    visualCycleID: visualClock.cycleID,
                    movementCycleID: movementClock.cycleID,
                )
            }
        guard let opportunity else { return nil }
        let timing = headsUpTiming(for: opportunity)
        return HeadsUpDeliverySnapshot(
            opportunity: opportunity,
            currentVisualCycleID: visualClock.cycleID,
            currentMovementCycleID: movementClock.cycleID,
            observedAt: observedAt,
            secondsUntilTarget: timing.target,
            secondsUntilLatest: timing.latest,
            headsUpEnabled: configuration.delivery.headsUpDefault,
            headsUpLeadSeconds: configuration.delivery.headsUpSecondsBeforeTarget,
            waitsForLowFrictionMoment: configuration.delivery.waitForLowFrictionMoment,
            isLowFrictionMoment: isLowFrictionMoment,
            suppressionReason: suppressionReason,
        )
    }

    private func headsUpTiming(
        for opportunity: HeadsUpOpportunityID,
    ) -> (target: TimeInterval, latest: TimeInterval) {
        let visual = (
            configuration.visual.targetSeconds - visualClock.accumulatedActiveUseSeconds,
            configuration.visual.latestPreferredSeconds
                - visualClock.accumulatedActiveUseSeconds,
        )
        let movement = (
            configuration.movement.targetSeconds - movementClock.accumulatedActiveUseSeconds,
            configuration.movement.latestPreferredSeconds
                - movementClock.accumulatedActiveUseSeconds,
        )
        return switch opportunity {
        case .visual:
            visual
        case .movement:
            movement
        case .merged:
            (min(visual.0, movement.0), min(visual.1, movement.1))
        }
    }
}
