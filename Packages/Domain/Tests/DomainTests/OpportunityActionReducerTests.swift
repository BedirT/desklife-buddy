import Foundation
import Testing
@testable import Domain

/// Story 2.3 RED: the one canonical opportunity-action reducer.
///
/// Fails before implementation. Every matrix row delegates its clock effect
/// and fact to the existing engine reduction, so standalone and merged
/// semantics stay identical by sharing one code path. The v1 matrix is
/// preserved exactly (pinned by MovementProtocolSemanticsTests); D-043
/// deltas that need clock/evidence machinery land in their owning stories.
/// Shared harness for the canonical-reducer suites in this file. The static
/// identities mirror the deterministic fixtures above so every suite reduces
/// against the same due clocks.
private let actionOpportunity = OpportunityID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
private let actionGlobal = GlobalStateID(UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!)
private let actionDevice = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!)
private let actionEpoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!)


private func actionConfiguration() throws -> ProtocolConfiguration {
    try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 10,
                targetSeconds: 20,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: 15,
                targetSeconds: 50,
                latestPreferredSeconds: 60,
                durationOptionsSeconds: [300, 120],
            ),
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 60,
                longIdleResetSeconds: 300,
                wakeUnlockGraceSeconds: 90,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: false,
                mergeWindowSeconds: 5,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 2,
                snoozeOptionsSeconds: [300, 600, 900],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )
}

// MARK: - Harness

private func dueEngine() throws -> ProtocolEngine {
    ProtocolEngine(
        configuration: try actionConfiguration(),
        visualClock: OpportunityClockState(
            accumulatedActiveUseSeconds: 1500,
            phase: .readyToPresent,
        ),
        movementClock: OpportunityClockState(
            accumulatedActiveUseSeconds: 3600,
            phase: .readyToPresent,
        ),
    )
}

private func makeLease(
    scope: LeaseScope,
    generation: CoordinatorGeneration = CoordinatorGeneration(0),
    grantedTicks: TimeInterval = 1000,
    expiryTicks: TimeInterval = 1090,
    projectionEpoch: ProjectionEpochID? = nil,
) throws -> OpportunityLease {
    try OpportunityLease(
        scope: scope,
        generation: generation,
        grantedDeviceID: actionDevice,
        grantedTicks: grantedTicks,
        expiryTicks: expiryTicks,
        projectionEpoch: projectionEpoch,
    )
}

private func makeEnvelope(
    _ kind: OpportunityActionKind,
    scope: OpportunityActionScope,
    revision: UInt64 = 0,
    actionUUID: String = "00000000-0000-0000-0000-00000000A001",
    counter: UInt64 = 1,
    originPhase: OpportunityActionPhase? = .offered,
    generation: CoordinatorGeneration = CoordinatorGeneration(0),
    lease: OpportunityLease? = nil,
    payload: OpportunityActionPayload = OpportunityActionPayload(),
) throws -> OpportunityActionEnvelope {
    OpportunityActionEnvelope(
        action: ActionID(
            uuid: UUID(uuidString: actionUUID)!,
            deviceID: actionDevice,
            counter: counter,
        ),
        kind: kind,
        scope: scope,
        originRevision: revision,
        generation: generation,
        projectionEpoch: actionEpoch,
        originPhase: originPhase,
        segmentID: nil,
        causalParents: [],
        lease: lease ?? (try makeLease(
            scope: .opportunity(id: actionOpportunity, revision: revision),
            generation: generation,
            projectionEpoch: actionEpoch,
        )),
        payload: payload,
    )
}

private func durationPayload(_ seconds: TimeInterval) -> OpportunityActionPayload {
    var payload = OpportunityActionPayload()
    payload.selectedDurationSeconds = seconds
    return payload
}

// MARK: - Movement offer vs acceptance

@Suite("Canonical opportunity-action reducer: movement")
struct OpportunityActionMovementTests {

    @Test("Opening a movement duration choice emits no breakStarted")
    func openingChoiceEmitsNoFact() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let receipt = reducer.reduce(
            try makeEnvelope(
                .nowOpenMovementOffer,
                scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .committed)
        #expect(receipt.facts.isEmpty)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .readyToPresent)
    }

    @Test("Selecting a movement duration emits exactly one breakStarted")
    func selectionEmitsExactlyOneFact() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let receipt = reducer.reduce(
            try makeEnvelope(
                .nowAcceptMovement,
                scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
                payload: durationPayload(300),
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .committed)
        #expect(receipt.facts.map(\.kind) == [.breakStarted])
        #expect(engine.movementClock.cycleID == 1)
        #expect(engine.movementClock.phase == .running)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)

        var direct = try dueEngine()
        let expected = direct.selectMovement(durationSeconds: 300)
        #expect(receipt.facts == expected.events)
        #expect(engine.movementClock == direct.movementClock)
        #expect(engine.visualClock == direct.visualClock)
    }

    @Test("An unsupported movement duration is an auditable no-op")
    func unsupportedDurationIsNoOp() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let receipt = reducer.reduce(
            try makeEnvelope(
                .nowAcceptMovement,
                scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
                payload: durationPayload(240),
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .rejectedInvalidPayload)
        #expect(receipt.facts.isEmpty)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
    }

    // MARK: - Terminal matrix preserves the v1 effects

    @Test("Visual timer finish begins a fresh visual cycle")
    func visualTimerFinishFreshensVisual() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let receipt = reducer.reduce(
            try makeEnvelope(
                .visualTimerFinished,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                originPhase: .running,
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .committed)
        #expect(receipt.facts.map(\.kind) == [.timerFinished])
        #expect(engine.visualClock == OpportunityClockState(cycleID: 1))
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
    }

    @Test("Movement Done-early begins a fresh movement cycle and keeps visual")
    func movementDoneEarlyKeepsVisual() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let receipt = reducer.reduce(
            try makeEnvelope(
                .movementDoneEarly,
                scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
                originPhase: .running,
                payload: durationPayload(300),
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .committed)
        #expect(receipt.facts.map(\.kind) == [.userDeclaredCompleted])
        #expect(engine.movementClock == OpportunityClockState(cycleID: 1))
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
    }

    @Test("Movement timer finish keeps movement accrual and freshens visual")
    func movementTimerFinishPreservesMovementAccrual() throws {
        var engine = ProtocolEngine(
            configuration: try actionConfiguration(),
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 0, phase: .accumulating),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 3600, phase: .running),
        )
        var reducer = OpportunityActionReducer()
        let receipt = reducer.reduce(
            try makeEnvelope(
                .movementTimerFinished,
                scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
                originPhase: .running,
                payload: durationPayload(300),
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .committed)
        #expect(receipt.facts.map(\.kind) == [.timerFinished])
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .gracedAfterSuppression)
        #expect(engine.visualClock == OpportunityClockState(cycleID: 1))
    }

    @Test("Already-moved begins a fresh movement cycle without visual credit")
    func alreadyMovedKeepsVisual() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let receipt = reducer.reduce(
            try makeEnvelope(
                .movementAlreadyMoved,
                scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
                originPhase: .running,
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .committed)
        #expect(receipt.facts.map(\.kind) == [.userDeclaredAlreadyMoved])
        #expect(engine.movementClock == OpportunityClockState(cycleID: 1))
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
    }

    @Test("Position change preserves the due movement clock")
    func positionChangePreservesMovement() throws {
        var engine = ProtocolEngine(
            configuration: try actionConfiguration(),
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 0, phase: .accumulating),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 3600, phase: .running),
        )
        var reducer = OpportunityActionReducer()
        let receipt = reducer.reduce(
            try makeEnvelope(
                .movementPositionChangedRunning,
                scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
                originPhase: .running,
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .committed)
        #expect(receipt.facts.map(\.kind) == [.positionChanged])
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .gracedAfterSuppression)
    }

    @Test("Standalone and merged movement exits share one engine effect")
    func standaloneAndMergedShareEffects() throws {
        var standalone = try dueEngine()
        var standaloneReducer = OpportunityActionReducer()
        let standaloneReceipt = standaloneReducer.reduce(
            try makeEnvelope(
                .movementDoneEarly,
                scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
                originPhase: .running,
                payload: durationPayload(300),
            ),
            on: &standalone,
            atTicks: 1010,
        )

        var merged = try dueEngine()
        var mergedReducer = OpportunityActionReducer()
        let mergedReceipt = mergedReducer.reduce(
            try makeEnvelope(
                .mergedMovementDoneEarly,
                scope: .merged(
                    visualCycle: ClockCycleID(scope: .visual, rawValue: 0),
                    movementCycle: ClockCycleID(scope: .movement, rawValue: 0),
                ),
                originPhase: .running,
                payload: durationPayload(300),
            ),
            on: &merged,
            atTicks: 1010,
        )
        #expect(standaloneReceipt.facts == mergedReceipt.facts)
        #expect(standalone.movementClock == merged.movementClock)
        #expect(standalone.visualClock == merged.visualClock)
    }
}

// MARK: - Stale, duplicate, invalid revisions are auditable no-ops

@Suite("Canonical opportunity-action reducer: staleness fences")
struct OpportunityActionStalenessTests {
    @Test("A stale generation is an auditable no-op")
    func staleGenerationIsNoOp() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let current = try makeEnvelope(
            .visualDoneEarly,
            scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
            originPhase: .running,
        )
        let stale = OpportunityActionEnvelope(
            action: current.action,
            kind: current.kind,
            scope: current.scope,
            originRevision: current.originRevision,
            generation: CoordinatorGeneration(7),
            projectionEpoch: current.projectionEpoch,
            originPhase: current.originPhase,
            segmentID: current.segmentID,
            causalParents: current.causalParents,
            lease: current.lease,
            payload: current.payload,
        )
        let receipt = reducer.reduce(stale, on: &engine, atTicks: 1010)
        #expect(receipt.outcome == .rejectedStaleGeneration)
        #expect(receipt.facts.isEmpty)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(!receipt.reason.isEmpty)
    }

    @Test("Post-rotation offers from the prior generation fence while current-generation offers commit")
    func generationRotationFencesStaleOffers() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        reducer.noteSessionRotation()
        #expect(reducer.generation == CoordinatorGeneration(1))

        let stale = reducer.reduce(
            try makeEnvelope(
                .visualDoneEarly,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                originPhase: .running,
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(stale.outcome == .rejectedStaleGeneration)
        #expect(stale.facts.isEmpty)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)

        let fresh = reducer.reduce(
            try makeEnvelope(
                .visualDoneEarly,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                actionUUID: "00000000-0000-0000-0000-00000000A002",
                counter: 2,
                originPhase: .running,
                generation: CoordinatorGeneration(1),
            ),
            on: &engine,
            atTicks: 1011,
        )
        #expect(fresh.outcome == .committed)
        #expect(fresh.facts.map(\.kind) == [.userDeclaredCompleted])
        #expect(engine.visualClock == OpportunityClockState(cycleID: 1))
    }

    @Test("A duplicate ActionID replays the original receipt without reapplying")
    func duplicateReplaysOriginalReceipt() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let first = reducer.reduce(
            try makeEnvelope(
                .visualDoneEarly,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                originPhase: .running,
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(first.outcome == .committed)
        let second = reducer.reduce(
            try makeEnvelope(
                .visualDoneEarly,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                originPhase: .running,
            ),
            on: &engine,
            atTicks: 1011,
        )
        #expect(second.outcome == .duplicateReplay)
        #expect(second.facts == first.facts)
        #expect(engine.visualClock.cycleID == 1)
    }

    @Test("A stale revision is an auditable no-op")
    func staleRevisionIsNoOp() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        _ = reducer.reduce(
            try makeEnvelope(
                .nowAcceptVisual,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                payload: durationPayload(5),
            ),
            on: &engine,
            atTicks: 1010,
        )
        let stale = reducer.reduce(
            try makeEnvelope(
                .visualDoneEarly,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                revision: 0,
                actionUUID: "00000000-0000-0000-0000-00000000A002",
                counter: 2,
                originPhase: .running,
            ),
            on: &engine,
            atTicks: 1011,
        )
        #expect(stale.outcome == .rejectedStaleRevision)
        #expect(stale.facts.isEmpty)
    }

    @Test("A mismatched lease scope is an auditable no-op")
    func scopeMismatchIsNoOp() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let globalLease = try makeLease(scope: .global(id: actionGlobal, revision: 8))
        let receipt = reducer.reduce(
            try makeEnvelope(
                .nowAcceptVisual,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                lease: globalLease,
                payload: durationPayload(5),
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .rejectedScopeMismatch)
        #expect(receipt.facts.isEmpty)
        #expect(engine.visualClock.phase == .readyToPresent)
    }

    @Test("An expired lease is an auditable no-op")
    func expiredLeaseIsNoOp() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let expired = try makeLease(
            scope: .opportunity(id: actionOpportunity, revision: 0),
            grantedTicks: 900,
            expiryTicks: 990,
        )
        let receipt = reducer.reduce(
            try makeEnvelope(
                .nowAcceptVisual,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                lease: expired,
                payload: durationPayload(5),
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .rejectedLeaseNotLive)
        #expect(receipt.facts.isEmpty)
    }

    @Test("An old-revision lease with a fresh envelope fails after the revision advances")
    func oldRevisionLeaseFailsWithFreshEnvelope() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        _ = reducer.reduce(
            try makeEnvelope(
                .nowAcceptVisual,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                payload: durationPayload(5),
            ),
            on: &engine,
            atTicks: 1010,
        )
        let spentLease = try makeLease(
            scope: .opportunity(id: actionOpportunity, revision: 0),
            projectionEpoch: actionEpoch,
        )
        let receipt = reducer.reduce(
            try makeEnvelope(
                .visualDoneEarly,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                revision: 1,
                actionUUID: "00000000-0000-0000-0000-00000000A002",
                counter: 2,
                originPhase: .running,
                lease: spentLease,
            ),
            on: &engine,
            atTicks: 1011,
        )
        #expect(receipt.outcome == .rejectedLeaseNotLive)
        #expect(receipt.facts.isEmpty)
        #expect(engine.visualClock.phase == .running)
    }

    @Test("An old-revision global lease with a fresh envelope fails after the revision advances")
    func oldGlobalLeaseFailsWithFreshEnvelope() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        var pausePayload = OpportunityActionPayload()
        pausePayload.pauseRecordID = UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!
        _ = reducer.reduce(
            OpportunityActionEnvelope(
                action: ActionID(
                    uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000A010")!,
                    deviceID: actionDevice,
                    counter: 10,
                ),
                kind: .pauseStart,
                scope: .globalSystem,
                originRevision: 0,
                generation: CoordinatorGeneration(0),
                projectionEpoch: nil,
                originPhase: nil,
                segmentID: nil,
                causalParents: [],
                lease: try makeLease(scope: .global(id: actionGlobal, revision: 0)),
                payload: pausePayload,
            ),
            on: &engine,
            atTicks: 1010,
        )
        let spentLease = try makeLease(scope: .global(id: actionGlobal, revision: 0))
        let receipt = reducer.reduce(
            OpportunityActionEnvelope(
                action: ActionID(
                    uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000A011")!,
                    deviceID: actionDevice,
                    counter: 11,
                ),
                kind: .pauseResume,
                scope: .globalSystem,
                originRevision: 1,
                generation: CoordinatorGeneration(0),
                projectionEpoch: nil,
                originPhase: nil,
                segmentID: nil,
                causalParents: [],
                lease: spentLease,
                payload: pausePayload,
            ),
            on: &engine,
            atTicks: 1011,
        )
        #expect(receipt.outcome == .rejectedLeaseNotLive)
        #expect(receipt.facts.isEmpty)
    }

    @Test("A lease bound to another epoch authorizes nothing under this epoch")
    func leaseBoundToAnotherEpochFails() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let foreignLease = try makeLease(
            scope: .opportunity(id: actionOpportunity, revision: 0),
            projectionEpoch: ProjectionEpochID(
                uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000E002")!,
            ),
        )
        let receipt = reducer.reduce(
            try makeEnvelope(
                .nowAcceptVisual,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                lease: foreignLease,
                payload: durationPayload(5),
            ),
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipt.outcome == .rejectedLeaseNotLive)
        #expect(receipt.facts.isEmpty)
        #expect(engine.visualClock.phase == .readyToPresent)
    }
}

// MARK: - Pause, hold, system plumbing

@Suite("Canonical opportunity-action reducer: global plumbing")
struct OpportunityActionGlobalTests {
    @Test("Pause and hold actions commit operationally without manufacturing facts")
    func pauseAndHoldAreOperational() throws {
        var engine = try dueEngine()
        var reducer = OpportunityActionReducer()
        let pauseLease = try makeLease(scope: .global(id: actionGlobal, revision: 0))
        var pausePayload = OpportunityActionPayload()
        pausePayload.pauseRecordID = UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!
        let pause = OpportunityActionEnvelope(
            action: ActionID(
                uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000A010")!,
                deviceID: actionDevice,
                counter: 10,
            ),
            kind: .pauseStart,
            scope: .globalSystem,
            originRevision: 0,
            generation: CoordinatorGeneration(0),
            projectionEpoch: nil,
            originPhase: nil,
            segmentID: nil,
            causalParents: [],
            lease: pauseLease,
            payload: pausePayload,
        )
        let pauseReceipt = reducer.reduce(pause, on: &engine, atTicks: 1010)
        #expect(pauseReceipt.outcome == .committed)
        #expect(pauseReceipt.facts.isEmpty)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
    }
}

// MARK: - Coordinator seam

@Suite("Canonical opportunity-action reducer: coordinator seam")
struct OpportunityActionCoordinatorTests {
    @Test("The coordinator seam keeps reducer state across dispatches")
    func coordinatorSeamKeepsReducerState() throws {
        var coordinator = OpportunityCoordinator(engine: try dueEngine())
        let first = coordinator.dispatchAction(
            try makeEnvelope(
                .nowAcceptVisual,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                payload: durationPayload(5),
            ),
            atTicks: 1010,
        )
        #expect(first.receipt.outcome == .committed)
        #expect(first.receipt.facts.map(\.kind) == [.breakStarted])
        #expect(coordinator.engine.visualClock.phase == .running)

        let stale = coordinator.dispatchAction(
            try makeEnvelope(
                .visualDoneEarly,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                revision: 0,
                actionUUID: "00000000-0000-0000-0000-00000000A002",
                counter: 2,
                originPhase: .running,
            ),
            atTicks: 1011,
        )
        #expect(stale.receipt.outcome == .rejectedStaleRevision)
        #expect(stale.receipt.facts.isEmpty)
        #expect(first.presentation == stale.presentation)
    }

    @Test("A dispatched interruption advances the action generation through the coordinator")
    func coordinatorRotationAdvancesGeneration() throws {
        var coordinator = OpportunityCoordinator(engine: try dueEngine())
        #expect(coordinator.actionReducer.generation == CoordinatorGeneration(0))
        _ = coordinator.dispatch(.observe(
            sample: .active(uptimeSeconds: 0, secondsSinceInput: 0),
            activeSuppressions: [],
            isLowFrictionMoment: false,
        ))
        _ = coordinator.dispatch(.observe(
            sample: .active(uptimeSeconds: 10, secondsSinceInput: 0),
            activeSuppressions: [],
            isLowFrictionMoment: false,
        ))
        let away = coordinator.dispatch(.observe(
            sample: .active(uptimeSeconds: 310, secondsSinceInput: 300),
            activeSuppressions: [],
            isLowFrictionMoment: false,
        ))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(coordinator.actionReducer.generation == CoordinatorGeneration(1))

        let stale = coordinator.dispatchAction(
            try makeEnvelope(
                .visualDoneEarly,
                scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
                originPhase: .running,
            ),
            atTicks: 1010,
        )
        #expect(stale.receipt.outcome == .rejectedStaleGeneration)
        #expect(stale.receipt.facts.isEmpty)

        let fresh = coordinator.dispatchAction(
            try makeEnvelope(
                .movementDoneEarly,
                scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
                actionUUID: "00000000-0000-0000-0000-00000000A020",
                counter: 20,
                originPhase: .running,
                generation: CoordinatorGeneration(1),
                payload: durationPayload(300),
            ),
            atTicks: 1011,
        )
        #expect(fresh.receipt.outcome == .committed)
        #expect(fresh.receipt.facts.map(\.kind) == [.userDeclaredCompleted])
    }

}
