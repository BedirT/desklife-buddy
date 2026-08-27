import AppKit
import HeadsUp

struct HeadsUpAccessibilityPost {
    let element: AnyObject
    let notification: NSAccessibility.Notification
    let localizedText: String
    let priority: Int
}

enum HeadsUpAccessibilityAnnouncer {
    typealias Poster = (HeadsUpAccessibilityPost) -> Void

    static func post(_ announcement: HeadsUpAnnouncement) {
        post(announcement) { request in
            NSAccessibility.post(
                element: request.element,
                notification: request.notification,
                userInfo: [
                    .announcement: request.localizedText,
                    .priority: request.priority,
                ],
            )
        }
    }

    static func post(
        _ announcement: HeadsUpAnnouncement,
        _ poster: Poster,
    ) {
        poster(HeadsUpAccessibilityPost(
            element: NSApplication.shared,
            notification: .announcementRequested,
            localizedText: announcement.localizedText,
            priority: NSAccessibilityPriorityLevel.medium.rawValue,
        ))
    }
}
