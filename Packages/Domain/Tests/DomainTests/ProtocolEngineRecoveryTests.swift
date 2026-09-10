import Foundation
import Testing
@testable import Domain

@Suite("Protocol engine recovery")
struct ProtocolEngineRecoveryTests {
    private let configuration: ProtocolConfiguration

    init() throws {
        configuration = try Self.makeConfiguration()
    }

    @Test("One snooze plus one skip and 90 seconds of eligible use offers recovery once")
    func twoMovementDeferralsReachRecoveryThreshold() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 89, secondsSinceInput: 0))

        _ = engine.snooze(
            .movement,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 0),
        )
        _ = engine.record(.skipped, opportunity: .movement)

        #expect(engine.recoveryState.accumulatedEligibleActiveUseSeconds == 89)
        #expect(engine.recoveryState.movementDeferralCount == 2)
        #expect(!engine.recoveryState.wasOfferedThisSession)

        let eligible = engine.observe(.active(uptimeSeconds: 90, secondsSinceInput: 0))

        #expect(eligible.presentation == .recovery)
        #expect(eligible.events.isEmpty)
        #expect(!engine.recoveryState.wasOfferedThisSession)

        let delivered = engine.record(.promptPresented, opportunity: .recovery)
        #expect(delivered.events.map(\.kind) == [.promptPresented])
        #expect(delivered.events.map(\.opportunity) == [.recovery])
        #expect(engine.recoveryState.wasOfferedThisSession)
    }

    @Test("Ineligible elapsed time does not advance recovery debt")
    func onlyEligibleActiveUseAdvancesRecoveryDebt() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.snooze(
            .movement,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 0),
        )
        _ = engine.record(.skipped, opportunity: .movement)

        _ = engine.observe(.active(uptimeSeconds: 45, secondsSinceInput: 0))
        let ineligible = engine.observe(.active(uptimeSeconds: 100, secondsSinceInput: 61))

        #expect(engine.recoveryState.accumulatedEligibleActiveUseSeconds == 45)
        #expect(ineligible.presentation != .recovery)

        let eligible = engine.observe(.active(uptimeSeconds: 145, secondsSinceInput: 0))

        #expect(engine.recoveryState.accumulatedEligibleActiveUseSeconds == 90)
        #expect(eligible.presentation == .recovery)
    }

    @Test("Position change preserves recovery debt and does not substitute for movement")
    func positionChangeDoesNotClearRecoveryDebt() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 89, secondsSinceInput: 0))
        _ = engine.snooze(
            .movement,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 0),
        )
        _ = engine.record(.skipped, opportunity: .movement)

        _ = engine.record(.positionChanged, opportunity: .positionChange)

        #expect(engine.recoveryState.accumulatedEligibleActiveUseSeconds == 89)
        #expect(engine.recoveryState.movementDeferralCount == 2)

        let eligible = engine.observe(.active(uptimeSeconds: 90, secondsSinceInput: 0))
        #expect(eligible.presentation == .recovery)
    }

    @Test("An accepted movement action clears recovery debt")
    func movementActionClearsRecoveryDebt() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 89, secondsSinceInput: 0))
        _ = engine.snooze(
            .movement,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 0),
        )
        _ = engine.record(.skipped, opportunity: .movement)

        _ = engine.record(
            .breakStarted,
            opportunity: .movement,
            selectedDurationSeconds: 6,
        )

        #expect(engine.recoveryState.accumulatedEligibleActiveUseSeconds == 0)
        #expect(engine.recoveryState.movementDeferralCount == 0)

        let later = engine.observe(.active(uptimeSeconds: 90, secondsSinceInput: 0))
        #expect(later.presentation != .recovery)
    }

    @Test("Recovery never re-offers or escalates within a restored session")
    func recoveryIsAtMostOncePerSession() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 90, secondsSinceInput: 0))
        _ = engine.snooze(
            .movement,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 0),
        )
        let firstEligibility = engine.record(.skipped, opportunity: .movement)

        #expect(firstEligibility.presentation == .recovery)
        #expect(firstEligibility.events.map(\.kind) == [.skipped])
        #expect(firstEligibility.events.map(\.opportunity) == [.movement])
        #expect(!engine.recoveryState.wasOfferedThisSession)

        _ = engine.record(.promptPresented, opportunity: .recovery)
        #expect(engine.recoveryState.wasOfferedThisSession)

        _ = engine.record(.skipped, opportunity: .recovery)
        let restoredState = engine.state
        var restored = ProtocolEngine(configuration: configuration, state: restoredState)

        _ = restored.snooze(
            .movement,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 0),
        )
        _ = restored.record(.skipped, opportunity: .movement)
        _ = restored.record(.skipped, opportunity: .movement)
        _ = restored.observe(.active(uptimeSeconds: 100, secondsSinceInput: 0))
        let later = restored.observe(.active(uptimeSeconds: 200, secondsSinceInput: 0))

        #expect(later.presentation != .recovery)
        #expect(later.events.filter { $0.opportunity == .recovery }.isEmpty)
        #expect(restored.recoveryState.wasOfferedThisSession)

        let boundary = restored.observe(.active(uptimeSeconds: 500, secondsSinceInput: 300))
        #expect(boundary.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(restored.recoveryState == RecoveryState())

        _ = restored.snooze(
            .movement,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 0),
        )
        _ = restored.record(.skipped, opportunity: .movement)
        _ = restored.observe(.active(uptimeSeconds: 501, secondsSinceInput: 0))
        let duringReturnGrace = restored.observe(.active(uptimeSeconds: 561, secondsSinceInput: 0))
        let nextSession = restored.observe(.active(uptimeSeconds: 651, secondsSinceInput: 0))
        #expect(duringReturnGrace.presentation != .recovery)
        #expect(nextSession.presentation == .recovery)
    }

    @Test("A movement snooze suppresses recovery until its retained deadline expires")
    func movementSnoozeSuppressesRecovery() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 90, secondsSinceInput: 0))
        _ = engine.record(.skipped, opportunity: .movement)
        _ = engine.snooze(
            .movement,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 100),
        )

        #expect(engine.recoveryState.movementDeferralCount == 2)
        #expect(engine.observe(.active(uptimeSeconds: 91, secondsSinceInput: 0)).presentation == nil)

        let resumed = engine.resumeExpiredSnoozes(at: Date(timeIntervalSince1970: 103))
        #expect(resumed.presentation == .recovery)
    }

    @Test("Offline and unavailable gaps rotate recovery only at the long-idle threshold")
    func recoverySessionBoundaries() {
        let debt = RecoveryState(
            accumulatedEligibleActiveUseSeconds: 90,
            movementDeferralCount: 2,
            wasOfferedThisSession: true,
        )
        var offline = ProtocolEngine(configuration: configuration, recoveryState: debt)
        offline.observeRecoverySession(at: Date(timeIntervalSince1970: 100), systemAvailable: true)
        offline.observeRecoverySession(at: Date(timeIntervalSince1970: 399), systemAvailable: true)
        #expect(offline.recoveryState == debt)

        offline.observeRecoverySession(at: Date(timeIntervalSince1970: 699), systemAvailable: true)
        #expect(offline.recoveryState == RecoveryState())

        var locked = ProtocolEngine(configuration: configuration, recoveryState: debt)
        locked.observeRecoverySession(at: Date(timeIntervalSince1970: 100), systemAvailable: true)
        locked.observeRecoverySession(at: Date(timeIntervalSince1970: 399), systemAvailable: false)
        #expect(locked.recoveryState == debt)

        locked.observeRecoverySession(at: Date(timeIntervalSince1970: 400), systemAvailable: false)
        #expect(locked.recoveryState == RecoveryState())
    }

    private static func makeConfiguration() throws -> ProtocolConfiguration {
        try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 500,
                targetSeconds: 600,
                latestPreferredSeconds: 700,
                durationOptionsSeconds: [5],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: 500,
                targetSeconds: 600,
                latestPreferredSeconds: 700,
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
            recovery: RecoveryConfiguration(
                eligibleAfterSeconds: 90,
                requiredMovementDeferrals: 2,
            ),
        )
    }
}
