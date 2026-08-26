import Domain
import Testing
@testable import StatusMenu

@Suite("StatusMenuModel")
struct StatusMenuModelTests {
    @Test("Normal state summarizes independent clocks without ticking seconds")
    func normal() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(
                visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 6),
                movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 12),
            ),
            configuration: configuration(),
            context: StatusMenuContext(
                estimatedActiveUseSeconds: 63,
                workingHoursOnly: true,
            ),
        )

        #expect(model.snapshot.glyph == .operating)
        #expect(model.snapshot.visual == StatusClockSummary(
            opportunity: .visual,
            progress: 0.3,
            timing: .next(aboutMinutes: 1),
        ))
        #expect(model.snapshot.movement == StatusClockSummary(
            opportunity: .movement,
            progress: 0.4,
            timing: .next(aboutMinutes: 1),
        ))
        #expect(model.snapshot.estimatedActiveUseMinutes == 1)
        #expect(model.snapshot.workingHoursOnly)
    }

    @Test("Soft-due clocks select the matching monochrome glyph beat", arguments: [
        (OpportunityType.visual, StatusMenuGlyph.visualDue),
        (OpportunityType.movement, StatusMenuGlyph.movementDue),
    ])
    func dueGlyph(opportunity: OpportunityType, expectedGlyph: StatusMenuGlyph) throws {
        let state = ProtocolState(
            visualClock: OpportunityClockState(
                accumulatedActiveUseSeconds: opportunity == .visual ? 10 : 0,
            ),
            movementClock: OpportunityClockState(
                accumulatedActiveUseSeconds: opportunity == .movement ? 20 : 0,
            ),
        )

        let model = try StatusMenuModel(state: state, configuration: configuration())

        #expect(model.snapshot.glyph == expectedGlyph)
        let timing = opportunity == .visual
            ? model.snapshot.visual.timing
            : model.snapshot.movement.timing
        #expect(timing == .due)
    }

    @Test("Two soft-due clocks select the two-dot merged glyph")
    func bothDue() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(
                visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 10),
                movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 20),
            ),
            configuration: configuration(),
        )

        #expect(model.snapshot.glyph == .bothDue)
        #expect(model.snapshot.visual.timing == .due)
        #expect(model.snapshot.movement.timing == .due)
    }

    @Test("Any active suppression explains why the menu is quiet and uses the paused glyph")
    func suppression() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(),
            configuration: configuration(),
            context: StatusMenuContext(activeSuppression: .calendarBusy),
        )

        #expect(model.snapshot.glyph == .paused)
        #expect(model.snapshot.activeSuppression == .calendarBusy)
    }

    @Test("A live heads-up adds keyboard-equivalent rows without changing event meaning")
    func headsUp() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(),
            configuration: configuration(),
            context: StatusMenuContext(liveHeadsUp: .movement),
        )

        #expect(model.snapshot.liveHeadsUp == .movement)
    }

    @Test("Every interaction is emitted as an explicit App-owned intent")
    func actionRouting() throws {
        var actions: [StatusMenuAction] = []
        let model = try StatusMenuModel(
            state: ProtocolState(),
            configuration: configuration(),
            onAction: { actions.append($0) },
        )

        model.send(.startVisualReset)
        model.send(.startMovement(.recommended))
        model.send(.pause(.untilResume))
        model.send(.toggleWorkingHours)
        model.send(.openWeeklyRhythm)
        model.send(.openSettings)
        model.send(.quit)

        #expect(actions == [
            .startVisualReset,
            .startMovement(.recommended),
            .pause(.untilResume),
            .toggleWorkingHours,
            .openWeeklyRhythm,
            .openSettings,
            .quit,
        ])
    }

    private func configuration() throws -> ProtocolConfiguration {
        try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 10,
                targetSeconds: 20,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [2],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: 20,
                targetSeconds: 30,
                latestPreferredSeconds: 40,
                durationOptionsSeconds: [5, 2],
            ),
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 6,
                longIdleResetSeconds: 30,
                wakeUnlockGraceSeconds: 9,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: true,
                mergeWindowSeconds: 5,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 4,
                snoozeOptionsSeconds: [5, 10, 15],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )
    }
}
