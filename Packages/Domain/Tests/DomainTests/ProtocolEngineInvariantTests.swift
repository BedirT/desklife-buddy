import Foundation
import Testing
@testable import Domain

@Suite("Protocol engine invariants")
struct ProtocolEngineInvariantTests {
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
                mergeWindowSeconds: 5,
                headsUpSecondsBeforeTarget: 2,
                snoozeOptionsSeconds: [3, 6, 9],
                maximumRepeatedEscalations: 1,
            ),
        )
    }

    @Test("Idle visual and position facts cannot infer movement completion")
    func noFalseMovementCompletion() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 40, secondsSinceInput: 0))
        let movementBefore = engine.movementClock.accumulatedActiveUseSeconds

        let idle = engine.observe(.active(uptimeSeconds: 340, secondsSinceInput: 300))
        _ = engine.record(.timerFinished, opportunity: .movement, source: .localTimer)
        _ = engine.record(.userDeclaredCompleted, opportunity: .visual)
        _ = engine.record(.positionChanged, opportunity: .positionChange)

        #expect(idle.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(engine.movementClock.accumulatedActiveUseSeconds == movementBefore)
    }

    @Test("A long idle episode emits only once and never changes accumulated clocks")
    func naturalInterruptionIsDistinct() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        let first = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        let second = engine.observe(.active(uptimeSeconds: 320, secondsSinceInput: 310))

        #expect(first.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(second.events.isEmpty)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 10)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 10)
    }

    @Test("Backward and invalid monotonic samples cannot duplicate or make elapsed negative")
    func invalidElapsedCannotAccumulate() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 100, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 110, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 90, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: .nan, secondsSinceInput: 0))

        #expect(engine.visualClock.accumulatedActiveUseSeconds == 10)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 10)
        #expect(engine.visualClock.accumulatedActiveUseSeconds >= 0)
        #expect(engine.movementClock.accumulatedActiveUseSeconds >= 0)
    }
}
