import AppKit
import Testing
@testable import App

@Suite("Settings window presentation")
struct SettingsWindowPresentationTests {
    @Test("Settings content extends beneath transparent titlebar chrome")
    func settingsUsesIntegratedTitlebar() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false,
        )

        SettingsWindowAppearance.apply(to: window)

        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.titlebarAppearsTransparent)
        #expect(window.titleVisibility == .hidden)
        #expect(window.isMovableByWindowBackground)
    }

    @Test("Settings retains its reviewed minimum content size")
    func settingsRetainsUsableSize() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false,
        )

        SettingsWindowAppearance.apply(to: window)

        #expect(window.contentMinSize == NSSize(width: 1000, height: 700))
        #expect(window.contentView?.frame.size.width == 1000)
        #expect(window.contentView?.frame.size.height == 700)
    }
}
