import AppKit
import StatusMenu
import Testing
@testable import App

@Suite("Dock fallback")
struct DockMenuTests {
    @Test("Dock menu mirrors essential Start Pause Settings and Quit routes")
    func essentialRoutes() {
        var actions: [StatusMenuAction] = []
        let controller = DockMenuController(onAction: { actions.append($0) })
        let menu = controller.makeMenu(snapshot: StatusMenuModel.preview(.normal).snapshot)

        #expect(dockMenuTitles(menu) == [
            "Start a visual reset", "Start movement", "Pause", "Settings…", "Quit",
        ])
        controller.perform(menu.item(withTitle: "Start a visual reset")!)
        controller.perform(menu.item(withTitle: "Pause")!.submenu!.items[0])

        #expect(actions == [.startVisualReset, .pause(.thirtyMinutes)])
    }

    @Test("Indefinite pause becomes a direct Resume route")
    func resumeRoute() {
        var actions: [StatusMenuAction] = []
        let controller = DockMenuController(onAction: { actions.append($0) })
        let menu = controller.makeMenu(snapshot: StatusMenuModel.preview(.paused).snapshot)

        #expect(menu.item(withTitle: "Pause") == nil)
        controller.perform(menu.item(withTitle: "Resume")!)
        #expect(actions == [.resume])
    }
}

private func dockMenuTitles(_ menu: NSMenu) -> [String] {
    menu.items.filter { !$0.isSeparatorItem && $0.view == nil }.map(\.title)
}
