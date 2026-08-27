import AppKit
import HeadsUp
import Testing
@testable import App

@Suite("Heads-Up accessibility announcer")
struct HeadsUpAccessibilityAnnouncerTests {
    @Test("The localized payload is posted once as a medium-priority native announcement")
    func post() {
        let announcement = HeadsUpAnnouncement(
            kind: .appearance,
            localizedText: "Visual reset in 45 seconds. Now, button. Later, menu button.",
        )
        var postCount = 0
        var targetsApplication = false
        var notification: NSAccessibility.Notification?
        var localizedText: String?
        var priority: Int?

        HeadsUpAccessibilityAnnouncer.post(announcement) { request in
            postCount += 1
            targetsApplication = request.element === NSApplication.shared
            notification = request.notification
            localizedText = request.localizedText
            priority = request.priority
        }

        #expect(postCount == 1)
        #expect(targetsApplication)
        #expect(notification == .announcementRequested)
        #expect(localizedText == announcement.localizedText)
        #expect(priority == NSAccessibilityPriorityLevel.medium.rawValue)
    }
}
