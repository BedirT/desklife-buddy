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

    @Test("Observed active use commits the exhaustive event facts and state atomically")
    func observe() async throws {
        let store = RuntimeStore()
        let ids = IDSequence()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 200) },
            makeID: { ids.next() },
        )
        try await runtime.restore()

        try await runtime.observe(ActivitySample(
            uptimeSeconds: 10,
            secondsSinceInput: 0,
            systemAwake: true,
            sessionActive: true,
            screenLocked: false,
        ))
        try await runtime.observe(ActivitySample(
            uptimeSeconds: 1490,
            secondsSinceInput: 0,
            systemAwake: true,
            sessionActive: true,
            screenLocked: false,
        ))

        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 1480)
        #expect(store.commits.count == 2)
        #expect(store.commits.last?.events.map(\.kind) == [.promptPresented])
        #expect(store.commits.last?.events.first?.recordedAt == Date(timeIntervalSince1970: 200))
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

private final class RuntimeStore: ProtocolRuntimeStore {
    struct Commit {
        let events: [OpportunityEvent]
        let state: ProtocolState
    }

    var state: ProtocolState?
    var commits: [Commit] = []

    init(state: ProtocolState? = nil) {
        self.state = state
    }

    func loadState() async throws -> ProtocolState? {
        state
    }

    func commit(events: [OpportunityEvent], state: ProtocolState) async throws {
        commits.append(Commit(events: events, state: state))
        self.state = state
    }
}

private final class IDSequence {
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
