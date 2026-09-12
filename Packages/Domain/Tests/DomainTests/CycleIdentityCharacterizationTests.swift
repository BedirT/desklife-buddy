import Foundation
import Testing
@testable import Domain

/// RED-first characterization: pins the CURRENT cycle/delivery identity
/// behavior before the versioned-identity migration.
///
/// These tests pass before and after Story 2.3. They prove the migration
/// wraps raw values (migrate, never recast): every `UInt64` cycle counter,
/// every delivery identifier, and every one of the ten event facts keeps its
/// exact raw value while the new versioned wrappers land alongside.
@Suite("Cycle and delivery identity characterization")
struct CycleIdentityCharacterizationTests {
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

    @Test("Fresh clocks start at raw cycle zero and accumulate independently")
    func freshClocksStartAtRawZero() {
        let engine = ProtocolEngine(configuration: configuration)
        #expect(engine.visualClock.cycleID == 0)
        #expect(engine.movementClock.cycleID == 0)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 0)
    }

    @Test("Each fresh-cycle effect advances exactly one raw counter by one")
    func freshCycleAdvancesOneRawCounter() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.record(.timerFinished, opportunity: .visual, source: .localTimer)
        #expect(engine.visualClock.cycleID == 1)
        #expect(engine.movementClock.cycleID == 0)

        _ = engine.record(.skipped, opportunity: .movement, source: .user)
        #expect(engine.visualClock.cycleID == 1)
        #expect(engine.movementClock.cycleID == 1)
    }

    @Test("A qualifying away advances only the visual raw counter")
    func awayAdvancesOnlyVisualCounter() {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        let away = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])
        #expect(engine.visualClock.cycleID == 1)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 0)
        #expect(engine.movementClock.cycleID == 0)
        #expect(engine.movementClock.accumulatedActiveUseSeconds == 10)
    }

    @Test("Raw cycle counters wrap with &+ instead of trapping")
    func rawCountersWrapInsteadOfTrapping() {
        var engine = ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                cycleID: UInt64.max,
                accumulatedActiveUseSeconds: 30,
                phase: .readyToPresent,
            ),
        )
        _ = engine.record(.timerFinished, opportunity: .visual, source: .localTimer)
        #expect(engine.visualClock.cycleID == 0)
        #expect(engine.visualClock.accumulatedActiveUseSeconds == 0)
    }

    @Test("Delivery opportunity IDs carry the exact raw scheduler cycles")
    func deliveryIDsCarryRawCycles() {
        #expect(HeadsUpOpportunityID.visual(cycleID: 6).visualCycleID == 6)
        #expect(HeadsUpOpportunityID.visual(cycleID: 6).movementCycleID == nil)
        #expect(HeadsUpOpportunityID.movement(cycleID: 14).movementCycleID == 14)
        #expect(HeadsUpOpportunityID.movement(cycleID: 14).visualCycleID == nil)
        let merged = HeadsUpOpportunityID.merged(visualCycleID: 1, movementCycleID: 0)
        #expect(merged.visualCycleID == 1)
        #expect(merged.movementCycleID == 0)
    }

    @Test("Delivery reservation keeps one stable ID until the cycle rotates")
    func deliveryIDStableUntilCycleRotates() {
        var reducer = HeadsUpDeliveryReducer(maximumSnoozeReoffers: 1)
        let id = HeadsUpDeliveryID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let snapshot = HeadsUpDeliverySnapshot(
            opportunity: .visual(cycleID: 4),
            currentVisualCycleID: 4,
            currentMovementCycleID: 0,
            observedAt: Date(timeIntervalSince1970: 1000),
            secondsUntilTarget: 45,
            secondsUntilLatest: 75,
            headsUpEnabled: true,
            headsUpLeadSeconds: 30,
            waitsForLowFrictionMoment: false,
            isLowFrictionMoment: false,
        )
        _ = reducer.observe(snapshot, proposedDeliveryID: id)
        #expect(reducer.state.activeDelivery?.id == id)
        #expect(reducer.state.activeDelivery?.opportunity == .visual(cycleID: 4))
    }

    @Test("All ten event facts keep their exact raw values")
    func tenFactsKeepRawValues() {
        #expect(OpportunityEventKind.allCases.count == 10)
        #expect(OpportunityEventKind.allCases.map(\.rawValue) == [
            "promptPresented",
            "breakStarted",
            "timerFinished",
            "userDeclaredCompleted",
            "userDeclaredAlreadyMoved",
            "positionChanged",
            "snoozed",
            "skipped",
            "notAppropriate",
            "likelyNaturalInterruption",
        ])
    }
}
