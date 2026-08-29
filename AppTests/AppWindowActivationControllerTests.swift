import AppKit
import Testing
@testable import App

@Suite("App window activation", .serialized)
struct AppWindowActivationControllerTests {
    @Test("The app is accessory-only until an owned window is presented")
    func menuBarOnlyUntilWindowPresentation() {
        var policies: [NSApplication.ActivationPolicy] = []
        var activationCount = 0
        var frontCount = 0
        var events: [String] = []
        let notificationCenter = NotificationCenter()
        let controller = AppWindowActivationController(
            notificationCenter: notificationCenter,
            setActivationPolicy: {
                policies.append($0)
                events.append($0 == .accessory ? "policy.accessory" : "policy.regular")
                return true
            },
            activate: {
                activationCount += 1
                events.append("activate")
            },
            frontWindow: { _, _ in
                frontCount += 1
                events.append("front")
            },
        )
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false,
        )

        controller.enterMenuBarOnlyMode()
        controller.present(window: window, sender: nil) {
            events.append("show")
        }

        #expect(policies == [.accessory, .regular])
        #expect(activationCount == 1)
        #expect(frontCount == 1)
        #expect(events == ["policy.accessory", "policy.regular", "show", "activate", "front"])
        notificationCenter.post(name: NSWindow.willCloseNotification, object: window)
    }

    @Test("Closing the final owned window restores accessory mode")
    func finalWindowCloseRestoresAccessoryMode() {
        var policies: [NSApplication.ActivationPolicy] = []
        let notificationCenter = NotificationCenter()
        let controller = AppWindowActivationController(
            notificationCenter: notificationCenter,
            setActivationPolicy: {
                policies.append($0)
                return true
            },
            activate: {},
            frontWindow: { _, _ in },
        )
        let first = makeWindow()
        let second = makeWindow()
        controller.enterMenuBarOnlyMode()
        controller.present(window: first, sender: nil, show: {})
        controller.present(window: second, sender: nil, show: {})

        notificationCenter.post(name: NSWindow.willCloseNotification, object: first)
        #expect(policies.last == .regular)

        notificationCenter.post(name: NSWindow.willCloseNotification, object: second)
        #expect(policies.last == .accessory)
    }

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false,
        )
    }
}
