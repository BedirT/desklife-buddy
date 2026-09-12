import Foundation
import Testing
@testable import Domain

@Suite("Trust repro: qualifying away followed by nuisance visual offer")
struct TrustReproTests {
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

    @Test("Qualifying away must not resurface a stale visual offer minutes later")
    func qualifyingAwayMustNotResurfaceStaleVisual() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        let away = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(away.presentation == nil)
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
    }

    @Test("Movement-qualifying away must not offer a nuisance visual minutes later")
    func movementQualifyingAwayMustNotOfferNuisanceVisual() {
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

    @Test("Return grace suppresses offers while nothing is due")
    func returnGraceSuppressesOffersWhileNothingIsDue() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))

        let returned = engine.observe(.active(uptimeSeconds: 320, secondsSinceInput: 10))
        #expect(returned.presentation == nil)
        #expect(engine.movementClock.phase == .gracedAfterSuppression)

        let insideGrace = engine.observe(.active(uptimeSeconds: 350, secondsSinceInput: 0))
        #expect(insideGrace.presentation == nil)

        let atBoundary = engine.observe(.active(uptimeSeconds: 380, secondsSinceInput: 0))
        #expect(atBoundary.presentation == nil)
    }

    @Test("Away preserves movement need and resets visual without completion")
    func awayPreservesMovementNeedWithoutCompletion() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        let away = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))

        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(engine.visualClock.cycleID == 1)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 10)
    }
}
