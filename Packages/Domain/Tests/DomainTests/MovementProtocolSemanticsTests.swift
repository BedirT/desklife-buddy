import Foundation
import Testing
@testable import Domain

@Suite("Movement protocol semantics")
struct MovementProtocolSemanticsTests {
    private let configuration: ProtocolConfiguration

    init() throws {
        configuration = try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 1200,
                targetSeconds: 1500,
                latestPreferredSeconds: 1800,
                durationOptionsSeconds: [20],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: 3000,
                targetSeconds: 3600,
                latestPreferredSeconds: 4200,
                durationOptionsSeconds: [300, 120],
            ),
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 60,
                longIdleResetSeconds: 300,
                wakeUnlockGraceSeconds: 90,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: true,
                mergeWindowSeconds: 300,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 45,
                snoozeOptionsSeconds: [300, 600, 900],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )
    }

    @Test("Automatic movement opening starts presentation without resetting movement")
    func automaticOpeningDoesNotResetMovement() {
        var engine = dueEngine()

        let output = engine.record(
            .breakStarted,
            opportunity: .movement,
            source: .localTimer,
        )

        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .running)
        #expect(output.events == [OpportunityEventDraft(
            kind: .breakStarted,
            source: .localTimer,
            opportunity: .movement,
        )])
    }

    @Test("Explicit five-minute movement selection resets movement only")
    func explicitFiveMinuteSelectionResetsMovement() {
        assertAcceptedMovementSelection(duration: 300)
    }

    @Test("Explicit two-minute movement selection resets movement only")
    func explicitTwoMinuteSelectionResetsMovement() {
        assertAcceptedMovementSelection(duration: 120)
    }

    @Test("Unsupported movement duration is rejected without another event or clock effect")
    func unsupportedMovementDurationIsRejected() {
        var engine = dueEngine()
        _ = engine.record(.breakStarted, opportunity: .movement, source: .localTimer)

        let output = engine.selectMovement(durationSeconds: 240)

        #expect(output.events.isEmpty)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .running)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
    }

    @Test("Movement timer finish exits running but does not declare completion")
    func movementTimerFinishLeavesClockDue() {
        var engine = dueEngine(visualSeconds: 0)
        _ = engine.record(.breakStarted, opportunity: .movement, source: .localTimer)

        let output = engine.record(
            .timerFinished,
            opportunity: .movement,
            source: .localTimer,
        )

        #expect(output.events.map(\.kind) == [.timerFinished])
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .gracedAfterSuppression)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 0)
        let nextObservation = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        #expect(nextObservation.presentation == nil)
    }

    @Test("Done early explicitly resets movement only")
    func doneEarlyResetsMovement() {
        var engine = dueEngine()
        _ = engine.record(.breakStarted, opportunity: .movement, source: .localTimer)

        let output = engine.record(.userDeclaredCompleted, opportunity: .movement)

        #expect(output.events.map(\.kind) == [.userDeclaredCompleted])
        #expect(engine.movementClock == OpportunityClockState(cycleID: 1))
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
    }

    @Test("Already moved explicitly resets movement only")
    func alreadyMovedResetsMovement() {
        var engine = dueEngine()
        _ = engine.record(.breakStarted, opportunity: .movement, source: .localTimer)

        let output = engine.record(.userDeclaredAlreadyMoved, opportunity: .movement)

        #expect(output.events.map(\.kind) == [.userDeclaredAlreadyMoved])
        #expect(engine.movementClock == OpportunityClockState(cycleID: 1))
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
    }

    @Test("Position change exits movement while preserving the due movement clock")
    func positionChangeDoesNotCompleteMovement() {
        var engine = dueEngine(visualSeconds: 0)
        _ = engine.record(.breakStarted, opportunity: .movement, source: .localTimer)

        let output = engine.record(.positionChanged, opportunity: .positionChange)

        #expect(output.events.map(\.kind) == [.positionChanged])
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .gracedAfterSuppression)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 0)
        let nextObservation = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        #expect(nextObservation.presentation == nil)
    }

    @Test("Standalone movement skip resets its cycle without claiming completion")
    func standaloneMovementSkipResetsMovement() {
        var engine = ProtocolEngine(
            configuration: configuration,
            movementClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 3600,
                phase: .readyToPresent,
            ),
        )
        _ = engine.record(.breakStarted, opportunity: .movement, source: .localTimer)

        let output = engine.record(.skipped, opportunity: .movement)

        #expect(output.events.map(\.kind) == [.skipped])
        #expect(engine.movementClock == OpportunityClockState(cycleID: 1))
        #expect(engine.visualClock == OpportunityClockState())
    }

    @Test("Configured movement snooze preserves the due clock")
    func configuredSnoozePreservesDueClock() {
        var engine = dueEngine()

        let now = Date(timeIntervalSince1970: 1000)
        let output = engine.snooze(
            .movement,
            durationSeconds: 300,
            at: now,
        )

        #expect(output.events.map(\.kind) == [.snoozed])
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .snoozed)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(engine.state.movementSnoozeDeadline == Date(timeIntervalSince1970: 1300))
        #expect(output.presentation == .visual)
    }

    @Test("Unsupported snooze duration is rejected")
    func unsupportedSnoozeDurationIsRejected() {
        var engine = dueEngine()

        let output = engine.snooze(
            .movement,
            durationSeconds: 60,
            at: Date(timeIntervalSince1970: 1000),
        )

        #expect(output.events.isEmpty)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .readyToPresent)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
    }

    @Test("Snooze deadline survives restoration and resumes explicitly at expiry")
    func snoozeDeadlineIsRestartSafe() {
        var engine = dueEngine(visualSeconds: 0)
        let start = Date(timeIntervalSince1970: 1000)
        let deadline = Date(timeIntervalSince1970: 1300)
        _ = engine.snooze(
            .movement,
            durationSeconds: 300,
            at: start,
        )
        let retainedState = engine.state
        #expect(retainedState.movementSnoozeDeadline == deadline)

        var restored = ProtocolEngine(configuration: configuration, state: retainedState)

        let beforeExpiry = restored.resumeExpiredSnoozes(
            at: Date(timeIntervalSince1970: 1299),
        )
        #expect(restored.movementClock.phase == .snoozed)
        #expect(beforeExpiry.presentation == nil)
        #expect(restored.state.movementSnoozeDeadline == deadline)

        let atExpiry = restored.resumeExpiredSnoozes(at: deadline)
        #expect(restored.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(restored.movementClock.phase == .readyToPresent)
        #expect(restored.state.movementSnoozeDeadline == nil)
        #expect(atExpiry.presentation == .movement)
        #expect(atExpiry.events.isEmpty)
    }

    @Test("Merged Escape during visual applies the canonical fresh effect")
    func mergedEscapeDuringVisualFreshensBothCycles() {
        // Contract-backed migration (Story 2.6, not green-painting): D-043
        // `timing_runtime_v2.yaml` action_contract `merged.escape_during_visual`
        // rows clocks {visual: fresh_cycle, movement: fresh_cycle, position:
        // retain, recovery: deferral_increment} with facts [skipped]. The
        // pre-2.6 retaining pin (both clocks due, graced) covered the legacy
        // `skipMergedSegment` route production no longer uses for this
        // segment; the coordinator `.mergedEscapeDuringVisual` command shares
        // the reducer's `applyMergedEscapeDuringVisual` effect by construction.
        var engine = dueEngine()
        _ = engine.record(.breakStarted, opportunity: .visual, source: .localTimer)
        var coordinator = OpportunityCoordinator(engine: engine)

        let output = coordinator.dispatch(.mergedEscapeDuringVisual)

        #expect(output.events.map(\.kind) == [.skipped])
        #expect(output.events.map(\.opportunity) == [.visual])
        #expect(coordinator.engine.visualClock == OpportunityClockState(cycleID: 1))
        #expect(coordinator.engine.movementClock == OpportunityClockState(cycleID: 1))
        #expect(coordinator.engine.recoveryState.movementDeferralCount == 1)
        engine = coordinator.engine
        let nextObservation = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        #expect(nextObservation.presentation == nil)
    }

    // Story 2.6 scope note: this movement-segment pin is intentionally NOT
    // migrated. D-043 `merged.escape_during_movement` rows visual: retain,
    // and only the visual-segment route moved to the canonical fresh effect
    // (`merged.escape_during_visual`); movement-segment production callers
    // keep the legacy retaining `skipMergedSegment` route, pinned here.
    @Test("Merged Escape after visual finish retains visual outcome and leaves movement due")
    func mergedEscapeDuringMovementRetainsVisualOutcome() {
        var engine = dueEngine()
        _ = engine.record(.breakStarted, opportunity: .visual, source: .localTimer)
        _ = engine.record(.timerFinished, opportunity: .visual, source: .localTimer)
        _ = engine.record(.breakStarted, opportunity: .movement, source: .localTimer)

        let output = engine.skipMergedSegment(.movement)

        #expect(output.events.map(\.kind) == [.skipped])
        #expect(engine.visualClock == OpportunityClockState(cycleID: 1))
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 3600)
        #expect(engine.movementClock.phase == .gracedAfterSuppression)
        let nextObservation = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        #expect(nextObservation.presentation == nil)
    }

    private func assertAcceptedMovementSelection(duration: TimeInterval) {
        var engine = dueEngine()
        let opening = engine.record(
            .breakStarted,
            opportunity: .movement,
            source: .localTimer,
        )

        let output = engine.selectMovement(durationSeconds: duration)

        #expect(opening.events.map(\.kind) == [.breakStarted])
        #expect(output.events == [OpportunityEventDraft(
            kind: .breakStarted,
            source: .user,
            opportunity: .movement,
            selectedDurationSeconds: duration,
        )])
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 0)
        #expect(engine.movementClock.phase == .running)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1500)
    }

    private func dueEngine(
        visualSeconds: TimeInterval = 1500,
        movementSeconds: TimeInterval = 3600,
    ) -> ProtocolEngine {
        ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                accumulatedActiveUseSeconds: visualSeconds,
                phase: visualSeconds >= 1500 ? .readyToPresent : .accumulating,
            ),
            movementClock: OpportunityClockState(
                accumulatedActiveUseSeconds: movementSeconds,
                phase: movementSeconds >= 3600 ? .readyToPresent : .accumulating,
            ),
        )
    }
}
