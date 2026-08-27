import Foundation

extension HeadsUpDeliveryReducer {
    mutating func reserveExpiredSnoozeReturn(
        _ snapshot: HeadsUpDeliverySnapshot,
        id: HeadsUpDeliveryID,
    ) -> HeadsUpDeliveryOutput? {
        guard hasExpiredSnooze(for: snapshot.opportunity, at: snapshot.observedAt) else {
            return nil
        }
        guard snapshot.headsUpEnabled else { return nil }
        guard let opportunity = uncoveredOpportunity(
            from: snapshot.opportunity,
            observedAt: snapshot.observedAt,
        ) else {
            return HeadsUpDeliveryOutput()
        }
        let leadSeconds = max(0, snapshot.headsUpLeadSeconds)
        let mark = HeadsUpCountdownMark.coarseValue(
            secondsUntilTarget: leadSeconds,
            leadSeconds: snapshot.headsUpLeadSeconds,
        )
        let active = HeadsUpActiveDelivery(
            id: id,
            opportunity: opportunity,
            countdownMark: mark,
            targetAt: snapshot.observedAt.addingTimeInterval(leadSeconds),
        )
        state.activeDelivery = active
        return HeadsUpDeliveryOutput(effects: [.reserve(HeadsUpDeliveryReservation(
            id: id,
            opportunity: opportunity,
            countdownMark: mark,
            targetAt: active.targetAt,
        ))])
    }

    mutating func reserveNewDelivery(
        _ snapshot: HeadsUpDeliverySnapshot,
        id: HeadsUpDeliveryID,
    ) -> HeadsUpDeliveryOutput {
        guard snapshot.headsUpEnabled,
              snapshot.secondsUntilTarget > 0,
              let opportunity = uncoveredOpportunity(
                  from: snapshot.opportunity,
                  observedAt: snapshot.observedAt,
              )
        else {
            return HeadsUpDeliveryOutput()
        }
        let mark = HeadsUpCountdownMark.coarseValue(
            secondsUntilTarget: snapshot.secondsUntilTarget,
            leadSeconds: snapshot.headsUpLeadSeconds,
        )
        let active = HeadsUpActiveDelivery(
            id: id,
            opportunity: opportunity,
            countdownMark: mark,
            targetAt: snapshot.observedAt.addingTimeInterval(snapshot.secondsUntilTarget),
        )
        state.activeDelivery = active
        return HeadsUpDeliveryOutput(effects: [.reserve(HeadsUpDeliveryReservation(
            id: id,
            opportunity: opportunity,
            countdownMark: mark,
            targetAt: active.targetAt,
        ))])
    }

    func hasExpiredSnooze(
        for opportunity: HeadsUpOpportunityID,
        at observedAt: Date,
    ) -> Bool {
        opportunity.clocks.contains { clock in
            let deadline = switch clock {
            case .visual: state.visualClock.snoozeDeadline
            case .movement: state.movementClock.snoozeDeadline
            }
            return deadline.map { observedAt >= $0 } ?? false
        }
    }

    mutating func clearSnoozeDeadline(for opportunity: HeadsUpOpportunityID) {
        if opportunity.visualCycleID != nil {
            state.visualClock.snoozeDeadline = nil
        }
        if opportunity.movementCycleID != nil {
            state.movementClock.snoozeDeadline = nil
        }
    }
}
