import Foundation
import Testing
@testable import Domain

/// Proves the coordinator facade rehoused current behavior without changing it.
///
/// Each test drives an identical command sequence through
/// `OpportunityCoordinator.dispatch` and through `ProtocolEngine` directly,
/// then requires identical outputs and identical persisted states.
@Suite("Opportunity coordinator parity")
struct OpportunityCoordinatorTests {
    private let configuration: ProtocolConfiguration

    init() throws {
        configuration = try Self.makeConfiguration()
    }

    @Test("Observe dispatch matches the engine reduction")
    func observeDispatchMatchesEngine() {
        var engine = ProtocolEngine(configuration: configuration)
        var coordinator = OpportunityCoordinator(engine: engine)
        let samples: [(ActivitySample, Bool)] = [
            (.active(uptimeSeconds: 0, secondsSinceInput: 0), false),
            (.active(uptimeSeconds: 10, secondsSinceInput: 0), false),
            (.active(uptimeSeconds: 20, secondsSinceInput: 0), true),
            (.active(uptimeSeconds: 25, secondsSinceInput: 5), true),
        ]
        for (sample, lowFriction) in samples {
            let direct = engine.observe(sample, isLowFrictionMoment: lowFriction)
            let routed = coordinator.dispatch(.observe(
                sample: sample,
                activeSuppressions: [],
                isLowFrictionMoment: lowFriction,
            ))
            #expect(routed.events == direct.events)
            #expect(routed.presentation == direct.presentation)
            #expect(coordinator.state == engine.state)
        }
    }

    @Test("Record dispatch matches the engine for every lifecycle fact")
    func recordDispatchMatchesEngine() {
        let facts: [(OpportunityEventKind, OpportunityType?)] = [
            (.breakStarted, .visual),
            (.breakStarted, .movement),
            (.timerFinished, .visual),
            (.userDeclaredCompleted, .movement),
            (.userDeclaredAlreadyMoved, .movement),
            (.positionChanged, .positionChange),
            (.skipped, .movement),
            (.skipped, .visual),
            (.notAppropriate, .visual),
            (.notAppropriate, .movement),
            (.promptPresented, .recovery),
            (.likelyNaturalInterruption, nil),
            (.snoozed, .visual),
        ]
        for (kind, opportunity) in facts {
            var engine = seededEngine()
            var coordinator = OpportunityCoordinator(engine: engine)
            let direct = engine.record(kind, opportunity: opportunity, source: .user)
            let routed = coordinator.dispatch(.record(
                kind: kind,
                opportunity: opportunity,
                selectedDurationSeconds: nil,
                source: .user,
            ))
            #expect(routed.events == direct.events)
            #expect(routed.presentation == direct.presentation)
            #expect(coordinator.state == engine.state)
        }
    }

    @Test("Selected movement durations dispatch identically, accepted or not")
    func selectMovementDispatchMatchesEngine() {
        for duration: TimeInterval in [12, 6, 7] {
            var engine = seededEngine()
            var coordinator = OpportunityCoordinator(engine: engine)
            let direct = engine.selectMovement(durationSeconds: duration)
            let routed = coordinator.dispatch(.selectMovement(durationSeconds: duration))
            #expect(routed.events == direct.events)
            #expect(routed.presentation == direct.presentation)
            #expect(coordinator.state == engine.state)
        }
    }

    @Test("Resolution dispatches match the engine")
    func resolutionDispatchMatchesEngine() {
        var engine = seededEngine()
        var coordinator = OpportunityCoordinator(engine: engine)

        let date = Date(timeIntervalSince1970: 1000)
        let commands: [OpportunityCoordinatorCommand] = [
            .observeRecoverySession(at: date, systemAvailable: true),
            .resumeExpiredSnoozes(at: date),
            .snooze(opportunity: .visual, durationSeconds: 3, at: date),
            .snooze(opportunity: .movement, durationSeconds: 3, at: date),
            .snooze(opportunity: .recovery, durationSeconds: 3, at: date),
            .skipMergedSegment(.visual),
            .mergedEscapeDuringVisual,
            .resumeRecoverySession(at: date),
            .resumeInterruptedBreak,
        ]
        for command in commands {
            let direct = applyDirectly(command, to: &engine)
            let routed = coordinator.dispatch(command)
            #expect(routed.events == direct.events)
            #expect(routed.presentation == direct.presentation)
            #expect(coordinator.state == engine.state)
        }
    }

    @Test("Current presentation matches every output presentation")
    func currentPresentationMatchesOutputs() throws {
        let configuration = try Self.makeConfiguration(mergeWindowSeconds: 0)
        let states: [(TimeInterval, TimeInterval, Bool)] = [
            (0, 0, false),
            (19, 55, true),
            (20, 55, true),
            (55, 55, false),
            (89, 89, true),
        ]
        for (visual, movement, lowFriction) in states {
            var engine = ProtocolEngine(
                configuration: configuration,
                visualClock: OpportunityClockState(
                    cycleID: 0,
                    accumulatedActiveUseSeconds: visual,
                    phase: .accumulating,
                ),
                movementClock: OpportunityClockState(
                    cycleID: 0,
                    accumulatedActiveUseSeconds: movement,
                    phase: .accumulating,
                ),
            )
            var coordinator = OpportunityCoordinator(engine: engine)
            let direct = engine.observe(
                .active(uptimeSeconds: 0, secondsSinceInput: 0),
                isLowFrictionMoment: lowFriction,
            )
            let routed = coordinator.dispatch(.observe(
                sample: .active(uptimeSeconds: 0, secondsSinceInput: 0),
                activeSuppressions: [],
                isLowFrictionMoment: lowFriction,
            ))
            #expect(routed.presentation == direct.presentation)
            #expect(coordinator.currentPresentation() == routed.presentation)
            #expect(coordinator.state == engine.state)
        }
    }

    @Test("Facade arbitrates merged, standalone, and recovery")
    func facadeArbitratesPresentations() throws {
        var merged = try ProtocolEngine(configuration: Self.makeConfiguration(movementTarget: 25))
        _ = merged.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        var mergedCoordinator = OpportunityCoordinator(engine: merged)
        let mergedOutput = mergedCoordinator.dispatch(.observe(
            sample: .active(uptimeSeconds: 20, secondsSinceInput: 0),
            activeSuppressions: [],
            isLowFrictionMoment: true,
        ))
        #expect(mergedOutput.presentation == .merged)
        #expect(mergedCoordinator.currentPresentation() == .merged)

        var visual = try ProtocolEngine(configuration: Self.makeConfiguration(movementTarget: 26))
        _ = visual.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        var visualCoordinator = OpportunityCoordinator(engine: visual)
        let visualOutput = visualCoordinator.dispatch(.observe(
            sample: .active(uptimeSeconds: 20, secondsSinceInput: 0),
            activeSuppressions: [],
            isLowFrictionMoment: true,
        ))
        #expect(visualOutput.presentation == .visual)

        let recoveryConfiguration = try Self.makeConfiguration(recoveryDeferrals: 2, recoveryAfter: 90)
        var recovery = ProtocolEngine(configuration: recoveryConfiguration)
        _ = recovery.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = recovery.observe(.active(uptimeSeconds: 89, secondsSinceInput: 0))
        var recoveryCoordinator = OpportunityCoordinator(engine: recovery)
        _ = recoveryCoordinator.dispatch(.snooze(
            opportunity: .movement,
            durationSeconds: 3,
            at: Date(timeIntervalSince1970: 0),
        ))
        _ = recoveryCoordinator.dispatch(.record(
            kind: .skipped,
            opportunity: .movement,
            selectedDurationSeconds: nil,
            source: .user,
        ))
        let recoveryOutput = recoveryCoordinator.dispatch(.observe(
            sample: .active(uptimeSeconds: 90, secondsSinceInput: 0),
            activeSuppressions: [],
            isLowFrictionMoment: false,
        ))
        #expect(recoveryOutput.presentation == .recovery)
    }

    @Test("Runtime observe and restore chains match through the facade")
    func runtimeChainsMatchThroughFacade() {
        var direct = seededEngine()
        var coordinator = OpportunityCoordinator(engine: direct)
        let observationDate = Date(timeIntervalSince1970: 1000)

        direct.observeRecoverySession(at: observationDate, systemAvailable: true)
        _ = direct.resumeExpiredSnoozes(at: observationDate)
        let directObserve = direct.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))

        _ = coordinator.dispatch(.observeRecoverySession(at: observationDate, systemAvailable: true))
        _ = coordinator.dispatch(.resumeExpiredSnoozes(at: observationDate))
        let routedObserve = coordinator.dispatch(.observe(
            sample: .active(uptimeSeconds: 10, secondsSinceInput: 0),
            activeSuppressions: [],
            isLowFrictionMoment: false,
        ))
        #expect(routedObserve.events == directObserve.events)
        #expect(routedObserve.presentation == directObserve.presentation)
        #expect(coordinator.state == direct.state)

        var restoring = ProtocolEngine(
            configuration: configuration,
            visualClock: OpportunityClockState(
                cycleID: 0,
                accumulatedActiveUseSeconds: 7,
                phase: .running,
            ),
            movementClock: OpportunityClockState(
                cycleID: 0,
                accumulatedActiveUseSeconds: 7,
                phase: .running,
            ),
        )
        var restoringCoordinator = OpportunityCoordinator(engine: restoring)
        restoring.resumeInterruptedBreak()
        restoring.resumeRecoverySession(at: observationDate)
        let directResumed = restoring.resumeExpiredSnoozes(at: observationDate)

        _ = restoringCoordinator.dispatch(.resumeInterruptedBreak)
        _ = restoringCoordinator.dispatch(.resumeRecoverySession(at: observationDate))
        let routedResumed = restoringCoordinator.dispatch(.resumeExpiredSnoozes(at: observationDate))
        #expect(routedResumed.events == directResumed.events)
        #expect(routedResumed.presentation == directResumed.presentation)
        #expect(restoringCoordinator.state == restoring.state)
    }

    private func seededEngine() -> ProtocolEngine {
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 7, secondsSinceInput: 0))
        return engine
    }

    private func applyDirectly(
        _ command: OpportunityCoordinatorCommand,
        to engine: inout ProtocolEngine,
    ) -> ProtocolEngineOutput {
        switch command {
        case let .observe(sample, activeSuppressions, isLowFrictionMoment):
            return engine.observe(
                sample,
                activeSuppressions: activeSuppressions,
                isLowFrictionMoment: isLowFrictionMoment,
            )
        case let .record(kind, opportunity, selectedDurationSeconds, source):
            return engine.record(
                kind,
                opportunity: opportunity,
                selectedDurationSeconds: selectedDurationSeconds,
                source: source,
            )
        case let .snooze(opportunity, durationSeconds, date):
            return engine.snooze(opportunity, durationSeconds: durationSeconds, at: date)
        case let .selectMovement(durationSeconds):
            return engine.selectMovement(durationSeconds: durationSeconds)
        case let .skipMergedSegment(opportunity):
            return engine.skipMergedSegment(opportunity)
        case .mergedEscapeDuringVisual:
            return ProtocolEngineOutput(
                events: [engine.applyMergedEscapeDuringVisual()],
                presentation: OpportunityCoordinator(engine: engine).currentPresentation(),
            )
        case let .resumeExpiredSnoozes(date):
            return engine.resumeExpiredSnoozes(at: date)
        case let .observeRecoverySession(date, systemAvailable):
            engine.observeRecoverySession(at: date, systemAvailable: systemAvailable)
            return ProtocolEngineOutput(
                events: [],
                presentation: OpportunityCoordinator(engine: engine).currentPresentation(),
            )
        case let .resumeRecoverySession(date):
            engine.resumeRecoverySession(at: date)
            return ProtocolEngineOutput(
                events: [],
                presentation: OpportunityCoordinator(engine: engine).currentPresentation(),
            )
        case .resumeInterruptedBreak:
            engine.resumeInterruptedBreak()
            return ProtocolEngineOutput(
                events: [],
                presentation: OpportunityCoordinator(engine: engine).currentPresentation(),
            )
        }
    }

    private static func makeConfiguration(
        movementTarget: TimeInterval = 50,
        mergeWindowSeconds: TimeInterval = 5,
        recoveryDeferrals: Int? = nil,
        recoveryAfter: TimeInterval = 90,
    ) throws -> ProtocolConfiguration {
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
                mergeWindowSeconds: mergeWindowSeconds,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 2,
                snoozeOptionsSeconds: [3, 6, 9],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
            recovery: recoveryDeferrals.map {
                try RecoveryConfiguration(
                    eligibleAfterSeconds: recoveryAfter,
                    requiredMovementDeferrals: $0,
                )
            },
        )
    }
}
