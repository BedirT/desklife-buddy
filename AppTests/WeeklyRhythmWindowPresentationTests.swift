import AppKit
import Testing
@testable import App

@Suite("Weekly rhythm window presentation")
struct WeeklyRhythmWindowPresentationTests {
    @Test("Weekly rhythm retains its reviewed minimum content size")
    func weeklyRhythmRetainsUsableSize() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false,
        )

        WeeklyRhythmWindowAppearance.apply(to: window)

        #expect(window.contentMinSize == NSSize(width: 1000, height: 700))
        #expect(window.contentView?.frame.size.width == 1000)
        #expect(window.contentView?.frame.size.height == 700)
    }
}
