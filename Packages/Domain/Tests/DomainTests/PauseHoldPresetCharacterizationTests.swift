import Foundation
import Testing
@testable import Domain

/// Characterization of current truthful Pause-vs-hold behavior and the
/// schedule-preset contract.
///
/// Current truth pinned here: `manualPause` (Paused) freezes accumulation for
/// both clocks, while hold-like context reasons (`calendarBusy`,
/// `focusFilter`, `explicitPresentationMode`, `snooze`, `lowFrictionWait`)
/// keep clocks accruing; every reason suppresses presentation; precedence is
/// `SuppressionReason.precedence` order with `manualPause` first. There is no
/// distinct Held clock state yet: holds project through the shared
/// suppressed/grace phases. Preset selection stays on the v1 identifiers with
/// exact v1 window values; v2 identifiers are canonical-not-activated.
@Suite("Pause, hold, and preset characterization")
struct PauseHoldPresetCharacterizationTests {
    private let configuration: ProtocolConfiguration

    init() throws {
        configuration = try ProtocolConfiguration(
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

    @Test("Manual pause freezes both clocks while a hold keeps accruing")
    func manualPauseFreezesWhileHoldAccrues() {
        var paused = ProtocolEngine(configuration: configuration)
        _ = paused.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        let pausedOutput = paused.observe(
            .active(uptimeSeconds: 5, secondsSinceInput: 0),
            activeSuppressions: [.manualPause],
        )

        var held = ProtocolEngine(configuration: configuration)
        _ = held.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        let heldOutput = held.observe(
            .active(uptimeSeconds: 5, secondsSinceInput: 0),
            activeSuppressions: [.calendarBusy],
        )

        #expect(paused.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(paused.movementClock.accumulatedActiveUseSeconds == 0)
        #expect(paused.visualClock.phase == .suppressed(.manualPause))
        #expect(pausedOutput.presentation == nil)

        #expect(held.visualClock.accumulatedActiveUseSeconds == 5)
        #expect(held.movementClock.accumulatedActiveUseSeconds == 5)
        #expect(held.visualClock.phase == .suppressed(.calendarBusy))
        #expect(heldOutput.presentation == nil)
    }

    @Test("Manual pause outranks every hold-like reason")
    func manualPauseOutranksHoldReasons() {
        let resolution = SuppressionResolver.resolve(activeReasons: [
            .calendarBusy,
            .focusFilter,
            .explicitPresentationMode,
            .snooze,
            .lowFrictionWait,
            .manualPause,
        ])
        #expect(resolution.reason == .manualPause)
        #expect(!resolution.shouldPresent)
        #expect(resolution.accumulationPolicy == .pause)
    }

    @Test("Pause release enters grace, then reschedules without catch-up")
    func pauseReleaseEntersGraceThenReschedules() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(
            .active(uptimeSeconds: 5, secondsSinceInput: 0),
            activeSuppressions: [.manualPause],
        )

        let released = engine.observe(.active(uptimeSeconds: 6, secondsSinceInput: 0))
        #expect(engine.visualClock.phase == .gracedAfterSuppression)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 1)
        #expect(released.presentation == nil)

        let output = engine.observe(.active(uptimeSeconds: 67, secondsSinceInput: 0))
        #expect(engine.visualClock.phase == .readyToPresent)
        #expect(output.presentation != nil)
    }

    @Test("Built-in profiles exclude the custom choice")
    func builtInProfilesExcludeCustom() {
        #expect(ProtocolProfileID.builtInCases == [
            .gentle,
            .balanced,
            .frequentMovement,
            .researchInformedHighFrequency,
        ])
        #expect(!ProtocolProfileID.builtInCases.contains(.custom))
        #expect(ProtocolProfileID.allCases.contains(.custom))
    }

    @Test("Schedule profile coding uses stable legacy tags")
    func scheduleProfileCodingUsesStableTags() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        for (json, expected) in [
            (#"{"kind":"gentle"}"#, ScheduleProfile.gentle),
            (#"{"kind":"balanced"}"#, ScheduleProfile.balanced),
            (#"{"kind":"frequent_movement"}"#, ScheduleProfile.frequentMovement),
            (
                #"{"kind":"research_informed_high_frequency"}"#,
                ScheduleProfile.researchInformedHighFrequency
            ),
        ] as [(String, ScheduleProfile)] {
            let decoded = try decoder.decode(
                ScheduleProfile.self,
                from: Data(json.utf8),
            )
            #expect(decoded == expected)
            let roundTripped = try decoder.decode(
                ScheduleProfile.self,
                from: encoder.encode(decoded),
            )
            #expect(roundTripped == expected)
        }
    }

    @Test("Custom timing replaces only schedules and preserves policy")
    func customTimingReplacesOnlySchedules() throws {
        let timing = try CustomProtocolTiming(
            visual: OpportunityTiming(
                softDueSeconds: 11,
                targetSeconds: 21,
                latestPreferredSeconds: 31,
                durationOptionsSeconds: [7],
            ),
            movement: OpportunityTiming(
                softDueSeconds: 16,
                targetSeconds: 51,
                latestPreferredSeconds: 61,
                durationOptionsSeconds: [13, 8],
            ),
        )
        let applied = timing.applying(to: configuration)

        #expect(applied.visual.softDueSeconds == 11)
        #expect(applied.visual.targetSeconds == 21)
        #expect(applied.visual.latestPreferredSeconds == 31)
        #expect(applied.visual.durationOptionsSeconds == [7])
        #expect(applied.movement.softDueSeconds == 16)
        #expect(applied.movement.durationOptionsSeconds == [13, 8])
        #expect(applied.activityEstimator == configuration.activityEstimator)
        #expect(applied.delivery == configuration.delivery)
        #expect(applied.recovery == configuration.recovery)
    }

    @Test("Custom timing rejects unordered windows and keeps duration order")
    func customTimingValidationKeepsDurationOrder() throws {
        #expect(throws: AppPreferencesValidationError.self) {
            try OpportunityTiming(
                softDueSeconds: 30,
                targetSeconds: 20,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            )
        }

        let ordered = try OpportunityTiming(
            softDueSeconds: 10,
            targetSeconds: 20,
            latestPreferredSeconds: 30,
            durationOptionsSeconds: [300, 30],
        )
        #expect(ordered.durationOptionsSeconds == [300, 30])
    }
}
