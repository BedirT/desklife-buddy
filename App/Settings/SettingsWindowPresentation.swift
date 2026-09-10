import AppKit
import SwiftUI

enum SettingsWindowAppearance {
    static let minimumContentSize = NSSize(width: 1000, height: 700)

    static func apply(to window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentMinSize = minimumContentSize
        window.setContentSize(usableContentSize(for: window))
    }

    private static func usableContentSize(for window: NSWindow) -> NSSize {
        let currentSize = window.contentRect(forFrameRect: window.frame).size
        return NSSize(
            width: max(currentSize.width, minimumContentSize.width),
            height: max(currentSize.height, minimumContentSize.height),
        )
    }
}

extension AppDelegate {
    @objc func showSettingsWindow(_ sender: Any?) {
        let controller: NSWindowController
        if let settingsWindowController {
            controller = settingsWindowController
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false,
            )
            SettingsWindowAppearance.apply(to: window)
            window.contentViewController = NSHostingController(
                rootView: SettingsView(appDelegate: self),
            )
            window.isReleasedWhenClosed = false
            window.title = AppL10n.settingsTitle
            window.center()
            controller = NSWindowController(window: window)
            settingsWindowController = controller
        }

        guard let window = controller.window else { return }
        SettingsWindowAppearance.apply(to: window)
        appWindowActivationController.present(window: window, sender: sender) {
            controller.showWindow(sender)
        }
        Task { await settingsSceneModel.refreshIntegrations() }
    }
}
