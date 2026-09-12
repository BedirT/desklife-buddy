import Domain
import Foundation
import Testing
@testable import App

/// Story 2.6 RED: single-coordinator App wiring.
///
/// Fails pre-implementation:
/// - production dispatch sites construct throwaway coordinators, so rotation
///   evidence never reaches a live reducer (ownership tests);
/// - merged Escape retains both clocks instead of the canonical D-043
///   `merged.escape_during_visual` effect (Escape tests);
/// - saves persist `engine.state` with an empty fence, so a committed
///   ActionID recommits after restore instead of replaying (fence tests).
@Suite("Protocol coordinator wiring")
struct ProtocolCoordinatorWiringTests {
    @Test("Rotation evidence advances the single owned coordinator generation")
    func rotationAdvancesOwnedGeneration() async throws {
        let store = WiringStore()
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        #expect(runtime.coordinator.actionReducer.generation == CoordinatorGeneration(0))

        try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        try await runtime.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        try await runtime.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))

        #expect(store.commits.last?.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(runtime.coordinator.actionReducer.generation == CoordinatorGeneration(1))
    }

    @Test("Every route shares one coordinator engine and published state")
    func routesShareOneCoordinator() async throws {
        let store = WiringStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()

        try await runtime.handleVisualReset(.opened)
        try await runtime.handleMovement(.opened, openingSource: .user)
        try await runtime.handleMovement(.skipped)

        #expect(runtime.coordinator.engine.state == runtime.state)
        #expect(runtime.coordinator.state == runtime.state)
    }
}

@Suite("Merged Escape canonical effect")
struct MergedEscapeCanonicalTests {
    // D-043 `timing_runtime_v2.yaml` action_contract `merged.escape_during_visual`:
    // clocks {visual: fresh_cycle, movement: fresh_cycle, recovery: deferral_increment},
    // facts [skipped], visible closed_immediately.

    @Test("Escape during the visual segment freshens both cycles with one deferral and one skip")
    func escapeDuringVisual() async throws {
        let store = WiringStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)

        try await runtime.handleMerged(.skipped)

        #expect(runtime.state.visualClock == OpportunityClockState(cycleID: 1))
        #expect(runtime.state.movementClock == OpportunityClockState(cycleID: 1))
        #expect(runtime.state.recoveryState.movementDeferralCount == 1)
        #expect(store.commits.last?.events.map(\.kind) == [.skipped])
        #expect(store.commits.last?.events.map(\.opportunity) == [.visual])

        try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        #expect(runtime.statusContext.liveHeadsUp == nil)
    }

    @Test("Break-flow merged Skip during the visual segment applies the canonical effect")
    func breakFlowMergedSkipDuringVisual() async throws {
        let store = WiringStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        store.commits.removeAll()

        try await runtime.handleBreakFlow(.skip(scope: .merged))

        let commit = try #require(store.commits.first)
        #expect(commit.events.map(\.kind) == [.skipped])
        #expect(commit.events.map(\.opportunity) == [.visual])
        #expect(commit.state.visualClock == OpportunityClockState(cycleID: 1))
        #expect(commit.state.movementClock == OpportunityClockState(cycleID: 1))
        #expect(commit.state.recoveryState.movementDeferralCount == 1)
    }

    @Test("Heads-up merged Skip applies the canonical effect")
    func headsUpMergedSkip() async throws {
        let store = WiringStore(state: dueState)
        let runtime = try makeHeadsUpRuntime(store: store)
        try await runtime.restore()
        try await presentAndAcknowledge(runtime, opportunity: .merged(visualCycleID: 0, movementCycleID: 0))
        store.commits.removeAll()

        try await runtime.respondToHeadsUp(deliveryID(1), response: .skip)

        #expect(runtime.state.visualClock == OpportunityClockState(cycleID: 1))
        #expect(runtime.state.movementClock == OpportunityClockState(cycleID: 1))
        #expect(runtime.state.recoveryState.movementDeferralCount == 1)
        #expect(store.commits.last?.events.map(\.kind) == [.skipped])
        #expect(store.commits.last?.events.map(\.opportunity) == [.visual])
    }
}

@Suite("Fence through save")
struct FenceThroughSaveTests {
    @Test("A committed ActionID saves its fence and replays after restore")
    func commitSaveRestoreResubmitReplays() async throws {
        let store = WiringStore()
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()

        let envelope = try skipEnvelope()
        let committed = runtime.coordinator.dispatchAction(envelope, atTicks: 1010)
        #expect(committed.receipt.outcome == .committed)
        #expect(committed.receipt.facts.map(\.kind) == [.skipped])

        try await runtime.persist([], state: runtime.coordinator.engine.state)
        let saved = try #require(store.commits.last?.state)
        #expect(saved.coordinatorFence.committedActions[envelope.action]?.outcome == .committed)

        let restoredStore = WiringStore(state: saved)
        let restored = try makeRuntime(store: restoredStore)
        try await restored.restore()
        #expect(restored.coordinator.actionReducer.fenceState == runtime.coordinator.actionReducer.fenceState)

        let replayed = restored.coordinator.dispatchAction(envelope, atTicks: 1010)
        #expect(replayed.receipt.outcome == .duplicateReplay)
        #expect(replayed.receipt.facts == committed.receipt.facts)
    }
}

@Suite("Persist failure rollback")
struct PersistFailureRollbackTests {
    // Story 2.6 F1: every dispatch-then-commit path snapshots the owned
    // coordinator (engine + fence) before its first dispatch and restores
    // both on any throw before publish. Each test fails the first store
    // write, retries, and proves the effect applied exactly once with the
    // session left pre-dispatch on the failed attempt.

    @Test("Movement open retries exactly once with the session untouched by the throw")
    func movementOpenRetriesExactlyOnce() async throws {
        let store = WiringStore()
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.failuresRemaining = 1

        await #expect(throws: WiringStore.Failure.self) {
            try await runtime.handleMovement(.opened, openingSource: .user)
        }
        #expect(store.commits.isEmpty)
        #expect(runtime.lifecycleSession == nil)

        try await runtime.handleMovement(.opened, openingSource: .user)

        #expect(store.commits.count == 1)
        #expect(store.commits[0].events.map(\.kind) == [.breakStarted])
        #expect(store.commits[0].events.map(\.opportunity) == [.movement])
        #expect(runtime.lifecycleSession == .movement(selectedDuration: nil))
    }

    @Test("Break-flow snooze retries exactly once")
    func breakFlowSnoozeRetriesExactlyOnce() async throws {
        let store = WiringStore()
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.failuresRemaining = 1

        await #expect(throws: WiringStore.Failure.self) {
            try await runtime.handleBreakFlow(.snooze(scope: .visual, durationSeconds: 300))
        }
        #expect(store.commits.isEmpty)

        try await runtime.handleBreakFlow(.snooze(scope: .visual, durationSeconds: 300))

        #expect(store.commits.count == 1)
        #expect(store.commits[0].events.map(\.kind) == [.snoozed])
        #expect(store.commits[0].events.map(\.opportunity) == [.visual])
    }

    @Test("Observation retries without duplicating rotation evidence")
    func observeRetriesWithoutDuplication() async throws {
        let store = WiringStore()
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.failuresRemaining = 1

        await #expect(throws: WiringStore.Failure.self) {
            try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        }
        #expect(store.commits.isEmpty)

        try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        try await runtime.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        try await runtime.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))

        #expect(store.commits.last?.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(store.commits.count(where: { !$0.events.isEmpty }) == 1)
    }

    @Test("Merged Escape retries to cycle 1 and deferral 1, never 2")
    func mergedEscapeRetryAppliesExactlyOnce() async throws {
        // Adversarial sketch from the F1 brief: without rollback the failed
        // attempt leaves fresh cycles + deferral live, so the retry freshens
        // again (cycleID 1->2, deferral 1->2) with zero skip events stored.
        let store = WiringStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        store.commits.removeAll()
        store.failuresRemaining = 1

        await #expect(throws: WiringStore.Failure.self) {
            try await runtime.handleMerged(.skipped)
        }
        #expect(store.commits.isEmpty)
        #expect(runtime.lifecycleSession == .merged(segment: .visual, selectedDuration: nil))

        try await runtime.handleMerged(.skipped)

        #expect(store.commits.count == 1)
        #expect(store.commits[0].events.map(\.kind) == [.skipped])
        #expect(store.commits[0].events.map(\.opportunity) == [.visual])
        #expect(runtime.state.visualClock == OpportunityClockState(cycleID: 1))
        #expect(runtime.state.movementClock == OpportunityClockState(cycleID: 1))
        #expect(runtime.state.recoveryState.movementDeferralCount == 1)
    }

    @Test("Status snooze retries exactly once")
    func statusSnoozeRetriesExactlyOnce() async throws {
        let store = WiringStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        try #require(runtime.statusContext.liveHeadsUp != nil, "Due clocks must present a live heads-up to snooze")
        store.commits.removeAll()
        store.failuresRemaining = 1

        await #expect(throws: WiringStore.Failure.self) {
            try await runtime.snooze(300)
        }
        #expect(store.commits.isEmpty)

        try await runtime.snooze(300)

        #expect(store.commits.count == 1)
        // Both due clocks present merged, so one status snooze drafts a snooze
        // per covered opportunity (visual + movement).
        #expect(store.commits[0].events.map(\.kind) == [.snoozed, .snoozed])
    }
}

// MARK: - Fixtures

private var dueState: ProtocolState {
    ProtocolState(
        profileID: .balanced,
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

private func makeRuntime(store: WiringStore) throws -> ProtocolRuntime {
    try ProtocolRuntime(
        configuration: ProtocolProfiles.configuration(for: .balanced),
        store: store,
        now: { Date(timeIntervalSince1970: 1000) },
        makeID: { UUID(12) },
    )
}

private func makeHeadsUpRuntime(store: WiringStore) throws -> ProtocolRuntime {
    try ProtocolRuntime(
        configuration: ProtocolProfiles.configuration(for: .balanced),
        store: store,
        headsUpRuntimePolicy: HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1),
        now: { Date(timeIntervalSince1970: 100) },
        makeID: { deliveryID(1).rawValue },
    )
}

private func presentAndAcknowledge(
    _ runtime: ProtocolRuntime,
    opportunity: HeadsUpOpportunityID,
) async throws {
    try await runtime.observeHeadsUp(HeadsUpDeliverySnapshot(
        opportunity: opportunity,
        currentVisualCycleID: 0,
        currentMovementCycleID: 0,
        observedAt: Date(timeIntervalSince1970: 100),
        secondsUntilTarget: 45,
        secondsUntilLatest: 105,
        headsUpEnabled: true,
        headsUpLeadSeconds: 45,
        waitsForLowFrictionMoment: false,
        isLowFrictionMoment: true,
        suppressionReason: nil,
    ))
    try await runtime.acknowledgeHeadsUpPresented(deliveryID(1), channel: .capsule)
}

private func deliveryID(_ value: UInt8) -> HeadsUpDeliveryID {
    HeadsUpDeliveryID(rawValue: UUID(12, value))
}

private let fenceOpportunity = OpportunityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000F1")!)
private let fenceDevice = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!)
private let fenceEpoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!)
private let fenceAction = ActionID(
    uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!,
    deviceID: fenceDevice,
    counter: 1,
)

private func skipEnvelope() throws -> OpportunityActionEnvelope {
    let lease = try OpportunityLease(
        scope: .opportunity(id: fenceOpportunity, revision: 0),
        generation: CoordinatorGeneration(0),
        grantedDeviceID: fenceDevice,
        grantedTicks: 1000,
        expiryTicks: 1090,
        projectionEpoch: fenceEpoch,
    )
    return OpportunityActionEnvelope(
        action: fenceAction,
        kind: .visualSkip,
        scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
        originRevision: 0,
        generation: CoordinatorGeneration(0),
        projectionEpoch: fenceEpoch,
        originPhase: .offered,
        segmentID: nil,
        causalParents: [],
        lease: lease,
        payload: OpportunityActionPayload(),
    )
}

private final class WiringStore: ProtocolRuntimeStore {
    enum Failure: Error {
        case requested
    }

    struct Commit {
        let events: [OpportunityEvent]
        let state: ProtocolState
    }

    var state: ProtocolState?
    var commits: [Commit] = []
    var failuresRemaining: Int
    var commitAttempts = 0

    init(state: ProtocolState? = nil, failuresRemaining: Int = 0) {
        self.state = state
        self.failuresRemaining = failuresRemaining
    }

    func loadState() async throws -> ProtocolState? {
        state
    }

    func commit(events: [OpportunityEvent], state: ProtocolState) async throws {
        commitAttempts += 1
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw Failure.requested
        }
        commits.append(Commit(events: events, state: state))
        self.state = state
    }
}

private extension UUID {
    init(_ high: UInt8, _ low: UInt8 = 0) {
        self.init(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, high, low))
    }
}
