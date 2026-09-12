import AppKit
import Domain
import HeadsUp
import StatusMenu
import Testing
@testable import App

@Suite("Native status item")
struct StatusItemCoordinatorTests {
    @Test("Menu preserves canonical order and platform submenus")
    func canonicalOrder() {
        let coordinator = StatusItemCoordinator(
            model: .preview(.normal),
            installsStatusItem: false,
        )

        let menu = coordinator.menu
        #expect(menu.items.first?.view != nil)
        #expect(menuTitles(menu) == [
            "Start a visual reset",
            "Start movement",
            "Pause",
            "Weekly rhythm…",
            "Settings…",
            "Quit",
        ])
        #expect(menu.item(withTitle: "Start movement")?.submenu?.items.map(\.title) == [
            "5 minutes", "2 minutes", "Position change",
        ])
        #expect(menu.item(withTitle: "Pause")?.submenu?.items.map(\.title) == [
            "For 30 minutes", "For 1 hour", "For the rest of the day", "Until I resume", "Presenting",
        ])
        #expect(menu.item(withTitle: "Settings…")?.keyEquivalent == ",")
    }

    @Test("Settings status item keeps Command-comma and routes the typed Settings action")
    func settingsRoute() throws {
        var actions: [StatusMenuAction] = []
        let coordinator = StatusItemCoordinator(
            model: .preview(.normal),
            installsStatusItem: false,
            onAction: { actions.append($0) },
        )
        let settings = try #require(coordinator.menu.item(withTitle: "Settings…"))

        #expect(settings.keyEquivalent == ",")
        #expect(settings.keyEquivalentModifierMask == .command)
        coordinator.perform(settings)
        #expect(actions == [.openSettings])
    }

    @Test("Overlay actions wait for native menu tracking to close")
    func overlayActionsWaitForMenuClose() throws {
        var actions: [StatusMenuAction] = []
        var scheduledAction: (@MainActor @Sendable () -> Void)?
        let coordinator = StatusItemCoordinator(
            model: .preview(.normal),
            installsStatusItem: false,
            onAction: { actions.append($0) },
            scheduleAfterMenuClose: { scheduledAction = $0 },
        )
        let visualReset = try #require(
            coordinator.menu.item(withTitle: "Start a visual reset"),
        )

        coordinator.menuWillOpen(coordinator.menu)
        coordinator.perform(visualReset)
        #expect(actions.isEmpty)

        coordinator.menuDidClose(coordinator.menu)
        #expect(actions.isEmpty)
        #expect(scheduledAction != nil)

        scheduledAction?()
        #expect(actions == [.startVisualReset])
    }

    @Test("Live heads-up rows preserve projection order and route every paired intent", arguments: [
        HeadsUpScope.visual,
        .movement,
        .merged,
    ])
    func liveHeadsUpActions(scope: HeadsUpScope) throws {
        var intents: [HeadsUpIntent] = []
        var statusActions: [StatusMenuAction] = []
        let projection = HeadsUpModel.preview(scope: scope).statusMenuProjection
        let coordinator = StatusItemCoordinator(
            model: .preview(.headsUp),
            headsUpProjection: projection,
            installsStatusItem: false,
            onAction: { statusActions.append($0) },
            onHeadsUpIntent: { intents.append($0) },
        )

        let start = try #require(coordinator.menu.item(withTitle: projection.startTitle))
        let later = try #require(coordinator.menu.item(withTitle: projection.laterTitle))
        let laterMenu = try #require(later.submenu)

        #expect(menuTitles(coordinator.menu).prefix(2) == [projection.startTitle, projection.laterTitle])
        #expect(laterMenu.items.map(\.title) == projection.laterOptions.map(\.title))
        #expect(start.accessibilityIdentifier() == "statusMenu.headsUp.start")
        #expect(later.accessibilityIdentifier() == "statusMenu.headsUp.later")

        coordinator.perform(start)
        for item in laterMenu.items {
            coordinator.perform(item)
        }

        #expect(intents == projection.intents)
        #expect(statusActions.isEmpty)
    }

    @Test("Optional Later rows appear only when projected and retain stable identifiers")
    func optionalHeadsUpRows() throws {
        let meetingEnd = Date(timeIntervalSince1970: 1_800_000_000)
        let standard = HeadsUpModel.preview(scope: .visual).statusMenuProjection
        let expanded = HeadsUpModel.preview(
            scope: .visual,
            calendarBusyEnd: meetingEnd,
            manualHoldDurationSeconds: 3600,
        ).statusMenuProjection
        var expandedIntents: [HeadsUpIntent] = []

        let standardCoordinator = StatusItemCoordinator(
            model: .preview(.headsUp),
            headsUpProjection: standard,
            installsStatusItem: false,
        )
        let expandedCoordinator = StatusItemCoordinator(
            model: .preview(.headsUp),
            headsUpProjection: expanded,
            installsStatusItem: false,
            onHeadsUpIntent: { expandedIntents.append($0) },
        )
        let standardLater = try #require(standardCoordinator.menu.item(withTitle: standard.laterTitle)?.submenu)
        let expandedStart = try #require(expandedCoordinator.menu.item(withTitle: expanded.startTitle))
        let expandedLater = try #require(expandedCoordinator.menu.item(withTitle: expanded.laterTitle)?.submenu)

        #expect(standardLater.items.map(\.title) == [
            "5 minutes", "10 minutes", "15 minutes", "More options",
        ])
        #expect(expandedLater.items.map(\.title) == [
            "5 minutes", "10 minutes", "15 minutes", "After this meeting",
            "Presenting for 1 hour", "More options",
        ])
        #expect(expandedLater.items.map { $0.accessibilityIdentifier() } == [
            "statusMenu.headsUp.later.snooze.300",
            "statusMenu.headsUp.later.snooze.600",
            "statusMenu.headsUp.later.snooze.900",
            "statusMenu.headsUp.later.afterMeeting",
            "statusMenu.headsUp.later.manualHold.3600",
            "statusMenu.headsUp.later.moreOptions",
        ])

        expandedCoordinator.perform(expandedStart)
        for item in expandedLater.items {
            expandedCoordinator.perform(item)
        }
        #expect(expandedIntents == expanded.intents)
    }

    @Test("A nil projection exposes no live rows even when the status snapshot is due")
    func nilHeadsUpProjection() {
        let coordinator = StatusItemCoordinator(
            model: .preview(.headsUp),
            headsUpProjection: HeadsUpModel.preview(scope: .visual).statusMenuProjection,
            installsStatusItem: false,
        )

        #expect(coordinator.menu.item(withTitle: "Start now") != nil)
        coordinator.update(model: .preview(.headsUp), headsUpProjection: nil)
        #expect(coordinator.menu.item(withTitle: "Start now") == nil)
        #expect(coordinator.menu.item(withTitle: "Later") == nil)
        #expect(menuTitles(coordinator.menu) == [
            "Start a visual reset",
            "Start movement",
            "Pause",
            "Weekly rhythm…",
            "Settings…",
            "Quit",
        ])
        #expect(coordinator.menu.item(withTitle: "Settings…")?.keyEquivalent == ",")
    }

    @Test("Unsettled recovery exposes no dead Start or Later controls")
    func recoveryHasNoDeadActions() throws {
        let model = try StatusMenuModel(
            state: ProtocolState(),
            configuration: ProtocolProfiles.configuration(for: .balanced),
            context: StatusMenuContext(liveHeadsUp: .recovery),
        )
        let coordinator = StatusItemCoordinator(
            model: model,
            headsUpProjection: nil,
            installsStatusItem: false,
        )

        #expect(coordinator.menu.item(withTitle: "Start now") == nil)
        #expect(coordinator.menu.item(withTitle: "Later") == nil)
        #expect(menuTitles(coordinator.menu) == [
            "Start a visual reset",
            "Start movement",
            "Pause",
            "Weekly rhythm…",
            "Settings…",
            "Quit",
        ])
        #expect(coordinator.menu.item(withTitle: "Settings…")?.keyEquivalent == ",")
    }

    @Test("Status value exposes both clocks, the estimate, and the quiet reason")
    func accessibilityValue() {
        let normal = StatusMenuModel.preview(.normal).snapshot
        let paused = StatusMenuModel.preview(.paused).snapshot
        let timedPause = StatusMenuModel.preview(.timedPause).snapshot

        #expect(StatusMenuCopy.accessibilityValue(for: normal) == """
        Visual reset in about 9 minutes. Movement in about 34 minutes. Estimated active computer use, 63 minutes.
        """)
        #expect(StatusMenuCopy.accessibilityValue(for: timedPause).contains("Paused until"))
        #expect(StatusMenuCopy.accessibilityValue(for: paused) == """
        Paused. Visual reset in about 9 minutes. Movement in about 34 minutes. Estimated active computer use, 63 minutes. Paused until you resume.
        """)
    }

    @Test("Every shipped bucket names itself first in the status value")
    func bucketHeadlines() {
        #expect(StatusMenuCopy.accessibilityValue(for: StatusMenuModel.preview(.held).snapshot)
            .hasPrefix("On hold."))
        #expect(StatusMenuCopy.accessibilityValue(for: StatusMenuModel.preview(.protected).snapshot)
            .hasPrefix("Quiet."))
        #expect(StatusMenuCopy.accessibilityValue(for: StatusMenuModel.preview(.acceptedRitual).snapshot)
            .hasPrefix("In progress."))
        #expect(StatusMenuCopy.accessibilityValue(for: StatusMenuModel.preview(.acceptedRitual).snapshot)
            .contains("You started a visual reset."))
        #expect(StatusMenuCopy.accessibilityValue(for: StatusMenuModel.preview(.acceptedRitual).snapshot)
            .contains("Visual reset in progress."))
        #expect(StatusMenuCopy.accessibilityValue(for: StatusMenuModel.preview(.headsUpOff).snapshot)
            .hasPrefix("Heads-up off."))
        #expect(StatusMenuCopy.accessibilityValue(for: StatusMenuModel.preview(.headsUpOff).snapshot)
            .contains("Reminders stay in the menu."))
        #expect(StatusMenuCopy.accessibilityValue(for: StatusMenuModel.preview(.visualDue).snapshot)
            .contains("Visual reset due after about 47 minutes of estimated active use."))
    }

    @Test("Held, protected, ritual, off, and due states keep Pause and never offer Resume")
    func quietBucketsKeepPause() {
        for state in [
            StatusMenuModel.PreviewState.held, .protected, .acceptedRitual, .headsUpOff,
            .visualDue, .movementDue, .bothDue, .calendarBusy,
        ] as [StatusMenuModel.PreviewState] {
            let coordinator = StatusItemCoordinator(
                model: .preview(state),
                installsStatusItem: false,
            )
            #expect(coordinator.menu.item(withTitle: "Pause") != nil, "\(state) keeps Pause")
            #expect(coordinator.menu.item(withTitle: "Resume") == nil, "\(state) hides Resume")
        }
    }

    @Test("Manual pause swaps Pause for Resume")
    func manualPauseOffersResume() {
        for state in [StatusMenuModel.PreviewState.paused, .timedPause] {
            let coordinator = StatusItemCoordinator(
                model: .preview(state),
                installsStatusItem: false,
            )
            #expect(coordinator.menu.item(withTitle: "Resume") != nil, "\(state) offers Resume")
            #expect(coordinator.menu.item(withTitle: "Pause") == nil, "\(state) hides Pause")
        }
    }
}

private func menuTitles(_ menu: NSMenu) -> [String] {
    menu.items.filter { !$0.isSeparatorItem && $0.view == nil }.map(\.title)
}
