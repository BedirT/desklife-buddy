import Foundation
import Testing
@testable import Domain

/// Story 1: explicit manual meeting / presenting-or-sharing / timed-focus
/// modes. Explicit user state resolves to a Held reason (never a clock
/// freeze), carries an explicit expiry, loses to manualPause, and clearing
/// it restores presentation eligibility.
@Suite("Manual context holds")
struct ManualContextHoldTests {
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

    @Test("Manual meeting mode holds without freezing clocks")
    func manualMeetingModeHoldsWithoutFreezingClocks() {
        let startedAt = Date(timeIntervalSince1970: 1_000_000)
        let hold = ManualContextHold(
            mode: .meetingOrCall,
            startedAt: startedAt,
            expiresAt: startedAt.addingTimeInterval(3600),
        )

        // Explicit expiry is present on the hold itself.
        #expect(hold.expiresAt > hold.startedAt)
        #expect(hold.suppressionReason == .userDeclaredMeetingOrCall)

        // Resolves to a Held reason: presentation blocked, accumulation continues.
        let resolution = SuppressionResolver.resolve(activeReasons: [hold.suppressionReason])
        #expect(!resolution.shouldPresent)
        #expect(resolution.reason == .userDeclaredMeetingOrCall)
        #expect(resolution.accumulationPolicy == .continue)

        // Need clocks keep accruing while the manual hold is active.
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        let heldOutput = engine.observe(
            .active(uptimeSeconds: 5, secondsSinceInput: 0),
            activeSuppressions: [hold.suppressionReason],
        )
        #expect(heldOutput.presentation == nil)
        #expect(engine.visualClock.phase == .suppressed(.userDeclaredMeetingOrCall))
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 5)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 5)

        // Explicit user pause still outranks the manual context hold.
        let outranked = SuppressionResolver.resolve(activeReasons: [
            .manualPause,
            hold.suppressionReason,
        ])
        #expect(outranked.reason == .manualPause)

        // Clearing the hold restores presentation eligibility.
        #expect(SuppressionResolver.resolve(activeReasons: []).shouldPresent)
        _ = engine.observe(.active(uptimeSeconds: 6, secondsSinceInput: 0))
        #expect(engine.visualClock.phase != .suppressed(.userDeclaredMeetingOrCall))
    }

    @Test("Every manual mode holds with continuing accumulation", arguments: [
        ManualContextMode.meetingOrCall,
        ManualContextMode.presentingOrSharing,
        ManualContextMode.timedFocus,
    ])
    func manualModesContinueAccumulation(mode: ManualContextMode) {
        let startedAt = Date(timeIntervalSince1970: 2_000_000)
        let hold = ManualContextHold(
            mode: mode,
            startedAt: startedAt,
            expiresAt: startedAt.addingTimeInterval(mode.defaultDurationSeconds),
        )
        #expect(hold.expiresAt > hold.startedAt)

        let resolution = SuppressionResolver.resolve(activeReasons: [hold.suppressionReason])
        #expect(!resolution.shouldPresent)
        #expect(resolution.accumulationPolicy == .continue)
    }
}
