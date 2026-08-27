import Foundation
import Testing
@testable import Domain

extension HeadsUpDeliveryTests {
    @Test("An overdue scheduler receives a full bounded heads-up only for allowed snooze returns")
    func overdueSnoozeReturnHonorsCap() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 31)
        let originalID = id(60)
        let returnID = id(61)
        let deadline = start.addingTimeInterval(300)
        var allowed = acknowledgedReducer(opportunity, id: originalID, maximumReoffers: 1)
        _ = allowed.respond(originalID, response: .snooze(until: deadline))

        let returned = allowed.observe(
            snapshot(opportunity, target: -300, observedAt: deadline),
            proposedDeliveryID: returnID,
        )
        let retained = allowed.observe(
            snapshot(
                opportunity,
                target: -310,
                observedAt: deadline.addingTimeInterval(10),
            ),
            proposedDeliveryID: id(62),
        )

        #expect(returned.effects == [.reserve(HeadsUpDeliveryReservation(
            id: returnID,
            opportunity: opportunity,
            countdownMark: .seconds45,
            targetAt: deadline.addingTimeInterval(45),
        ))])
        #expect(retained.effects == [.reserve(HeadsUpDeliveryReservation(
            id: returnID,
            opportunity: opportunity,
            countdownMark: .seconds45,
            targetAt: deadline.addingTimeInterval(45),
        ))])

        assertExhaustedReturnStaysQuiet(
            opportunity: opportunity,
            originalID: originalID,
            returnID: returnID,
            deadline: deadline,
        )
        assertDisabledReturnOpensNormally(
            opportunity: opportunity,
            originalID: originalID,
            returnID: returnID,
            deadline: deadline,
        )
    }

    private func assertExhaustedReturnStaysQuiet(
        opportunity: HeadsUpOpportunityID,
        originalID: HeadsUpDeliveryID,
        returnID: HeadsUpDeliveryID,
        deadline: Date,
    ) {
        var reducer = acknowledgedReducer(opportunity, id: originalID, maximumReoffers: 0)
        _ = reducer.respond(originalID, response: .snooze(until: deadline))
        for offset in [0.0, 5.0] {
            let output = reducer.observe(
                snapshot(
                    opportunity,
                    target: -300 - offset,
                    observedAt: deadline.addingTimeInterval(offset),
                ),
                proposedDeliveryID: returnID,
            )
            #expect(output == HeadsUpDeliveryOutput())
        }
        #expect(reducer.state.activeDelivery == nil)
        #expect(reducer.state.pendingAction == nil)
        #expect(reducer.state.visualClock.snoozeDeadline == deadline)
    }

    private func assertDisabledReturnOpensNormally(
        opportunity: HeadsUpOpportunityID,
        originalID: HeadsUpDeliveryID,
        returnID: HeadsUpDeliveryID,
        deadline: Date,
    ) {
        var reducer = acknowledgedReducer(opportunity, id: originalID, maximumReoffers: 1)
        _ = reducer.respond(originalID, response: .snooze(until: deadline))
        let output = reducer.observe(
            snapshot(
                opportunity,
                target: -300,
                observedAt: deadline,
                headsUpEnabled: false,
                lowFriction: true,
            ),
            proposedDeliveryID: returnID,
        )

        #expect(output.effects == [.openBreak(opportunity)])
        #expect(reducer.state.pendingAction == HeadsUpPendingAction(
            id: returnID,
            kind: .openBreak,
            opportunity: opportunity,
            source: .localTimer,
        ))
        #expect(reducer.state.visualClock.snoozeDeadline == nil)
    }
}
