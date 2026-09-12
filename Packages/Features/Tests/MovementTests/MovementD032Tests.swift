import Domain
import Foundation
import Testing
@testable import Movement

/// D-032 conformance: entrance, exit, accepted deadline, focus, every printed
/// shortcut (1/2/3/Q/A/P/Return) and every pointer control are active on the
/// first frame. There is no declaration guard (D-032, clarified by D-043;
/// INTERACTION_SPEC §§1–9, §4).
@Suite("Movement D-032 first-frame keyboard")
struct MovementD032Tests {
    @Test("Printed keyboard choices apply on the first frame")
    func keyboardChoicesAreImmediateFirstFrame() throws {
        let clock = TestClock()
        var announcements: [MovementAnnouncement] = []
        let model = try makeModel(
            clock: clock,
            onAnnouncement: { announcements.append($0) },
        )
        model.open()

        model.selectFromKeyboard(.smallSpace)

        #expect(model.selectedChoice == .smallSpace)
        #expect(announcements == [
            .opened(durationSeconds: 300),
            .selectionChanged(.smallSpace),
        ])
    }

    @Test("Q applies the quick duration on the first frame")
    func keyboardQuickDurationIsImmediateFirstFrame() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        let model = try makeModel(clock: clock, onAction: { actions.append($0) })
        model.open()

        model.selectQuickDurationFromKeyboard()

        #expect(model.selectedDurationSeconds == 120)
        #expect(model.deadline == 120)
        #expect(actions == [.opened, .selectedDuration(120)])
    }

    @Test("Terminal keyboard declarations finish on the first frame")
    func keyboardDeclarationsAreImmediateFirstFrame() throws {
        for terminal in [
            MovementTerminalAction.doneEarly,
            .alreadyMoved,
            .positionChanged,
        ] as [MovementTerminalAction] {
            let clock = TestClock()
            var actions: [MovementAction] = []
            let model = try makeModel(clock: clock, onAction: { actions.append($0) })
            model.open()

            switch terminal {
            case .doneEarly: model.doneEarlyFromKeyboard()
            case .alreadyMoved: model.alreadyMovedFromKeyboard()
            case .positionChanged: model.positionChangedFromKeyboard()
            case .timerFinished, .visualOnly, .skipped: break
            }

            #expect(model.phase == .finished(terminal))
            #expect(actions.last == terminal.action)
        }
    }

    @Test("A terminal receipt without a confirmed persistence fact changes nothing")
    func unconfirmedTerminalChangesNothing() throws {
        let clock = TestClock()
        var actions: [MovementAction] = []
        let schedule = try movementSchedule(durations: [300, 120])
        let model = MovementModel(
            durations: MovementDurations.projected(from: schedule),
            requiresLifecycleConfirmation: true,
            now: { clock.value },
            onAction: { actions.append($0) },
        )
        model.open()
        model.confirmLifecycle(.opened)

        // No receipt has been offered past the facade: confirming an
        // un-emitted terminal fact must fail closed.
        model.confirmLifecycle(.doneEarly)

        #expect(model.phase == .running)
    }
}
