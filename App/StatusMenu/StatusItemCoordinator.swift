import AppKit
import DesignSystem
import HeadsUp
import StatusMenu
import SwiftUI

/// Owns the system status item and its native, keyboard-driven menu.
final class StatusItemCoordinator: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem?
    private let onAction: (StatusMenuAction) -> Void
    private let onHeadsUpIntent: (HeadsUpIntent) -> Void
    private var model: StatusMenuModel
    private var headsUpProjection: HeadsUpStatusMenuProjection?
    private var isMenuOpen = false
    private let menuPointSize: CGFloat
    private var lastAccessibilityValue: String?
    private(set) var menu = NSMenu()

    init(
        model: StatusMenuModel,
        headsUpProjection: HeadsUpStatusMenuProjection? = nil,
        installsStatusItem: Bool = true,
        menuPointSize: CGFloat = NSFont.menuFont(ofSize: 0).pointSize,
        onAction: @escaping (StatusMenuAction) -> Void = { _ in },
        onHeadsUpIntent: @escaping (HeadsUpIntent) -> Void = { _ in },
    ) {
        self.model = model
        self.headsUpProjection = headsUpProjection
        self.onAction = onAction
        self.onHeadsUpIntent = onHeadsUpIntent
        self.menuPointSize = menuPointSize
        statusItem = installsStatusItem ? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) : nil
        super.init()
        rebuildMenu()
        statusItem?.menu = menu
        configureStatusButton()
    }

    func update(
        model: StatusMenuModel,
        headsUpProjection: HeadsUpStatusMenuProjection? = nil,
    ) {
        self.model = model
        self.headsUpProjection = headsUpProjection
        configureStatusButton()
        if !isMenuOpen {
            rebuildMenu()
            statusItem?.menu = menu
        }
    }

    func perform(_ item: NSMenuItem) {
        activateMenuItem(item)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        rebuildMenu()
        statusItem?.menu = self.menu
    }

    func openMenuForVerification() {
        statusItem?.button?.performClick(nil)
    }

    #if DEBUG
        @discardableResult
        func captureMenuForVerification() -> Bool {
            guard let menuView = menu.items.first?.view?.window?.contentView,
                  let menuData = verificationPNGData(for: menuView)
            else {
                return false
            }
            if let button = statusItem?.button,
               let buttonData = verificationPNGData(
                   for: button,
                   backgroundColor: .windowBackgroundColor,
               )
            {
                _ = writeVerificationPNG(buttonData, prefix: "status-item")
            }
            return writeVerificationPNG(menuData, prefix: "status-menu")
        }

        private func verificationPNGData(
            for view: NSView,
            backgroundColor: NSColor? = nil,
        ) -> Data? {
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds),
                  let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
            else { return nil }
            view.layoutSubtreeIfNeeded()
            view.displayIgnoringOpacity(view.bounds, in: graphicsContext)
            if let backgroundColor {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = graphicsContext
                graphicsContext.cgContext.setBlendMode(.destinationOver)
                backgroundColor.setFill()
                view.bounds.fill()
                NSGraphicsContext.restoreGraphicsState()
            }
            return bitmap.representation(using: .png, properties: [:])
        }

        private func writeVerificationPNG(_ data: Data, prefix: String) -> Bool {
            guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            else { return false }
            let filename = "\(prefix)-\(ProcessInfo.processInfo.processIdentifier).png"
            let destination = caches.appendingPathComponent(filename)
            do {
                let existingSize = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard data.count > existingSize else { return true }
                try data.write(to: destination, options: .atomic)
                return true
            } catch {
                do {
                    try data.write(to: destination, options: .atomic)
                    return true
                } catch {
                    return false
                }
            }
        }
    #endif

    @objc private func activateMenuItem(_ item: NSMenuItem) {
        if let intent = (item.representedObject as? HeadsUpIntentBox)?.intent {
            onHeadsUpIntent(intent)
        } else if let action = (item.representedObject as? StatusMenuActionBox)?.action {
            onAction(action)
        }
    }

    var statusRegionWidth: CGFloat {
        312 * max(1, menuPointSize / NSFont.systemFontSize)
    }
}

private extension StatusItemCoordinator {
    func rebuildMenu() {
        let rebuilt = NSMenu()
        rebuilt.autoenablesItems = false
        rebuilt.delegate = self
        rebuilt.addItem(statusRegionItem())
        rebuilt.addItem(.separator())

        if let headsUpProjection, addHeadsUpRows(headsUpProjection, to: rebuilt) {
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
        let content = StatusMenuStatusRegion(
            model: model,
            menuTextPointSize: menuPointSize,
        )
        .frame(width: statusRegionWidth)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: statusRegionWidth,
            height: hostingView.fittingSize.height,
        )
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

    @discardableResult
    func addHeadsUpRows(
        _ projection: HeadsUpStatusMenuProjection,
        to menu: NSMenu,
    ) -> Bool {
        guard let startIntent = projection.intents.first,
              projection.intents.count == projection.laterOptions.count + 1
        else {
            return false
        }

        menu.addItem(headsUpItem(
            projection.startTitle,
            intent: startIntent,
            accessibilityIdentifier: "statusMenu.headsUp.start",
        ))

        let later = NSMenuItem(title: projection.laterTitle, action: nil, keyEquivalent: "")
        later.setAccessibilityIdentifier("statusMenu.headsUp.later")
        let submenu = NSMenu(title: projection.laterTitle)
        submenu.autoenablesItems = false
        for (option, intent) in zip(projection.laterOptions, projection.intents.dropFirst()) {
            submenu.addItem(headsUpItem(
                title(for: option, projection: projection),
                intent: intent,
                accessibilityIdentifier: accessibilityIdentifier(for: option),
            ))
        }
        later.submenu = submenu
        menu.addItem(later)
        return true
    }

    func headsUpItem(
        _ title: String,
        intent: HeadsUpIntent,
        accessibilityIdentifier: String,
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(activateMenuItem(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = HeadsUpIntentBox(intent)
        item.isEnabled = true
        item.setAccessibilityIdentifier(accessibilityIdentifier)
        return item
    }

    func title(
        for option: HeadsUpLaterOption,
        projection: HeadsUpStatusMenuProjection,
    ) -> String {
        option == .moreOptions ? projection.moreOptionsTitle : option.title
    }

    func accessibilityIdentifier(for option: HeadsUpLaterOption) -> String {
        switch option {
        case let .snooze(durationSeconds):
            "statusMenu.headsUp.later.snooze.\(Int(durationSeconds))"
        case .afterMeeting:
            "statusMenu.headsUp.later.afterMeeting"
        case let .manualHold(durationSeconds):
            "statusMenu.headsUp.later.manualHold.\(Int(durationSeconds))"
        case .moreOptions:
            "statusMenu.headsUp.later.moreOptions"
        }
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
        let accessibilityValue = StatusMenuCopy.accessibilityValue(for: model.snapshot)
        button.setAccessibilityValue(accessibilityValue)
        if let lastAccessibilityValue, lastAccessibilityValue != accessibilityValue {
            NSAccessibility.post(element: button, notification: .valueChanged)
        }
        lastAccessibilityValue = accessibilityValue
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

final class HeadsUpIntentBox: NSObject {
    let intent: HeadsUpIntent

    init(_ intent: HeadsUpIntent) {
        self.intent = intent
    }
}
