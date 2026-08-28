import AppKit
import SwiftUI

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
            window.contentViewController = NSHostingController(
                rootView: SettingsView(appDelegate: self),
            )
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 780, height: 560)
            window.title = AppL10n.settingsTitle
            window.center()
            controller = NSWindowController(window: window)
            settingsWindowController = controller
        }

        controller.showWindow(sender)
        controller.window?.makeKeyAndOrderFront(sender)
        NSApp.activate()
        Task { await settingsSceneModel.refreshIntegrations() }
    }
}
