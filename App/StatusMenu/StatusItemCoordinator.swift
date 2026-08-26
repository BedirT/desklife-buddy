import AppKit
import DesignSystem
import StatusMenu
import SwiftUI

/// Owns the system status item and its native, keyboard-driven menu.
final class StatusItemCoordinator: NSObject {
    private let statusItem: NSStatusItem?
    private let onAction: (StatusMenuAction) -> Void
    private var model: StatusMenuModel
    private(set) var menu = NSMenu()

    init(
        model: StatusMenuModel,
        installsStatusItem: Bool = true,
        onAction: @escaping (StatusMenuAction) -> Void = { _ in },
    ) {
        self.model = model
        self.onAction = onAction
        statusItem = installsStatusItem ? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) : nil
        super.init()
        rebuildMenu()
        statusItem?.menu = menu
        configureStatusButton()
    }

    func update(model: StatusMenuModel) {
        self.model = model
        rebuildMenu()
        statusItem?.menu = menu
        configureStatusButton()
    }

    func perform(_ item: NSMenuItem) {
        activateMenuItem(item)
    }

    @objc private func activateMenuItem(_ item: NSMenuItem) {
        guard let action = (item.representedObject as? StatusMenuActionBox)?.action else { return }
        onAction(action)
    }
}

private extension StatusItemCoordinator {
    func rebuildMenu() {
        let rebuilt = NSMenu()
        rebuilt.autoenablesItems = false
        rebuilt.addItem(statusRegionItem())
        rebuilt.addItem(.separator())

        if model.snapshot.liveHeadsUp != nil {
            rebuilt.addItem(actionItem(StatusMenuCopy.startNow, action: .startHeadsUpNow))
            rebuilt.addItem(submenuItem(
                StatusMenuCopy.later,
                choices: [
                    (StatusMenuCopy.snoozeFiveMinutes, .snooze(300)),
                    (StatusMenuCopy.snoozeTenMinutes, .snooze(600)),
                    (StatusMenuCopy.snoozeFifteenMinutes, .snooze(900)),
                ],
            ))
            rebuilt.addItem(.separator())
        }

        rebuilt.addItem(actionItem(StatusMenuCopy.startVisualReset, action: .startVisualReset))
        rebuilt.addItem(submenuItem(
            StatusMenuCopy.startMovement,
            choices: [
                (StatusMenuCopy.movementRecommended, .startMovement(.recommended)),
                (StatusMenuCopy.movementQuick, .startMovement(.quick)),
                (StatusMenuCopy.movementPosition, .startMovement(.positionChange)),
            ],
        ))
        addPauseOrResume(to: rebuilt)
        rebuilt.addItem(.separator())

        let workingHours = actionItem(StatusMenuCopy.workingHoursOnly, action: .toggleWorkingHours)
        workingHours.state = model.snapshot.workingHoursOnly ? .on : .off
        rebuilt.addItem(workingHours)
        rebuilt.addItem(actionItem(StatusMenuCopy.weeklyRhythm, action: .openWeeklyRhythm))
        rebuilt.addItem(.separator())

        let settings = actionItem(StatusMenuCopy.settings, action: .openSettings)
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = [.command]
        rebuilt.addItem(settings)
        rebuilt.addItem(actionItem(StatusMenuCopy.quit, action: .quit))
        menu = rebuilt
    }

    func addPauseOrResume(to menu: NSMenu) {
        if model.snapshot.activeSuppression == .manualPause {
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
    }

    func statusRegionItem() -> NSMenuItem {
        let item = NSMenuItem()
        let content = StatusMenuStatusRegion(model: model)
            .frame(width: 312)
            .background(Color.dsSurface)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 312, height: hostingView.fittingSize.height)
        item.view = hostingView
        return item
    }

    func actionItem(_ title: String, action: StatusMenuAction) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(activateMenuItem(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = StatusMenuActionBox(action)
        item.isEnabled = true
        return item
    }

    func submenuItem(
        _ title: String,
        choices: [(String, StatusMenuAction)],
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        for (choiceTitle, action) in choices {
            submenu.addItem(actionItem(choiceTitle, action: action))
        }
        item.submenu = submenu
        return item
    }

    func configureStatusButton() {
        guard let button = statusItem?.button else { return }
        button.image = markImage
        button.imagePosition = .imageOnly
        button.setAccessibilityIdentifier("statusMenu.item")
        button.setAccessibilityLabel(StatusMenuCopy.accessibilityLabel)
    }

    var markImage: NSImage? {
        let renderer = ImageRenderer(
            content: DSProtocolMark(state: markState, size: 18)
                .foregroundStyle(.black)
                .frame(width: 18, height: 18),
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        return image
    }

    var markState: DSProtocolMark.State {
        switch model.snapshot.glyph {
        case .operating: .operating
        case .visualDue: .visualDue
        case .movementDue: .movementDue
        case .bothDue: .bothDue
        case .paused: .paused
        }
    }
}

final class StatusMenuActionBox: NSObject {
    let action: StatusMenuAction

    init(_ action: StatusMenuAction) {
        self.action = action
    }
}
