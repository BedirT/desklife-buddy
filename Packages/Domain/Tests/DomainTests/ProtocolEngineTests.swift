import Foundation
import Testing
@testable import Domain

@Suite("Protocol engine")
struct ProtocolEngineTests {
    private let configuration: ProtocolConfiguration

    init() throws {
        configuration = try Self.makeConfiguration()
    }

    @Test("Eligible monotonic elapsed time advances both clocks independently")
    func accumulatesBothClocks() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        _ = engine.observe(.active(uptimeSeconds: 107, secondsSinceInput: 0))

        #expect(engine.visualClock.accumulatedActiveUseSeconds == 7)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 7)
    }

    @Test("Visual schedule crosses soft heads-up target and latest boundaries")
    func visualBoundaries() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))

        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        #expect(engine.visualClock.phase == .softDue)

        let headsUp = engine.observe(.active(uptimeSeconds: 18, secondsSinceInput: 0))
        #expect(engine.visualClock.phase == .headsUpPresented)
        #expect(headsUp.events.isEmpty)

        let delivered = engine.record(.promptPresented, opportunity: .visual)
        #expect(delivered.events.map(\.kind) == [.promptPresented])

        _ = engine.observe(.active(uptimeSeconds: 20, secondsSinceInput: 0))
        #expect(engine.visualClock.phase == .waitingForLowFrictionMoment)

        let latest = engine.observe(.active(uptimeSeconds: 30, secondsSinceInput: 0))
        #expect(engine.visualClock.phase == .readyToPresent)
        #expect(latest.presentation == .visual)
    }

    @Test("Low-friction target can release before latest")
    func lowFrictionRelease() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))

        let output = engine.observe(
            .active(uptimeSeconds: 20, secondsSinceInput: 0),
            isLowFrictionMoment: true,
        )

        #expect(engine.visualClock.phase == .readyToPresent)
        #expect(output.presentation == .visual)
    }

    @Test("Pause suppressions stop accumulation while context holds continue it")
    func suppressionAccumulationPolicy() {
        var paused = ProtocolEngine(configuration: configuration)
        _ = paused.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = paused.observe(
            .active(uptimeSeconds: 5, secondsSinceInput: 0),
            activeSuppressions: [.manualPause],
        )

        var held = ProtocolEngine(configuration: configuration)
        _ = held.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = held.observe(
            .active(uptimeSeconds: 5, secondsSinceInput: 0),
            activeSuppressions: [.calendarBusy],
        )

        #expect(paused.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(held.visualClock.accumulatedActiveUseSeconds == 5)
        #expect(held.visualClock.phase == .suppressed(.calendarBusy))
    }

    @Test("Suppression exit enters grace and does not yank a running break")
    func suppressionLifecycle() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(
            .active(uptimeSeconds: 5, secondsSinceInput: 0),
            activeSuppressions: [.calendarBusy],
        )

        _ = engine.observe(.active(uptimeSeconds: 6, secondsSinceInput: 0))
        #expect(engine.visualClock.phase == .gracedAfterSuppression)

        engine.resumeAfterSuppressionGrace()
        #expect(engine.visualClock.phase == .accumulating)

        _ = engine.record(.breakStarted, opportunity: .visual)
        _ = engine.observe(
            .active(uptimeSeconds: 7, secondsSinceInput: 0),
            activeSuppressions: [.manualPause],
        )
        #expect(engine.visualClock.phase == .running)
    }

    @Test("Visual timer completion resets only visual")
    func visualTimerCompletion() {
        var engine = accumulatedEngine(seconds: 7)

        let output = engine.record(.timerFinished, opportunity: .visual, source: .localTimer)

        #expect(engine.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 7)
        #expect(output.events.map(\.kind) == [.timerFinished])
    }

    @Test("Movement timer fact does not claim movement completion")
    func movementTimerDoesNotReset() {
        var engine = accumulatedEngine(seconds: 7)

        _ = engine.record(.timerFinished, opportunity: .movement, source: .localTimer)

        #expect(engine.movementClock.accumulatedActiveUseSeconds == 7)
    }

    @Test("Accepted selected movement start resets only movement")
    func selectedMovementStart() {
        var engine = accumulatedEngine(seconds: 7)

        _ = engine.record(
            .breakStarted,
            opportunity: .movement,
            selectedDurationSeconds: 6,
        )

        #expect(engine.visualClock.accumulatedActiveUseSeconds == 7)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 0)
        #expect(engine.movementClock.phase == .running)
    }

    @Test("Snooze preserves due state while skip resets only its clock")
    func snoozeAndSkip() {
        var engine = accumulatedEngine(seconds: 20)

        _ = engine.snooze(
            .visual,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 100),
        )
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 20)
        #expect(engine.visualClock.phase == .snoozed)

        _ = engine.record(.skipped, opportunity: .visual)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 20)
    }

    @Test("Target times inside the merge window yield one merged presentation")
    func mergeWindow() throws {
        var inside = try ProtocolEngine(configuration: Self.makeConfiguration(movementTarget: 25))
        _ = inside.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        let merged = inside.observe(
            .active(uptimeSeconds: 20, secondsSinceInput: 0),
            isLowFrictionMoment: true,
        )

        var outside = try ProtocolEngine(configuration: Self.makeConfiguration(movementTarget: 26))
        _ = outside.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        let visual = outside.observe(
            .active(uptimeSeconds: 20, secondsSinceInput: 0),
            isLowFrictionMoment: true,
        )

        #expect(merged.presentation == .merged)
        #expect(visual.presentation == .visual)
    }

    private func accumulatedEngine(seconds: TimeInterval) -> ProtocolEngine {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: seconds, secondsSinceInput: 0))
        return engine
    }

    private static func makeConfiguration(movementTarget: TimeInterval = 50) throws -> ProtocolConfiguration {
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
                mergeWindowSeconds: 5,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 2,
                snoozeOptionsSeconds: [3, 6, 9],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )
    }
}
