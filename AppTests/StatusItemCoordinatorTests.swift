import AppKit
import Domain
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
            "Only during working hours",
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

    @Test("Live heads-up rows route the same explicit intents as the capsule")
    func liveHeadsUpActions() {
        var actions: [StatusMenuAction] = []
        let coordinator = StatusItemCoordinator(
            model: .preview(.headsUp),
            installsStatusItem: false,
            onAction: { actions.append($0) },
        )

        coordinator.perform(coordinator.menu.item(withTitle: "Start now")!)
        let later = coordinator.menu.item(withTitle: "Later")!.submenu!
        coordinator.perform(later.items[1])
        coordinator.perform(later.item(withTitle: "More options")!)

        #expect(actions == [.startHeadsUpNow, .snooze(600), .openSnoozeOptions])
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
            installsStatusItem: false,
        )

        #expect(coordinator.menu.item(withTitle: "Start now") == nil)
        #expect(coordinator.menu.item(withTitle: "Later") == nil)
    }

    @Test("Status value exposes both clocks, the estimate, and the quiet reason")
    func accessibilityValue() {
        let normal = StatusMenuModel.preview(.normal).snapshot
        let paused = StatusMenuModel.preview(.paused).snapshot
        let timedPause = StatusMenuModel.preview(.timedPause).snapshot

        #expect(StatusMenuCopy.accessibilityValue(for: normal) == """
        Visual reset in about 9 minutes. Movement in about 34 minutes. Estimated active computer use, 63 minutes.
        """)
        #expect(StatusMenuCopy.accessibilityValue(for: paused) == """
        Visual reset in about 9 minutes. Movement in about 34 minutes. Estimated active computer use, 63 minutes. Paused until you resume.
        """)
        #expect(StatusMenuCopy.accessibilityValue(for: timedPause).contains("Paused until"))
        #expect(!StatusMenuCopy.accessibilityValue(for: timedPause).contains("until you resume"))
    }

    @Test("Custom status region grows with the system menu font")
    func statusRegionScaling() {
        let coordinator = StatusItemCoordinator(
            model: .preview(.normal),
            installsStatusItem: false,
            menuPointSize: NSFont.systemFontSize * 1.35,
        )

        #expect(abs(coordinator.statusRegionWidth - 421.2) < 0.001)
    }
}

private func menuTitles(_ menu: NSMenu) -> [String] {
    menu.items.filter { !$0.isSeparatorItem && $0.view == nil }.map(\.title)
}
