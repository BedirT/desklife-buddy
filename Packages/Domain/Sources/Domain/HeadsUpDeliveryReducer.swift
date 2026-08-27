import Foundation

/// Pure restart-safe reducer for actionable heads-up reservation and response delivery.
public struct HeadsUpDeliveryReducer: Sendable {
    public private(set) var state: HeadsUpDeliveryState
    private let maximumSnoozeReoffers: Int

    /// Restores delivery state with an explicitly injected, unresolved re-offer policy.
    public init(
        state: HeadsUpDeliveryState = HeadsUpDeliveryState(),
        maximumSnoozeReoffers: Int,
    ) {
        precondition(maximumSnoozeReoffers >= 0)
        self.state = state
        self.maximumSnoozeReoffers = maximumSnoozeReoffers
    }

    /// Aligns persisted delivery coverage with the scheduler's current outer cycles.
    public mutating func synchronizeCycles(
        visualCycleID: UInt64,
        movementCycleID: UInt64,
    ) -> HeadsUpDeliveryOutput {
        synchronizeLedgers(
            visualCycleID: visualCycleID,
            movementCycleID: movementCycleID,
        )
        guard let cancelledID = discardStaleActiveDelivery(
            visualCycleID: visualCycleID,
            movementCycleID: movementCycleID,
        ) else {
            return HeadsUpDeliveryOutput()
        }
        return HeadsUpDeliveryOutput(effects: [.cancel(cancelledID)])
    }

    /// Reduces a scheduler snapshot and reserves, updates, holds, or opens as needed.
    public mutating func observe(
        _ snapshot: HeadsUpDeliverySnapshot,
        proposedDeliveryID: HeadsUpDeliveryID,
    ) -> HeadsUpDeliveryOutput {
        let synchronization = synchronizeCycles(
            visualCycleID: snapshot.currentVisualCycleID,
            movementCycleID: snapshot.currentMovementCycleID,
        )
        if !synchronization.effects.isEmpty {
            return synchronization
        }
        guard opportunityMatchesCycles(
            snapshot.opportunity,
            visualCycleID: snapshot.currentVisualCycleID,
            movementCycleID: snapshot.currentMovementCycleID,
        ) else {
            return HeadsUpDeliveryOutput()
        }

        if let reason = snapshot.suppressionReason {
            return applySuppression(reason)
        }
        if shouldOpenBreak(snapshot) {
            state.activeDelivery = nil
            return HeadsUpDeliveryOutput(effects: [.openBreak(snapshot.opportunity)])
        }
        if var active = state.activeDelivery {
            return updateActiveDelivery(&active, snapshot: snapshot)
        }

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
            id: proposedDeliveryID,
            opportunity: opportunity,
            countdownMark: mark,
        )
        state.activeDelivery = active
        return HeadsUpDeliveryOutput(effects: [.reserve(HeadsUpDeliveryReservation(
            id: proposedDeliveryID,
            opportunity: opportunity,
            countdownMark: mark,
        ))])
    }

    /// Records adapter-confirmed presentation and emits its one pending prompt fact.
    public mutating func acknowledgePresented(
        _ id: HeadsUpDeliveryID,
        channel: HeadsUpDeliveryChannel,
    ) -> HeadsUpDeliveryOutput {
        guard var active = state.activeDelivery,
              active.id == id,
              active.phase == .reserved
        else {
            return HeadsUpDeliveryOutput()
        }

        active.phase = .presented
        active.channel = channel
        active.promptFactStatus = .pending
        state.activeDelivery = active
        incrementPresentationCount(for: active.opportunity)
        return HeadsUpDeliveryOutput(events: [OpportunityEventDraft(
            kind: .promptPresented,
            source: .localTimer,
            opportunity: active.opportunity.eventOpportunity,
        )])
    }

    /// Marks the pending prompt fact committed without presenting the delivery again.
    @discardableResult
    public mutating func acknowledgePromptFact(_ id: HeadsUpDeliveryID) -> Bool {
        guard var active = state.activeDelivery,
              active.id == id,
              active.promptFactStatus == .pending
        else {
            return false
        }
        active.promptFactStatus = .acknowledged
        state.activeDelivery = active
        return true
    }

    /// Reduces an explicit response only when it belongs to the current delivery identity.
    public mutating func respond(
        _ id: HeadsUpDeliveryID,
        response: HeadsUpDeliveryResponse,
    ) -> HeadsUpDeliveryOutput {
        guard let active = state.activeDelivery,
              active.id == id,
              active.phase == .presented,
              active.promptFactStatus == .acknowledged
        else {
            return HeadsUpDeliveryOutput()
        }

        state.activeDelivery = nil
        switch response {
        case .startNow:
            return HeadsUpDeliveryOutput(effects: [.openBreak(active.opportunity)])
        case let .snooze(until: deadline):
            setSnoozeDeadline(deadline, for: active.opportunity)
            return HeadsUpDeliveryOutput(effects: [.snooze(
                id,
                clocks: active.opportunity.clocks,
                until: deadline,
            )])
        case .skip:
            return HeadsUpDeliveryOutput(effects: [.skip(
                id,
                opportunity: active.opportunity,
            )])
        case .moreOptions:
            return HeadsUpDeliveryOutput(effects: [.openMoreOptions(
                id,
                opportunity: active.opportunity,
            )])
        case .dismissedWithoutAction:
            return HeadsUpDeliveryOutput()
        }
    }
}

extension HeadsUpDeliveryReducer {
    func opportunityMatchesCycles(
        _ opportunity: HeadsUpOpportunityID,
        visualCycleID: UInt64,
        movementCycleID: UInt64,
    ) -> Bool {
        let visualMatches = opportunity.visualCycleID.map { $0 == visualCycleID } ?? true
        let movementMatches = opportunity.movementCycleID.map { $0 == movementCycleID } ?? true
        return visualMatches && movementMatches
    }

    mutating func synchronizeLedgers(
        visualCycleID: UInt64,
        movementCycleID: UInt64,
    ) {
        if state.visualClock.cycleID != visualCycleID {
            state.visualClock = HeadsUpClockLedger(cycleID: visualCycleID)
        }
        if state.movementClock.cycleID != movementCycleID {
            state.movementClock = HeadsUpClockLedger(cycleID: movementCycleID)
        }
    }

    mutating func discardStaleActiveDelivery(
        visualCycleID: UInt64,
        movementCycleID: UInt64,
    ) -> HeadsUpDeliveryID? {
        guard let active = state.activeDelivery else { return nil }
        let activeVisualIsCurrent = active.opportunity.visualCycleID.map {
            $0 == visualCycleID
        } ?? true
        let activeMovementIsCurrent = active.opportunity.movementCycleID.map {
            $0 == movementCycleID
        } ?? true
        if !activeVisualIsCurrent || !activeMovementIsCurrent {
            state.activeDelivery = nil
            return active.id
        }
        return nil
    }

    mutating func applySuppression(_ reason: SuppressionReason) -> HeadsUpDeliveryOutput {
        guard let active = state.activeDelivery else {
            return HeadsUpDeliveryOutput()
        }
        switch active.phase {
        case .reserved:
            state.activeDelivery = nil
            return HeadsUpDeliveryOutput(effects: [.cancel(active.id)])
        case .presented:
            state.activeDelivery = nil
            return HeadsUpDeliveryOutput(effects: [.holdThenRetract(active.id, reason)])
        }
    }

    func shouldOpenBreak(_ snapshot: HeadsUpDeliverySnapshot) -> Bool {
        snapshot.secondsUntilLatest <= 0
            || (snapshot.secondsUntilTarget <= 0
                && (!snapshot.waitsForLowFrictionMoment || snapshot.isLowFrictionMoment))
    }

    mutating func updateActiveDelivery(
        _ active: inout HeadsUpActiveDelivery,
        snapshot: HeadsUpDeliverySnapshot,
    ) -> HeadsUpDeliveryOutput {
        if active.phase == .reserved {
            let mark = HeadsUpCountdownMark.coarseValue(
                secondsUntilTarget: snapshot.secondsUntilTarget,
                leadSeconds: snapshot.headsUpLeadSeconds,
            )
            active.countdownMark = mark
            state.activeDelivery = active
            return HeadsUpDeliveryOutput(effects: [.reserve(HeadsUpDeliveryReservation(
                id: active.id,
                opportunity: active.opportunity,
                countdownMark: mark,
            ))])
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
        guard active.countdownMark != mark else {
            return HeadsUpDeliveryOutput()
        }
        active.countdownMark = mark
        state.activeDelivery = active
        return HeadsUpDeliveryOutput(effects: [.updateCountdown(active.id, mark)])
    }

    mutating func incrementPresentationCount(for opportunity: HeadsUpOpportunityID) {
        if opportunity.visualCycleID != nil {
            state.visualClock.presentationCount += 1
            state.visualClock.snoozeDeadline = nil
        }
        if opportunity.movementCycleID != nil {
            state.movementClock.presentationCount += 1
            state.movementClock.snoozeDeadline = nil
        }
    }

    mutating func setSnoozeDeadline(
        _ deadline: Date,
        for opportunity: HeadsUpOpportunityID,
    ) {
        if opportunity.visualCycleID != nil {
            state.visualClock.snoozeDeadline = deadline
        }
        if opportunity.movementCycleID != nil {
            state.movementClock.snoozeDeadline = deadline
        }
    }

    mutating func uncoveredOpportunity(
        from opportunity: HeadsUpOpportunityID,
        observedAt: Date,
    ) -> HeadsUpOpportunityID? {
        let visualIsUncovered = opportunity.visualCycleID.map {
            ledgerCanPresent(&state.visualClock, cycleID: $0, observedAt: observedAt)
        } ?? false
        let movementIsUncovered = opportunity.movementCycleID.map {
            ledgerCanPresent(&state.movementClock, cycleID: $0, observedAt: observedAt)
        } ?? false

        switch opportunity {
        case let .visual(cycleID):
            return visualIsUncovered ? .visual(cycleID: cycleID) : nil
        case let .movement(cycleID):
            return movementIsUncovered ? .movement(cycleID: cycleID) : nil
        case let .merged(visualCycleID, movementCycleID):
            if visualIsUncovered, movementIsUncovered {
                return .merged(
                    visualCycleID: visualCycleID,
                    movementCycleID: movementCycleID,
                )
            }
            if visualIsUncovered { return .visual(cycleID: visualCycleID) }
            if movementIsUncovered { return .movement(cycleID: movementCycleID) }
            return nil
        }
    }

    func ledgerCanPresent(
        _ ledger: inout HeadsUpClockLedger,
        cycleID: UInt64,
        observedAt: Date,
    ) -> Bool {
        guard ledger.cycleID == cycleID else { return true }
        guard ledger.presentationCount > 0 else { return true }
        guard let deadline = ledger.snoozeDeadline else { return false }
        guard observedAt >= deadline else { return false }
        ledger.snoozeDeadline = nil
        return ledger.presentationCount <= maximumSnoozeReoffers
    }
}
