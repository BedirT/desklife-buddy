import AppKit
import Movement

enum MovementAccessibilityAnnouncer {
    static func post(_ announcement: MovementAnnouncement) {
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
