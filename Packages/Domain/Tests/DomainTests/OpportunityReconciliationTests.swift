import Foundation
import Testing
@testable import Domain

/// Story 2.3 RED: deterministic reconciliation — complete nonterminal rank,
/// same-generation terminal reduction, generation/projection fences, and
/// reordered-replay convergence with no early re-offer.
///
/// Fails before implementation. Reductions are commutative, associative, and
/// idempotent: every permutation of one candidate set settles the same
/// winner, one fact, and one fenced successor.
/// Shared harness for the reconciliation suites in this file. The static
/// identities mirror the deterministic fixtures above so every suite settles
/// against the same running merged clocks.
private let reconcileOpportunity = OpportunityID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
private let reconcileDeviceA = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
private let reconcileDeviceB = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!)
private let reconcileEpoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!)

private func reconcileConfiguration() throws -> ProtocolConfiguration {
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

private func runningMergedEngine() throws -> ProtocolEngine {
    ProtocolEngine(
        configuration: try reconcileConfiguration(),
        visualClock: OpportunityClockState(cycleID: 1, accumulatedActiveUseSeconds: 0, phase: .accumulating),
        movementClock: OpportunityClockState(
            accumulatedActiveUseSeconds: 3600,
            phase: .running,
        ),
    )
}

private func mergedScope() -> OpportunityActionScope {
    .merged(
        visualCycle: ClockCycleID(scope: .visual, rawValue: 1),
        movementCycle: ClockCycleID(scope: .movement, rawValue: 0),
    )
}

private func donePayload() -> OpportunityActionPayload {
    var payload = OpportunityActionPayload()
    payload.selectedDurationSeconds = 300
    return payload
}

private func makeCandidate(
    _ kind: OpportunityActionKind,
    actionUUID: String,
    device: DeviceID,
    counter: UInt64,
    scope: OpportunityActionScope,
    revision: UInt64 = 0,
    payload: OpportunityActionPayload = OpportunityActionPayload(),
) throws -> OpportunityActionEnvelope {
    let lease = try OpportunityLease(
        scope: .opportunity(id: reconcileOpportunity, revision: revision),
        generation: CoordinatorGeneration(0),
        grantedDeviceID: device,
        grantedTicks: 1000,
        expiryTicks: 1090,
        projectionEpoch: reconcileEpoch,
    )
    return OpportunityActionEnvelope(
        action: ActionID(uuid: UUID(uuidString: actionUUID)!, deviceID: device, counter: counter),
        kind: kind,
        scope: scope,
        originRevision: revision,
        generation: CoordinatorGeneration(0),
        projectionEpoch: reconcileEpoch,
        originPhase: .running,
        segmentID: nil,
        causalParents: [],
        lease: lease,
        payload: payload,
    )
}

@Suite("Opportunity reconciliation: terminal rank")
struct OpportunityTerminalRankTests {

    // MARK: - Terminal claim rank

    @Test("Terminal claim rank orders skip before timer finish")
    func terminalRankOrdersSkipFirst() {
        #expect(OpportunityActionKind.mergedEscapeDuringMovement.terminalClaimRank
            < OpportunityActionKind.mergedMovementTimerFinished.terminalClaimRank)
        #expect(OpportunityActionKind.mergedMovementDoneEarly.terminalClaimRank
            < OpportunityActionKind.mergedMovementTimerFinished.terminalClaimRank)
        #expect(OpportunityActionKind.mergedMovementAlreadyMoved.terminalClaimRank
            < OpportunityActionKind.mergedMovementDoneEarly.terminalClaimRank)
    }

    @Test("Reordered terminal replays converge on the skip winner with one fact")
    func reorderedReplaysConvergeOnSkip() throws {
        let skip = try makeCandidate(
            .mergedEscapeDuringMovement,
            actionUUID: "00000000-0000-0000-0000-00000000C001",
            device: reconcileDeviceA,
            counter: 3,
            scope: mergedScope(),
        )
        let done = try makeCandidate(
            .mergedMovementTimerFinished,
            actionUUID: "00000000-0000-0000-0000-00000000C002",
            device: reconcileDeviceB,
            counter: 1,
            scope: mergedScope(),
            payload: donePayload(),
        )
        for ordering in [[skip, done], [done, skip]] {
            var engine = try runningMergedEngine()
            var reducer = OpportunityActionReducer()
            let receipts = reducer.reduceAll(ordering, on: &engine, atTicks: 1010)
            let committed = receipts.filter { $0.outcome == .committed }
            #expect(committed.count == 1)
            #expect(committed.first?.facts.map(\.kind) == [.skipped])
            #expect(committed.first?.actionID.uuid.uuidString == "00000000-0000-0000-0000-00000000C001")
            #expect(receipts.filter { $0.outcome != .committed }.count == 1)
        }
    }

    @Test("A terminal winner fences its epoch against later arrivals")
    func terminalWinnerFencesEpoch() throws {
        // Only a movement-segment exit (target terminal_provisional) closes
        // and fences; visual-segment exits bind without fencing (pinned in
        // visualExitCreatesMovementSegment).
        #expect(OpportunityActionKind.mergedMovementDoneEarly.isTerminal)
        #expect(!OpportunityActionKind.mergedVisualSegmentDoneEarly.isTerminal)
        var engine = try runningMergedEngine()
        var reducer = OpportunityActionReducer()
        let done = try makeCandidate(
            .mergedMovementDoneEarly,
            actionUUID: "00000000-0000-0000-0000-00000000C010",
            device: reconcileDeviceA,
            counter: 1,
            scope: mergedScope(),
            payload: donePayload(),
        )
        let first = reducer.reduce(done, on: &engine, atTicks: 1010)
        #expect(first.outcome == .committed)
        #expect(first.facts.map(\.kind) == [.userDeclaredCompleted])

        let late = try makeCandidate(
            .mergedMovementTimerFinished,
            actionUUID: "00000000-0000-0000-0000-00000000C011",
            device: reconcileDeviceB,
            counter: 2,
            scope: mergedScope(),
            payload: donePayload(),
        )
        let second = reducer.reduce(late, on: &engine, atTicks: 1011)
        #expect(second.outcome == .rejectedFencedEpoch)
        #expect(second.facts.isEmpty)
        #expect(engine.movementClock == OpportunityClockState(cycleID: 1))
    }

    @Test("A terminal action beats a nonterminal accept for one revision")
    func terminalBeatsNonterminalAccept() throws {
        var acceptPayload = OpportunityActionPayload()
        acceptPayload.selectedDurationSeconds = 300
        let accept = try makeCandidate(
            .mergedMovementAccept,
            actionUUID: "00000000-0000-0000-0000-00000000C020",
            device: reconcileDeviceA,
            counter: 1,
            scope: mergedScope(),
            payload: acceptPayload,
        )
        let skip = try makeCandidate(
            .mergedEscapeDuringMovement,
            actionUUID: "00000000-0000-0000-0000-00000000C021",
            device: reconcileDeviceB,
            counter: 2,
            scope: mergedScope(),
        )
        for ordering in [[accept, skip], [skip, accept]] {
            var engine = try runningMergedEngine()
            var reducer = OpportunityActionReducer()
            let receipts = reducer.reduceAll(ordering, on: &engine, atTicks: 1010)
            let facts = receipts.filter { $0.outcome == .committed }.flatMap(\.facts)
            #expect(facts.map(\.kind) == [.skipped])
        }
    }
}

/// The accept → visual-exit → movement-accept prefix shared by the merged
/// segment-guard tests. Runs the three commits and hands back the reduced
/// engine, reducer, envelopes, and receipts for assertion.
private struct VisualExitFlow {
    var engine: ProtocolEngine
    var reducer: OpportunityActionReducer
    var accept: OpportunityActionEnvelope
    var segmentExit: OpportunityActionEnvelope
    var movementJoin: OpportunityActionEnvelope
    var accepted: OpportunityActionReceipt
    var exited: OpportunityActionReceipt
    var joined: OpportunityActionReceipt
}

private func makeVisualExitFlow() throws -> VisualExitFlow {
    var engine = ProtocolEngine(
        configuration: try reconcileConfiguration(),
        visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1500, phase: .running),
        movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 3600, phase: .readyToPresent),
    )
    var reducer = OpportunityActionReducer()
    var acceptPayload = OpportunityActionPayload()
    acceptPayload.selectedDurationSeconds = 5
    let accept = OpportunityActionEnvelope(
        action: ActionID(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000C060")!,
            deviceID: reconcileDeviceA,
            counter: 1,
        ),
        kind: .mergedAccept,
        scope: mergedScope(),
        originRevision: 0,
        generation: CoordinatorGeneration(0),
        projectionEpoch: reconcileEpoch,
        originPhase: .offered,
        segmentID: nil,
        causalParents: [],
        lease: try OpportunityLease(
            scope: .opportunity(id: reconcileOpportunity, revision: 0),
            generation: CoordinatorGeneration(0),
            grantedDeviceID: reconcileDeviceA,
            grantedTicks: 1000,
            expiryTicks: 1090,
            projectionEpoch: reconcileEpoch,
        ),
        payload: acceptPayload,
    )
    let accepted = reducer.reduce(accept, on: &engine, atTicks: 1010)
    let segmentExit = OpportunityActionEnvelope(
        action: ActionID(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000C061")!,
            deviceID: reconcileDeviceA,
            counter: 2,
        ),
        kind: .mergedVisualSegmentDoneEarly,
        scope: mergedScope(),
        originRevision: 1,
        generation: CoordinatorGeneration(0),
        projectionEpoch: reconcileEpoch,
        originPhase: .running,
        segmentID: MergedSegmentID.visual(for: reconcileOpportunity),
        causalParents: [accepted.actionID],
        lease: try OpportunityLease(
            scope: .opportunity(id: reconcileOpportunity, revision: 1),
            generation: CoordinatorGeneration(0),
            grantedDeviceID: reconcileDeviceA,
            grantedTicks: 1000,
            expiryTicks: 1090,
            projectionEpoch: reconcileEpoch,
        ),
        payload: OpportunityActionPayload(),
    )
    let exited = reducer.reduce(segmentExit, on: &engine, atTicks: 1011)
    var joinPayload = OpportunityActionPayload()
    joinPayload.selectedDurationSeconds = 300
    let movementJoin = OpportunityActionEnvelope(
        action: ActionID(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000C062")!,
            deviceID: reconcileDeviceA,
            counter: 3,
        ),
        kind: .mergedMovementAccept,
        scope: mergedScope(),
        originRevision: 2,
        generation: CoordinatorGeneration(0),
        projectionEpoch: reconcileEpoch,
        originPhase: .running,
        segmentID: MergedSegmentID.movement(for: reconcileOpportunity),
        causalParents: [exited.actionID],
        lease: try OpportunityLease(
            scope: .opportunity(id: reconcileOpportunity, revision: 2),
            generation: CoordinatorGeneration(0),
            grantedDeviceID: reconcileDeviceA,
            grantedTicks: 1000,
            expiryTicks: 1090,
            projectionEpoch: reconcileEpoch,
        ),
        payload: joinPayload,
    )
    let joined = reducer.reduce(movementJoin, on: &engine, atTicks: 1012)
    return VisualExitFlow(
        engine: engine,
        reducer: reducer,
        accept: accept,
        segmentExit: segmentExit,
        movementJoin: movementJoin,
        accepted: accepted,
        exited: exited,
        joined: joined,
    )
}

// MARK: - Nonterminal conflict keys and merged segment guards

@Suite("Opportunity reconciliation: nonterminal keys and segments")
struct OpportunityNonterminalKeyTests {
    @Test("One winner applies per conflict key in canonical order")
    func oneWinnerPerConflictKey() throws {
        var engine = ProtocolEngine(configuration: try reconcileConfiguration())
        var reducer = OpportunityActionReducer()
        var pausePayload = OpportunityActionPayload()
        pausePayload.pauseRecordID = UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!
        let globalLease = try OpportunityLease(
            scope: .global(
                id: GlobalStateID(UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!),
                revision: 0,
            ),
            generation: CoordinatorGeneration(0),
            grantedDeviceID: reconcileDeviceA,
            grantedTicks: 1000,
            expiryTicks: 1090,
        )
        func globalAction(
            _ kind: OpportunityActionKind,
            uuid: String,
            counter: UInt64,
        ) -> OpportunityActionEnvelope {
            OpportunityActionEnvelope(
                action: ActionID(
                    uuid: UUID(uuidString: uuid)!,
                    deviceID: reconcileDeviceA,
                    counter: counter,
                ),
                kind: kind,
                scope: .globalSystem,
                originRevision: 0,
                generation: CoordinatorGeneration(0),
                projectionEpoch: nil,
                originPhase: nil,
                segmentID: nil,
                causalParents: [],
                lease: globalLease,
                payload: pausePayload,
            )
        }
        let receipts = reducer.reduceAll(
            [
                globalAction(.pauseResume, uuid: "00000000-0000-0000-0000-00000000C030", counter: 2),
                globalAction(.pauseStart, uuid: "00000000-0000-0000-0000-00000000C031", counter: 1),
            ],
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipts.filter { $0.outcome == .committed }.count == 1)
        #expect(receipts.first(where: { $0.outcome == .committed })?.actionID.uuid.uuidString
            == "00000000-0000-0000-0000-00000000C031")
    }

    @Test("Compatible disjoint keys all commit in one transaction")
    func disjointKeysAllCommit() throws {
        var engine = ProtocolEngine(configuration: try reconcileConfiguration())
        var reducer = OpportunityActionReducer()
        var pausePayload = OpportunityActionPayload()
        pausePayload.pauseRecordID = UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!
        var holdPayload = OpportunityActionPayload()
        holdPayload.holdDecisionID = DecisionID(UUID(uuidString: "00000000-0000-0000-0000-00000000D002")!)
        let globalID = GlobalStateID(UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!)
        func globalAction(
            _ kind: OpportunityActionKind,
            uuid: String,
            payload: OpportunityActionPayload,
        ) throws -> OpportunityActionEnvelope {
            let lease = try OpportunityLease(
                scope: .global(id: globalID, revision: 0),
                generation: CoordinatorGeneration(0),
                grantedDeviceID: reconcileDeviceA,
                grantedTicks: 1000,
                expiryTicks: 1090,
            )
            return OpportunityActionEnvelope(
                action: ActionID(uuid: UUID(uuidString: uuid)!, deviceID: reconcileDeviceA, counter: 1),
                kind: kind,
                scope: .globalSystem,
                originRevision: 0,
                generation: CoordinatorGeneration(0),
                projectionEpoch: nil,
                originPhase: nil,
                segmentID: nil,
                causalParents: [],
                lease: lease,
                payload: payload,
            )
        }
        let receipts = reducer.reduceAll(
            [
                try globalAction(.pauseStart, uuid: "00000000-0000-0000-0000-00000000C040", payload: pausePayload),
                try globalAction(.holdBegin, uuid: "00000000-0000-0000-0000-00000000C041", payload: holdPayload),
            ],
            on: &engine,
            atTicks: 1010,
        )
        #expect(receipts.allSatisfy { $0.outcome == .committed })
        #expect(receipts.flatMap(\.facts).isEmpty)
    }

    // MARK: - Merged segment guards

    @Test("A movement accept cannot consume a segment before its creation")
    func segmentGuardRequiresCreation() throws {
        var engine = ProtocolEngine(
            configuration: try reconcileConfiguration(),
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1500, phase: .readyToPresent),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 3600, phase: .readyToPresent),
        )
        var reducer = OpportunityActionReducer()
        var payload = OpportunityActionPayload()
        payload.selectedDurationSeconds = 300
        let early = try makeCandidate(
            .mergedMovementAccept,
            actionUUID: "00000000-0000-0000-0000-00000000C050",
            device: reconcileDeviceA,
            counter: 1,
            scope: mergedScope(),
            payload: payload,
        )
        let receipt = reducer.reduce(early, on: &engine, atTicks: 1010)
        #expect(receipt.outcome == .rejectedInvalidPayload)
        #expect(receipt.facts.isEmpty)
    }

    @Test("Merged visual exit creates the movement segment for the same opportunity")
    func visualExitCreatesMovementSegment() throws {
        // Contract §17: visual-segment exits target an offered phase, so
        // they are component advances, not closes.
        #expect(!OpportunityActionKind.mergedVisualSegmentFinished.isTerminal)
        #expect(!OpportunityActionKind.mergedVisualSegmentDoneEarly.isTerminal)
        let flow = try makeVisualExitFlow()
        #expect(flow.accepted.outcome == .committed)
        #expect(flow.accepted.facts.map(\.kind) == [.breakStarted])
        #expect(flow.exited.outcome == .committed)
        #expect(flow.exited.facts.map(\.kind) == [.userDeclaredCompleted])
        let session = flow.reducer.mergedSession(for: reconcileOpportunity)
        #expect(session?.movementSegmentID == MergedSegmentID.movement(for: reconcileOpportunity))
        // The visual-segment exit binds the epoch without fencing it: a
        // same-epoch movement accept still commits afterwards.
        #expect(flow.joined.outcome == .committed)
        #expect(flow.joined.facts.map(\.kind) == [.breakStarted])
        #expect(flow.engine.movementClock.phase == .running)
    }

    @Test("The movement-segment exit is the flow's single terminal close")
    func movementSegmentExitIsTheSingleTerminalClose() throws {
        let flow = try makeVisualExitFlow()
        #expect(flow.accepted.outcome == .committed)
        #expect(flow.exited.outcome == .committed)
        #expect(flow.joined.outcome == .committed)
        var engine = flow.engine
        var reducer = flow.reducer
        // The movement-segment exit commits the terminal fact and fences
        // the epoch it closes.
        let close = try makeCandidate(
            .mergedMovementDoneEarly,
            actionUUID: "00000000-0000-0000-0000-00000000C063",
            device: reconcileDeviceA,
            counter: 4,
            scope: mergedScope(),
            revision: 3,
            payload: donePayload(),
        )
        let closed = reducer.reduce(close, on: &engine, atTicks: 1013)
        #expect(closed.outcome == .committed)
        #expect(closed.facts.map(\.kind) == [.userDeclaredCompleted])
        let terminalKinds = [flow.accept.kind, flow.segmentExit.kind, flow.movementJoin.kind, close.kind]
            .filter { $0.isTerminal }
        #expect(terminalKinds == [.mergedMovementDoneEarly])
        // A fenced epoch authorizes nothing further under it.
        let late = try makeCandidate(
            .mergedMovementTimerFinished,
            actionUUID: "00000000-0000-0000-0000-00000000C064",
            device: reconcileDeviceA,
            counter: 5,
            scope: mergedScope(),
            payload: donePayload(),
        )
        let lateReceipt = reducer.reduce(late, on: &engine, atTicks: 1014)
        #expect(lateReceipt.outcome == .rejectedFencedEpoch)
        #expect(lateReceipt.facts.isEmpty)
    }
}
