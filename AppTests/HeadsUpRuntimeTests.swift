import BreakFlow
import Domain
import Foundation
import Testing
@testable import App

@Suite("Heads-Up protocol runtime")
struct HeadsUpRuntimeTests {
    @Test("Scheduler observation and Heads-Up reservation persist as one candidate")
    func schedulerObservationReservesAtomically() async throws {
        let retained = ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1455),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 3555),
        )
        let trace = RuntimeTrace()
        let store = HeadsUpRuntimeStore(
            state: retained,
            onCommit: { trace.values.append("commit") },
        )
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = {
            trace.values.append("effect")
            effects.append($0)
        }
        try await runtime.restore()
        store.commits.removeAll()
        trace.values.removeAll()

        try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))

        #expect(store.commits.count == 1)
        #expect(trace.values == ["commit", "effect"])
        #expect(store.commits[0].state.visualClock.accumulatedActiveUseSeconds == 1455)
        #expect(store.commits[0].state.movementClock.accumulatedActiveUseSeconds == 3555)
        #expect(
            store.commits[0].state.headsUpDeliveryState.activeDelivery?.opportunity
                == .merged(visualCycleID: 0, movementCycleID: 0),
        )
        #expect(effects == [.reserve(HeadsUpDeliveryReservation(
            id: deliveryID(1),
            opportunity: .merged(visualCycleID: 0, movementCycleID: 0),
            countdownMark: .seconds45,
            targetAt: Date(timeIntervalSince1970: 145),
        ))])
    }

    @Test("A failed combined scheduler reservation publishes and emits nothing")
    func failedCombinedSchedulerReservationIsInvisible() async throws {
        let retained = ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1455),
        )
        let store = HeadsUpRuntimeStore(state: retained)
        let runtime = try makeRuntime(store: store)
        var changes = 0
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onChange = { _, _ in changes += 1 }
        runtime.onHeadsUpEffect = { effects.append($0) }
        try await runtime.restore()
        let publishedBeforeFailure = runtime.state
        store.failuresRemaining = 1
        changes = 0

        await #expect(throws: HeadsUpRuntimeStore.Failure.self) {
            try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        }

        #expect(runtime.state == publishedBeforeFailure)
        #expect(changes == 0)
        #expect(effects.isEmpty)
    }

    @Test("Scheduler suppression persists its clock state and delivery cancellation atomically")
    func schedulerSuppressionCancelsAtomically() async throws {
        let retained = ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1455),
        )
        let trace = RuntimeTrace()
        let store = HeadsUpRuntimeStore(
            state: retained,
            onCommit: { trace.values.append("commit") },
        )
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = {
            trace.values.append("effect")
            effects.append($0)
        }
        try await runtime.restore()
        try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        store.commits.removeAll()
        trace.values.removeAll()
        effects.removeAll()

        try await runtime.observe(
            .active(uptimeSeconds: 1, secondsSinceInput: 0),
            activeSuppressions: [.manualPause],
        )

        #expect(store.commits.count == 1)
        #expect(trace.values == ["commit", "effect"])
        #expect(store.commits[0].state.visualClock.phase == .suppressed(.manualPause))
        #expect(store.commits[0].state.headsUpDeliveryState.activeDelivery == nil)
        #expect(effects == [.cancel(deliveryID(1))])
    }

    @Test("Recovery masks a new reservation but cannot replace an active actionable delivery")
    func recoveryAndActiveDeliveryNeverDoublePrompt() async throws {
        let debt = RecoveryState(
            accumulatedEligibleActiveUseSeconds: 5400,
            movementDeferralCount: 2,
        )
        let maskedStore = HeadsUpRuntimeStore(state: ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1455),
            recoveryState: debt,
        ))
        let masked = try makeRuntime(store: maskedStore)
        var maskedEffects: [HeadsUpRuntimeEffect] = []
        masked.onHeadsUpEffect = { maskedEffects.append($0) }
        try await masked.restore()
        maskedEffects.removeAll()

        try await masked.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))

        #expect(masked.statusContext.liveHeadsUp == .recovery)
        #expect(masked.state.headsUpDeliveryState.activeDelivery == nil)
        #expect(maskedEffects.isEmpty)

        let active = HeadsUpActiveDelivery(
            id: deliveryID(8),
            opportunity: .visual(cycleID: 0),
            countdownMark: .seconds45,
            targetAt: Date(timeIntervalSince1970: 145),
        )
        let activeStore = HeadsUpRuntimeStore(state: ProtocolState(
            visualClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 1455,
                phase: .headsUpPresented,
            ),
            recoveryState: debt,
            headsUpDeliveryState: HeadsUpDeliveryState(
                visualClock: HeadsUpClockLedger(cycleID: 0),
                movementClock: HeadsUpClockLedger(cycleID: 0),
                activeDelivery: active,
            ),
        ))
        let retained = try makeRuntime(store: activeStore)
        var retainedEffects: [HeadsUpRuntimeEffect] = []
        retained.onHeadsUpEffect = { retainedEffects.append($0) }

        try await retained.restore()
        #expect(retained.statusContext.liveHeadsUp == .visual)
        retainedEffects.removeAll()
        try await retained.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))

        #expect(retained.statusContext.liveHeadsUp == .visual)
        #expect(retained.state.headsUpDeliveryState.activeDelivery?.id == deliveryID(8))
        #expect(retainedEffects == [.reserve(HeadsUpDeliveryReservation(
            id: deliveryID(8),
            opportunity: .visual(cycleID: 0),
            countdownMark: .seconds45,
            targetAt: Date(timeIntervalSince1970: 145),
        ))])
    }

    @Test("Ordinary observation remains scheduler-functional without a Heads-Up policy")
    func nilPolicyOrdinaryObservationIsHeadsUpInert() async throws {
        let store = HeadsUpRuntimeStore(state: ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1500),
        ))
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 100) },
            makeID: { deliveryID(1).rawValue },
        )
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = { effects.append($0) }
        try await runtime.restore()
        store.commits.removeAll()

        try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))

        #expect(store.commits.count == 1)
        #expect(runtime.statusContext.liveHeadsUp == .visual)
        #expect(runtime.state.headsUpDeliveryState == HeadsUpDeliveryState())
        #expect(effects.isEmpty)
    }

    @Test("Nil-policy restore ignores stranded persisted delivery rows and effects")
    func nilPolicyRestoreIgnoresPersistedDelivery() async throws {
        let active = HeadsUpActiveDelivery(
            id: deliveryID(9),
            opportunity: .movement(cycleID: 0),
            countdownMark: .seconds30,
        )
        let store = HeadsUpRuntimeStore(state: ProtocolState(
            headsUpDeliveryState: HeadsUpDeliveryState(
                activeDelivery: active,
            ),
        ))
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
        )
        var effects: [HeadsUpRuntimeEffect] = []
        var restored: [HeadsUpActiveDelivery] = []
        runtime.onHeadsUpEffect = { effects.append($0) }
        runtime.onHeadsUpRestoredDelivery = { restored.append($0) }

        try await runtime.restore()

        #expect(runtime.statusContext.liveHeadsUp == nil)
        #expect(effects.isEmpty)
        #expect(restored.isEmpty)
    }

    @Test("A reservation is persisted before it can escape to an adapter")
    func reservationPersistsBeforeEffect() async throws {
        let trace = RuntimeTrace()
        let store = HeadsUpRuntimeStore(onCommit: { trace.values.append("commit") })
        let runtime = try makeRuntime(store: store)
        runtime.onHeadsUpEffect = { _ in trace.values.append("effect") }
        try await runtime.restore()
        trace.values.removeAll()

        try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 45))

        let active = runtime.state.headsUpDeliveryState.activeDelivery
        #expect(trace.values == ["commit", "effect"])
        #expect(store.commits.last?.state.headsUpDeliveryState.activeDelivery == active)
        #expect(active?.id == deliveryID(1))
    }

    @Test("Presented timing updates carry the exact retargeted instant")
    func presentationTimingUpdatesAreExact() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = { effects.append($0) }
        try await runtime.restore()
        try await presentAndAcknowledge(runtime, opportunity: .visual(cycleID: 0))
        effects.removeAll()

        try await runtime.observeHeadsUp(HeadsUpDeliverySnapshot(
            opportunity: .visual(cycleID: 0),
            currentVisualCycleID: 0,
            currentMovementCycleID: 0,
            observedAt: Date(timeIntervalSince1970: 110),
            secondsUntilTarget: 44,
            secondsUntilLatest: 104,
            headsUpEnabled: true,
            headsUpLeadSeconds: 45,
            waitsForLowFrictionMoment: false,
            isLowFrictionMoment: true,
        ))
        #expect(effects == [
            .updateTiming(deliveryID(1), targetAt: Date(timeIntervalSince1970: 154)),
        ])
        effects.removeAll()

        try await runtime.observeHeadsUp(HeadsUpDeliverySnapshot(
            opportunity: .visual(cycleID: 0),
            currentVisualCycleID: 0,
            currentMovementCycleID: 0,
            observedAt: Date(timeIntervalSince1970: 111),
            secondsUntilTarget: 30,
            secondsUntilLatest: 90,
            headsUpEnabled: true,
            headsUpLeadSeconds: 45,
            waitsForLowFrictionMoment: false,
            isLowFrictionMoment: true,
        ))
        #expect(effects == [.updateCountdown(
            deliveryID(1),
            .seconds30,
            targetAt: Date(timeIntervalSince1970: 141),
        )])
    }

    @Test("A failed reservation publishes no state or adapter effect")
    func failedReservationIsInvisible() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = { effects.append($0) }
        try await runtime.restore()
        store.failuresRemaining = 1

        await #expect(throws: HeadsUpRuntimeStore.Failure.self) {
            try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 45))
        }

        #expect(runtime.state.headsUpDeliveryState.activeDelivery == nil)
        #expect(effects.isEmpty)
    }

    @Test("Presentation persists prompt fact pending then state-only acknowledged")
    func presentationAcknowledgementOrder() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var ready: [HeadsUpDeliveryID] = []
        runtime.onHeadsUpPromptFactReady = { ready.append($0) }
        try await runtime.restore()
        try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 45))
        store.commits.removeAll()

        try await runtime.acknowledgeHeadsUpPresented(deliveryID(1), channel: .notification)

        #expect(store.commits.count == 2)
        #expect(store.commits[0].events.map(\.kind) == [.promptPresented])
        #expect(store.commits[0].events.map(\.opportunity) == [.visual])
        #expect(
            store.commits[0].state.headsUpDeliveryState.activeDelivery?.promptFactStatus == .pending,
        )
        #expect(store.commits[1].events.isEmpty)
        #expect(
            store.commits[1].state.headsUpDeliveryState.activeDelivery?.promptFactStatus
                == .acknowledged,
        )
        #expect(ready == [deliveryID(1)])
    }

    @Test("A failed fact acknowledgement repairs without duplicating promptPresented")
    func promptFactAcknowledgementRepairs() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var ready: [HeadsUpDeliveryID] = []
        runtime.onHeadsUpPromptFactReady = { ready.append($0) }
        try await runtime.restore()
        try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 45))
        store.commits.removeAll()
        store.failOnAttempt = store.commitAttempts + 2

        await #expect(throws: HeadsUpRuntimeStore.Failure.self) {
            try await runtime.acknowledgeHeadsUpPresented(deliveryID(1), channel: .capsule)
        }
        #expect(store.commits.count == 1)
        #expect(store.commits[0].events.map(\.kind) == [.promptPresented])
        #expect(runtime.state.headsUpDeliveryState.activeDelivery?.phase == .reserved)
        #expect(ready.isEmpty)

        try await runtime.acknowledgeHeadsUpPresented(deliveryID(1), channel: .capsule)

        #expect(store.commits.flatMap(\.events).map(\.kind) == [.promptPresented])
        #expect(runtime.state.headsUpDeliveryState.activeDelivery?.promptFactStatus == .acknowledged)
        #expect(ready == [deliveryID(1)])
    }

    @Test("Restore reconciles reserved pending and acknowledged identities without replacement")
    func restoreExactIdentities() async throws {
        let cases: [(HeadsUpPromptFactStatus?, Int, Bool)] = [
            (nil, 0, false),
            (.pending, 1, true),
            (.acknowledged, 0, true),
        ]
        for (factStatus, expectedCommits, expectsReady) in cases {
            let active = HeadsUpActiveDelivery(
                id: deliveryID(8),
                opportunity: .movement(cycleID: 4),
                phase: factStatus == nil ? .reserved : .presented,
                channel: factStatus == nil ? nil : .notification,
                promptFactStatus: factStatus,
                countdownMark: .seconds30,
            )
            let retained = ProtocolState(
                movementClock: OpportunityClockState(cycleID: 4),
                headsUpDeliveryState: HeadsUpDeliveryState(
                    visualClock: HeadsUpClockLedger(cycleID: 0),
                    movementClock: HeadsUpClockLedger(cycleID: 4, presentationCount: 1),
                    activeDelivery: active,
                ),
            )
            let store = HeadsUpRuntimeStore(state: retained)
            let runtime = try makeRuntime(store: store)
            var effects: [HeadsUpRuntimeEffect] = []
            var restored: [HeadsUpActiveDelivery] = []
            var ready: [HeadsUpDeliveryID] = []
            runtime.onHeadsUpEffect = { effects.append($0) }
            runtime.onHeadsUpRestoredDelivery = { restored.append($0) }
            runtime.onHeadsUpPromptFactReady = { ready.append($0) }

            try await runtime.restore()

            #expect(store.commits.count == expectedCommits)
            #expect(runtime.state.headsUpDeliveryState.activeDelivery?.id == deliveryID(8))
            if factStatus == nil {
                #expect(effects == [.reserve(HeadsUpDeliveryReservation(
                    id: deliveryID(8),
                    opportunity: .movement(cycleID: 4),
                    countdownMark: .seconds30,
                ))])
                #expect(restored.isEmpty)
                #expect(ready.isEmpty)
            } else {
                #expect(effects.isEmpty)
                #expect(restored.map(\.id) == [deliveryID(8)])
                #expect(ready == (expectsReady ? [deliveryID(8)] : []))
                #expect(
                    runtime.state.headsUpDeliveryState.activeDelivery?.promptFactStatus
                        == .acknowledged,
                )
            }
        }
    }

    @Test("A stale delivery identity is inert")
    func staleIdentityIsInert() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = { effects.append($0) }
        try await runtime.restore()
        try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 45))
        store.commits.removeAll()
        effects.removeAll()

        try await runtime.acknowledgeHeadsUpPresented(deliveryID(99), channel: .capsule)
        try await runtime.respondToHeadsUp(deliveryID(99), response: .skip)

        #expect(store.commits.isEmpty)
        #expect(effects.isEmpty)
        #expect(runtime.state.headsUpDeliveryState.activeDelivery?.id == deliveryID(1))
    }

    @Test("Explicit Start is user-sourced and automatic target opening is timer-sourced")
    func openingSources() async throws {
        let explicitStore = HeadsUpRuntimeStore()
        let explicit = try makeRuntime(store: explicitStore)
        var explicitEffects: [HeadsUpRuntimeEffect] = []
        explicit.onHeadsUpEffect = { explicitEffects.append($0) }
        try await explicit.restore()
        try await presentAndAcknowledge(explicit, opportunity: .visual(cycleID: 0))
        explicitStore.commits.removeAll()
        explicitEffects.removeAll()

        try await explicit.respondToHeadsUp(deliveryID(1), response: .startNow)

        #expect(explicitStore.commits.last?.events.isEmpty == true)
        #expect(explicitEffects == [
            .cancel(deliveryID(1)),
            .openBreak(
                deliveryID(1),
                opportunity: .visual(cycleID: 0),
                source: .user,
            ),
        ])
        #expect(explicit.lifecycleSession == nil)

        _ = try await explicit.completeHeadsUpPendingAction(
            deliveryID(1),
            kind: .openBreak,
            opportunity: .visual(cycleID: 0),
        )

        #expect(explicitStore.commits.last?.events.map(\.kind) == [.breakStarted])
        #expect(explicitStore.commits.last?.events.map(\.source) == [.user])

        let automaticStore = HeadsUpRuntimeStore()
        let automatic = try makeRuntime(store: automaticStore)
        var automaticEffects: [HeadsUpRuntimeEffect] = []
        automatic.onHeadsUpEffect = { automaticEffects.append($0) }
        try await automatic.restore()
        automaticStore.commits.removeAll()
        automaticEffects.removeAll()
        try await automatic.observeHeadsUp(snapshot(.movement(cycleID: 0), target: 0))

        #expect(automaticStore.commits.last?.events.isEmpty == true)
        #expect(automaticEffects == [
            .openBreak(
                deliveryID(1),
                opportunity: .movement(cycleID: 0),
                source: .localTimer,
            ),
        ])
        #expect(automatic.lifecycleSession == nil)

        _ = try await automatic.completeHeadsUpPendingAction(
            deliveryID(1),
            kind: .openBreak,
            opportunity: .movement(cycleID: 0),
        )

        #expect(automaticStore.commits.last?.events.map(\.kind) == [.breakStarted])
        #expect(automaticStore.commits.last?.events.map(\.source) == [.localTimer])
        #expect(automatic.lifecycleSession == .movement(selectedDuration: nil))
    }

    @Test("Break opening completion atomically records the fact and clears the exact outbox action")
    func breakOpeningCompletionIsAtomicAndRetryable() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await presentAndAcknowledge(runtime, opportunity: .movement(cycleID: 0))
        try await runtime.respondToHeadsUp(deliveryID(1), response: .startNow)
        let action = try #require(runtime.state.headsUpDeliveryState.pendingAction)
        store.commits.removeAll()
        store.failuresRemaining = 1

        await #expect(throws: HeadsUpRuntimeStore.Failure.self) {
            try await runtime.completeHeadsUpPendingAction(
                action.id,
                kind: .openBreak,
                opportunity: action.opportunity,
            )
        }

        #expect(runtime.state.headsUpDeliveryState.pendingAction == action)
        #expect(runtime.lifecycleSession == nil)
        #expect(store.commits.isEmpty)

        let stale = try await runtime.completeHeadsUpPendingAction(
            deliveryID(99),
            kind: .openBreak,
            opportunity: action.opportunity,
        )
        let completed = try await runtime.completeHeadsUpPendingAction(
            action.id,
            kind: .openBreak,
            opportunity: action.opportunity,
        )

        #expect(stale == nil)
        #expect(completed == action)
        #expect(store.commits.count == 1)
        #expect(store.commits[0].events.map(\.kind) == [.breakStarted])
        #expect(store.commits[0].events.map(\.source) == [.user])
        #expect(store.commits[0].state.headsUpDeliveryState.pendingAction == nil)
        #expect(runtime.lifecycleSession == .movement(selectedDuration: nil))
    }

    @Test("Relaunch after opening repairs every interrupted break without duplicating facts")
    func relaunchAfterOpeningRepairsInterruptedBreaks() async throws {
        let cases: [(HeadsUpOpportunityID, OpportunityType)] = [
            (.visual(cycleID: 0), .visual),
            (.movement(cycleID: 0), .movement),
            (.merged(visualCycleID: 0, movementCycleID: 0), .visual),
        ]

        for (opportunity, runningOpportunity) in cases {
            let store = HeadsUpRuntimeStore()
            let original = try makeRuntime(store: store)
            try await original.restore()
            try await original.observeHeadsUp(snapshot(opportunity, target: 0))
            _ = try await original.completeHeadsUpPendingAction(
                deliveryID(1),
                kind: .openBreak,
                opportunity: opportunity,
            )
            let commitsBeforeRelaunch = store.commits.count

            let restored = try makeRuntime(store: store)
            try await restored.restore()

            #expect(restored.state.headsUpDeliveryState.pendingAction == nil)
            #expect(restored.lifecycleSession == nil)
            #expect(restored.state.visualClock.phase != .running)
            #expect(restored.state.movementClock.phase != .running)
            #expect(store.commits.count == commitsBeforeRelaunch + 1)
            #expect(store.commits.last?.events.isEmpty == true)
            let openingFacts = store.commits
                .flatMap(\.events)
                .filter { $0.kind == .breakStarted && $0.opportunity == runningOpportunity }
            #expect(openingFacts.count == 1)
        }
    }

    @Test("Restore re-emits the exact pending action and More Options clears only on exact completion")
    func pendingActionRestoresAndCompletesExactly() async throws {
        let store = HeadsUpRuntimeStore()
        let original = try makeRuntime(store: store)
        try await original.restore()
        try await presentAndAcknowledge(original, opportunity: .visual(cycleID: 0))
        try await original.respondToHeadsUp(deliveryID(1), response: .moreOptions)
        let action = try #require(store.state?.headsUpDeliveryState.pendingAction)

        let restored = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        restored.onHeadsUpEffect = { effects.append($0) }
        try await restored.restore()
        let commitsAfterRestore = store.commits.count

        #expect(effects == [
            .openMoreOptions(action.id, opportunity: action.opportunity),
        ])
        #expect(store.commits.count == commitsAfterRestore)

        let wrongKind = try await restored.completeHeadsUpPendingAction(
            action.id,
            kind: .openBreak,
            opportunity: action.opportunity,
        )
        #expect(wrongKind == nil)
        #expect(restored.state.headsUpDeliveryState.pendingAction == action)

        let wrongOpportunity = try await restored.completeHeadsUpPendingAction(
            action.id,
            kind: .openMoreOptions,
            opportunity: .movement(cycleID: 0),
        )
        #expect(wrongOpportunity == nil)
        #expect(restored.state.headsUpDeliveryState.pendingAction == action)

        let completed = try await restored.completeHeadsUpPendingAction(
            action.id,
            kind: .openMoreOptions,
            opportunity: action.opportunity,
        )
        #expect(completed == action)
        #expect(store.commits.last?.events.isEmpty == true)
        #expect(store.commits.last?.state.headsUpDeliveryState.pendingAction == nil)
    }

    @Test("More Options snooze atomically returns one overdue opportunity through Heads-Up")
    func moreOptionsSnoozeReturnsThroughHeadsUp() async throws {
        var currentDate = Date(timeIntervalSince1970: 100)
        let store = HeadsUpRuntimeStore(state: ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1500),
        ))
        let original = try makeRuntime(store: store, now: { currentDate })
        try await original.restore()
        try await presentAndAcknowledge(original, opportunity: .visual(cycleID: 0))
        try await original.respondToHeadsUp(deliveryID(1), response: .moreOptions)
        _ = try await original.completeHeadsUpPendingAction(
            deliveryID(1),
            kind: .openMoreOptions,
            opportunity: .visual(cycleID: 0),
        )
        store.commits.removeAll()

        try await original.handleBreakFlow(.snooze(
            scope: .visual,
            durationSeconds: 300,
        ))

        let snoozed = try #require(store.commits.first)
        let deadline = Date(timeIntervalSince1970: 400)
        #expect(store.commits.count == 1)
        #expect(snoozed.events.map(\.kind) == [.snoozed])
        #expect(snoozed.state.visualSnoozeDeadline == deadline)
        #expect(snoozed.state.headsUpDeliveryState.visualClock.snoozeDeadline == deadline)

        currentDate = deadline
        let restored = try makeRuntime(store: store, now: { currentDate })
        var effects: [HeadsUpRuntimeEffect] = []
        restored.onHeadsUpEffect = { effects.append($0) }
        try await restored.restore()
        effects.removeAll()

        try await restored.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        currentDate = deadline.addingTimeInterval(5)
        try await restored.observe(.active(uptimeSeconds: 5, secondsSinceInput: 0))

        #expect(effects == [
            .reserve(HeadsUpDeliveryReservation(
                id: deliveryID(1),
                opportunity: .visual(cycleID: 0),
                countdownMark: .seconds45,
                targetAt: deadline.addingTimeInterval(45),
            )),
            .reserve(HeadsUpDeliveryReservation(
                id: deliveryID(1),
                opportunity: .visual(cycleID: 0),
                countdownMark: .seconds45,
                targetAt: deadline.addingTimeInterval(45),
            )),
        ])
        #expect(restored.state.headsUpDeliveryState.pendingAction == nil)
    }

    @Test("Automatic opening retires an adapter-live delivery before opening the break")
    func automaticOpeningRetractsLiveDelivery() async throws {
        let trace = RuntimeTrace()
        let store = HeadsUpRuntimeStore(onCommit: { trace.values.append("commit") })
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = {
            trace.values.append("effect")
            effects.append($0)
        }
        try await runtime.restore()
        try await presentAndAcknowledge(runtime, opportunity: .visual(cycleID: 0))
        trace.values.removeAll()
        effects.removeAll()

        try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 0))

        #expect(trace.values == ["commit", "effect", "effect"])
        #expect(effects == [
            .cancel(deliveryID(1)),
            .openBreak(
                deliveryID(1),
                opportunity: .visual(cycleID: 0),
                source: .localTimer,
            ),
        ])
        #expect(runtime.state.headsUpDeliveryState.activeDelivery == nil)
    }

    @Test("Merged snooze persists exactly two same-deadline facts atomically")
    func mergedSnoozeIsAtomic() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        let deadline = Date(timeIntervalSince1970: 400)
        try await runtime.restore()
        try await presentAndAcknowledge(
            runtime,
            opportunity: .merged(visualCycleID: 0, movementCycleID: 0),
        )
        store.commits.removeAll()

        try await runtime.respondToHeadsUp(deliveryID(1), response: .snooze(until: deadline))

        #expect(store.commits.count == 1)
        #expect(store.commits[0].events.map(\.kind) == [.snoozed, .snoozed])
        #expect(store.commits[0].events.map(\.opportunity) == [.visual, .movement])
        #expect(store.commits[0].events.map(\.selectedDurationSeconds) == [300, 300])
        #expect(store.commits[0].state.visualSnoozeDeadline == deadline)
        #expect(store.commits[0].state.movementSnoozeDeadline == deadline)
    }

    @Test("Snooze uses one action instant and retains the exact requested deadline")
    func advancingClockSnoozeRetainsExactDeadline() async throws {
        for opportunity in [
            HeadsUpOpportunityID.visual(cycleID: 0),
            .merged(visualCycleID: 0, movementCycleID: 0),
        ] {
            let clock = AdvancingRuntimeClock(
                date: Date(timeIntervalSince1970: 100),
                increment: 0.01,
            )
            let store = HeadsUpRuntimeStore()
            let runtime = try makeRuntime(store: store, now: clock.now)
            try await runtime.restore()
            try await presentAndAcknowledge(runtime, opportunity: opportunity)
            store.commits.removeAll()
            let deadline = clock.date.addingTimeInterval(300)

            try await runtime.respondToHeadsUp(
                deliveryID(1),
                response: .snooze(until: deadline),
            )

            #expect(store.commits.count == 1)
            #expect(store.commits[0].events.map(\.selectedDurationSeconds) ==
                Array(repeating: 300, count: opportunity == .visual(cycleID: 0) ? 1 : 2))
            #expect(store.commits[0].state.visualSnoozeDeadline == deadline)
            #expect(
                store.commits[0].state.headsUpDeliveryState.visualClock.snoozeDeadline == deadline,
            )
            if opportunity == .merged(visualCycleID: 0, movementCycleID: 0) {
                #expect(store.commits[0].state.movementSnoozeDeadline == deadline)
                #expect(
                    store.commits[0].state.headsUpDeliveryState.movementClock.snoozeDeadline
                        == deadline,
                )
            }
        }
    }

    @Test("An arbitrary far deadline cannot be coerced into a configured snooze fact")
    func arbitrarySnoozeDeadlineIsRejected() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = { effects.append($0) }
        try await runtime.restore()
        try await presentAndAcknowledge(runtime, opportunity: .visual(cycleID: 0))
        store.commits.removeAll()
        effects.removeAll()
        let retained = runtime.state

        await #expect(throws: ProtocolLifecycleError.invalidSnoozeDuration) {
            try await runtime.respondToHeadsUp(
                deliveryID(1),
                response: .snooze(until: Date(timeIntervalSince1970: 3700)),
            )
        }

        #expect(store.commits.isEmpty)
        #expect(runtime.state == retained)
        #expect(effects.isEmpty)
    }

    @Test("Standalone skip rotates its cycle while merged skip applies the canonical fresh effect")
    func skipSemantics() async throws {
        let dueVisual = ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1500),
        )
        let standaloneStore = HeadsUpRuntimeStore(state: dueVisual)
        let standalone = try makeRuntime(store: standaloneStore)
        try await standalone.restore()
        try await presentAndAcknowledge(standalone, opportunity: .visual(cycleID: 0))
        try await standalone.respondToHeadsUp(deliveryID(1), response: .skip)
        #expect(standalone.state.visualClock.cycleID == 1)
        #expect(standalone.state.visualClock.accumulatedActiveUseSeconds == 0)

        // Contract-backed migration (Story 2.6): D-043
        // `timing_runtime_v2.yaml` action_contract `merged.escape_during_visual`
        // rows clocks {visual: fresh_cycle, movement: fresh_cycle, recovery:
        // deferral_increment} with facts [skipped]. The pre-2.6 retaining pin
        // (both due clocks untouched) covered the legacy `skipMergedSegment`
        // route production no longer uses for this segment.
        let dueMerged = ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1500),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 3600),
        )
        let mergedStore = HeadsUpRuntimeStore(state: dueMerged)
        let merged = try makeRuntime(store: mergedStore)
        try await merged.restore()
        try await presentAndAcknowledge(
            merged,
            opportunity: .merged(visualCycleID: 0, movementCycleID: 0),
        )
        try await merged.respondToHeadsUp(deliveryID(1), response: .skip)
        #expect(merged.state.visualClock == OpportunityClockState(cycleID: 1))
        #expect(merged.state.movementClock == OpportunityClockState(cycleID: 1))
        #expect(merged.state.recoveryState.movementDeferralCount == 1)
    }

    @Test("More Options and dismissal clear delivery without declaring a user fact")
    func factFreeSettlingResponses() async throws {
        for response in [HeadsUpDeliveryResponse.moreOptions, .dismissedWithoutAction] {
            let store = HeadsUpRuntimeStore()
            let runtime = try makeRuntime(store: store)
            var settled: [(HeadsUpDeliveryID, HeadsUpDeliveryResponse)] = []
            runtime.onHeadsUpSettled = { settled.append(($0, $1)) }
            try await runtime.restore()
            try await presentAndAcknowledge(runtime, opportunity: .visual(cycleID: 0))
            store.commits.removeAll()

            try await runtime.respondToHeadsUp(deliveryID(1), response: response)

            #expect(store.commits.count == 1)
            #expect(store.commits[0].events.isEmpty)
            #expect(store.commits[0].state.headsUpDeliveryState.activeDelivery == nil)
            #expect(settled.count == 1)
            #expect(settled.first?.0 == deliveryID(1))
            #expect(settled.first?.1 == response)
        }
    }

    @Test("A failed response publishes no state effect or settlement")
    func failedResponseRemainsRetryable() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        var settled: [HeadsUpDeliveryID] = []
        runtime.onHeadsUpEffect = { effects.append($0) }
        runtime.onHeadsUpSettled = { id, _ in settled.append(id) }
        try await runtime.restore()
        try await presentAndAcknowledge(runtime, opportunity: .visual(cycleID: 0))
        effects.removeAll()
        store.failuresRemaining = 1
        let published = runtime.state

        await #expect(throws: HeadsUpRuntimeStore.Failure.self) {
            try await runtime.respondToHeadsUp(deliveryID(1), response: .moreOptions)
        }

        #expect(runtime.state == published)
        #expect(runtime.state.headsUpDeliveryState.activeDelivery?.id == deliveryID(1))
        #expect(effects.isEmpty)
        #expect(settled.isEmpty)
    }

    @Test("Suppression cancels a reservation but holds then retracts a presented delivery")
    func suppressionEffects() async throws {
        for presented in [false, true] {
            let trace = RuntimeTrace()
            let store = HeadsUpRuntimeStore(onCommit: { trace.values.append("commit") })
            let runtime = try makeRuntime(store: store)
            var effects: [HeadsUpRuntimeEffect] = []
            runtime.onHeadsUpEffect = {
                trace.values.append("effect")
                effects.append($0)
            }
            try await runtime.restore()
            try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 45))
            if presented {
                try await runtime.acknowledgeHeadsUpPresented(
                    deliveryID(1),
                    channel: .capsule,
                )
            }
            trace.values.removeAll()
            effects.removeAll()

            try await runtime.observeHeadsUp(snapshot(
                .visual(cycleID: 0),
                target: 30,
                suppression: .manualPause,
            ))

            #expect(trace.values == ["commit", "effect"])
            #expect(effects == (presented
                    ? [.holdThenRetract(deliveryID(1), .manualPause)]
                    : [.cancel(deliveryID(1))]))
        }
    }

    @Test("Ordinary clock mutation synchronizes delivery cycles before commit and cancels after")
    func ordinaryMutationSynchronizesDelivery() async throws {
        let trace = RuntimeTrace()
        let store = HeadsUpRuntimeStore(onCommit: { trace.values.append("commit") })
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = {
            trace.values.append("effect")
            effects.append($0)
        }
        try await runtime.restore()
        try await presentAndAcknowledge(runtime, opportunity: .visual(cycleID: 0))
        trace.values.removeAll()
        effects.removeAll()

        try await runtime.handleVisualReset(.timerFinished)

        #expect(runtime.state.visualClock.cycleID == 1)
        #expect(runtime.state.headsUpDeliveryState.visualClock.cycleID == 1)
        #expect(runtime.state.headsUpDeliveryState.activeDelivery == nil)
        #expect(trace.values == ["commit", "effect"])
        #expect(effects == [.cancel(deliveryID(1))])
    }

    @Test("Cycle rotation durably cancels an in-flight pending App action")
    func ordinaryMutationCancelsPendingActionAfterCommit() async throws {
        let trace = RuntimeTrace()
        let store = HeadsUpRuntimeStore(onCommit: { trace.values.append("commit") })
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = {
            trace.values.append("effect")
            effects.append($0)
        }
        try await runtime.restore()
        try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 0))
        let action = try #require(runtime.state.headsUpDeliveryState.pendingAction)
        trace.values.removeAll()
        effects.removeAll()

        try await runtime.handleVisualReset(.timerFinished)

        #expect(trace.values == ["commit", "effect"])
        #expect(effects == [.cancelPendingAction(action)])
        #expect(store.commits.last?.state.headsUpDeliveryState.pendingAction == nil)
        #expect(runtime.state.visualClock.cycleID == 1)
    }

    @Test("Manual pause durably cancels an automatic pending open before publishing")
    func manualPauseCancelsAutomaticPendingOpen() async throws {
        let trace = RuntimeTrace()
        let store = HeadsUpRuntimeStore(onCommit: { trace.values.append("commit") })
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = {
            trace.values.append("effect")
            effects.append($0)
        }
        try await runtime.restore()
        try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 0))
        let action = try #require(runtime.state.headsUpDeliveryState.pendingAction)
        trace.values.removeAll()
        effects.removeAll()

        try await runtime.handle(.pause(.untilResume))

        #expect(trace.values == ["commit", "effect"])
        #expect(effects == [.cancelPendingAction(action)])
        #expect(runtime.state.headsUpDeliveryState.pendingAction == nil)
        #expect(runtime.statusContext.activeSuppression == .manualPause)
    }

    @Test("Manual pause durably retracts every adapter-live delivery phase")
    func manualPauseRetractsActiveDelivery() async throws {
        for presented in [false, true] {
            let trace = RuntimeTrace()
            let store = HeadsUpRuntimeStore(onCommit: { trace.values.append("commit") })
            let runtime = try makeRuntime(store: store)
            var effects: [HeadsUpRuntimeEffect] = []
            runtime.onHeadsUpEffect = {
                trace.values.append("effect")
                effects.append($0)
            }
            try await runtime.restore()
            try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 45))
            if presented {
                try await runtime.acknowledgeHeadsUpPresented(
                    deliveryID(1),
                    channel: .capsule,
                )
            }
            trace.values.removeAll()
            effects.removeAll()

            try await runtime.handle(.pause(.untilResume))

            #expect(trace.values == ["commit", "effect"])
            #expect(effects == [presented
                    ? .holdThenRetract(deliveryID(1), .manualPause)
                    : .cancel(deliveryID(1))])
            #expect(runtime.state.headsUpDeliveryState.activeDelivery == nil)
        }
    }

    @Test("A failed manual-pause cancellation leaves the automatic open and status unchanged")
    func failedManualPauseRetainsAutomaticPendingOpen() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var effects: [HeadsUpRuntimeEffect] = []
        runtime.onHeadsUpEffect = { effects.append($0) }
        try await runtime.restore()
        try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 0))
        let retained = runtime.state
        let retainedStatus = runtime.statusContext
        effects.removeAll()
        store.failuresRemaining = 1

        await #expect(throws: HeadsUpRuntimeStore.Failure.self) {
            try await runtime.handle(.pause(.untilResume))
        }

        #expect(runtime.state == retained)
        #expect(runtime.statusContext == retainedStatus)
        #expect(effects.isEmpty)
    }

    @Test("Heads-Up routing fails closed when no policy was injected")
    func missingPolicyFailsClosed() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
        )
        try await runtime.restore()

        await #expect(throws: HeadsUpRuntimeError.policyNotConfigured) {
            try await runtime.observeHeadsUp(snapshot(.visual(cycleID: 0), target: 45))
        }
        #expect(store.commits.isEmpty)
    }
}
