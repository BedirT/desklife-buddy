import Domain
import Foundation
import Testing
@testable import Movement

@Suite("Movement session")
struct MovementModelTests {
    @Test("Standard layout keeps the full control stack above the revealed Dock")
    func standardLayoutClearsRevealedDock() {
        let verticalPosition = MovementStandardLayoutMetrics.y(
            MovementStandardLayoutMetrics.controlsYFraction,
            in: 982,
        )
        #expect(verticalPosition <= 760)
    }

    @Test("Open self-starts with the protocol's recommended duration")
    func opensWithConfiguredDuration() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        var announcements: [MovementAnnouncement] = []
        let model = try makeModel(
            clock: clock,
            durations: [300, 120],
            onAction: { actions.append($0) },
            onAnnouncement: { announcements.append($0) },
        )

        model.open()
        model.open()

        #expect(model.phase == .running)
        #expect(model.selectedDurationSeconds == 300)
        #expect(model.remainingSeconds == 300)
        #expect(model.deadline == 300)
        #expect(model.selectedChoice == .walkOrWheel)
        #expect(actions == [.opened])
        #expect(announcements == [.opened(durationSeconds: 300)])
    }

    @Test("The first two protocol duration options remain the recommended and quick choices")
    func derivesDurationsFromProtocol() throws {
        let model = try makeModel(durations: [420, 150])

        #expect(model.recommendedDurationSeconds == 420)
        #expect(model.quickDurationSeconds == 150)
        #expect(model.selectedDurationSeconds == 420)
        #expect(model.remainingSeconds == 420)
    }

    @Test("A configured quick entry opens with the matching duration announcement")
    func opensWithQuickEntry() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        var announcements: [MovementAnnouncement] = []
        let schedule = try movementSchedule(durations: [300, 120])
        let model = MovementModel(
            schedule: schedule,
            initialDurationSeconds: 120,
            now: { clock.value },
            onAction: { actions.append($0) },
            onAnnouncement: { announcements.append($0) },
        )

        model.open()
        model.confirmSelectedDuration()

        #expect(model.deadline == 120)
        #expect(model.remainingSeconds == 120)
        #expect(actions == [.opened, .selectedDuration(120)])
        #expect(announcements == [.opened(durationSeconds: 120)])
    }

    @Test("Refresh derives countdown and progress from the injected monotonic deadline")
    func refreshesFromDeadline() throws {
        let clock = TestClock()
        let model = try makeModel(clock: clock)
        model.open()

        clock.value = 74.25
        model.refresh()

        #expect(model.remainingSeconds == 226)
        #expect(model.progress == 74.25 / 300)
        #expect(model.deadline == 300)
    }

    @Test("All three movement choices have equal typed selection behavior and bound guidance")
    func selectionParity() throws {
        var announcements: [MovementAnnouncement] = []
        let model = try makeModel(onAnnouncement: { announcements.append($0) })
        model.open()

        for choice in [MovementChoice.smallSpace, .seated, .walkOrWheel] {
            model.select(choice)
            #expect(model.selectedChoice == choice)
            #expect(model.guidance == MovementGuidance(choice: choice))
        }

        #expect(announcements == [
            .opened(durationSeconds: 300),
            .selectionChanged(.smallSpace),
            .selectionChanged(.seated),
            .selectionChanged(.walkOrWheel),
        ])
    }

    @Test("Keyboard choices remain inert until the declaration guard arms")
    func selectionKeyboardGuard() throws {
        let clock = TestClock()
        var announcements: [MovementAnnouncement] = []
        let model = try makeModel(
            clock: clock,
            onAnnouncement: { announcements.append($0) },
        )
        model.open()

        clock.value = 0.79
        model.selectFromKeyboard(.smallSpace)
        #expect(model.selectedChoice == .walkOrWheel)

        clock.value = 0.8
        model.selectFromKeyboard(.smallSpace)

        #expect(model.selectedChoice == .smallSpace)
        #expect(announcements == [
            .opened(durationSeconds: 300),
            .selectionChanged(.smallSpace),
        ])
    }

    @Test("Q switches to quick duration from the original open time after the guard arms")
    func durationKeyboardSwitch() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        let model = try makeModel(clock: clock, onAction: { actions.append($0) })
        model.open()

        clock.value = 0.79
        model.selectQuickDurationFromKeyboard()
        #expect(model.selectedDurationSeconds == 300)

        clock.value = 30
        model.selectQuickDurationFromKeyboard()

        #expect(model.selectedDurationSeconds == 120)
        #expect(model.deadline == 120)
        #expect(model.remainingSeconds == 90)
        #expect(actions == [.opened, .selectedDuration(120)])

        model.selectQuickDurationFromKeyboard()
        #expect(model.selectedDurationSeconds == 120)
        #expect(model.deadline == 120)
        #expect(model.remainingSeconds == 90)
        #expect(actions == [.opened, .selectedDuration(120)])
    }

    @Test("Pointer duration selection is immediate and does not restart elapsed time")
    func durationPointerSelection() throws {
        let clock = TestClock()
        let model = try makeModel(clock: clock)
        model.open()
        clock.value = 15

        model.selectQuickDuration()

        #expect(model.selectedDurationSeconds == 120)
        #expect(model.deadline == 120)
        #expect(model.remainingSeconds == 105)
    }

    @Test("Explicit recommended selection is distinct from the automatic visual default")
    func explicitRecommendedSelection() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        let model = try makeModel(clock: clock, onAction: { actions.append($0) })
        model.open()
        clock.value = 15

        model.selectRecommendedDuration()
        model.selectRecommendedDuration()

        #expect(model.selectedDurationSeconds == 300)
        #expect(model.deadline == 300)
        #expect(model.remainingSeconds == 285)
        #expect(actions == [.opened, .selectedDuration(300)])
    }

    @Test("Quick selection cannot extend the session back to recommended duration")
    func quickSelectionIsOneWay() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        let model = try makeModel(clock: clock, onAction: { actions.append($0) })
        model.open()
        clock.value = 15
        model.selectQuickDuration()

        model.selectRecommendedDuration()

        #expect(model.selectedDurationSeconds == 120)
        #expect(model.deadline == 120)
        #expect(model.remainingSeconds == 105)
        #expect(actions == [.opened, .selectedDuration(120)])
    }

    @Test("A rejected quick duration lifecycle fact can be retried from the same selection")
    func rejectedQuickDurationIsRetryable() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        let schedule = try movementSchedule(durations: [300, 120])
        let model = MovementModel(
            schedule: schedule,
            requiresLifecycleConfirmation: true,
            now: { clock.value },
            onAction: { actions.append($0) },
        )
        model.open()
        model.confirmLifecycle(.opened)

        model.selectQuickDuration()
        model.rejectLifecycle(.selectedDuration(120))
        model.selectQuickDuration()

        #expect(model.selectedDurationSeconds == 120)
        #expect(model.deadline == 120)
        #expect(actions == [
            .opened,
            .selectedDuration(120),
            .selectedDuration(120),
        ])
    }

    @Test("Return A and P are guarded while pointer declarations remain immediate")
    func declarationGuard() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        let model = try makeModel(clock: clock, onAction: { actions.append($0) })
        model.open()

        clock.value = 0.79
        model.doneEarlyFromKeyboard()
        model.alreadyMovedFromKeyboard()
        model.positionChangedFromKeyboard()
        #expect(model.phase == .running)

        model.doneEarly()

        #expect(model.phase == .finished(.doneEarly))
        #expect(actions == [.opened, .doneEarly])
    }
}

extension MovementModelTests {
    @Test("Escape is immediate on the first frame and every terminal action is emitted once")
    func escapeIsImmediateAndTerminalIsOnceOnly() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        var announcements: [MovementAnnouncement] = []
        let model = try makeModel(
            clock: clock,
            onAction: { actions.append($0) },
            onAnnouncement: { announcements.append($0) },
        )
        model.open()

        model.skip()
        model.skip()
        model.doneEarly()
        model.alreadyMoved()
        model.positionChanged()
        clock.value = 300
        model.refresh()

        #expect(model.phase == .finished(.skipped))
        #expect(actions == [.opened, .skipped])
        #expect(announcements == [.opened(durationSeconds: 300), .skipped])
    }

    @Test("Timer announces only open one minute and terminal milestones")
    func announcementsAreCoarse() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        var announcements: [MovementAnnouncement] = []
        let model = try makeModel(
            clock: clock,
            onAction: { actions.append($0) },
            onAnnouncement: { announcements.append($0) },
        )
        model.open()

        for elapsed in stride(from: 1.0, through: 239.0, by: 1.0) {
            clock.value = elapsed
            model.refresh()
        }
        #expect(announcements == [.opened(durationSeconds: 300)])

        clock.value = 240
        model.refresh()
        clock.value = 241
        model.refresh()
        #expect(announcements == [.opened(durationSeconds: 300), .oneMinuteRemaining])

        clock.value = 300
        model.refresh()
        model.refresh()
        #expect(announcements == [
            .opened(durationSeconds: 300),
            .oneMinuteRemaining,
            .finished,
        ])
        #expect(model.phase == .finished(.timerFinished))
        #expect(actions == [.opened, .timerFinished])
    }

    @Test("A rejected timer fact retries once per second rather than once per render")
    func rejectedTimerRetryIsThrottled() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        let schedule = try movementSchedule(durations: [300, 120])
        let model = MovementModel(
            schedule: schedule,
            requiresLifecycleConfirmation: true,
            now: { clock.value },
            onAction: { actions.append($0) },
        )
        model.open()
        model.confirmLifecycle(.opened)
        clock.value = 300
        model.refresh()

        model.rejectLifecycle(.timerFinished)
        for frame in 1 ... 29 {
            clock.value = 300 + Double(frame) / 30
            model.refresh()
        }

        #expect(model.phase == .running)
        #expect(actions == [.opened, .timerFinished])

        clock.value = 301
        model.refresh()

        #expect(model.phase == .finished(.timerFinished))
        #expect(actions == [.opened, .timerFinished, .timerFinished])
    }

    @Test("Each declared exit has its exact terminal announcement", arguments: [
        (MovementTerminalAction.doneEarly, MovementAnnouncement.doneEarly),
        (MovementTerminalAction.alreadyMoved, MovementAnnouncement.alreadyMoved),
        (MovementTerminalAction.positionChanged, MovementAnnouncement.positionChanged),
    ])
    func terminalAnnouncement(
        terminal: MovementTerminalAction,
        announcement: MovementAnnouncement,
    ) throws {
        let clock = TestClock()
        var announcements: [MovementAnnouncement] = []
        let model = try makeModel(
            clock: clock,
            onAnnouncement: { announcements.append($0) },
        )
        model.open()
        clock.value = 0.8

        switch terminal {
        case .timerFinished, .visualOnly, .skipped:
            Issue.record("Covered by dedicated timer and Escape tests")
        case .doneEarly:
            model.doneEarlyFromKeyboard()
        case .alreadyMoved:
            model.alreadyMovedFromKeyboard()
        case .positionChanged:
            model.positionChangedFromKeyboard()
        }

        #expect(model.phase == .finished(terminal))
        #expect(announcements == [.opened(durationSeconds: 300), announcement])
    }

    @Test("Accessibility changes apply live without moving the deadline or restarting")
    func accessibilityChangesAreLive() throws {
        let clock = TestClock()
        let model = try makeModel(clock: clock)
        model.open()
        clock.value = 90
        model.refresh()
        #expect(model.progress == 0.3)

        model.updateAccessibility(.init(
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
            staticPresentation: true,
        ))

        #expect(model.accessibility.reduceMotion)
        #expect(model.accessibility.reduceTransparency)
        #expect(model.accessibility.increaseContrast)
        #expect(model.accessibility.staticPresentation)
        #expect(model.progress == 0)
        #expect(model.deadline == 300)

        clock.value = 180
        model.refresh()
        #expect(model.progress == 0.5)
        #expect(model.remainingSeconds == 120)
    }
}
