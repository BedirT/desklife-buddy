import Foundation
import Testing
@testable import VisualReset

@Suite("Visual reset session")
struct VisualResetModelTests {
    @Test("Standard layout keeps the alternative above the revealed Dock")
    func standardLayoutClearsRevealedDock() {
        let verticalPosition = VisualResetStandardLayoutMetrics.y(
            VisualResetStandardLayoutMetrics.alternativeYFraction,
            in: 982,
        )
        #expect(verticalPosition <= 840)
    }

    @Test("Opening starts one self-running 20-second session")
    func opensOnce() {
        let clock = TestClock()
        var actions: [VisualResetAction] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            now: { clock.value },
            onAction: { actions.append($0) },
        )

        model.open()
        model.open()

        #expect(model.phase == .running)
        #expect(model.remainingSeconds == 20)
        #expect(model.progress == 0)
        #expect(actions == [.opened])
    }

    @Test("Refresh derives countdown and progress from the monotonic clock")
    func refreshesFromClock() {
        let clock = TestClock()
        let model = VisualResetModel(durationSeconds: 20, now: { clock.value })
        model.open()

        clock.value = 7.25
        model.refresh()

        #expect(model.remainingSeconds == 13)
        #expect(model.progress == 7.25 / 20)
        #expect(model.phase == .running)
    }

    @Test("A deferred countdown stays at twenty until the field settles")
    func countdownStartsAfterEntrance() {
        let clock = TestClock()
        let model = VisualResetModel(
            durationSeconds: 20,
            countdownStartsOnOpen: false,
            now: { clock.value },
        )
        model.open()

        clock.value = 3
        model.refresh()
        #expect(model.remainingSeconds == 20)
        #expect(model.progress == 0)

        model.startCountdown()
        model.startCountdown()
        clock.value = 4.1
        model.refresh()

        #expect(model.remainingSeconds == 19)
        #expect(abs(model.progress - 1.1 / 20) < 0.000_001)
    }

    @Test("An instant settled field can request the countdown before open")
    func settledFieldBeforeOpen() {
        let clock = TestClock()
        let model = VisualResetModel(
            durationSeconds: 20,
            countdownStartsOnOpen: false,
            now: { clock.value },
        )

        model.startCountdown()
        clock.value = 2
        model.open()
        clock.value = 3.1
        model.refresh()

        #expect(model.remainingSeconds == 19)
    }

    @Test("The centralized final-seconds threshold precedes one timer fact")
    func finishesOnce() {
        let clock = TestClock()
        var actions: [VisualResetAction] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            finalSecondsThreshold: 3,
            now: { clock.value },
            onAction: { actions.append($0) },
        )
        model.open()

        clock.value = 17
        model.refresh()
        #expect(model.phase == .finalSeconds)
        #expect(model.remainingSeconds == 3)

        clock.value = 20
        model.refresh()
        model.refresh()

        #expect(model.phase == .finished(.timerFinished))
        #expect(model.remainingSeconds == 0)
        #expect(model.progress == 1)
        #expect(actions == [.opened, .timerFinished])
    }

    @Test("Keyboard Done early is immediate from the first active frame")
    func immediateKeyboardDeclaration() {
        let clock = TestClock()
        var actions: [VisualResetAction] = []
        var announcements: [VisualResetAnnouncement] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            declarationArmDelay: 0.8,
            now: { clock.value },
            onAction: { actions.append($0) },
            onAnnouncement: { announcements.append($0) },
        )
        model.open()

        model.doneEarlyFromKeyboard()
        model.doneEarlyFromKeyboard()

        #expect(model.phase == .finished(.doneEarly))
        #expect(actions == [.opened, .doneEarly])
        #expect(announcements == [.opened(durationSeconds: 20), .doneEarly])
    }

    @Test("Pointer and assistive activation can declare Done early immediately")
    func declarationControlIsImmediate() {
        let clock = TestClock()
        let model = VisualResetModel(durationSeconds: 20, now: { clock.value })
        model.open()

        model.doneEarly()

        #expect(model.phase == .finished(.doneEarly))
    }

    @Test("Escape-style skip is immediate and terminal from the first frame")
    func skipIsImmediate() {
        let clock = TestClock()
        var actions: [VisualResetAction] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            now: { clock.value },
            onAction: { actions.append($0) },
        )
        model.open()

        model.skip()
        model.skip()
        clock.value = 20
        model.refresh()

        #expect(model.phase == .finished(.skipped))
        #expect(actions == [.opened, .skipped])
    }

    @Test("A terminal announcement waits for persistence confirmation")
    func terminalWaitsForLifecycleConfirmation() {
        let clock = TestClock()
        var actions: [VisualResetAction] = []
        var announcements: [VisualResetAnnouncement] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            requiresLifecycleConfirmation: true,
            now: { clock.value },
            onAction: { actions.append($0) },
            onAnnouncement: { announcements.append($0) },
        )
        model.open()
        model.confirmLifecycle(.opened)

        model.doneEarly()
        #expect(announcements == [.opened(durationSeconds: 20)])
        model.confirmLifecycle(.doneEarly)
        model.confirmLifecycle(.doneEarly)

        #expect(model.phase == .finished(.doneEarly))
        #expect(actions == [.opened, .doneEarly])
        #expect(announcements == [.opened(durationSeconds: 20), .doneEarly])
    }

    @Test("A rejected terminal restores its exact active phase and can be retried")
    func rejectedTerminalIsRetryable() {
        let clock = TestClock()
        var actions: [VisualResetAction] = []
        var announcements: [VisualResetAnnouncement] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            requiresLifecycleConfirmation: true,
            now: { clock.value },
            onAction: { actions.append($0) },
            onAnnouncement: { announcements.append($0) },
        )
        model.open()
        model.confirmLifecycle(.opened)
        clock.value = 17
        model.refresh()
        #expect(model.phase == .finalSeconds)

        model.skip()
        model.rejectLifecycle(.skipped)
        #expect(model.phase == .finalSeconds)

        model.skip()
        model.confirmLifecycle(.skipped)

        #expect(model.phase == .finished(.skipped))
        #expect(actions == [.opened, .skipped, .skipped])
        #expect(announcements == [
            .opened(durationSeconds: 20),
            .tenSecondsRemaining,
            .skipped,
        ])
    }

    @Test("A rejected timer fact retries once per second rather than once per render")
    func rejectedTimerRetryIsThrottled() {
        let clock = TestClock()
        var actions: [VisualResetAction] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            requiresLifecycleConfirmation: true,
            now: { clock.value },
            onAction: { actions.append($0) },
        )
        model.open()
        model.confirmLifecycle(.opened)
        clock.value = 17
        model.refresh()
        clock.value = 20
        model.refresh()

        model.rejectLifecycle(.timerFinished)
        #expect(model.phase == .finalSeconds)
        for frame in 1 ... 29 {
            clock.value = 20 + Double(frame) / 30
            model.refresh()
        }

        #expect(model.phase == .finalSeconds)
        #expect(actions == [.opened, .timerFinished])

        clock.value = 21
        model.refresh()

        #expect(model.phase == .finished(.timerFinished))
        #expect(actions == [.opened, .timerFinished, .timerFinished])
    }
}

extension VisualResetModelTests {
    @Test("A rejected open returns to ready and can begin again")
    func rejectedOpenIsRetryable() {
        let clock = TestClock()
        var actions: [VisualResetAction] = []
        var announcements: [VisualResetAnnouncement] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            requiresLifecycleConfirmation: true,
            now: { clock.value },
            onAction: { actions.append($0) },
            onAnnouncement: { announcements.append($0) },
        )

        model.open()
        model.rejectLifecycle(.opened)
        #expect(model.phase == .ready)

        clock.value = 4
        model.open()
        model.confirmLifecycle(.opened)

        #expect(model.phase == .running)
        #expect(model.remainingSeconds == 20)
        #expect(actions == [.opened, .opened])
        #expect(announcements == [.opened(durationSeconds: 20)])
    }

    @Test("VoiceOver receives only open ten-second and terminal milestones")
    func announcementsAreCoarse() {
        let clock = TestClock()
        var announcements: [VisualResetAnnouncement] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            now: { clock.value },
            onAnnouncement: { announcements.append($0) },
        )
        model.open()

        for elapsed in 1 ... 9 {
            clock.value = Double(elapsed)
            model.refresh()
        }
        #expect(announcements == [.opened(durationSeconds: 20)])

        clock.value = 10
        model.refresh()
        clock.value = 11
        model.refresh()
        #expect(announcements == [.opened(durationSeconds: 20), .tenSecondsRemaining])

        clock.value = 20
        model.refresh()
        #expect(announcements == [
            .opened(durationSeconds: 20),
            .tenSecondsRemaining,
            .finished,
        ])
    }

    @Test("Accessibility presentation changes apply live without restarting the session")
    func accessibilityChangesAreLive() {
        let clock = TestClock()
        let model = VisualResetModel(durationSeconds: 20, now: { clock.value })
        model.open()
        clock.value = 6
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

        clock.value = 11
        model.refresh()
        #expect(model.progress == 0.5)
    }
}

private final class TestClock {
    var value: TimeInterval = 0
}
