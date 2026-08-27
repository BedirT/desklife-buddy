import Testing
@testable import Domain

extension HeadsUpDeliveryTests {
    @Test("Automatic opening persists one exact restartable pending action")
    func automaticOpeningPersistsPendingAction() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 3)
        let actionID = id(2)
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)

        let opened = reducer.observe(
            snapshot(opportunity, target: 0, lowFriction: true),
            proposedDeliveryID: actionID,
        )
        var restored = HeadsUpDeliveryReducer(
            state: reducer.state,
            maximumSnoozeReoffers: 0,
        )
        let replayed = restored.observe(
            snapshot(opportunity, target: -1, lowFriction: true),
            proposedDeliveryID: id(3),
        )

        #expect(opened.effects == [.openBreak(opportunity)])
        #expect(reducer.state.pendingAction == HeadsUpPendingAction(
            id: actionID,
            kind: .openBreak,
            opportunity: opportunity,
            source: .localTimer,
        ))
        #expect(replayed.effects.isEmpty)
        #expect(restored.state.pendingAction?.id == actionID)
    }

    @Test("Start and More Options retain user-sourced pending actions until exact completion")
    func explicitPendingActionsRequireExactCompletion() {
        let opportunity = HeadsUpOpportunityID.movement(cycleID: 5)
        let deliveryID = id(4)
        for (response, kind) in [
            (HeadsUpDeliveryResponse.startNow, HeadsUpPendingActionKind.openBreak),
            (.moreOptions, .openMoreOptions),
        ] {
            var reducer = acknowledgedReducer(opportunity, id: deliveryID)
            let output = reducer.respond(deliveryID, response: response)
            let stale = reducer.completePendingAction(id(99), kind: kind)
            let completed = reducer.completePendingAction(deliveryID, kind: kind)

            #expect(output.effects.count == 1)
            #expect(stale == nil)
            #expect(completed == HeadsUpPendingAction(
                id: deliveryID,
                kind: kind,
                opportunity: opportunity,
                source: .user,
            ))
            #expect(reducer.state.pendingAction == nil)
        }
    }

    @Test("Synchronizing one rotated cycle resets only its ledger")
    func synchronizeRotatedSingleCycles() {
        var movement = acknowledgedReducer(.movement(cycleID: 7), id: id(79))
        let movementState = movement.state
        #expect(movement.synchronizeCycles(
            visualCycleID: 4,
            movementCycleID: 7,
        ) == HeadsUpDeliveryOutput())
        #expect(movement.state.visualClock == HeadsUpClockLedger(cycleID: 4))
        #expect(movement.state.movementClock == movementState.movementClock)
        #expect(movement.state.activeDelivery == movementState.activeDelivery)
        var visual = acknowledgedReducer(.visual(cycleID: 5), id: id(80))
        let visualState = visual.state
        #expect(visual.synchronizeCycles(
            visualCycleID: 5,
            movementCycleID: 9,
        ) == HeadsUpDeliveryOutput())
        #expect(visual.state.visualClock == visualState.visualClock)
        #expect(visual.state.movementClock == HeadsUpClockLedger(cycleID: 9))
        #expect(visual.state.activeDelivery == visualState.activeDelivery)
    }

    @Test("Suppression cancels an automatic pending open but retains explicit user intent")
    func suppressionCancelsOnlyAutomaticPendingOpen() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 3)
        var automatic = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
        _ = automatic.observe(
            snapshot(opportunity, target: 0, lowFriction: true),
            proposedDeliveryID: id(90),
        )
        let automaticAction = automatic.state.pendingAction

        let cancelled = automatic.observe(
            snapshot(opportunity, target: -1, suppression: .manualPause),
            proposedDeliveryID: id(91),
        )

        #expect(cancelled.effects == automaticAction.map {
            [.cancelPendingAction($0)]
        })
        #expect(automatic.state.pendingAction == nil)

        var explicit = acknowledgedReducer(opportunity, id: id(92))
        _ = explicit.respond(id(92), response: .startNow)
        let retained = explicit.state.pendingAction
        let suppressed = explicit.observe(
            snapshot(opportunity, target: -1, suppression: .manualPause),
            proposedDeliveryID: id(93),
        )

        #expect(suppressed == HeadsUpDeliveryOutput())
        #expect(explicit.state.pendingAction == retained)
    }
}
