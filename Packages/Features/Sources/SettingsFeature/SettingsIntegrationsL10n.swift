import Domain
import FeatureLocalization
import Foundation

enum SettingsIntegrationsL10n {
    static let availableNow = string("settings.integrations.available_now", default: "Available now")
    static let availableNowDetail = string(
        "settings.integrations.available_now_detail",
        default: "Optional system features stay separate. The app still works when they are unavailable or turned off.",
    )
    static let notifications = string("settings.integrations.notifications", default: "Notifications")
    static let notificationsDetail = string(
        "settings.integrations.notifications_detail",
        default: "Use macOS notifications for a quiet heads-up before a break. The in-app heads-up remains available when notifications are off.",
    )
    static let notificationNotDetermined = string(
        "settings.integrations.notifications.not_determined",
        default: "Not set up. Opening Settings never requests permission.",
    )
    static let notificationAuthorized = string(
        "settings.integrations.notifications.authorized",
        default: "Allowed in System Settings",
    )
    static let notificationDenied = string(
        "settings.integrations.notifications.denied",
        default: "Off in System Settings. The in-app heads-up remains available.",
    )
    static let notificationRevoked = string(
        "settings.integrations.notifications.revoked",
        default: "No longer allowed in System Settings. The in-app heads-up remains available.",
    )
    static let notificationUnavailable = string(
        "settings.integrations.notifications.unavailable",
        default: "Notifications are unavailable. The in-app heads-up remains available.",
    )
    static let setupNotifications = string(
        "settings.integrations.notifications.setup",
        default: "Set up notifications…",
    )
    static let openNotificationSettings = string(
        "settings.integrations.notifications.open_settings",
        default: "Open Notification Settings…",
    )
    static let launchAtLogin = string(
        "settings.integrations.launch_at_login",
        default: "Open at login",
    )
    static let launchAtLoginDetail = string(
        "settings.integrations.launch_at_login_detail",
        default: "Open the app after you sign in to this Mac.",
    )
    static let launchAtLoginUnavailable = string(
        "settings.integrations.launch_at_login_unavailable",
        default: "Open at login is unavailable in this build.",
    )
    static let launchAtLoginRequiresApproval = string(
        "settings.integrations.launch_at_login.requires_approval",
        default: "Approval required in System Settings. Open at login is currently off.",
    )
    static let openLoginItemsSettings = string(
        "settings.integrations.launch_at_login.open_login_items",
        default: "Open Login Items…",
    )
    static let unavailableThisBuild = string(
        "settings.integrations.unavailable_this_build",
        default: "Not available in this build",
    )
    static let unavailableThisBuildDetail = string(
        "settings.integrations.unavailable_this_build_detail",
        default: "These integrations are shown for transparency. They do not request access or run in the background.",
    )
    static let calendarBusyTimes = string(
        "settings.integrations.calendar",
        default: "Calendar busy times",
    )
    static let calendarBusyTimesDetail = string(
        "settings.integrations.calendar_detail",
        default: "No Calendar data is requested or read in this build.",
    )
    static let focusFilter = string("settings.integrations.focus", default: "Focus Filter")
    static let focusFilterDetail = string(
        "settings.integrations.focus_detail",
        default: "No Focus information is requested or read in this build.",
    )

    static func notificationStatus(_ authorization: IntegrationAuthorizationState) -> String {
        switch authorization {
        case .notRequired: notificationAuthorized
        case .notDetermined: notificationNotDetermined
        case .authorized: notificationAuthorized
        case .denied: notificationDenied
        case .revoked: notificationRevoked
        }
    }

    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }
}
