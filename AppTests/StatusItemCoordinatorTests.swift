import AppKit
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
        let later = coordinator.menu.item(withTitle: "Later")!.submenu!.items[1]
        coordinator.perform(later)

        #expect(actions == [.startHeadsUpNow, .snooze(600)])
    }
}

private func menuTitles(_ menu: NSMenu) -> [String] {
    menu.items.filter { !$0.isSeparatorItem && $0.view == nil }.map(\.title)
}
