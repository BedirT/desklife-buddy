import Foundation
import Testing
@testable import Domain

/// Pins the current opportunity arbitration and reduction behavior at the public
/// engine seam. These tests change no behavior: they freeze the selection
/// (merged vs standalone vs recovery), the record/event-effect dispatch, and the
/// exact observe/restore call sequences the runtime performs, so the coordinator
/// cutover can prove parity.
@Suite("Opportunity arbitration characterization")
struct OpportunityArbitrationCharacterizationTests {
    private let configuration: ProtocolConfiguration

    init() throws {
        configuration = try Self.makeConfiguration()
    }

    @Test("Both due inside the merge window yields one merged presentation")
    func mergedWhenBothDueInsideWindow() throws {
        var engine = try ProtocolEngine(configuration: Self.makeConfiguration(movementTarget: 25))
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        let merged = engine.observe(
            .active(uptimeSeconds: 20, secondsSinceInput: 0),
            isLowFrictionMoment: true,
        )

        #expect(merged.events.isEmpty)
        #expect(merged.presentation == .merged)
    }

    @Test("Movement outside the merge window leaves a standalone visual presentation")
    func standaloneVisualWhenOutsideWindow() throws {
        var engine = try ProtocolEngine(configuration: Self.makeConfiguration(movementTarget: 26))
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        let visual = engine.observe(
            .active(uptimeSeconds: 20, secondsSinceInput: 0),
            isLowFrictionMoment: true,
        )

        #expect(visual.presentation == .visual)
    }

    @Test("Movement wins when both clocks are presentable outside the merge window")
    func movementWinsWhenBothPresentableOutsideWindow() throws {
        let configuration = try Self.makeConfiguration(mergeWindowSeconds: 0)
        var engine = ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                cycleID: 0,
                accumulatedActiveUseSeconds: 19,
                phase: .accumulating,
            ),
            movementClock: OpportunityClockState(
                cycleID: 0,
                accumulatedActiveUseSeconds: 55,
                phase: .accumulating,
            ),
        )
        let output = engine.observe(
            .active(uptimeSeconds: 0, secondsSinceInput: 0),
            isLowFrictionMoment: true,
        )

        #expect(engine.visualClock.phase == .headsUpPresented)
        #expect(engine.movementClock.phase == .readyToPresent)
        #expect(output.presentation == .movement)
    }

    @Test("Either presentable clock inside the merge window yields merged")
    func mergedWhenEitherPresentableInsideWindow() throws {
        var engine = ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                cycleID: 0,
                accumulatedActiveUseSeconds: 19,
                phase: .accumulating,
            ),
            movementClock: OpportunityClockState(
                cycleID: 0,
                accumulatedActiveUseSeconds: 55,
                phase: .accumulating,
            ),
        )
        let output = engine.observe(
            .active(uptimeSeconds: 0, secondsSinceInput: 0),
            isLowFrictionMoment: true,
        )

        #expect(output.presentation == .merged)
    }

    @Test("Eligible recovery preempts an otherwise due actionable opportunity")
    func recoveryPreemptsActionable() throws {
        let configuration = try Self.makeConfiguration(recoveryDeferrals: 2, recoveryAfter: 90)
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 89, secondsSinceInput: 0))
        _ = engine.snooze(.movement, durationSeconds: 3, at: Date(timeIntervalSince1970: 0))
        _ = engine.record(.skipped, opportunity: .movement)

        let eligible = engine.observe(.active(uptimeSeconds: 90, secondsSinceInput: 0))

        // The skip resets the movement clock, so recovery preempts even while
        // no actionable clock is due.
        #expect(engine.movementClock.phase == .accumulating)
        #expect(eligible.presentation == .recovery)
    }

    @Test("Visual not-appropriate leaves a standalone movement presentation")
    func visualNotAppropriateLeavesMovement() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 55, secondsSinceInput: 0))

        let output = engine.record(.notAppropriate, opportunity: .visual, source: .user)

        #expect(output.events.map(\.kind) == [.notAppropriate])
        #expect(output.presentation == .movement)
    }

    @Test("Record emits its distinct fact and recomputes the presentation")
    func recordEmitsDistinctFact() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 7, secondsSinceInput: 0))

        let output = engine.record(.breakStarted, opportunity: .movement, selectedDurationSeconds: 6)

        #expect(output.events.count == 1)
        #expect(output.events.map(\.kind) == [.breakStarted])
        #expect(output.events.map(\.opportunity) == [.movement])
        #expect(output.events.map(\.source) == [.user])
        #expect(engine.movementClock.phase == .running)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 7)
    }

    @Test("Invalid record kinds emit no fact")
    func invalidRecordEmitsNothing() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))

        let output = engine.record(.snoozed, opportunity: .visual, source: .user)

        #expect(output.events.isEmpty)
    }

    @Test("Snooze, select-movement, and merged-skip reductions keep their outputs")
    func resolutionReductions() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 20, secondsSinceInput: 0))

        let snoozed = engine.snooze(.visual, durationSeconds: 3, at: Date(timeIntervalSince1970: 100))
        #expect(snoozed.events.map(\.kind) == [.snoozed])
        #expect(engine.visualClock.phase == .snoozed)

        let selected = engine.selectMovement(durationSeconds: 6)
        #expect(selected.events.map(\.kind) == [.breakStarted])
        #expect(engine.movementClock.phase == .running)

        var merged = ProtocolEngine(configuration: configuration)
        _ = merged.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = merged.observe(.active(uptimeSeconds: 55, secondsSinceInput: 0))
        let skipped = merged.skipMergedSegment(.visual)
        #expect(skipped.events.map(\.kind) == [.skipped])
        #expect(merged.visualClock.phase == .gracedAfterSuppression)
    }

    @Test("Runtime observe sequence preserves phases and presentation")
    func runtimeObserveSequence() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 5, secondsSinceInput: 0))

        // Mirrors ProtocolRuntime.observe: recovery-session boundary, snooze
        // expiry, then the coarse observation itself.
        engine.observeRecoverySession(at: Date(timeIntervalSince1970: 1000), systemAvailable: true)
        let resumed = engine.resumeExpiredSnoozes(at: Date(timeIntervalSince1970: 1000))
        let output = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        #expect(resumed.events.isEmpty)
        #expect(output.events.isEmpty)
        #expect(output.presentation == nil)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 10)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 10)
    }

    @Test("Runtime restore sequence repairs running breaks without inferring use")
    func runtimeRestoreSequence() {
        var engine = ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                cycleID: 0,
                accumulatedActiveUseSeconds: 7,
                phase: .running,
            ),
            movementClock: OpportunityClockState(
                cycleID: 0,
                accumulatedActiveUseSeconds: 7,
                phase: .running,
            ),
        )

        // Mirrors ProtocolRuntime.restore: interrupted-break repair, offline
        // boundary, then retained-snooze expiry.
        engine.resumeInterruptedBreak()
        engine.resumeRecoverySession(at: Date(timeIntervalSince1970: 1000))
        let resumed = engine.resumeExpiredSnoozes(at: Date(timeIntervalSince1970: 1000))

        #expect(engine.visualClock.phase == .gracedAfterSuppression)
        #expect(engine.movementClock.phase == .gracedAfterSuppression)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 7)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 7)
        #expect(resumed.events.isEmpty)
        #expect(resumed.presentation == nil)
    }

    private static func makeConfiguration(
        movementTarget: TimeInterval = 50,
        mergeWindowSeconds: TimeInterval = 5,
        recoveryDeferrals: Int? = nil,
        recoveryAfter: TimeInterval = 90,
    ) throws -> ProtocolConfiguration {
        try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 10,
                targetSeconds: 20,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: min(15, movementTarget),
                targetSeconds: movementTarget,
                latestPreferredSeconds: max(60, movementTarget),
                durationOptionsSeconds: [12, 6],
            ),
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 60,
                longIdleResetSeconds: 300,
                wakeUnlockGraceSeconds: 90,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: true,
                mergeWindowSeconds: mergeWindowSeconds,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 2,
                snoozeOptionsSeconds: [3, 6, 9],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
            recovery: recoveryDeferrals.map {
                try RecoveryConfiguration(
                    eligibleAfterSeconds: recoveryAfter,
                    requiredMovementDeferrals: $0,
                )
            },
        )
    }
}
