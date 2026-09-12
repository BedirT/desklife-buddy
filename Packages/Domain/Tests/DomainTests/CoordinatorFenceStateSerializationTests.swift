import Foundation
import Testing
@testable import Domain

/// Story 2.5 RED: reducer fence/dedup state must survive restore.
///
/// The contract (PRODUCT_MODEL coordination continuity; AUTHORITY.md data
/// lifecycle) designs the crash-replay outbox resend explicitly: a committed
/// ActionID resubmitted post-restore must yield `duplicateReplay`, not a
/// second commit. Fence/dedup state is session-scoped in 2.3 by design (see
/// `OpportunityActionReducer` settlement order); this suite fails until 2.5
/// persists it: generation, revisions, fenced epochs, committed
/// ActionIDs/receipts, and merged sessions.
///
/// Courtesy state (R2) is pinned in-memory-only here: the extended-away
/// runway is anchored to monotonic uptime, and the no-catch-up restore rule
/// (`ProtocolStateStore` seam docs; `noOfflineCatchUp` precedent) re-anchors
/// the baseline on relaunch instead of reconstructing wall time. A persisted
/// uptime anchor would hold fresh-boot samples inside a dead epoch's runway,
/// so relaunch must start clean. That pinning test characterizes current
/// behavior; every other test in this file is RED until the fence snapshot
/// API and receipt Codable land.
@Suite("Coordinator fence state persistence contract")
struct CoordinatorFenceStateSerializationTests {
    @Test("Fence snapshot captures generation, revisions, epochs, receipts, and sessions")
    func fenceSnapshotRoundTrip() throws {
        var reducer = OpportunityActionReducer()
        var engine = try fenceTestEngine()

        let offer = try fenceTestEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "10000000-0000-0000-0000-000000000001",
            counter: 1,
        )
        let offerReceipt = reducer.reduce(offer, on: &engine, atTicks: 1000)
        #expect(offerReceipt.outcome == .committed)

        let merged = try fenceTestEnvelope(
            .mergedAccept,
            scope: .merged(
                visualCycle: ClockCycleID(scope: .visual, rawValue: 0),
                movementCycle: ClockCycleID(scope: .movement, rawValue: 0),
            ),
            actionUUID: "10000000-0000-0000-0000-000000000002",
            counter: 2,
            revision: 1,
        )
        let mergedReceipt = reducer.reduce(merged, on: &engine, atTicks: 1000)
        #expect(mergedReceipt.outcome == .committed)

        reducer.noteSessionRotation()

        let snapshot = reducer.fenceState
        #expect(snapshot.generation == CoordinatorGeneration(1))
        #expect(snapshot.opportunityRevisions[fenceTestOpportunity] == 2)
        #expect(snapshot.projectionEpochs[fenceTestOpportunity] == fenceTestEpoch)
        #expect(snapshot.committedActions[offer.action]?.outcome == .committed)
        #expect(snapshot.committedActions[merged.action]?.outcome == .committed)
        #expect(snapshot.mergedSessions[fenceTestOpportunity]?.revision == 2)

        var restored = OpportunityActionReducer(fenceState: snapshot)
        #expect(restored.fenceState == snapshot)
        #expect(restored.generation == reducer.generation)
        #expect(restored.globalRevision == reducer.globalRevision)
        #expect(restored.opportunityRevisions == reducer.opportunityRevisions)
        #expect(restored.projectionEpochs == reducer.projectionEpochs)
        #expect(restored.fencedEpochs == reducer.fencedEpochs)
        #expect(restored.committedActions == reducer.committedActions)
        #expect(restored.mergedSession(for: fenceTestOpportunity) == reducer.mergedSession(for: fenceTestOpportunity))
    }

    @Test("A committed ActionID resubmitted post-restore replays instead of recommitting")
    func restoredDuplicateReplaysOriginalReceipt() throws {
        var reducer = OpportunityActionReducer()
        var engine = try fenceTestEngine()
        let envelope = try fenceTestEnvelope(
            .nowAcceptMovement,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "10000000-0000-0000-0000-000000000011",
            counter: 7,
            payload: OpportunityActionPayload(selectedDurationSeconds: 300),
        )
        let original = reducer.reduce(envelope, on: &engine, atTicks: 1000)
        #expect(original.outcome == .committed)
        #expect(original.facts.map(\.kind) == [.breakStarted])

        // Crash: only the snapshot survives. Replay arrives with skewed
        // ticks far past the pre-crash lease expiry, and again before the
        // pre-crash grant. Dedup precedes lease validation, so both replay.
        var restored = OpportunityActionReducer(fenceState: reducer.fenceState)
        let replayedLate = restored.reduce(envelope, on: &engine, atTicks: 5000)
        #expect(replayedLate.outcome == .duplicateReplay)
        #expect(replayedLate.facts == original.facts)

        var restoredEarly = OpportunityActionReducer(fenceState: reducer.fenceState)
        let replayedEarly = restoredEarly.reduce(envelope, on: &engine, atTicks: 5)
        #expect(replayedEarly.outcome == .duplicateReplay)
        #expect(replayedEarly.facts == original.facts)

        // No second commit happened: the frontier did not advance again.
        #expect(restored.opportunityRevisions[fenceTestOpportunity] == 1)
    }

    @Test("A fenced epoch stays fenced after restore while an unfenced epoch stays committable")
    func fencedVersusUnfencedRestore() throws {
        var reducer = OpportunityActionReducer()
        var engine = try fenceTestEngine()
        let terminal = try fenceTestEnvelope(
            .visualSkip,
            scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
            actionUUID: "10000000-0000-0000-0000-000000000021",
            counter: 11,
        )
        let terminalReceipt = reducer.reduce(terminal, on: &engine, atTicks: 1000)
        #expect(terminalReceipt.outcome == .committed)
        #expect(reducer.fenceState.fencedEpochs.contains(fenceTestEpoch))

        var restored = OpportunityActionReducer(fenceState: reducer.fenceState)
        let staleSameEpoch = try fenceTestEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "10000000-0000-0000-0000-000000000022",
            counter: 12,
        )
        #expect(restored.reduce(staleSameEpoch, on: &engine, atTicks: 1000).outcome == .rejectedFencedEpoch)

        // A successor epoch bound after the fence commits normally.
        let successorEpoch = ProjectionEpochID(uuid: UUID(uuidString: "10000000-0000-0000-0000-00000000E002")!)
        var rebound = OpportunityActionReducer(fenceState: restored.fenceState)
        rebound.projectionEpochs[fenceTestOpportunity] = successorEpoch
        let successor = try fenceTestEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "10000000-0000-0000-0000-000000000023",
            counter: 13,
            projectionEpoch: successorEpoch,
            revision: 1,
        )
        #expect(rebound.reduce(successor, on: &engine, atTicks: 1000).outcome == .committed)
    }

    @Test("Receipts and drafts survive a Codable round-trip and reject tampered identities")
    func receiptCodableRoundTrip() throws {
        let receipt = OpportunityActionReceipt(
            actionID: ActionID(
                uuid: UUID(uuidString: "10000000-0000-0000-0000-000000000031")!,
                deviceID: fenceTestDevice,
                counter: 3,
            ),
            outcome: .committed,
            facts: [OpportunityEventDraft(
                kind: .breakStarted,
                source: .user,
                opportunity: .movement,
                selectedDurationSeconds: 300,
            )],
            reason: "Committed.",
            globalRevision: 0,
            opportunityRevision: 1,
        )
        let data = try JSONEncoder().encode(receipt)
        #expect(try JSONDecoder().decode(OpportunityActionReceipt.self, from: data) == receipt)

        let malformedUUID = """
        {"actionID":{"uuid":"not-a-uuid","deviceID":"00000000-0000-0000-0000-0000000000d1","counter":3},\
        "outcome":"committed","facts":[],"reason":"x","globalRevision":0,"opportunityRevision":1}
        """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(OpportunityActionReceipt.self, from: malformedUUID)
        }
        let unknownOutcome = """
        {"actionID":{"uuid":"10000000-0000-0000-0000-000000000031",\
        "deviceID":"00000000-0000-0000-0000-0000000000d1","counter":3},\
        "outcome":"committedTwice","facts":[],"reason":"x","globalRevision":0,"opportunityRevision":1}
        """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(OpportunityActionReceipt.self, from: unknownOutcome)
        }
    }

    @Test("The fence snapshot itself is Codable without inventing historical identity")
    func fenceStateCodableRoundTrip() throws {
        var reducer = OpportunityActionReducer()
        var engine = try fenceTestEngine()
        let envelope = try fenceTestEnvelope(
            .mergedAccept,
            scope: .merged(
                visualCycle: ClockCycleID(scope: .visual, rawValue: 0),
                movementCycle: ClockCycleID(scope: .movement, rawValue: 0),
            ),
            actionUUID: "10000000-0000-0000-0000-000000000041",
            counter: 21,
        )
        #expect(reducer.reduce(envelope, on: &engine, atTicks: 1000).outcome == .committed)
        reducer.noteSessionRotation()

        let snapshot = reducer.fenceState
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(CoordinatorFenceState.self, from: data)
        #expect(decoded == snapshot)
        // Authorship survives the round-trip: the authoring device and its
        // gap-free counter ride along with the receipt, never regenerated.
        let restoredAction = try #require(decoded.committedActions.keys.first)
        #expect(restoredAction.deviceID == fenceTestDevice)
        #expect(restoredAction.counter == 21)
    }

    @Test("Relaunch starts clean: the courtesy runway is in-memory-only per the no-catch-up rule")
    func relaunchStartsCleanWithoutCourtesy() throws {
        // Contract citation: INTERACTION_SPEC relaunch ("restored clocks
        // return ... and never catch up unobserved wall time") and the
        // ProtocolStateStore seam ("without the estimator's monotonic
        // baseline"; "without a wall-clock catch-up anchor"). The runway is
        // anchored to monotonic uptime, which dies with the process, so only
        // counters persist.
        var engine = ProtocolEngine(configuration: try fenceCourtesyConfiguration())
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        let away = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])

        let saved = engine.state
        var relaunched = ProtocolEngine(configuration: try fenceCourtesyConfiguration(), state: saved)
        #expect(relaunched.state.visualClock == saved.visualClock)
        #expect(relaunched.state.movementClock == saved.movementClock)

        // Fresh-boot samples re-anchor; the dead epoch's runway must not
        // hold the visual clock back on its normal schedule.
        _ = relaunched.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        var sawDue = false
        var uptime: TimeInterval = 10
        while uptime <= 150 {
            let output = relaunched.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            if relaunched.visualClock.phase == .readyToPresent
                || output.presentation == .visual
                || output.presentation == .merged
            {
                sawDue = true
                break
            }
            uptime += 10
        }
        #expect(sawDue, "A persisted courtesy anchor would hold visual past its normal due")
    }

    @Test("A tampered payload with duplicate records throws instead of trapping")
    func duplicatedRecordsThrowInsteadOfTrapping() throws {
        var reducer = OpportunityActionReducer()
        var engine = try fenceTestEngine()
        let offer = try fenceTestEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "10000000-0000-0000-0000-000000000031",
            counter: 1,
        )
        #expect(reducer.reduce(offer, on: &engine, atTicks: 1000).outcome == .committed)
        let merged = try fenceTestEnvelope(
            .mergedAccept,
            scope: .merged(
                visualCycle: ClockCycleID(scope: .visual, rawValue: 0),
                movementCycle: ClockCycleID(scope: .movement, rawValue: 0),
            ),
            actionUUID: "10000000-0000-0000-0000-000000000032",
            counter: 2,
            revision: 1,
        )
        #expect(reducer.reduce(merged, on: &engine, atTicks: 1000).outcome == .committed)
        let valid = String(decoding: try JSONEncoder().encode(reducer.fenceState), as: UTF8.self)

        // Every keyed map in the fence fails closed: a second record for
        // one key decodes to a thrown error, never a launch-path trap in
        // `Dictionary(uniqueKeysWithValues:)`.
        for mapKey in ["opportunityRevisions", "projectionEpochs", "committedActions", "mergedSessions"] {
            let tampered = try #require(duplicateFirstRecord(in: valid, arrayKey: mapKey))
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(
                    CoordinatorFenceState.self,
                    from: Data(tampered.utf8),
                )
            }
        }
    }
}
// MARK: - Harness (deterministic owner-named fixtures; all identity injected)

/// Duplicates the first element of the JSON array under `arrayKey`, returning
/// the tampered document, or nil when the array is absent or empty. The scan
/// respects string literals and escapes, so the duplicate is byte-exact.
private func duplicateFirstRecord(in document: String, arrayKey: String) -> String? {
    let needle = "\"\(arrayKey)\":["
    guard let keyRange = document.range(of: needle) else { return nil }
    var index = keyRange.upperBound
    var depth = 1
    var inString = false
    var escaped = false
    let chars = document
    var end = document.endIndex
    var cursor = index
    while cursor < chars.endIndex {
        let char = chars[cursor]
        if inString {
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                inString = false
            }
        } else if char == "\"" {
            inString = true
        } else if char == "[" || char == "{" {
            depth += 1
        } else if char == "]" || char == "}" {
            depth -= 1
            if depth == 0 {
                end = cursor
                break
            }
        }
        cursor = chars.index(after: cursor)
    }
    guard depth == 0, index < end else { return nil }
    let inner = document[index ..< end]
    guard !inner.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
    var tampered = document
    tampered.replaceSubrange(index ..< end, with: "\(inner),\(inner)")
    return tampered
}

private let fenceTestOpportunity = OpportunityID(UUID(uuidString: "10000000-0000-0000-0000-000000000001")!)
private let fenceTestDevice = DeviceID(uuid: UUID(uuidString: "10000000-0000-0000-0000-0000000000d1")!)
private let fenceTestEpoch = ProjectionEpochID(uuid: UUID(uuidString: "10000000-0000-0000-0000-00000000e001")!)

private func fenceTestEngine() throws -> ProtocolEngine {
    try ProtocolEngine(
        configuration: ProtocolConfiguration(
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
        ),
        visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1500, phase: .readyToPresent),
        movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 3600, phase: .readyToPresent),
    )
}

private func fenceCourtesyConfiguration() throws -> ProtocolConfiguration {
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
            durationOptionsSeconds: [12, 6],
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
            snoozeOptionsSeconds: [3, 6, 9],
            maximumRepeatedEscalations: 1,
            lockoutAllowed: false,
        ),
    )
}

private func fenceTestLease(
    revision: UInt64 = 0,
    generation: CoordinatorGeneration = CoordinatorGeneration(0),
    projectionEpoch: ProjectionEpochID? = fenceTestEpoch,
) throws -> OpportunityLease {
    try OpportunityLease(
        scope: .opportunity(id: fenceTestOpportunity, revision: revision),
        generation: generation,
        grantedDeviceID: fenceTestDevice,
        grantedTicks: 1000,
        expiryTicks: 1090,
        projectionEpoch: projectionEpoch,
    )
}

private func fenceTestEnvelope(
    _ kind: OpportunityActionKind,
    scope: OpportunityActionScope,
    actionUUID: String,
    counter: UInt64,
    originPhase: OpportunityActionPhase? = .offered,
    generation: CoordinatorGeneration = CoordinatorGeneration(0),
    projectionEpoch: ProjectionEpochID? = fenceTestEpoch,
    revision: UInt64 = 0,
    payload: OpportunityActionPayload = OpportunityActionPayload(),
) throws -> OpportunityActionEnvelope {
    OpportunityActionEnvelope(
        action: ActionID(uuid: UUID(uuidString: actionUUID)!, deviceID: fenceTestDevice, counter: counter),
        kind: kind,
        scope: scope,
        originRevision: revision,
        generation: generation,
        projectionEpoch: projectionEpoch,
        originPhase: originPhase,
        segmentID: nil,
        causalParents: [],
        lease: try fenceTestLease(revision: revision, generation: generation, projectionEpoch: projectionEpoch),
        payload: payload,
    )
}
