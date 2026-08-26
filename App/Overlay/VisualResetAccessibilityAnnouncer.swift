import AppKit
import VisualReset

enum VisualResetAccessibilityAnnouncer {
    static func post(_ announcement: VisualResetAnnouncement) {
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
