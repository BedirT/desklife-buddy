import Domain
import Foundation
import StatusMenu
import Testing
@testable import App

@Suite("Protocol runtime")
struct ProtocolRuntimeTests {
    @Test("Restore publishes retained counters without inventing elapsed use")
    func restore() async throws {
        let retained = ProtocolState(
            profileID: .balanced,
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 900),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 1800),
        )
        let store = RuntimeStore(state: retained)
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 100) },
            makeID: { UUID(0) },
        )

        try await runtime.restore()

        #expect(runtime.state == retained)
        #expect(runtime.statusContext.estimatedActiveUseSeconds == 1800)
        #expect(store.commits.isEmpty)
    }

    @Test("Restore rotates recovery only after a retained offline session gap")
    func restoreRecoverySessionBoundary() async throws {
        let debt = RecoveryState(
            accumulatedEligibleActiveUseSeconds: 5400,
            movementDeferralCount: 2,
            wasOfferedThisSession: true,
        )
        let staleStore = RuntimeStore(state: ProtocolState(
            recoveryState: debt,
            recoveryLastObservedAt: Date(timeIntervalSince1970: 100),
        ))
        let staleRuntime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: staleStore,
            now: { Date(timeIntervalSince1970: 400) },
            makeID: { UUID(0) },
        )

        try await staleRuntime.restore()

        #expect(staleRuntime.state.recoveryState == RecoveryState())
        #expect(staleStore.commits.count == 1)

        let currentStore = RuntimeStore(state: ProtocolState(
            recoveryState: debt,
            recoveryLastObservedAt: Date(timeIntervalSince1970: 200),
        ))
        let currentRuntime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: currentStore,
            now: { Date(timeIntervalSince1970: 400) },
            makeID: { UUID(0) },
        )

        try await currentRuntime.restore()

        #expect(currentRuntime.state.recoveryState == debt)
        #expect(currentStore.commits.isEmpty)
    }

    @Test("Scheduling stays fact-free until delivery acknowledgement commits promptPresented")
    func observe() async throws {
        let store = RuntimeStore()
        let ids = IDSequence()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            headsUpRuntimePolicy: HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1),
            now: { Date(timeIntervalSince1970: 200) },
            makeID: { ids.next() },
        )
        try await runtime.restore()
        store.commits.removeAll()

        try await runtime.observe(ActivitySample(
            uptimeSeconds: 10,
            secondsSinceInput: 0,
            systemAwake: true,
            sessionActive: true,
            screenLocked: false,
        ))
        for uptime in stride(from: 100.0, through: 1450.0, by: 90.0) {
            try await runtime.observe(ActivitySample(
                uptimeSeconds: uptime,
                secondsSinceInput: 0,
                systemAwake: true,
                sessionActive: true,
                screenLocked: false,
            ))
        }
        try await runtime.observe(ActivitySample(
            uptimeSeconds: 1490,
            secondsSinceInput: 0,
            systemAwake: true,
            sessionActive: true,
            screenLocked: false,
        ))

        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 1480)
        #expect(store.commits.count == 18)
        #expect(store.commits.last?.events.isEmpty == true)
        #expect(runtime.statusContext.liveHeadsUp == .visual)

        try await runtime.observeHeadsUp(HeadsUpDeliverySnapshot(
            opportunity: .visual(cycleID: 0),
            currentVisualCycleID: 0,
            currentMovementCycleID: 0,
            observedAt: Date(timeIntervalSince1970: 200),
            secondsUntilTarget: 20,
            secondsUntilLatest: 100,
            headsUpEnabled: true,
            headsUpLeadSeconds: 45,
            waitsForLowFrictionMoment: false,
            isLowFrictionMoment: true,
        ))
        try await runtime.acknowledgeHeadsUpPresented(
            HeadsUpDeliveryID(rawValue: UUID(0)),
            channel: .capsule,
        )

        let promptCommit = store.commits.last { !$0.events.isEmpty }
        #expect(promptCommit?.events.map(\.kind) == [.promptPresented])
        #expect(promptCommit?.events.map(\.opportunity) == [.visual])
        #expect(promptCommit?.events.first?.recordedAt == Date(timeIntervalSince1970: 200))
    }

    @Test("Recovery delivery acknowledgement atomically latches the once-per-session offer")
    func recoveryDeliveryAcknowledgement() async throws {
        let retained = ProtocolState(
            recoveryState: RecoveryState(
                accumulatedEligibleActiveUseSeconds: 5400,
                movementDeferralCount: 2,
            ),
        )
        let store = RuntimeStore(state: retained)
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 250) },
            makeID: { UUID(0) },
        )
        try await runtime.restore()

        try await runtime.acknowledgeRecoveryPromptPresented()

        #expect(store.commits.last?.events.map(\.kind) == [.promptPresented])
        #expect(store.commits.last?.events.map(\.opportunity) == [.recovery])
        #expect(runtime.state.recoveryState.wasOfferedThisSession)
    }

    @Test("Menu pause and resume alter presentation context without logging fake break completion")
    func pauseAndResume() async throws {
        let store = RuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 300) },
            makeID: { UUID(0) },
        )
        try await runtime.restore()

        try await runtime.handle(.pause(.untilResume))
        #expect(runtime.statusContext.activeSuppression == .manualPause)
        #expect(store.commits.isEmpty)

        try await runtime.handle(.resume)
        #expect(runtime.statusContext.activeSuppression == nil)
        #expect(store.commits.isEmpty)
    }

    @Test("A timed pause publishes its real deadline instead of claiming it lasts until resume")
    func timedPauseDeadline() async throws {
        let store = RuntimeStore()
        let now = Date(timeIntervalSince1970: 300)
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { now },
            makeID: { UUID(0) },
        )
        try await runtime.restore()

        try await runtime.handle(.pause(.thirtyMinutes))

        #expect(runtime.statusContext.manualPause == .until(now.addingTimeInterval(1800)))
    }

    @Test("An unavailable public system sample immediately supplies the honest quiet reason")
    func unavailableSystem() async throws {
        let store = RuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 400) },
            makeID: { UUID(0) },
        )
        try await runtime.restore()

        try await runtime.observe(ActivitySample(
            uptimeSeconds: 10,
            secondsSinceInput: 0,
            systemAwake: false,
            sessionActive: true,
            screenLocked: false,
        ))

        #expect(runtime.statusContext.activeSuppression == .systemInactiveOrLocked)
        #expect(runtime.state.visualClock.phase == .suppressed(.systemInactiveOrLocked))
        #expect(runtime.state.movementClock.phase == .suppressed(.systemInactiveOrLocked))
    }

    @Test("A visual reset persists its open and timer facts while resetting only the visual clock")
    func visualResetTimerLifecycle() async throws {
        let retained = ProtocolState(
            profileID: .balanced,
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 900),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 1800),
        )
        let store = RuntimeStore(state: retained)
        let ids = IDSequence()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 500) },
            makeID: { ids.next() },
        )
        try await runtime.restore()

        try await runtime.handleVisualReset(.opened)
        try await runtime.handleVisualReset(.timerFinished)

        #expect(store.commits.map(\.events.first?.kind) == [.breakStarted, .timerFinished])
        #expect(store.commits.map(\.events.first?.source) == [.user, .localTimer])
        #expect(store.commits.allSatisfy { $0.events.count == 1 })
        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 1800)
    }

    @Test("Done early persists the user's visual completion declaration")
    func visualResetDoneEarly() async throws {
        try await expectVisualResetFact(
            event: .doneEarly,
            kind: .userDeclaredCompleted,
        )
    }

    @Test("Skip persists the user's visual skip without manufacturing completion")
    func visualResetSkipped() async throws {
        try await expectVisualResetFact(event: .skipped, kind: .skipped)
    }

    @Test("A failed visual lifecycle commit leaves the published reducer state unchanged")
    func visualResetCommitFailure() async throws {
        let retained = ProtocolState(
            profileID: .balanced,
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 900),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 1800),
        )
        let store = RuntimeStore(state: retained, failuresRemaining: 1)
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 700) },
            makeID: { UUID(0) },
        )
        try await runtime.restore()

        await #expect(throws: RuntimeStore.Failure.self) {
            try await runtime.handleVisualReset(.opened)
        }

        #expect(runtime.state == retained)
        #expect(store.commits.isEmpty)
        #expect(store.state == retained)
    }

    @Test("A failed visual terminal commit can be retried through the lifecycle queue")
    func visualResetTerminalCommitRetry() async throws {
        let store = RuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 800) },
            makeID: { UUID(0) },
        )
        let queue = VisualResetLifecycleQueue()
        try await runtime.restore()

        queue.enqueue(.opened) { event in
            try await runtime.handleVisualReset(event)
        }
        let openingFailure = await queue.drain()
        #expect(openingFailure == nil)

        store.failuresRemaining = 1
        queue.enqueue(.doneEarly) { event in
            try await runtime.handleVisualReset(event)
        }
        let terminalFailure = await queue.drain()
        #expect(terminalFailure is RuntimeStore.Failure)

        queue.enqueue(.doneEarly) { event in
            try await runtime.handleVisualReset(event)
        }
        let retryFailure = await queue.drain()
        #expect(retryFailure == nil)

        #expect(store.commitAttempts == 3)
        #expect(store.commits.map { $0.events.map(\.kind) } == [
            [.breakStarted],
            [.userDeclaredCompleted],
        ])
    }

    private func expectVisualResetFact(
        event: VisualResetLifecycleEvent,
        kind: OpportunityEventKind,
    ) async throws {
        let store = RuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 600) },
            makeID: { UUID(0) },
        )
        try await runtime.restore()

        try await runtime.handleVisualReset(event)

        #expect(store.commits.count == 1)
        #expect(store.commits.first?.events.map(\.kind) == [kind])
        #expect(store.commits.first?.events.first?.source == .user)
        #expect(store.commits.first?.events.first?.opportunity == .visual)
    }
}

final class RuntimeStore: ProtocolRuntimeStore {
    enum Failure: Error {
        case requested
    }

    struct Commit {
        let events: [OpportunityEvent]
        let state: ProtocolState
    }

    var state: ProtocolState?
    var commits: [Commit] = []
    var commitAttempts = 0
    var failuresRemaining: Int

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

final class IDSequence {
    private var value: UInt8 = 0

    func next() -> UUID {
        defer { value += 1 }
        return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

private extension UUID {
    init(_ value: UInt8) {
        self.init(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
