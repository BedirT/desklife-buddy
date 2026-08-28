import Foundation
import Testing
@testable import Domain

extension HeadsUpDeliveryTests {
    @Test("Presented delivery refreshes exact target timing even when its coarse mark is unchanged")
    func presentedDeliveryRefreshesExactTargetTiming() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 6)
        let deliveryID = id(5)
        var reducer = acknowledgedReducer(opportunity, id: deliveryID)

        let refreshed = reducer.observe(
            snapshot(
                opportunity,
                target: 44,
                observedAt: start.addingTimeInterval(10),
            ),
            proposedDeliveryID: id(6),
        )

        #expect(refreshed.effects == [
            .updateTiming(deliveryID, targetAt: start.addingTimeInterval(54)),
        ])
        #expect(reducer.state.activeDelivery?.countdownMark == .seconds45)
        #expect(reducer.state.activeDelivery?.targetAt == start.addingTimeInterval(54))
    }

    @Test("Countdown transition carries the refreshed exact target timing")
    func countdownTransitionCarriesTargetTiming() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 6)
        let deliveryID = id(6)
        var reducer = acknowledgedReducer(opportunity, id: deliveryID)

        let refreshed = reducer.observe(
            snapshot(
                opportunity,
                target: 30,
                observedAt: start.addingTimeInterval(10),
            ),
            proposedDeliveryID: id(7),
        )

        #expect(refreshed.effects == [
            .updateCountdown(
                deliveryID,
                .seconds30,
                targetAt: start.addingTimeInterval(40),
            ),
        ])
    }

    @Test("Cycle rotation cancels an exact pending App action")
    func cycleRotationCancelsPendingAction() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 3)
        let action = HeadsUpPendingAction(
            id: id(7),
            kind: .openBreak,
            opportunity: opportunity,
            source: .localTimer,
        )
        var reducer = HeadsUpDeliveryReducer(
            state: HeadsUpDeliveryState(
                visualClock: HeadsUpClockLedger(cycleID: 3),
                movementClock: HeadsUpClockLedger(cycleID: 0),
                pendingAction: action,
            ),
            maximumSnoozeReoffers: 0,
        )

        let synchronization = reducer.synchronizeCycles(
            visualCycleID: 4,
            movementCycleID: 0,
        )

        #expect(synchronization.effects == [.cancelPendingAction(action)])
        #expect(reducer.state.pendingAction == nil)
    }

    @Test("Engine derives exact merged timing and ignores recovery for actionable delivery")
    func engineDerivesActionableSnapshot() throws {
        let base = try configuration()
        let configuration = try ProtocolConfiguration(
            visual: base.visual,
            movement: base.movement,
            activityEstimator: base.activityEstimator,
            delivery: base.delivery,
            recovery: RecoveryConfiguration(
                eligibleAfterSeconds: 1,
                requiredMovementDeferrals: 1,
            ),
        )
        let observedAt = Date(timeIntervalSince1970: 20)
        let merged = ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                cycleID: 7,
                accumulatedActiveUseSeconds: 18,
                phase: .headsUpPresented,
            ),
            movementClock: OpportunityClockState(
                cycleID: 9,
                accumulatedActiveUseSeconds: 47,
                phase: .headsUpPresented,
            ),
        ).actionableHeadsUpSnapshot(
            observedAt: observedAt,
            isLowFrictionMoment: false,
            suppressionReason: nil,
        )
        let recoveryMasked = ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                cycleID: 8,
                accumulatedActiveUseSeconds: 18,
                phase: .headsUpPresented,
            ),
            recoveryState: RecoveryState(
                accumulatedEligibleActiveUseSeconds: 1,
                movementDeferralCount: 1,
            ),
        ).actionableHeadsUpSnapshot(
            observedAt: observedAt,
            isLowFrictionMoment: true,
            suppressionReason: nil,
        )

        #expect(merged?.opportunity == .merged(visualCycleID: 7, movementCycleID: 9))
        #expect(merged?.secondsUntilTarget == 2)
        #expect(merged?.secondsUntilLatest == 12)
        #expect(recoveryMasked == nil)
    }

    @Test("Merged snooze returns typed actions for both independent clocks")
    func mergedSnoozeActions() {
        let opportunity = HeadsUpOpportunityID.merged(visualCycleID: 4, movementCycleID: 9)
        let deliveryID = id(22)
        var reducer = acknowledgedReducer(opportunity, id: deliveryID)
        let deadline = start.addingTimeInterval(300)

        let output = reducer.respond(deliveryID, response: .snooze(until: deadline))

        #expect(output.effects == [.snooze(
            deliveryID,
            clocks: [.visual, .movement],
            until: deadline,
        )])
        #expect(reducer.state.visualClock.snoozeDeadline == deadline)
        #expect(reducer.state.movementClock.snoozeDeadline == deadline)
    }

    @Test(arguments: [0, 1, 2])
    func injectedSnoozeCapControlsExactReoffers(maximumReoffers: Int) {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 30)
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: maximumReoffers)
        var deliveries = 0

        for index in 0 ... maximumReoffers + 1 {
            let deliveryID = id(30 + index)
            let observedAt = start.addingTimeInterval(TimeInterval(index * 301))
            let output = reducer.observe(
                snapshot(opportunity, target: 45, observedAt: observedAt),
                proposedDeliveryID: deliveryID,
            )
            guard output.effects.contains(where: { $0.deliveryID == deliveryID }) else { continue }
            deliveries += 1
            _ = reducer.acknowledgePresented(deliveryID, channel: .notification)
            _ = reducer.acknowledgePromptFact(deliveryID)
            _ = reducer.respond(
                deliveryID,
                response: .snooze(until: observedAt.addingTimeInterval(300)),
            )
        }

        #expect(deliveries == 1 + maximumReoffers)
    }

    @Test("A response from an old delivery cannot affect a new cycle")
    func staleResponseIsIdempotent() {
        let oldID = id(40)
        var reducer = acknowledgedReducer(.visual(cycleID: 1), id: oldID)
        _ = reducer.respond(oldID, response: .dismissedWithoutAction)
        let newID = id(41)
        _ = reducer.observe(
            snapshot(.visual(cycleID: 2), target: 45),
            proposedDeliveryID: newID,
        )

        let stale = reducer.respond(oldID, response: .startNow)

        #expect(stale == HeadsUpDeliveryOutput())
        #expect(reducer.state.activeDelivery?.id == newID)
    }

    @Test("Skip response preserves the exact typed opportunity for Escape routing")
    func skipRoutesExactOpportunity() {
        let opportunity = HeadsUpOpportunityID.merged(visualCycleID: 8, movementCycleID: 13)
        let deliveryID = id(72)
        var reducer = acknowledgedReducer(opportunity, id: deliveryID)

        let output = reducer.respond(deliveryID, response: .skip)
        let stale = reducer.respond(deliveryID, response: .skip)

        #expect(output.effects == [.skip(deliveryID, opportunity: opportunity)])
        #expect(stale == HeadsUpDeliveryOutput())
    }

    @Test("More options is fact-free and consumes only the current presented delivery")
    func moreOptionsRoutesCurrentOpportunity() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 9)
        let deliveryID = id(74)
        var reducer = acknowledgedReducer(opportunity, id: deliveryID)

        let output = reducer.respond(deliveryID, response: .moreOptions)
        let stale = reducer.respond(deliveryID, response: .moreOptions)

        #expect(output.effects == [.openMoreOptions(deliveryID, opportunity: opportunity)])
        #expect(output.events.isEmpty)
        #expect(stale == HeadsUpDeliveryOutput())
    }

    @Test("Dismissal is fact-free and normal target timing still opens")
    func dismissalDoesNotClaimAnOutcome() {
        let opportunity = HeadsUpOpportunityID.movement(cycleID: 14)
        let deliveryID = id(42)
        var reducer = acknowledgedReducer(opportunity, id: deliveryID)

        let dismissal = reducer.respond(deliveryID, response: .dismissedWithoutAction)
        let target = reducer.observe(
            snapshot(opportunity, target: 0, latest: 60, lowFriction: true),
            proposedDeliveryID: id(43),
        )

        #expect(dismissal == HeadsUpDeliveryOutput())
        #expect(target.effects == [.openBreak(opportunity)])
        #expect(target.events.isEmpty)
    }

    @Test("Prompt fact acknowledgement does not redeliver")
    func promptFactAcknowledgementIsIdempotent() {
        let deliveryID = id(44)
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
        _ = reducer.observe(
            snapshot(.visual(cycleID: 50), target: 45),
            proposedDeliveryID: deliveryID,
        )
        _ = reducer.acknowledgePresented(deliveryID, channel: .notification)

        #expect(reducer.state.activeDelivery?.promptFactStatus == .pending)
        let first = reducer.acknowledgePromptFact(deliveryID)
        let second = reducer.acknowledgePromptFact(deliveryID)
        #expect(first)
        #expect(!second)
        #expect(reducer.state.activeDelivery?.promptFactStatus == .acknowledged)
        #expect(reducer.observe(
            snapshot(.visual(cycleID: 50), target: 45),
            proposedDeliveryID: id(45),
        ).effects.isEmpty)
    }

    @Test("Failed prompt-fact transaction retries acknowledgement with the reserved identity")
    func failedPromptFactTransactionRetriesWithoutRedelivery() {
        let deliveryID = id(73)
        var reserved = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
        _ = reserved.observe(
            snapshot(.visual(cycleID: 51), target: 45),
            proposedDeliveryID: deliveryID,
        )
        let persistedReservation = reserved.state

        var failedAttempt = HeadsUpDeliveryReducer(
            state: persistedReservation,
            maximumSnoozeReoffers: 0,
        )
        _ = failedAttempt.acknowledgePresented(deliveryID, channel: .notification)

        var retry = HeadsUpDeliveryReducer(
            state: persistedReservation,
            maximumSnoozeReoffers: 0,
        )
        let output = retry.acknowledgePresented(deliveryID, channel: .notification)

        #expect(output.events.map(\.kind) == [.promptPresented])
        #expect(output.effects.isEmpty)
        #expect(retry.state.activeDelivery?.id == deliveryID)
        #expect(retry.state.visualClock.presentationCount == 1)
    }

    @Test("Actions wait for prompt-fact acknowledgement then route exactly once")
    func responsesRequireAcknowledgedPromptFact() {
        let opportunity = HeadsUpOpportunityID.visual(cycleID: 52)
        let deadline = start.addingTimeInterval(300)
        let cases: [(HeadsUpDeliveryResponse, HeadsUpDeliveryEffect)] = [
            (.startNow, .openBreak(opportunity)),
            (.snooze(until: deadline), .snooze(id(80), clocks: [.visual], until: deadline)),
            (.skip, .skip(id(80), opportunity: opportunity)),
            (.moreOptions, .openMoreOptions(id(80), opportunity: opportunity)),
        ]

        for (response, expectedEffect) in cases {
            let deliveryID = id(80)
            var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 0)
            _ = reducer.observe(
                snapshot(opportunity, target: 45),
                proposedDeliveryID: deliveryID,
            )
            _ = reducer.acknowledgePresented(deliveryID, channel: .notification)

            let pending = reducer.respond(deliveryID, response: response)
            #expect(pending == HeadsUpDeliveryOutput())
            #expect(reducer.state.activeDelivery?.id == deliveryID)

            let factAcknowledged = reducer.acknowledgePromptFact(deliveryID)
            #expect(factAcknowledged)
            let acknowledged = reducer.respond(deliveryID, response: response)
            let repeated = reducer.respond(deliveryID, response: response)

            #expect(acknowledged.effects == [expectedEffect])
            #expect(repeated == HeadsUpDeliveryOutput())
        }
    }

    @Test("Recovery cannot form an actionable heads-up identity")
    func recoveryIsExcludedByConstruction() {
        #expect(HeadsUpOpportunityID(
            presentation: .visual,
            visualCycleID: 1,
            movementCycleID: 2,
        ) == .visual(cycleID: 1))
        #expect(HeadsUpOpportunityID(
            presentation: .merged,
            visualCycleID: 1,
            movementCycleID: 2,
        ) == .merged(visualCycleID: 1, movementCycleID: 2))
        #expect(HeadsUpOpportunityID(
            presentation: .recovery,
            visualCycleID: 1,
            movementCycleID: 2,
        ) == nil)
    }

    @Test("Clock generations advance only when a new cycle begins")
    func cycleGenerationsAdvanceOnReset() throws {
        let configuration = try configuration()
        var engine = ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                cycleID: 5,
                accumulatedActiveUseSeconds: 20,
                phase: .readyToPresent,
            ),
            movementClock: OpportunityClockState(
                cycleID: 9,
                accumulatedActiveUseSeconds: 50,
                phase: .readyToPresent,
            ),
        )

        _ = engine.record(.timerFinished, opportunity: .movement, source: .localTimer)
        #expect(engine.movementClock.cycleID == 9)
        _ = engine.record(.timerFinished, opportunity: .visual, source: .localTimer)
        #expect(engine.visualClock.cycleID == 6)
        #expect(engine.movementClock.cycleID == 9)
        _ = engine.selectMovement(durationSeconds: 12)
        #expect(engine.movementClock.cycleID == 10)
    }

    @Test("Delivery ledger and active reservation survive ProtocolState restoration")
    func reducerStatePersistsWithProtocolState() throws {
        let deliveryID = id(46)
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 1)
        _ = reducer.observe(
            snapshot(.visual(cycleID: 4), target: 45),
            proposedDeliveryID: deliveryID,
        )
        let state = ProtocolState(headsUpDeliveryState: reducer.state)
        var engine = try ProtocolEngine(configuration: configuration(), state: state)

        #expect(engine.state.headsUpDeliveryState.activeDelivery?.id == deliveryID)
        engine.synchronizeHeadsUpDeliveryState(HeadsUpDeliveryState())
        #expect(engine.state.headsUpDeliveryState == HeadsUpDeliveryState())
    }
}
