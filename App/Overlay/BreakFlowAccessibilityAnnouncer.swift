import AppKit
import BreakFlow

enum BreakFlowAccessibilityAnnouncer {
    static func post(_ announcement: BreakFlowAnnouncement) {
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement.localizedText,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ],
        )
    }
}
