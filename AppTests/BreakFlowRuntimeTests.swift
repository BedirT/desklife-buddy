import BreakFlow
import Domain
import Foundation
import StatusMenu
import Testing
@testable import App

@Suite("Break flow runtime")
struct BreakFlowRuntimeTests {
    @Test("An explicit visual snooze retains its exact configured deadline")
    func visualSnooze() async throws {
        let store = BreakFlowRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.commits.removeAll()

        try await runtime.handleBreakFlow(.snooze(scope: .visual, durationSeconds: 300))

        let commit = try #require(store.commits.first)
        #expect(commit.events.map(\.kind) == [.snoozed])
        #expect(commit.events.map(\.opportunity) == [.visual])
        #expect(commit.events.map(\.selectedDurationSeconds) == [300])
        #expect(commit.state.visualSnoozeDeadline == now.addingTimeInterval(300))
        #expect(commit.state.movementSnoozeDeadline == nil)
        #expect(runtime.statusContext.liveHeadsUp == nil)
    }

    @Test("A merged snooze records both exact facts in one transaction")
    func mergedSnooze() async throws {
        let store = BreakFlowRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.commits.removeAll()

        try await runtime.handleBreakFlow(.snooze(scope: .merged, durationSeconds: 600))

        let commit = try #require(store.commits.first)
        #expect(store.commits.count == 1)
        #expect(commit.events.map(\.kind) == [.snoozed, .snoozed])
        #expect(commit.events.map(\.opportunity) == [.visual, .movement])
        #expect(commit.events.allSatisfy { $0.recordedAt == now })
        #expect(commit.state.visualSnoozeDeadline == now.addingTimeInterval(600))
        #expect(commit.state.movementSnoozeDeadline == now.addingTimeInterval(600))
    }

    @Test("An unconfigured snooze duration is rejected without persistence")
    func invalidSnooze() async throws {
        let store = BreakFlowRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.commits.removeAll()

        await #expect(throws: ProtocolLifecycleError.invalidSnoozeDuration) {
            try await runtime.handleBreakFlow(.snooze(scope: .movement, durationSeconds: 301))
        }

        #expect(store.commits.isEmpty)
        #expect(runtime.state == dueState)
    }

    @Test("Pause for one hour publishes the real deadline without a protocol fact")
    func pauseOneHour() async throws {
        let store = BreakFlowRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.commits.removeAll()

        try await runtime.handleBreakFlow(.pauseOneHour)

        #expect(runtime.statusContext.manualPause == .until(now.addingTimeInterval(3600)))
        #expect(store.commits.isEmpty)
    }

    @Test("Merged not-appropriate records both exact facts atomically")
    func mergedNotAppropriate() async throws {
        let store = BreakFlowRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.commits.removeAll()

        try await runtime.handleBreakFlow(.notAppropriate(scope: .merged))

        let commit = try #require(store.commits.first)
        #expect(store.commits.count == 1)
        #expect(commit.events.map(\.kind) == [.notAppropriate, .notAppropriate])
        #expect(commit.events.map(\.opportunity) == [.visual, .movement])
        #expect(commit.events.allSatisfy { $0.source == .user && $0.recordedAt == now })
        #expect(commit.state.notAppropriateOpportunities == [.visual, .movement])
        #expect(runtime.state.notAppropriateOpportunities == [.visual, .movement])
    }

    @Test("A failed merged not-appropriate transaction publishes neither choice")
    func mergedNotAppropriateFailure() async throws {
        let store = BreakFlowRuntimeStore(state: dueState, failuresRemaining: 1)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()

        await #expect(throws: BreakFlowRuntimeStore.Failure.requested) {
            try await runtime.handleBreakFlow(.notAppropriate(scope: .merged))
        }

        #expect(store.commits.isEmpty)
        #expect(store.state == dueState)
        #expect(runtime.state == dueState)
    }

    @Test("Standalone Skip resets only the typed opportunity cycle")
    func standaloneSkip() async throws {
        let store = BreakFlowRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.commits.removeAll()

        try await runtime.handleBreakFlow(.skip(scope: .visual))

        let commit = try #require(store.commits.first)
        #expect(commit.events.map(\.kind) == [.skipped])
        #expect(commit.events.map(\.opportunity) == [.visual])
        #expect(commit.state.visualClock == OpportunityClockState())
        #expect(commit.state.movementClock == dueState.movementClock)
    }

    @Test("Merged Skip retains the active unfinished segment clock")
    func mergedSkip() async throws {
        let store = BreakFlowRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        store.commits.removeAll()

        try await runtime.handleBreakFlow(.skip(scope: .merged))

        let commit = try #require(store.commits.first)
        #expect(commit.events.map(\.kind) == [.skipped])
        #expect(commit.events.map(\.opportunity) == [.visual])
        #expect(commit.state.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(commit.state.visualClock.phase == .gracedAfterSuppression)
        #expect(commit.state.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(commit.state.movementClock.phase == .gracedAfterSuppression)
    }

    @Test("Merged Skip before opening targets only the first visual segment")
    func mergedSkipBeforeOpening() async throws {
        let store = BreakFlowRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.commits.removeAll()

        try await runtime.handleBreakFlow(.skip(scope: .merged))

        let commit = try #require(store.commits.first)
        #expect(commit.events.map(\.kind) == [.skipped])
        #expect(commit.events.map(\.opportunity) == [.visual])
        #expect(commit.state.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(commit.state.movementClock.accumulatedActiveUseSeconds == 3600)
    }

    @Test("An exact calendar deadline stays unsupported until Domain can retain it")
    func unsupportedExactDeadline() async throws {
        let store = BreakFlowRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.commits.removeAll()

        await #expect(throws: BreakFlowRuntimeError.unsupportedExactDeadline) {
            try await runtime.handleBreakFlow(.snoozeUntil(
                scope: .visual,
                deadline: now.addingTimeInterval(420),
            ))
        }

        #expect(store.commits.isEmpty)
        #expect(runtime.state == dueState)
    }

    private var now: Date { Date(timeIntervalSince1970: 1000) }

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

    private func makeRuntime(store: BreakFlowRuntimeStore) throws -> ProtocolRuntime {
        try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { now },
            makeID: { UUID(12) },
        )
    }
}

private final class BreakFlowRuntimeStore: ProtocolRuntimeStore {
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

    init(state: ProtocolState? = nil, failuresRemaining: Int = 0) {
        self.state = state
        self.failuresRemaining = failuresRemaining
    }

    func loadState() async throws -> ProtocolState? {
        state
    }

    func commit(events: [OpportunityEvent], state: ProtocolState) async throws {
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw Failure.requested
        }
        commits.append(Commit(events: events, state: state))
        self.state = state
    }
}

private extension UUID {
    init(_ value: UInt8) {
        self.init(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
