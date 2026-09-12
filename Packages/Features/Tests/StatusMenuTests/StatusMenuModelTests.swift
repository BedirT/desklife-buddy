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

    @Test("An explicit pause explains why the menu is quiet and uses the paused glyph")
    func suppression() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(),
            configuration: configuration(),
            context: StatusMenuContext(activeSuppression: .manualPause),
        )

        #expect(model.snapshot.glyph == .paused)
        #expect(model.snapshot.activeSuppression == .manualPause)
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
    @Test("User-declared holds and waits read as held, never paused", arguments: [
        SuppressionReason.userDeclaredMeetingOrCall,
        SuppressionReason.userDeclaredScreenSharingOrPresentation,
        SuppressionReason.userSelectedTimedTask,
        SuppressionReason.snooze,
        SuppressionReason.lowFrictionWait,
    ])
    func heldBucket(reason: SuppressionReason) throws {
        let model = try StatusMenuModel(
            state: ProtocolState(),
            configuration: configuration(),
            context: StatusMenuContext(activeSuppression: reason),
        )

        #expect(model.snapshot.glyph == .held)
        #expect(model.snapshot.activeSuppression == reason)
    }

    @Test("Protected contexts read as quiet, never paused", arguments: [
        SuppressionReason.systemInactiveOrLocked,
        SuppressionReason.explicitPresentationMode,
        SuppressionReason.focusFilter,
        SuppressionReason.calendarBusy,
        SuppressionReason.excludedApplication,
    ])
    func protectedBucket(reason: SuppressionReason) throws {
        let model = try StatusMenuModel(
            state: ProtocolState(),
            configuration: configuration(),
            context: StatusMenuContext(activeSuppression: reason),
        )

        #expect(model.snapshot.glyph == .protected)
        #expect(model.snapshot.activeSuppression == reason)
    }

    @Test("Pause-policy reasons stay on the paused glyph", arguments: [
        SuppressionReason.manualPause,
        SuppressionReason.outsideWorkingHours,
    ])
    func pausedBucket(reason: SuppressionReason) throws {
        let model = try StatusMenuModel(
            state: ProtocolState(),
            configuration: configuration(),
            context: StatusMenuContext(activeSuppression: reason),
        )

        #expect(model.snapshot.glyph == .paused)
    }

    @Test("A running clock reads as an accepted ritual instead of due")
    func acceptedRitual() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(
                visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 25, phase: .running),
                movementClock: OpportunityClockState(),
            ),
            configuration: configuration(),
        )

        #expect(model.snapshot.glyph == .acceptedRitual)
        #expect(model.snapshot.visual.isRunning)
        #expect(!model.snapshot.movement.isRunning)
        #expect(model.snapshot.visual.timing == .due)
    }

    @Test("Quiet wins over a running ritual")
    func suppressionBeatsRunning() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(
                visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 25, phase: .running),
            ),
            configuration: configuration(),
            context: StatusMenuContext(activeSuppression: .calendarBusy),
        )

        #expect(model.snapshot.glyph == .protected)
    }

    @Test("Heads-up off reads as a degraded menu-only state")
    func headsUpOff() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(),
            configuration: configuration(headsUpDefault: false),
        )

        #expect(model.snapshot.glyph == .degraded)
    }

    @Test("Due clocks stay due-shaped when heads-up is off", arguments: [
        OpportunityType.visual,
        OpportunityType.movement,
    ])
    func degradedKeepsDueTiming(opportunity: OpportunityType) throws {
        let model = try StatusMenuModel(
            state: ProtocolState(
                visualClock: OpportunityClockState(
                    accumulatedActiveUseSeconds: opportunity == .visual ? 25 : 0,
                ),
                movementClock: OpportunityClockState(
                    accumulatedActiveUseSeconds: opportunity == .movement ? 35 : 0,
                ),
            ),
            configuration: configuration(headsUpDefault: false),
        )

        #expect(model.snapshot.glyph == .degraded)
        let timing = opportunity == .visual
            ? model.snapshot.visual.timing
            : model.snapshot.movement.timing
        #expect(timing == .due)
    }

    @Test("Quiet and in-progress states win over heads-up off")
    func degradedYields() throws {
        let quiet = try StatusMenuModel(
            state: ProtocolState(),
            configuration: configuration(headsUpDefault: false),
            context: StatusMenuContext(activeSuppression: .calendarBusy),
        )
        #expect(quiet.snapshot.glyph == .protected)

        let ritual = try StatusMenuModel(
            state: ProtocolState(
                movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 35, phase: .running),
            ),
            configuration: configuration(headsUpDefault: false),
        )
        #expect(ritual.snapshot.glyph == .acceptedRitual)
    }

    @Test("Clock summaries carry counted minutes for the Why-now line")
    func countedMinutes() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(
                visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 2820),
                movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 2040),
            ),
            configuration: configuration(),
        )

        #expect(model.snapshot.glyph == .bothDue)
        #expect(model.snapshot.visual.activeUseMinutes == 47)
        #expect(model.snapshot.movement.activeUseMinutes == 34)
    }

    @Test("Every preview state maps to its shipped glyph")
    func previewGlyphs() {
        #expect(StatusMenuModel.preview(.normal).snapshot.glyph == .operating)
        #expect(StatusMenuModel.preview(.visualDue).snapshot.glyph == .visualDue)
        #expect(StatusMenuModel.preview(.movementDue).snapshot.glyph == .movementDue)
        #expect(StatusMenuModel.preview(.bothDue).snapshot.glyph == .bothDue)
        #expect(StatusMenuModel.preview(.paused).snapshot.glyph == .paused)
        #expect(StatusMenuModel.preview(.timedPause).snapshot.glyph == .paused)
        #expect(StatusMenuModel.preview(.calendarBusy).snapshot.glyph == .protected)
        #expect(StatusMenuModel.preview(.held).snapshot.glyph == .held)
        #expect(StatusMenuModel.preview(.protected).snapshot.glyph == .protected)
        #expect(StatusMenuModel.preview(.acceptedRitual).snapshot.glyph == .acceptedRitual)
        #expect(StatusMenuModel.preview(.headsUpOff).snapshot.glyph == .degraded)
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

    private func configuration(headsUpDefault: Bool = true) throws -> ProtocolConfiguration {
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
                headsUpDefault: headsUpDefault,
                headsUpSecondsBeforeTarget: 4,
                snoozeOptionsSeconds: [5, 10, 15],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )
    }
}
