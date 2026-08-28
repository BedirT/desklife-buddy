import Foundation
import Testing
@testable import HeadsUp

@Suite("Heads-up notification content")
struct HeadsUpNotificationContentTests {
    @Test("Each scope has the exact approved notification title and body", arguments: [
        (HeadsUpScope.visual, "Visual reset", "A short break from near focus."),
        (.movement, "Movement opportunity", "Move in a way that works for you."),
        (.merged, "Visual reset and movement", "Both are due. One break covers them."),
    ])
    func exactContent(scope: HeadsUpScope, title: String, body: String) {
        let content = HeadsUpNotificationContent(scope: scope)

        #expect(content.title == title)
        #expect(content.body == body)
    }

    @Test("Every notification has the same exact ordinary actions", arguments: HeadsUpScope.allCases)
    func exactActions(scope: HeadsUpScope) {
        let content = HeadsUpNotificationContent(scope: scope)

        #expect(content.actions == [
            .init(kind: .startNow, title: "Start now"),
            .init(kind: .snoozeFiveMinutes, title: "In 5 minutes"),
            .init(kind: .moreOptions, title: "More options"),
        ])
    }
}

@Suite("Heads-up hold content")
struct HeadsUpHoldContentTests {
    @Test("Every sanctioned hold preserves its source and exact approved detail")
    func exactHoldPresentation() {
        for value in holdPresentationCases {
            var announcements: [HeadsUpAnnouncement] = []
            let model = HeadsUpModel(
                scope: .visual,
                snoozeDurationsSeconds: [300, 600, 900],
                formatDeadline: { _ in "3:00 PM" },
                onAnnouncement: { announcements.append($0) },
            )

            model.updatePhase(.hold(value.hold))

            #expect(model.presentationPhase == .hold(value.hold))
            #expect(model.presentation.hold == value.hold)
            #expect(model.presentation.title == value.title)
            #expect(model.presentation.detail == value.detail)
            #expect(model.presentation.statusAccessibilityLabel == value.statusLabel)
            #expect(model.presentation.showsActions == false)
            #expect(announcements == [
                HeadsUpAnnouncement(kind: .holdChange, localizedText: value.statusLabel),
            ])
        }
    }

    @Test("Low-friction waiting remains landed and is never represented as a hold")
    func lowFrictionWait() {
        let model = HeadsUpModel(
            scope: .visual,
            phase: .landedWaiting,
            snoozeDurationsSeconds: [300, 600, 900],
        )

        #expect(model.presentationPhase == .landedWaiting)
        #expect(model.presentation.hold == nil)
        #expect(model.presentation.detail == "now, or whenever suits")
    }
}

@Suite("Heads-up status accessibility content")
struct HeadsUpStatusContentTests {
    @Test("Approach and landed states expose a neutral combined status label")
    func statusAccessibilityLabel() {
        for value in statusLabelCases {
            let model = HeadsUpModel(
                scope: value.scope,
                phase: value.phase,
                snoozeDurationsSeconds: [300, 600, 900],
            )

            #expect(model.presentation.statusAccessibilityLabel == value.expectedLabel)
        }
    }
}

private struct HoldPresentationCase {
    let hold: HeadsUpHold
    let title: String
    let detail: String
    let statusLabel: String
}

private struct StatusLabelCase {
    let scope: HeadsUpScope
    let phase: HeadsUpPhase
    let expectedLabel: String
}

private let holdDeadline = Date(timeIntervalSince1970: 1_800_000_000)
private let holdPresentationCases = [
    HoldPresentationCase(
        hold: .manualPause(until: holdDeadline),
        title: "Paused",
        detail: "until 3:00 PM",
        statusLabel: "Paused until 3:00 PM",
    ),
    HoldPresentationCase(
        hold: .manualPause(until: nil),
        title: "Paused",
        detail: "until you resume",
        statusLabel: "Paused until you resume",
    ),
    HoldPresentationCase(
        hold: .systemInactiveOrLocked,
        title: "Quiet",
        detail: "while the Mac is inactive",
        statusLabel: "Quiet while the Mac is inactive",
    ),
    HoldPresentationCase(
        hold: .explicitPresentationMode,
        title: "Presenting",
        detail: "reminders off",
        statusLabel: "Presenting, reminders off",
    ),
    HoldPresentationCase(
        hold: .focusFilter,
        title: "Quiet",
        detail: "in Focus",
        statusLabel: "Quiet in Focus",
    ),
    HoldPresentationCase(
        hold: .calendarBusy(until: holdDeadline),
        title: "On hold",
        detail: "busy until 3:00 PM",
        statusLabel: "On hold · busy until 3:00 PM",
    ),
    HoldPresentationCase(
        hold: .calendarBusy(until: nil),
        title: "Quiet",
        detail: "during Calendar busy time",
        statusLabel: "Quiet during Calendar busy time",
    ),
    HoldPresentationCase(
        hold: .excludedApplication,
        title: "Quiet",
        detail: "in this app",
        statusLabel: "Quiet in this app",
    ),
    HoldPresentationCase(
        hold: .outsideWorkingHours,
        title: "Outside working hours",
        detail: "",
        statusLabel: "Outside working hours",
    ),
    HoldPresentationCase(
        hold: .snooze,
        title: "Snoozed",
        detail: "",
        statusLabel: "Snoozed",
    ),
]

private let statusLabelCases = [
    StatusLabelCase(
        scope: .visual,
        phase: .approaching(.seconds45),
        expectedLabel: "Visual reset, in 45 s",
    ),
    StatusLabelCase(
        scope: .movement,
        phase: .landedWaiting,
        expectedLabel: "Movement opportunity, now, or whenever suits",
    ),
    StatusLabelCase(
        scope: .merged,
        phase: .approaching(.seconds15),
        expectedLabel: "Visual reset and movement, in 15 s",
    ),
]
