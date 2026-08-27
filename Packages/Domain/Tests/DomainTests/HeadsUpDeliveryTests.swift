import Foundation
import Testing
@testable import Domain

@Suite("Heads-up delivery reducer")
struct HeadsUpDeliveryTests {
    let start = Date(timeIntervalSince1970: 1000)

    @Test("A visual cycle reserves and acknowledges exactly one delivery")
    func visualCycleDeliversOnce() {
        let deliveryID = id(1)
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 1)
        let reservation = reducer.observe(
            snapshot(.visual(cycleID: 4), target: 45),
            proposedDeliveryID: deliveryID,
        )
        let acknowledgement = reducer.acknowledgePresented(deliveryID, channel: .notification)
        let duplicate = reducer.observe(
            snapshot(.visual(cycleID: 4), target: 44),
            proposedDeliveryID: id(2),
        )
        let duplicateAcknowledgement = reducer.acknowledgePresented(
            deliveryID,
            channel: .notification,
        )
        #expect(reservation.effects == [.reserve(HeadsUpDeliveryReservation(
            id: deliveryID,
            opportunity: .visual(cycleID: 4),
            countdownMark: .seconds45,
            targetAt: start.addingTimeInterval(45),
        ))])
        #expect(acknowledgement.events == [OpportunityEventDraft(
            kind: .promptPresented,
            source: .localTimer,
            opportunity: .visual,
        )])
        #expect(duplicate.effects == [
            .updateTiming(deliveryID, targetAt: start.addingTimeInterval(44)),
        ])
        #expect(duplicateAcknowledgement == HeadsUpDeliveryOutput())
        #expect(reducer.state.visualClock.presentationCount == 1)
    }

    @Test("Reserved and presented deliveries restore without changing identity")
    func reservationAndPresentationRestore() {
        let deliveryID = id(3)
        var original = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 1)
        let due = snapshot(.visual(cycleID: 8), target: 45)
        _ = original.observe(due, proposedDeliveryID: deliveryID)
        var reserved = HeadsUpDeliveryReducer(
            state: original.state,
            maximumSnoozeReoffers: 1,
        )
        let retry = reserved.observe(due, proposedDeliveryID: id(4))
        #expect(retry.effects.first?.deliveryID == deliveryID)
        _ = reserved.acknowledgePresented(deliveryID, channel: .capsule)
        var presented = HeadsUpDeliveryReducer(
            state: reserved.state,
            maximumSnoozeReoffers: 1,
        )
        let afterRestore = presented.observe(
            snapshot(.visual(cycleID: 8), target: 44),
            proposedDeliveryID: id(5),
        )
        #expect(afterRestore.effects == [
            .updateTiming(deliveryID, targetAt: start.addingTimeInterval(44)),
        ])
        #expect(presented.state.activeDelivery?.id == deliveryID)
    }

    @Test("Restored reservation keeps identity but refreshes its coarse countdown")
    func restoredReservationRefreshesCountdown() {
        let deliveryID = id(75)
        var original = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
        _ = original.observe(
            snapshot(.visual(cycleID: 8), target: 45),
            proposedDeliveryID: deliveryID,
        )
        var restored = HeadsUpDeliveryReducer(
            state: original.state,
            maximumSnoozeReoffers: 0,
        )
        let retry = restored.observe(
            snapshot(.visual(cycleID: 8), target: 15),
            proposedDeliveryID: id(76),
        )
        #expect(retry.effects == [.reserve(HeadsUpDeliveryReservation(
            id: deliveryID,
            opportunity: .visual(cycleID: 8),
            countdownMark: .seconds15,
            targetAt: start.addingTimeInterval(15),
        ))])
        #expect(restored.state.activeDelivery?.countdownMark == .seconds15)
    }

    @Test("Candidate priority changes do not discard an adapter-live current-cycle delivery")
    func candidatePriorityChangeKeepsActiveDelivery() {
        let deliveryID = id(77)
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
        _ = reducer.observe(
            snapshot(
                .visual(cycleID: 4),
                target: 45,
                currentVisualCycleID: 4,
                currentMovementCycleID: 9,
            ),
            proposedDeliveryID: deliveryID,
        )

        let output = reducer.observe(
            snapshot(
                .movement(cycleID: 9),
                target: 30,
                currentVisualCycleID: 4,
                currentMovementCycleID: 9,
            ),
            proposedDeliveryID: id(78),
        )

        #expect(output.effects.first?.deliveryID == deliveryID)
        #expect(reducer.state.activeDelivery?.id == deliveryID)
        #expect(reducer.state.activeDelivery?.opportunity == .visual(cycleID: 4))
    }

    @Test("Notification and capsule acknowledgements have identical semantics")
    func channelsHaveParity() {
        let deliveryID = id(6)
        let due = snapshot(.movement(cycleID: 2), target: 45)
        var notification = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
        var capsule = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
        _ = notification.observe(due, proposedDeliveryID: deliveryID)
        _ = capsule.observe(due, proposedDeliveryID: deliveryID)

        let notificationOutput = notification.acknowledgePresented(
            deliveryID,
            channel: .notification,
        )
        let capsuleOutput = capsule.acknowledgePresented(deliveryID, channel: .capsule)

        #expect(notificationOutput == capsuleOutput)
        #expect(notification.state.movementClock == capsule.state.movementClock)
        #expect(notification.state.activeDelivery?.opportunity == capsule.state.activeDelivery?.opportunity)
        #expect(notification.state.activeDelivery?.channel == .notification)
        #expect(capsule.state.activeDelivery?.channel == .capsule)
    }

    @Test("Countdown exposes only the 45 30 15 and 5 second coarse marks")
    func coarseCountdownMarks() {
        let expectations: [(TimeInterval, HeadsUpCountdownMark)] = [
            (45, .seconds45),
            (44, .seconds45),
            (30, .seconds30),
            (29, .seconds30),
            (15, .seconds15),
            (14, .seconds15),
            (5, .seconds5),
            (4, .seconds5),
            (0, .seconds5),
        ]

        for (seconds, expected) in expectations {
            #expect(HeadsUpCountdownMark.coarseValue(
                secondsUntilTarget: seconds,
                leadSeconds: 45,
            ) == expected)
        }

        #expect(HeadsUpCountdownMark.coarseValue(
            secondsUntilTarget: 59,
            leadSeconds: 60,
        ) == .seconds60)
        #expect(HeadsUpCountdownMark.coarseValue(
            secondsUntilTarget: 30,
            leadSeconds: 30,
        ) == .seconds30)
    }
}

extension HeadsUpDeliveryTests {
    @Test("Target waits without low friction while low friction and latest open")
    func targetAndLatestBounds() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 10)
        let deliveryID = id(7)
        var waiting = acknowledgedReducer(opportunity, id: deliveryID)

        let landed = waiting.observe(
            snapshot(opportunity, target: 0, latest: 60),
            proposedDeliveryID: id(8),
        )
        let lowFriction = waiting.observe(
            snapshot(opportunity, target: 0, latest: 60, lowFriction: true),
            proposedDeliveryID: id(9),
        )

        var latest = acknowledgedReducer(opportunity, id: deliveryID)
        let bounded = latest.observe(
            snapshot(opportunity, target: -60, latest: 0),
            proposedDeliveryID: id(10),
        )

        #expect(landed.effects == [.land(deliveryID)])
        #expect(lowFriction.effects == [.openBreak(opportunity)])
        #expect(bounded.effects == [.openBreak(opportunity)])
    }

    @Test("Target opens immediately when low-friction waiting is disabled")
    func targetWithoutLowFrictionWait() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 10)
        var reducer = acknowledgedReducer(opportunity, id: id(70))

        let output = reducer.observe(
            snapshot(
                opportunity,
                target: 0,
                latest: 60,
                waitsForLowFrictionMoment: false,
            ),
            proposedDeliveryID: id(71),
        )

        #expect(output.effects == [.openBreak(opportunity)])
    }

    @Test("Disabled heads-up still opens at low friction or latest")
    func disabledHeadsUpStillOpens() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 11)
        var atTarget = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
        var atLatest = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)

        let lowFriction = atTarget.observe(
            snapshot(
                opportunity,
                target: 0,
                latest: 60,
                headsUpEnabled: false,
                lowFriction: true,
            ),
            proposedDeliveryID: id(11),
        )
        let latest = atLatest.observe(
            snapshot(opportunity, target: -60, latest: 0, headsUpEnabled: false),
            proposedDeliveryID: id(12),
        )

        #expect(lowFriction.effects == [.openBreak(opportunity)])
        #expect(latest.effects == [.openBreak(opportunity)])
    }

    @Test("Suppression during countdown holds and retracts once without resuming")
    func midCountdownSuppression() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 12)
        let deliveryID = id(13)
        var reducer = acknowledgedReducer(opportunity, id: deliveryID)

        let first = reducer.observe(
            snapshot(opportunity, target: 30, suppression: .calendarBusy),
            proposedDeliveryID: id(14),
        )
        let repeated = reducer.observe(
            snapshot(opportunity, target: 29, suppression: .calendarBusy),
            proposedDeliveryID: id(15),
        )
        let afterSuppression = reducer.observe(
            snapshot(opportunity, target: 29),
            proposedDeliveryID: id(16),
        )

        #expect(first.effects == [.holdThenRetract(deliveryID, .calendarBusy)])
        #expect(repeated.effects.isEmpty)
        #expect(afterSuppression.effects.isEmpty)
        #expect(reducer.state.activeDelivery == nil)
    }

    @Test("Suppression before acknowledgement cancels without a prompt fact")
    func suppressionBeforeAcknowledgement() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 13)
        let deliveryID = id(17)
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
        _ = reducer.observe(snapshot(opportunity, target: 45), proposedDeliveryID: deliveryID)

        let cancelled = reducer.observe(
            snapshot(opportunity, target: 44, suppression: .manualPause),
            proposedDeliveryID: id(18),
        )
        let staleAcknowledgement = reducer.acknowledgePresented(
            deliveryID,
            channel: .notification,
        )

        #expect(cancelled.effects == [.cancel(deliveryID)])
        #expect(cancelled.events.isEmpty)
        #expect(staleAcknowledgement == HeadsUpDeliveryOutput())
        #expect(reducer.state.activeDelivery == nil)
        #expect(reducer.state.visualClock.presentationCount == 0)
    }

    @Test("Merged acknowledgement covers both cycles and emits one unscoped prompt fact")
    func mergedDeliveryCoversBothCycles() {
        let opportunity = HeadsUpOpportunityID.merged(visualCycleID: 3, movementCycleID: 7)
        let deliveryID = id(19)
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 1)
        let reserved = reducer.observe(
            snapshot(opportunity, target: 45),
            proposedDeliveryID: deliveryID,
        )
        let acknowledged = reducer.acknowledgePresented(deliveryID, channel: .capsule)

        #expect(reserved.effects.count == 1)
        #expect(acknowledged.events == [OpportunityEventDraft(
            kind: .promptPresented,
            source: .localTimer,
        )])
        #expect(reducer.state.visualClock.presentationCount == 1)
        #expect(reducer.state.movementClock.presentationCount == 1)
    }

    @Test("A reset constituent can deliver while the unchanged merged constituent stays covered")
    func constituentResetKeepsOtherCovered() {
        let deliveryID = id(20)
        var reducer = acknowledgedReducer(
            .merged(visualCycleID: 1, movementCycleID: 1),
            id: deliveryID,
        )
        _ = reducer.respond(deliveryID, response: .dismissedWithoutAction)

        let output = reducer.observe(
            snapshot(.merged(visualCycleID: 2, movementCycleID: 1), target: 45),
            proposedDeliveryID: id(21),
        )
        #expect(output.effects == [.reserve(HeadsUpDeliveryReservation(
            id: id(21),
            opportunity: .visual(cycleID: 2),
            countdownMark: .seconds45,
            targetAt: start.addingTimeInterval(45),
        ))])
        #expect(reducer.state.movementClock.cycleID == 1)
        #expect(reducer.state.movementClock.presentationCount == 1)
    }

    @Test("Cycle synchronization cancels stale delivery and rejects stale candidates")
    func synchronizeRotatedMergedConstituent() throws {
        for (index, cycles) in [(12, 21), (11, 22)].enumerated() {
            let deliveryID = id(81 + index)
            var reducer = acknowledgedReducer(.merged(
                visualCycleID: 11,
                movementCycleID: 21,
            ), id: deliveryID)
            let original = reducer.state
            let inert = reducer.synchronizeCycles(visualCycleID: 11, movementCycleID: 21)
            #expect(inert == HeadsUpDeliveryOutput())
            #expect(reducer.state == original)
            let output = reducer.synchronizeCycles(
                visualCycleID: UInt64(cycles.0),
                movementCycleID: UInt64(cycles.1),
            )
            #expect(output.effects == [.cancel(deliveryID)])
            #expect(reducer.state.activeDelivery == nil)
            let data = try JSONEncoder().encode(reducer.state)
            #expect(try JSONDecoder().decode(HeadsUpDeliveryState.self, from: data) == reducer.state)
        }
        let staleCandidates: [(HeadsUpOpportunityID, HeadsUpOpportunityID)] = [
            (.visual(cycleID: 1), .visual(cycleID: 2)),
            (.movement(cycleID: 1), .movement(cycleID: 2)),
            (.merged(visualCycleID: 1, movementCycleID: 1), .merged(visualCycleID: 2, movementCycleID: 1)),
            (.merged(visualCycleID: 1, movementCycleID: 1), .merged(visualCycleID: 1, movementCycleID: 2)),
        ]
        for candidate in staleCandidates {
            let cycles = currentCycles(for: candidate.1)
            for target in [0.0, 45.0] {
                var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
                let output = reducer.observe(
                    snapshot(
                        candidate.0,
                        target: target,
                        latest: target,
                        currentVisualCycleID: cycles.visual,
                        currentMovementCycleID: cycles.movement,
                    ),
                    proposedDeliveryID: id(85),
                )
                #expect(output == HeadsUpDeliveryOutput())
            }
        }
    }
}
