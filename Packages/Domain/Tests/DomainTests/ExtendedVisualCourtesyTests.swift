import Foundation
import Testing
@testable import Domain

/// Extended-away visual courtesy: a same-epoch unavailable episode of at least
/// 300 seconds grants the fresh visual cycle a 300-second courtesy runway.
/// The visual clock keeps accruing but must not re-due minutes after return,
/// while movement and recovery accrual proceed untouched.
///
/// Normative sources: `timing_runtime_v2.yaml`
/// `system.available_after_extended_unavailable` (same-epoch elapsed >= 300,
/// fresh visual cycle, 60 s return grace) and `product_protocol.yaml`
/// `system_unavailable_visual_courtesy_seconds: 300`.
@Suite("Extended visual courtesy after qualifying away")
struct ExtendedVisualCourtesyTests {
    private let configuration: ProtocolConfiguration
    private let recoveryConfiguration: ProtocolConfiguration

    init() throws {
        configuration = try Self.makeConfiguration(recovery: nil)
        recoveryConfiguration = try Self.makeConfiguration(
            recovery: RecoveryConfiguration(
                eligibleAfterSeconds: 90,
                requiredMovementDeferrals: 2,
            ),
        )
    }

    @Test("Post-extended-away return grants the visual courtesy runway")
    func extendedAwayGrantsVisualCourtesyRunway() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        let away = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(engine.visualClock.cycleID == 1)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 10)

        _ = engine.observe(.active(uptimeSeconds: 320, secondsSinceInput: 10))
        var latest = ProtocolEngineOutput(events: [], presentation: nil)
        var uptime: TimeInterval = 350
        while uptime <= 500 {
            latest = engine.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            uptime += 30
        }

        #expect(latest.presentation == nil || latest.presentation == .movement)
        #expect(latest.presentation != .visual)
        #expect(latest.presentation != .merged)
        #expect(engine.visualClock.phase != .readyToPresent)
        // Accrual proceeds under courtesy; only re-due is held back.
        #expect(engine.visualClock.accumulatedActiveUseSeconds > 0)
        #expect(engine.movementClock.accumulatedActiveUseSeconds > 10)
    }

    @Test("Movement need survives extended away while visual rests")
    func movementQualifyingAwayKeepsMovementDueWhileVisualRests() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 40, secondsSinceInput: 0))

        let away = engine.observe(.active(uptimeSeconds: 340, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 40)

        _ = engine.observe(.active(uptimeSeconds: 350, secondsSinceInput: 10))
        var latest = ProtocolEngineOutput(events: [], presentation: nil)
        var uptime: TimeInterval = 380
        while uptime <= 530 {
            latest = engine.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            uptime += 30
        }

        #expect(engine.movementClock.accumulatedActiveUseSeconds >= 40)
        #expect(latest.presentation == nil || latest.presentation == .movement)
        #expect(latest.presentation != .visual)
        #expect(latest.presentation != .merged)
    }

    @Test("Recovery debt keeps accruing while the visual courtesy holds")
    func recoveryAccrualProceedsDuringVisualCourtesy() {
        var engine = ProtocolEngine(configuration: recoveryConfiguration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        let away = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(engine.recoveryState == RecoveryState())

        _ = engine.observe(.active(uptimeSeconds: 320, secondsSinceInput: 10))
        var latest = ProtocolEngineOutput(events: [], presentation: nil)
        var uptime: TimeInterval = 350
        while uptime <= 500 {
            latest = engine.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            uptime += 30
        }

        #expect(engine.movementClock.accumulatedActiveUseSeconds == 130)
        #expect(engine.recoveryState.accumulatedEligibleActiveUseSeconds == 120)
        #expect(engine.visualClock.phase != .readyToPresent)
        #expect(latest.presentation == .movement)
    }

    @Test("Visual courtesy releases after its runway elapses")
    func courtesyRunwayReleasesVisualAfter300Seconds() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        _ = engine.observe(.active(uptimeSeconds: 320, secondsSinceInput: 10))

        var latest = ProtocolEngineOutput(events: [], presentation: nil)
        var uptime: TimeInterval = 350
        while uptime <= 650 {
            latest = engine.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            uptime += 30
        }

        #expect(engine.visualClock.phase == .readyToPresent)
        #expect(latest.presentation == .merged)
    }

    @Test("A short away below the extended threshold earns no courtesy")
    func shortAwayEarnsNoCourtesy() throws {
        let shortIdle = try Self.makeConfiguration(
            recovery: nil,
            longIdleResetSeconds: 120,
        )
        var engine = ProtocolEngine(configuration: shortIdle)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 20, secondsSinceInput: 0))

        let away = engine.observe(.active(uptimeSeconds: 140, secondsSinceInput: 120))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])

        _ = engine.observe(.active(uptimeSeconds: 150, secondsSinceInput: 10))
        var latest = ProtocolEngineOutput(events: [], presentation: nil)
        var uptime: TimeInterval = 180
        while uptime <= 300 {
            latest = engine.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            uptime += 30
        }

        #expect(engine.visualClock.phase == .readyToPresent)
        #expect(latest.presentation == .merged)
    }

    @Test("Discontinuous elapsed time earns no courtesy")
    func discontinuousElapsedEarnsNoCourtesy() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 20, secondsSinceInput: 0))

        let away = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])

        _ = engine.observe(.active(uptimeSeconds: 40, secondsSinceInput: 0))
        let reDue = engine.observe(.active(uptimeSeconds: 130, secondsSinceInput: 0))

        #expect(engine.visualClock.phase == .readyToPresent)
        #expect(reDue.presentation == .merged)
    }

    @Test("A running ritual is not reset by extended away")
    func runningRitualIsNotResetByExtendedAway() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 20, secondsSinceInput: 0))
        _ = engine.record(.breakStarted, opportunity: .visual)

        let away = engine.observe(.active(uptimeSeconds: 320, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(engine.visualClock.phase == .running)
        #expect(engine.visualClock.cycleID == 0)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 20)

        let returned = engine.observe(.active(uptimeSeconds: 330, secondsSinceInput: 10))
        #expect(returned.events.isEmpty)
        #expect(engine.visualClock.phase == .running)
    }

    @Test("Completing visual after away starts a clean cycle without courtesy")
    func visualCompletionAfterAwayStartsCleanCycle() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        _ = engine.observe(.active(uptimeSeconds: 320, secondsSinceInput: 10))

        _ = engine.record(.breakStarted, opportunity: .visual)
        _ = engine.record(.timerFinished, opportunity: .visual, source: .localTimer)

        var uptime: TimeInterval = 350
        while uptime <= 410 {
            _ = engine.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            uptime += 30
        }

        // 410 is inside the original 300-second runway, yet the fresh
        // post-completion cycle schedules normally.
        #expect(engine.visualClock.cycleID == 2)
        #expect(engine.visualClock.phase == .readyToPresent)
    }

    @Test("An uncovered sample gap accrues nothing and resets the baseline")
    func uncoveredSampleGapAccruesNothingAndResetsBaseline() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        let gapped = engine.observe(.active(uptimeSeconds: 110, secondsSinceInput: 0))
        #expect(gapped.events.isEmpty)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 10)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 10)

        _ = engine.observe(.active(uptimeSeconds: 120, secondsSinceInput: 0))
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 20)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 20)
    }

    @Test("A backward re-baseline cannot borrow pre-jump time for the runway")
    func backwardRebaselineDoesNotArmCourtesy() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 20, secondsSinceInput: 0))
        // The clock jumps backward with no input evidence; the estimator
        // re-baselines instead of carrying the pre-jump elapsed time.
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        // Only ~10 s of same-epoch evidence backs this onset, so no runway
        // may arm even though the input has been silent for 300 s.
        let away = engine.observe(.active(uptimeSeconds: 20, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])

        _ = engine.observe(.active(uptimeSeconds: 50, secondsSinceInput: 0))
        let reDue = engine.observe(.active(uptimeSeconds: 140, secondsSinceInput: 0))

        #expect(engine.visualClock.phase == .readyToPresent)
        #expect(reDue.presentation == .merged)
    }

    @Test("An extended crossing after long-idle onset still earns the runway")
    func lateExtendedCrossingArmsCourtesyAfterLongIdleOnset() throws {
        let divergent = try Self.makeConfiguration(
            recovery: nil,
            longIdleResetSeconds: 120,
        )
        var engine = ProtocolEngine(configuration: divergent)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 20, secondsSinceInput: 0))

        // Long-idle onset at 120 s earns no runway on its own.
        let onset = engine.observe(.active(uptimeSeconds: 140, secondsSinceInput: 120))
        #expect(onset.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(engine.visualClock.cycleID == 1)

        // Crossing the 300 s extended threshold is an independent edge: it
        // arms the runway without manufacturing a second interruption fact.
        let crossing = engine.observe(.active(uptimeSeconds: 320, secondsSinceInput: 300))
        #expect(crossing.events.isEmpty)
        #expect(engine.visualClock.phase == .gracedAfterSuppression)

        _ = engine.observe(.active(uptimeSeconds: 330, secondsSinceInput: 10))
        var latest = ProtocolEngineOutput(events: [], presentation: nil)
        var uptime: TimeInterval = 360
        while uptime <= 510 {
            latest = engine.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            uptime += 30
        }

        #expect(engine.visualClock.phase != .readyToPresent)
        #expect(latest.presentation == .movement)
    }

    @Test("An extended threshold below the long-idle reset is rejected")
    func extendedThresholdBelowLongIdleIsRejected() throws {
        #expect(throws: ProtocolConfigurationError.invalidActivityThresholds) {
            try ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 60,
                longIdleResetSeconds: 300,
                wakeUnlockGraceSeconds: 90,
                extendedUnavailableThresholdSeconds: 120,
            )
        }
        // The boundary itself stays reachable: equal thresholds arm together.
        let boundary = try ActivityEstimatorConfiguration(
            recentInputWindowSeconds: 60,
            longIdleResetSeconds: 300,
            wakeUnlockGraceSeconds: 90,
            extendedUnavailableThresholdSeconds: 300,
        )
        #expect(boundary.extendedUnavailableThresholdSeconds == 300)
    }

    @Test("A legacy visual skip orphans a stale runway instead of masking dues")
    func legacyVisualSkipOrphansCourtesyRunway() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        _ = engine.observe(.active(uptimeSeconds: 320, secondsSinceInput: 10))

        var uptime: TimeInterval = 350
        while uptime <= 440 {
            _ = engine.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            uptime += 30
        }
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 60)

        let skipped = engine.skipMergedSegment(.visual)
        #expect(skipped.events.map(\.kind) == [.skipped])
        #expect(skipped.events.map(\.opportunity) == [.visual])

        var latest = ProtocolEngineOutput(events: [], presentation: nil)
        uptime = 470
        while uptime <= 530 {
            latest = engine.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            uptime += 30
        }

        // 530 is inside the original 300-second runway, yet the retained due
        // clock schedules normally once the stale runway is orphaned.
        #expect(engine.visualClock.phase == .readyToPresent)
        #expect(latest.presentation == .merged)
    }

    private static func makeConfiguration(
        recovery: RecoveryConfiguration?,
        longIdleResetSeconds: TimeInterval = 300,
    ) throws -> ProtocolConfiguration {
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
                longIdleResetSeconds: longIdleResetSeconds,
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
            recovery: recovery,
        )
    }
}
