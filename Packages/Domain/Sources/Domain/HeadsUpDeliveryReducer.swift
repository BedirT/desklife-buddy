import Foundation

/// Pure restart-safe reducer for actionable heads-up reservation and response delivery.
public struct HeadsUpDeliveryReducer: Sendable {
    public internal(set) var state: HeadsUpDeliveryState
    let maximumSnoozeReoffers: Int

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
        var effects: [HeadsUpDeliveryEffect] = []
        if let cancelledAction = discardStalePendingAction(
            visualCycleID: visualCycleID,
            movementCycleID: movementCycleID,
        ) {
            effects.append(.cancelPendingAction(cancelledAction))
        }
        if let cancelledID = discardStaleActiveDelivery(
            visualCycleID: visualCycleID,
            movementCycleID: movementCycleID,
        ) {
            effects.append(.cancel(cancelledID))
        }
        return HeadsUpDeliveryOutput(effects: effects)
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
        if state.pendingAction != nil {
            if snapshot.suppressionReason != nil {
                if let cancelled = cancelPendingAutomaticOpen() {
                    return HeadsUpDeliveryOutput(effects: [.cancelPendingAction(cancelled)])
                }
            }
            return HeadsUpDeliveryOutput()
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
        if var active = state.activeDelivery {
            let effectiveSnapshot = activeDeliverySnapshot(active, schedulerSnapshot: snapshot)
            if shouldOpenBreak(effectiveSnapshot) {
                return openBreak(
                    opportunity: active.opportunity,
                    id: active.id,
                    source: .localTimer,
                )
            }
            return updateActiveDelivery(&active, snapshot: effectiveSnapshot)
        }
        if let snoozeReturn = reserveExpiredSnoozeReturn(snapshot, id: proposedDeliveryID) {
            return snoozeReturn
        }
        if shouldOpenBreak(snapshot) {
            return openBreak(
                opportunity: snapshot.opportunity,
                id: proposedDeliveryID,
                source: .localTimer,
            )
        }

        return reserveNewDelivery(snapshot, id: proposedDeliveryID)
    }

    mutating func openBreak(
        opportunity: HeadsUpOpportunityID,
        id: HeadsUpDeliveryID,
        source: OpportunityEventSource,
    ) -> HeadsUpDeliveryOutput {
        clearSnoozeDeadline(for: opportunity)
        let pendingAction = HeadsUpPendingAction(
            id: id,
            kind: .openBreak,
            opportunity: opportunity,
            source: source,
        )
        state.activeDelivery = nil
        state.pendingAction = pendingAction
        return HeadsUpDeliveryOutput(effects: [.openBreak(opportunity)])
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
            state.pendingAction = HeadsUpPendingAction(
                id: id,
                kind: .openBreak,
                opportunity: active.opportunity,
                source: .user,
            )
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
            state.pendingAction = HeadsUpPendingAction(
                id: id,
                kind: .openMoreOptions,
                opportunity: active.opportunity,
                source: .user,
            )
            return HeadsUpDeliveryOutput(effects: [.openMoreOptions(
                id,
                opportunity: active.opportunity,
            )])
        case .dismissedWithoutAction:
            return HeadsUpDeliveryOutput()
        }
    }

    /// Clears only the matching recoverable action after its exact surface opened.
    @discardableResult
    public mutating func completePendingAction(
        _ id: HeadsUpDeliveryID,
        kind: HeadsUpPendingActionKind,
    ) -> HeadsUpPendingAction? {
        guard let pendingAction = state.pendingAction,
              pendingAction.id == id,
              pendingAction.kind == kind
        else {
            return nil
        }
        state.pendingAction = nil
        return pendingAction
    }

    /// Clears only an automatic break-opening request that suppression may safely retract.
    @discardableResult
    public mutating func cancelPendingAutomaticOpen() -> HeadsUpPendingAction? {
        guard let pendingAction = state.pendingAction,
              pendingAction.kind == .openBreak,
              pendingAction.source == .localTimer
        else {
            return nil
        }
        state.pendingAction = nil
        return pendingAction
    }

    /// Applies a newly selected suppression to the one App-visible delivery or automatic open.
    public mutating func suppress(_ reason: SuppressionReason) -> HeadsUpDeliveryOutput {
        if let action = cancelPendingAutomaticOpen() {
            return HeadsUpDeliveryOutput(effects: [.cancelPendingAction(action)])
        }
        guard state.pendingAction == nil else { return HeadsUpDeliveryOutput() }
        return applySuppression(reason)
    }

    /// Mirrors a shared snooze-sheet selection only for clocks already presented this cycle.
    public mutating func snoozePreviouslyPresentedClocks(
        _ clocks: [HeadsUpClock],
        until deadline: Date,
    ) {
        guard deadline.timeIntervalSinceReferenceDate.isFinite else { return }
        for clock in clocks {
            switch clock {
            case .visual where state.visualClock.presentationCount > 0:
                state.visualClock.snoozeDeadline = deadline
            case .movement where state.movementClock.presentationCount > 0:
                state.movementClock.snoozeDeadline = deadline
            case .visual, .movement:
                break
            }
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

    mutating func discardStalePendingAction(
        visualCycleID: UInt64,
        movementCycleID: UInt64,
    ) -> HeadsUpPendingAction? {
        if let pendingAction = state.pendingAction,
           !opportunityMatchesCycles(
               pendingAction.opportunity,
               visualCycleID: visualCycleID,
               movementCycleID: movementCycleID,
           )
        {
            state.pendingAction = nil
            return pendingAction
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
        guard ledger.presentationCount <= maximumSnoozeReoffers else { return false }
        ledger.snoozeDeadline = nil
        return true
    }
}
