import AppKit
import StatusMenu

/// Essential controls duplicated in the Dock when the menu bar is hidden.
final class DockMenuController: NSObject {
    private let onAction: (StatusMenuAction) -> Void

    init(onAction: @escaping (StatusMenuAction) -> Void = { _ in }) {
        self.onAction = onAction
    }

    func makeMenu(snapshot: StatusMenuSnapshot) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(actionItem(StatusMenuCopy.startVisualReset, action: .startVisualReset))
        menu.addItem(submenuItem(
            StatusMenuCopy.startMovement,
            choices: [
                (StatusMenuCopy.movementRecommended, .startMovement(.recommended)),
                (StatusMenuCopy.movementQuick, .startMovement(.quick)),
                (StatusMenuCopy.movementPosition, .startMovement(.positionChange)),
            ],
        ))

        if snapshot.activeSuppression == .manualPause {
            menu.addItem(actionItem(StatusMenuCopy.resume, action: .resume))
        } else {
            menu.addItem(submenuItem(
                StatusMenuCopy.pause,
                choices: [
                    (StatusMenuCopy.pauseThirtyMinutes, .pause(.thirtyMinutes)),
                    (StatusMenuCopy.pauseOneHour, .pause(.oneHour)),
                    (StatusMenuCopy.pauseRestOfDay, .pause(.restOfDay)),
                    (StatusMenuCopy.pauseUntilResume, .pause(.untilResume)),
                    (StatusMenuCopy.presenting, .pause(.presenting)),
                ],
            ))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(StatusMenuCopy.settings, action: .openSettings))
        menu.addItem(actionItem(StatusMenuCopy.quit, action: .quit))
        return menu
    }

    func perform(_ item: NSMenuItem) {
        activateMenuItem(item)
    }

    @objc private func activateMenuItem(_ item: NSMenuItem) {
        guard let action = (item.representedObject as? StatusMenuActionBox)?.action else { return }
        onAction(action)
    }
}

private extension DockMenuController {
    func actionItem(_ title: String, action: StatusMenuAction) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(activateMenuItem(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = StatusMenuActionBox(action)
        item.isEnabled = true
        return item
    }

    func submenuItem(_ title: String, choices: [(String, StatusMenuAction)]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        for (choiceTitle, action) in choices {
            submenu.addItem(actionItem(choiceTitle, action: action))
        }
        item.submenu = submenu
        return item
    }
}
