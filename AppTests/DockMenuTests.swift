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

    @Test("Dock menu opens with the truthful state line for every shipped bucket")
    func stateLines() {
        let rows: [(StatusMenuModel.PreviewState, String)] = [
            (.paused, "Paused until you resume"),
            (.held, "On hold: In a meeting you marked"),
            (.protected, "Quiet during Calendar busy time"),
            (.acceptedRitual, "You started a visual reset."),
            (.headsUpOff, "Heads-up off (menu only)"),
            (.visualDue, "Visual reset due"),
            (.movementDue, "Movement due"),
            (.bothDue, "Visual reset and movement due"),
        ]
        for (state, expected) in rows {
            let controller = DockMenuController(onAction: { _ in })
            let menu = controller.makeMenu(snapshot: StatusMenuModel.preview(state).snapshot)
            #expect(menu.items.first?.title == expected, "\(state) dock line")
            #expect(menu.items.first?.isEnabled == false)
        }
    }

    @Test("Plain operating keeps today's menu with no state line")
    func operatingHasNoStateLine() {
        var actions: [StatusMenuAction] = []
        let controller = DockMenuController(onAction: { actions.append($0) })
        let menu = controller.makeMenu(snapshot: StatusMenuModel.preview(.normal).snapshot)

        #expect(dockMenuTitles(menu) == [
            "Start a visual reset", "Start movement", "Pause", "Settings…", "Quit",
        ])
        controller.perform(menu.item(withTitle: "Start a visual reset")!)
        #expect(actions == [.startVisualReset])
    }
}

private func dockMenuTitles(_ menu: NSMenu) -> [String] {
    menu.items.filter { !$0.isSeparatorItem && $0.view == nil }.map(\.title)
}
