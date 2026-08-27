import Domain
import Foundation
import Testing
@testable import App

@Suite("Movement lifecycle runtime")
struct MovementLifecycleRuntimeTests {
    @Test("Movement lifecycle maps every typed action to one exact retained fact")
    func factMapping() async throws {
        let cases: [MovementFactCase] = [
            MovementFactCase(
                event: .opened,
                expected: Fact(
                    kind: .breakStarted,
                    source: .localTimer,
                    opportunity: .movement,
                    duration: nil,
                ),
            ),
            MovementFactCase(
                event: .timerFinished,
                expected: Fact(
                    kind: .timerFinished,
                    source: .localTimer,
                    opportunity: .movement,
                    duration: nil,
                ),
            ),
            MovementFactCase(
                event: .doneEarly,
                expected: Fact(
                    kind: .userDeclaredCompleted,
                    source: .user,
                    opportunity: .movement,
                    duration: nil,
                ),
            ),
            MovementFactCase(
                event: .alreadyMoved,
                expected: Fact(
                    kind: .userDeclaredAlreadyMoved,
                    source: .user,
                    opportunity: .movement,
                    duration: nil,
                ),
            ),
            MovementFactCase(
                event: .positionChanged,
                expected: Fact(
                    kind: .positionChanged,
                    source: .user,
                    opportunity: .positionChange,
                    duration: nil,
                ),
            ),
            MovementFactCase(
                event: .skipped,
                expected: Fact(
                    kind: .skipped,
                    source: .user,
                    opportunity: .movement,
                    duration: nil,
                ),
            ),
        ]

        for testCase in cases {
            let store = MovementRuntimeStore(state: dueState)
            let runtime = try makeRuntime(store: store)
            try await runtime.restore()

            if testCase.event != .opened {
                try await runtime.handleMovement(.opened, openingSource: .localTimer)
                store.commits.removeAll()
            }

            try await runtime.handleMovement(testCase.event, openingSource: .localTimer)

            #expect(store.commits.count == 1)
            #expect(store.commits.first?.events.map(Fact.init) == [testCase.expected])
        }
    }

    @Test("Automatic open and a finished timer do not infer movement completion")
    func automaticOpenAndTimerDoNotReset() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()

        try await runtime.handleMovement(.opened, openingSource: .localTimer)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 3600)

        try await runtime.handleMovement(.timerFinished)

        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(store.commits.flatMap(\.events).map(\.kind) == [.breakStarted, .timerFinished])
    }

    @Test(arguments: [300.0, 120.0])
    func acceptedExplicitDurationResetsOnlyMovement(duration: TimeInterval) async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMovement(.opened, openingSource: .localTimer)
        store.commits.removeAll()

        try await runtime.handleMovement(.selectedDuration(duration))

        #expect(store.commits.count == 1)
        #expect(store.commits.first?.events.map(Fact.init) == [Fact(
            kind: .breakStarted,
            source: .user,
            opportunity: .movement,
            duration: duration,
        )])
        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 0)
        #expect(runtime.state.movementClock.phase == .running)
    }

    @Test("The selected duration is retained only on its accepted movement-start fact")
    func selectedDurationIsCarriedByStartFact() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMovement(.opened, openingSource: .localTimer)
        try await runtime.handleMovement(.selectedDuration(120))
        store.commits.removeAll()

        try await runtime.handleMovement(.timerFinished)

        #expect(store.commits.count == 1)
        #expect(store.commits.first?.events.map(Fact.init) == [Fact(
            kind: .timerFinished,
            source: .localTimer,
            opportunity: .movement,
            duration: nil,
        )])
    }

    @Test(arguments: [299.0, 0.0, -1.0, .infinity, .nan])
    func invalidDurationNeverCommits(duration: TimeInterval) async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMovement(.opened, openingSource: .localTimer)
        let retainedAfterOpen = runtime.state
        store.commits.removeAll()

        await #expect(throws: ProtocolLifecycleError.invalidMovementDuration) {
            try await runtime.handleMovement(.selectedDuration(duration))
        }

        #expect(store.commits.isEmpty)
        #expect(store.state == retainedAfterOpen)
        #expect(runtime.state == retainedAfterOpen)
    }

    @Test("Position change is retained separately and never resets movement")
    func positionChangeDoesNotResetMovement() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMovement(.opened, openingSource: .localTimer)

        try await runtime.handleMovement(.positionChanged)

        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(store.commits.last?.events.map(Fact.init) == [Fact(
            kind: .positionChanged,
            source: .user,
            opportunity: .positionChange,
            duration: nil,
        )])
    }

    @Test("Standalone Escape records Skip and resets only its movement cycle")
    func standaloneSkipResetsMovement() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMovement(.opened, openingSource: .localTimer)

        try await runtime.handleMovement(.skipped)

        #expect(runtime.state.visualClock == dueState.visualClock)
        #expect(runtime.state.movementClock == OpportunityClockState(cycleID: 1))
        #expect(store.commits.last?.events.map(\.kind) == [.skipped])
    }

    @Test("A failed movement commit preserves the published engine and lifecycle session")
    func failedCommitPreservesEngine() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMovement(.opened, openingSource: .localTimer)
        let retainedAfterOpen = runtime.state
        store.commits.removeAll()
        store.failuresRemaining = 1

        await #expect(throws: MovementRuntimeStore.Failure.self) {
            try await runtime.handleMovement(.selectedDuration(300))
        }

        #expect(runtime.state == retainedAfterOpen)
        #expect(store.state == retainedAfterOpen)
        #expect(store.commits.isEmpty)

        try await runtime.handleMovement(.selectedDuration(300))
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 0)
    }

    @Test("Activity observations share the lifecycle transaction lane")
    func observationCannotOvertakeLifecycleCommit() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        store.commits.removeAll()
        store.commitAttempts.removeAll()
        store.gateNextCommit = true

        let opening = Task {
            try await runtime.handleMovement(.opened, openingSource: .localTimer)
        }
        guard await store.waitForAttemptCount(1) else {
            opening.cancel()
            Issue.record("Timed out waiting for the gated movement commit")
            return
        }

        let observation = Task {
            try await runtime.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(store.commitAttempts.count == 1)

        store.acknowledgeNextCommit()
        try await opening.value
        try await observation.value

        #expect(store.commits.map { $0.events.map(\.kind) } == [[.breakStarted], []])
        #expect(runtime.state.movementClock.phase == .running)
        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 1510)
    }

    @Test("Pause waits for an active observation and wins the final presentation state")
    func pauseCannotBeOverwrittenByObservation() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.gateNextCommit = true

        let observation = Task {
            try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        }
        guard await store.waitForAttemptCount(1) else {
            observation.cancel()
            Issue.record("Timed out waiting for the gated observation")
            return
        }

        let pause = Task {
            try await runtime.handle(.pause(.untilResume))
        }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(runtime.statusContext.activeSuppression == nil)

        store.acknowledgeNextCommit()
        try await observation.value
        try await pause.value

        #expect(runtime.statusContext.activeSuppression == .manualPause)
        #expect(runtime.statusContext.liveHeadsUp == nil)
    }

    @Test(arguments: [
        MovementLifecycleEvent.timerFinished,
        .doneEarly,
        .alreadyMoved,
        .positionChanged,
        .skipped,
    ])
    func terminalActionOutsideSessionIsRejected(event: MovementLifecycleEvent) async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()

        await #expect(throws: ProtocolLifecycleError.noActiveSession) {
            try await runtime.handleMovement(event)
        }

        #expect(store.commits.isEmpty)
        #expect(runtime.state == dueState)
    }

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

    private func makeRuntime(store: MovementRuntimeStore) throws -> ProtocolRuntime {
        try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 800) },
            makeID: { UUID(8) },
        )
    }
}

@Suite("Merged lifecycle runtime")
struct MergedLifecycleRuntimeTests {
    @Test("Merged snooze shares one action timestamp across both clocks and facts")
    func mergedSnoozeUsesOneTimestamp() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        store.commits.removeAll()

        try await runtime.handle(.snooze(300))

        let commit = try #require(store.commits.first)
        let actionDate = Date(timeIntervalSince1970: 900)
        let deadline = actionDate.addingTimeInterval(300)
        #expect(commit.events.map(\.kind) == [.snoozed, .snoozed])
        #expect(commit.events.allSatisfy { $0.recordedAt == actionDate })
        #expect(commit.state.visualSnoozeDeadline == deadline)
        #expect(commit.state.movementSnoozeDeadline == deadline)
    }

    @Test("Merged lifecycle persists visual then movement opening facts in order")
    func orderedSegments() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()

        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        try await runtime.handleMerged(.visualTimerFinished)

        #expect(store.commits.count == 2)
        #expect(store.commits[0].events.map(Fact.init) == [Fact(
            kind: .breakStarted,
            source: .localTimer,
            opportunity: .visual,
            duration: nil,
        )])
        #expect(store.commits[1].events.map(Fact.init) == [
            Fact(
                kind: .timerFinished,
                source: .localTimer,
                opportunity: .visual,
                duration: nil,
            ),
            Fact(
                kind: .breakStarted,
                source: .localTimer,
                opportunity: .movement,
                duration: nil,
            ),
        ])
        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 3600)
    }

    @Test("Done early during the visual segment records visual completion before movement opens")
    func visualDoneEarlyAdvancesToMovement() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        store.commits.removeAll()

        try await runtime.handleMerged(.doneEarly)

        #expect(store.commits.count == 1)
        #expect(store.commits[0].events.map(Fact.init) == [
            Fact(
                kind: .userDeclaredCompleted,
                source: .user,
                opportunity: .visual,
                duration: nil,
            ),
            Fact(
                kind: .breakStarted,
                source: .localTimer,
                opportunity: .movement,
                duration: nil,
            ),
        ])
        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 3600)

        try await runtime.handleMerged(.skipped)
        #expect(store.commits.last?.events.first?.opportunity == .movement)
    }

    @Test("Escape during the visual segment retains both unfinished clocks")
    func escapeDuringVisual() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)

        try await runtime.handleMerged(.skipped)

        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(runtime.state.visualClock.phase == .gracedAfterSuppression)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(runtime.state.movementClock.phase == .gracedAfterSuppression)
        #expect(store.commits.last?.events.map(Fact.init) == [Fact(
            kind: .skipped,
            source: .user,
            opportunity: .visual,
            duration: nil,
        )])

        try await runtime.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        #expect(runtime.statusContext.liveHeadsUp == nil)
    }

    @Test("Escape after visual completion retains visual effect and leaves movement due")
    func escapeDuringMovement() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        try await runtime.handleMerged(.visualTimerFinished)

        try await runtime.handleMerged(.skipped)

        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(runtime.state.movementClock.phase == .gracedAfterSuppression)
        #expect(store.commits.last?.events.map(Fact.init) == [Fact(
            kind: .skipped,
            source: .user,
            opportunity: .movement,
            duration: nil,
        )])
    }

    @Test("Choosing visual only retains the completed visual segment and movement due state")
    func visualOnly() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        try await runtime.handleMerged(.visualTimerFinished)

        try await runtime.handleMerged(.visualOnly)

        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(runtime.state.movementClock.phase == .gracedAfterSuppression)
        #expect(store.commits.last?.events.map(Fact.init) == [Fact(
            kind: .skipped,
            source: .user,
            opportunity: .movement,
            duration: nil,
        )])
    }

    @Test(arguments: [300.0, 120.0])
    func acceptedMergedMovementDurationResetsOnlyMovement(duration: TimeInterval) async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        try await runtime.handleMerged(.visualTimerFinished)
        store.commits.removeAll()

        try await runtime.handleMerged(.selectedDuration(duration))

        #expect(store.commits.count == 1)
        #expect(store.commits.first?.events.map(Fact.init) == [Fact(
            kind: .breakStarted,
            source: .user,
            opportunity: .movement,
            duration: duration,
        )])
        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds == 0)
        #expect(runtime.state.movementClock.phase == .running)
    }

    @Test("Merged movement terminal fact does not duplicate the selected start duration")
    func mergedTerminalDoesNotDuplicateDuration() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        try await runtime.handleMerged(.visualTimerFinished)
        try await runtime.handleMerged(.selectedDuration(300))
        store.commits.removeAll()

        try await runtime.handleMerged(.movementTimerFinished)

        #expect(store.commits.first?.events.map(Fact.init) == [Fact(
            kind: .timerFinished,
            source: .localTimer,
            opportunity: .movement,
            duration: nil,
        )])
    }

    @Test("Merged explicit completion and declaration facts keep movement semantics")
    func mergedMovementFactMapping() async throws {
        let cases: [(MergedLifecycleEvent, Fact)] = [
            (
                .doneEarly,
                Fact(
                    kind: .userDeclaredCompleted,
                    source: .user,
                    opportunity: .movement,
                    duration: nil,
                ),
            ),
            (
                .alreadyMoved,
                Fact(
                    kind: .userDeclaredAlreadyMoved,
                    source: .user,
                    opportunity: .movement,
                    duration: nil,
                ),
            ),
            (
                .positionChanged,
                Fact(
                    kind: .positionChanged,
                    source: .user,
                    opportunity: .positionChange,
                    duration: nil,
                ),
            ),
        ]

        for (event, expected) in cases {
            let store = MovementRuntimeStore(state: dueState)
            let runtime = try makeRuntime(store: store)
            try await runtime.restore()
            try await runtime.handleMerged(.opened, openingSource: .localTimer)
            try await runtime.handleMerged(.visualTimerFinished)
            store.commits.removeAll()

            try await runtime.handleMerged(event)

            #expect(store.commits.first?.events.map(Fact.init) == [expected])
        }
    }

    @Test(arguments: [299.0, 0.0, -1.0, .infinity, .nan])
    func invalidMergedDurationNeverCommits(duration: TimeInterval) async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        try await runtime.handleMerged(.visualTimerFinished)
        let retainedMovementSegment = runtime.state
        store.commits.removeAll()

        await #expect(throws: ProtocolLifecycleError.invalidMovementDuration) {
            try await runtime.handleMerged(.selectedDuration(duration))
        }

        #expect(store.commits.isEmpty)
        #expect(store.state == retainedMovementSegment)
        #expect(runtime.state == retainedMovementSegment)
    }

    @Test("A failed segment transition does not advance merged lifecycle state")
    func transitionFailurePreservesActiveSegment() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        let retainedAfterOpen = runtime.state
        store.commits.removeAll()
        store.failuresRemaining = 1

        await #expect(throws: MovementRuntimeStore.Failure.self) {
            try await runtime.handleMerged(.visualTimerFinished)
        }

        #expect(runtime.state == retainedAfterOpen)
        #expect(store.state == retainedAfterOpen)
        #expect(store.commits.isEmpty)

        try await runtime.handleMerged(.skipped)
        #expect(store.commits.last?.events.first?.opportunity == .visual)
    }

    @Test("A merged segment cannot accept a second action before persistence acknowledges the first")
    func persistenceAcknowledgementGatesNextAction() async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()
        try await runtime.handleMerged(.opened, openingSource: .localTimer)
        store.commits.removeAll()
        store.gateNextCommit = true

        let finish = Task {
            try await runtime.handleMerged(.visualTimerFinished)
        }
        guard await store.waitForAttemptCount(2) else {
            finish.cancel()
            Issue.record("Timed out waiting for the gated lifecycle commit")
            return
        }

        let escape = Task {
            try await runtime.handleMerged(.skipped)
        }
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        #expect(store.commitAttempts.count == 2)

        store.acknowledgeNextCommit()
        try await finish.value
        try await escape.value

        #expect(store.commits.map { $0.events.map(\.kind) } == [
            [.timerFinished, .breakStarted],
            [.skipped],
        ])
        #expect(store.commits.last?.events.first?.opportunity == .movement)
    }

    @Test(arguments: [
        MergedLifecycleEvent.visualTimerFinished,
        .selectedDuration(300),
        .movementTimerFinished,
        .doneEarly,
        .alreadyMoved,
        .positionChanged,
        .visualOnly,
        .skipped,
    ])
    func terminalOutsideSession(event: MergedLifecycleEvent) async throws {
        let store = MovementRuntimeStore(state: dueState)
        let runtime = try makeRuntime(store: store)
        try await runtime.restore()

        await #expect(throws: ProtocolLifecycleError.noActiveSession) {
            try await runtime.handleMerged(event)
        }

        #expect(store.commits.isEmpty)
        #expect(runtime.state == dueState)
    }

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

    private func makeRuntime(store: MovementRuntimeStore) throws -> ProtocolRuntime {
        try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 900) },
            makeID: { UUID(9) },
        )
    }
}

private struct MovementFactCase {
    let event: MovementLifecycleEvent
    let expected: Fact
}

private struct Fact: Equatable {
    let kind: OpportunityEventKind
    let source: OpportunityEventSource
    let opportunity: OpportunityType?
    let duration: TimeInterval?

    init(
        kind: OpportunityEventKind,
        source: OpportunityEventSource,
        opportunity: OpportunityType?,
        duration: TimeInterval?,
    ) {
        self.kind = kind
        self.source = source
        self.opportunity = opportunity
        self.duration = duration
    }

    init(_ event: OpportunityEvent) {
        self.init(
            kind: event.kind,
            source: event.source,
            opportunity: event.opportunity,
            duration: event.selectedDurationSeconds,
        )
    }
}

private final class MovementRuntimeStore: ProtocolRuntimeStore {
    enum Failure: Error {
        case requested
    }

    struct Commit {
        let events: [OpportunityEvent]
        let state: ProtocolState
    }

    var state: ProtocolState?
    var commits: [Commit] = []
    var commitAttempts: [Commit] = []
    var failuresRemaining = 0
    var gateNextCommit = false

    private var acknowledgement: CheckedContinuation<Void, Never>?

    init(state: ProtocolState? = nil) {
        self.state = state
    }

    func loadState() async throws -> ProtocolState? {
        state
    }

    func commit(events: [OpportunityEvent], state: ProtocolState) async throws {
        let commit = Commit(events: events, state: state)
        commitAttempts.append(commit)

        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw Failure.requested
        }
        if gateNextCommit {
            gateNextCommit = false
            await withCheckedContinuation { continuation in
                acknowledgement = continuation
            }
        }

        commits.append(commit)
        self.state = state
    }

    func waitForAttemptCount(_ count: Int) async -> Bool {
        for _ in 0 ..< 10000 {
            if commitAttempts.count >= count { return true }
            await Task.yield()
        }
        return false
    }

    func acknowledgeNextCommit() {
        acknowledgement?.resume()
        acknowledgement = nil
    }
}

private extension UUID {
    init(_ value: UInt8) {
        self.init(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
