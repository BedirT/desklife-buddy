import Foundation
import Testing
@testable import VisualReset

/// D-032 conformance: the final field, accepted deadline, and every printed
/// control are active on the first frame. There is no declaration guard or
/// entrance-settlement countdown gate (D-032, clarified by D-043;
/// INTERACTION_SPEC §§1–9).
@Suite("Visual reset D-032 immediate presentation")
struct VisualResetD032Tests {
    @Test("The countdown starts in the same committed open action")
    func countdownStartsInCommittedOpen() {
        let clock = D032VisualTestClock()
        // The shipped coordinator path defers the countdown until the frost
        // entrance settles. The canonical contract starts the 20 s timer in
        // the same committed open action that records breakStarted.
        let model = VisualResetModel(
            durationSeconds: 20,
            now: { clock.value },
        )
        model.open()

        clock.value = 1.1
        model.refresh()

        #expect(model.remainingSeconds == 19)
    }

    @Test("Done early from the keyboard is immediate on the first frame")
    func keyboardDoneEarlyIsImmediateFirstFrame() {
        let clock = D032VisualTestClock()
        var actions: [VisualResetAction] = []
        let model = VisualResetModel(
            durationSeconds: 20,
            now: { clock.value },
            onAction: { actions.append($0) },
        )
        model.open()

        model.doneEarlyFromKeyboard()

        #expect(model.phase == .finished(.doneEarly))
        #expect(actions == [.opened, .doneEarly])
    }

    @Test("A terminal receipt without a confirmed persistence fact changes nothing")
    func unconfirmedTerminalChangesNothing() {
        let clock = D032VisualTestClock()
        var actions: [VisualResetAction] = []
        let model = VisualResetModel(
            durationSeconds: 20,
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
        #expect(actions == [.opened])
    }
}

private final class D032VisualTestClock {
    var value: TimeInterval = 0
}
