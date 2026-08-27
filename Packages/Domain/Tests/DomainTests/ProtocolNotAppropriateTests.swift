import Foundation
import Testing
@testable import Domain

@Suite("Session-scoped not-appropriate outcomes")
struct ProtocolNotAppropriateTests {
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
                softDueSeconds: 40,
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
            recovery: RecoveryConfiguration(
                eligibleAfterSeconds: 90,
                requiredMovementDeferrals: 2,
            ),
        )
    }

    @Test("Older protocol-state construction defaults to no session suppression")
    func additiveStateDefaultsToEmpty() {
        let state = ProtocolState(
            profileID: .balanced,
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 10),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 20),
        )

        #expect(state.notAppropriateOpportunities.isEmpty)
    }

    @Test("Visual not-appropriate records its fact and leaves movement independently presentable")
    func visualSuppressionIsIndependent() {
        var engine = dueEngine()
        let visualBefore = engine.visualClock
        let movementBefore = engine.movementClock
        let recoveryBefore = engine.recoveryState

        let output = engine.record(.notAppropriate, opportunity: .visual)

        #expect(output.events == [OpportunityEventDraft(
            kind: .notAppropriate,
            source: .user,
            opportunity: .visual,
        )])
        #expect(output.presentation == .movement)
        #expect(engine.notAppropriateOpportunities == [.visual])
        #expect(engine.visualClock == visualBefore)
        #expect(engine.movementClock == movementBefore)
        #expect(engine.recoveryState == recoveryBefore)
    }

    @Test("Movement not-appropriate leaves visual independent and suppresses recovery")
    func movementSuppressionPreventsRecovery() {
        let recovery = RecoveryState(
            accumulatedEligibleActiveUseSeconds: 90,
            movementDeferralCount: 2,
        )
        var engine = ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 20,
                phase: .readyToPresent,
            ),
            movementClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 50,
                phase: .readyToPresent,
            ),
            recoveryState: recovery,
        )
        let visualBefore = engine.visualClock
        let movementBefore = engine.movementClock

        let output = engine.record(.notAppropriate, opportunity: .movement)

        #expect(output.events == [OpportunityEventDraft(
            kind: .notAppropriate,
            source: .user,
            opportunity: .movement,
        )])
        #expect(output.presentation == .visual)
        #expect(engine.notAppropriateOpportunities == [.movement])
        #expect(engine.visualClock == visualBefore)
        #expect(engine.movementClock == movementBefore)
        #expect(engine.recoveryState == recovery)

        let later = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        #expect(later.presentation == .visual)
    }

    @Test("Only visual and movement identities enter the persisted suppression set")
    func suppressionSetIsBounded() {
        let state = ProtocolState(
            notAppropriateOpportunities: [.visual, .movement, .positionChange, .recovery],
        )

        #expect(state.notAppropriateOpportunities == [.visual, .movement])
    }

    @Test("Session suppression round-trips through Domain state storage")
    func stateRoundTrip() async throws {
        let expected: Set<OpportunityType> = [.visual, .movement]
        let state = ProtocolState(notAppropriateOpportunities: expected)
        let store = InMemoryProtocolStateStore()

        try await store.saveState(state)

        let loaded = try #require(try await store.loadState())
        #expect(loaded.notAppropriateOpportunities == expected)
        let restored = ProtocolEngine(configuration: configuration, state: loaded)
        #expect(restored.notAppropriateOpportunities == expected)
        #expect(restored.state.notAppropriateOpportunities == expected)
    }

    @Test("A recovery session gap clears not-appropriate state but not before its boundary")
    func sessionGapClearsSuppression() {
        var engine = ProtocolEngine(
            configuration: configuration,
            notAppropriateOpportunities: [.visual, .movement],
        )

        engine.observeRecoverySession(
            at: Date(timeIntervalSince1970: 100),
            systemAvailable: true,
        )
        engine.observeRecoverySession(
            at: Date(timeIntervalSince1970: 399),
            systemAvailable: false,
        )
        #expect(engine.notAppropriateOpportunities == [.visual, .movement])

        engine.observeRecoverySession(
            at: Date(timeIntervalSince1970: 400),
            systemAvailable: false,
        )
        #expect(engine.notAppropriateOpportunities.isEmpty)
    }

    @Test("A likely natural interruption rotates not-appropriate session state")
    func naturalInterruptionClearsSuppression() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.record(.notAppropriate, opportunity: .movement)

        let boundary = engine.observe(
            .active(uptimeSeconds: 300, secondsSinceInput: 300),
        )

        #expect(boundary.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(engine.notAppropriateOpportunities.isEmpty)
    }

    private func dueEngine() -> ProtocolEngine {
        ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 20,
                phase: .readyToPresent,
            ),
            movementClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 50,
                phase: .readyToPresent,
            ),
        )
    }
}
