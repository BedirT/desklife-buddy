import Foundation

extension HeadsUpDeliveryReducer {
    func shouldOpenBreak(_ snapshot: HeadsUpDeliverySnapshot) -> Bool {
        snapshot.secondsUntilLatest <= 0
            || (snapshot.secondsUntilTarget <= 0
                && (!snapshot.waitsForLowFrictionMoment || snapshot.isLowFrictionMoment))
    }

    func activeDeliverySnapshot(
        _ active: HeadsUpActiveDelivery,
        schedulerSnapshot: HeadsUpDeliverySnapshot,
    ) -> HeadsUpDeliverySnapshot {
        guard isSnoozeReoffer(active), let targetAt = active.targetAt else {
            return schedulerSnapshot
        }
        let remaining = targetAt.timeIntervalSince(schedulerSnapshot.observedAt)
        return HeadsUpDeliverySnapshot(
            opportunity: active.opportunity,
            currentVisualCycleID: schedulerSnapshot.currentVisualCycleID,
            currentMovementCycleID: schedulerSnapshot.currentMovementCycleID,
            observedAt: schedulerSnapshot.observedAt,
            secondsUntilTarget: remaining,
            secondsUntilLatest: remaining,
            headsUpEnabled: schedulerSnapshot.headsUpEnabled,
            headsUpLeadSeconds: schedulerSnapshot.headsUpLeadSeconds,
            waitsForLowFrictionMoment: schedulerSnapshot.waitsForLowFrictionMoment,
            isLowFrictionMoment: schedulerSnapshot.isLowFrictionMoment,
            suppressionReason: schedulerSnapshot.suppressionReason,
        )
    }

    func isSnoozeReoffer(_ active: HeadsUpActiveDelivery) -> Bool {
        let priorPresentations = active.opportunity.clocks.map { clock in
            switch clock {
            case .visual: state.visualClock.presentationCount
            case .movement: state.movementClock.presentationCount
            }
        }.min() ?? 0
        let threshold = active.phase == .reserved ? 1 : 2
        return priorPresentations >= threshold
    }

    mutating func updateActiveDelivery(
        _ active: inout HeadsUpActiveDelivery,
        snapshot: HeadsUpDeliverySnapshot,
    ) -> HeadsUpDeliveryOutput {
        if active.phase == .reserved {
            return refreshReservedDelivery(&active, snapshot: snapshot)
        }
        if snapshot.secondsUntilTarget <= 0 {
            guard !active.didLand else { return HeadsUpDeliveryOutput() }
            active.didLand = true
            state.activeDelivery = active
            return HeadsUpDeliveryOutput(effects: [.land(active.id)])
        }

        let mark = HeadsUpCountdownMark.coarseValue(
            secondsUntilTarget: snapshot.secondsUntilTarget,
            leadSeconds: snapshot.headsUpLeadSeconds,
        )
        let targetAt = snapshot.observedAt.addingTimeInterval(snapshot.secondsUntilTarget)
        let countdownChanged = active.countdownMark != mark
        let timingChanged = active.targetAt != targetAt
        guard countdownChanged || timingChanged else {
            return HeadsUpDeliveryOutput()
        }
        active.countdownMark = mark
        active.targetAt = targetAt
        state.activeDelivery = active
        if countdownChanged {
            return HeadsUpDeliveryOutput(effects: [.updateCountdown(
                active.id,
                mark,
                targetAt: targetAt,
            )])
        }
        return HeadsUpDeliveryOutput(effects: [.updateTiming(active.id, targetAt: targetAt)])
    }

    private mutating func refreshReservedDelivery(
        _ active: inout HeadsUpActiveDelivery,
        snapshot: HeadsUpDeliverySnapshot,
    ) -> HeadsUpDeliveryOutput {
        let mark = HeadsUpCountdownMark.coarseValue(
            secondsUntilTarget: snapshot.secondsUntilTarget,
            leadSeconds: snapshot.headsUpLeadSeconds,
        )
        active.countdownMark = mark
        active.targetAt = snapshot.observedAt.addingTimeInterval(snapshot.secondsUntilTarget)
        state.activeDelivery = active
        return HeadsUpDeliveryOutput(effects: [.reserve(HeadsUpDeliveryReservation(
            id: active.id,
            opportunity: active.opportunity,
            countdownMark: mark,
            targetAt: active.targetAt,
        ))])
    }
}
