import Foundation
import Testing
@testable import BreakFlow

@Suite("Break flow presentation model")
struct BreakFlowModelTests {
    @Test("Recovery controls stay above the revealed Dock")
    func recoveryControlsClearRevealedDock() {
        let verticalPosition = RecoveryStandardLayoutMetrics.y(
            RecoveryStandardLayoutMetrics.controlsYFraction,
            in: 982,
        )
        #expect(verticalPosition <= 760)
    }

    @Test("Visual-only acknowledgement exposes a passive lifetime and finishes once")
    func acknowledgementLifetime() {
        var actions: [BreakFlowAction] = []
        let model = BreakFlowModel(
            surface: .visualOnlyAcknowledgement,
            snoozeDurationsSeconds: [300, 600, 900],
            recoveryDurationsSeconds: [300, 600],
            acknowledgementDurationSeconds: 2,
            onAction: { actions.append($0) },
        )

        model.acknowledgementDidFinish()
        model.acknowledgementDidFinish()

        #expect(model.acknowledgementDurationSeconds == 2)
        #expect(actions == [.acknowledgementFinished])
        #expect(model.isFinished)
    }

    @Test("Snooze choices come from configuration and preserve their typed scope")
    func configuredSnoozeChoices() {
        var actions: [BreakFlowAction] = []
        let model = BreakFlowModel(
            surface: .snooze(scope: .merged, calendarEnd: nil),
            snoozeDurationsSeconds: [240, 480, 720],
            recoveryDurationsSeconds: [300, 600],
            onAction: { actions.append($0) },
        )

        model.snooze(for: 480)

        #expect(model.snoozeDurationsSeconds == [240, 480, 720])
        #expect(actions == [.snooze(scope: .merged, durationSeconds: 480)])
        #expect(!model.isFinished)

        model.confirmPersistence(.snooze(scope: .merged, durationSeconds: 480))

        #expect(actions == [.snooze(scope: .merged, durationSeconds: 480)])
        #expect(model.isFinished)
    }

    @Test("Unavailable and in-flight snooze choices are inert until rejection permits retry")
    func invalidPendingAndRejectedSnooze() {
        var actions: [BreakFlowAction] = []
        let model = BreakFlowModel.preview(.snooze(scope: .movement, calendarEnd: nil)) {
            actions.append($0)
        }

        model.snooze(for: 42)
        model.snooze(for: 300)
        model.snooze(for: 600)

        #expect(actions == [.snooze(scope: .movement, durationSeconds: 300)])
        #expect(!model.isFinished)

        model.rejectPersistence(.snooze(scope: .movement, durationSeconds: 300))
        model.snooze(for: 600)

        #expect(actions == [
            .snooze(scope: .movement, durationSeconds: 300),
            .snooze(scope: .movement, durationSeconds: 600),
        ])
        #expect(!model.isFinished)

        model.confirmPersistence(.snooze(scope: .movement, durationSeconds: 600))

        #expect(model.isFinished)
    }

    @Test("Calendar action exists only for an honestly bounded meeting end")
    func calendarAvailability() {
        let meetingEnd = Date(timeIntervalSinceReferenceDate: 1000)
        var actions: [BreakFlowAction] = []
        let available = BreakFlowModel.preview(
            .snooze(scope: .visual, calendarEnd: meetingEnd),
            onAction: { actions.append($0) },
        )
        let unavailable = BreakFlowModel.preview(.snooze(scope: .visual, calendarEnd: nil))

        available.snoozeUntilMeetingEnds()
        unavailable.snoozeUntilMeetingEnds()

        #expect(actions == [.snoozeUntil(scope: .visual, deadline: meetingEnd)])
        #expect(!available.isFinished)
        #expect(unavailable.isFinished == false)

        available.confirmPersistence(.snoozeUntil(scope: .visual, deadline: meetingEnd))

        #expect(available.isFinished)
    }

    @Test("Pause not-appropriate and skip wait for persistence and retry after rejection", arguments: [
        (BreakFlowCommand.pauseOneHour, BreakFlowAction.pauseOneHour),
        (.notAppropriate, .notAppropriate(scope: .movement)),
        (.skip, .skip(scope: .movement)),
    ])
    func exactSheetActions(command: BreakFlowCommand, expected: BreakFlowAction) {
        var actions: [BreakFlowAction] = []
        let model = BreakFlowModel.preview(.snooze(scope: .movement, calendarEnd: nil)) {
            actions.append($0)
        }

        model.send(command)
        model.send(command)

        #expect(actions == [expected])
        #expect(!model.isFinished)

        model.rejectPersistence(expected)
        model.send(command)
        model.send(command)

        #expect(actions == [expected, expected])
        #expect(!model.isFinished)

        model.confirmPersistence(expected)

        #expect(model.isFinished)
    }

    @Test("Unmatched persistence results cannot finish or release the pending action")
    func unmatchedPersistenceResultIsInert() {
        var actions: [BreakFlowAction] = []
        let model = BreakFlowModel.preview(.snooze(scope: .merged, calendarEnd: nil)) {
            actions.append($0)
        }
        let pending = BreakFlowAction.notAppropriate(scope: .merged)

        model.send(.notAppropriate)
        model.confirmPersistence(.skip(scope: .merged))
        model.rejectPersistence(.pauseOneHour)
        model.send(.skip)

        #expect(actions == [pending])
        #expect(!model.isFinished)

        model.confirmPersistence(pending)

        #expect(model.isFinished)
    }

    @Test("Recovery choices derive from policy and dismissal is once-only")
    func recoveryActions() {
        var startActions: [BreakFlowAction] = []
        let start = BreakFlowModel(
            surface: .recoveryOffer,
            snoozeDurationsSeconds: [300, 600, 900],
            recoveryDurationsSeconds: [240, 540],
            onAction: { startActions.append($0) },
        )
        start.chooseRecovery(durationSeconds: 540)

        var dismissActions: [BreakFlowAction] = []
        let dismiss = BreakFlowModel.preview(.recoveryOffer) { dismissActions.append($0) }
        dismiss.dismissRecovery()
        dismiss.dismissRecovery()

        #expect(start.recoveryDurationsSeconds == [240, 540])
        #expect(startActions == [.chooseRecovery(durationSeconds: 540)])
        #expect(start.isFinished)
        #expect(dismissActions == [.dismissRecovery])
        #expect(dismiss.isFinished)
    }

    @Test("Deferral count never changes the visible snooze model")
    func noEscalationState() {
        let first = BreakFlowModel.preview(
            .snooze(scope: .merged, calendarEnd: nil),
            deferralCount: 1,
        )
        let repeated = BreakFlowModel.preview(
            .snooze(scope: .merged, calendarEnd: nil),
            deferralCount: 8,
        )

        #expect(first.presentation == repeated.presentation)
        #expect(!first.showsEscalation)
        #expect(!repeated.showsEscalation)
    }

    @Test("Actions from the wrong surface are inert")
    func wrongSurfaceActions() {
        var actions: [BreakFlowAction] = []
        let acknowledgement = BreakFlowModel.preview(.visualOnlyAcknowledgement) {
            actions.append($0)
        }
        let recovery = BreakFlowModel.preview(.recoveryOffer) { actions.append($0) }
        let snooze = BreakFlowModel.preview(.snooze(scope: .visual, calendarEnd: nil)) {
            actions.append($0)
        }

        acknowledgement.snooze(for: 300)
        acknowledgement.chooseRecovery(durationSeconds: 300)
        recovery.acknowledgementDidFinish()
        recovery.snooze(for: 300)
        snooze.dismissRecovery()
        snooze.chooseRecovery(durationSeconds: 300)

        #expect(actions.isEmpty)
    }
}
