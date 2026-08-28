import FeatureLocalization
import Foundation

public enum HeadsUpNotificationActionKind: Equatable, Sendable {
    case startNow, snoozeFiveMinutes, moreOptions
}

public struct HeadsUpNotificationAction: Equatable, Sendable {
    public let kind: HeadsUpNotificationActionKind
    public let title: String

    public init(kind: HeadsUpNotificationActionKind, title: String) {
        self.kind = kind
        self.title = title
    }
}

public struct HeadsUpNotificationContent: Equatable, Sendable {
    public let scope: HeadsUpScope
    public let title, body: String
    public let actions: [HeadsUpNotificationAction]

    public init(scope: HeadsUpScope) {
        self.scope = scope
        (title, body) = switch scope {
        case .visual:
            (HeadsUpL10n.visualTitle, HeadsUpL10n.visualNotificationBody)
        case .movement:
            (HeadsUpL10n.movementTitle, HeadsUpL10n.movementNotificationBody)
        case .merged:
            (HeadsUpL10n.mergedTitle, HeadsUpL10n.mergedNotificationBody)
        }
        actions = [
            HeadsUpNotificationAction(kind: .startNow, title: HeadsUpL10n.startNow),
            HeadsUpNotificationAction(
                kind: .snoozeFiveMinutes,
                title: HeadsUpL10n.inFiveMinutes,
            ),
            HeadsUpNotificationAction(kind: .moreOptions, title: HeadsUpL10n.moreOptions),
        ]
    }
}

public enum HeadsUpPermissionSettingsState: Equatable, Sendable {
    case denied, revoked
}

public struct HeadsUpPermissionPresentation: Equatable, Sendable {
    public let title, message, primaryActionTitle: String
    public let secondaryActionTitle: String?
    public let primaryActionAccessibilityHint: String?
    public let secondaryActionAccessibilityHint: String?

    public init(
        title: String,
        message: String,
        primaryActionTitle: String,
        secondaryActionTitle: String?,
        primaryActionAccessibilityHint: String?,
        secondaryActionAccessibilityHint: String?,
    ) {
        self.title = title
        self.message = message
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.primaryActionAccessibilityHint = primaryActionAccessibilityHint
        self.secondaryActionAccessibilityHint = secondaryActionAccessibilityHint
    }

    public static let inContextExplainer = HeadsUpPermissionPresentation(
        title: HeadsUpL10n.permissionExplainerTitle,
        message: HeadsUpL10n.permissionExplainerMessage,
        primaryActionTitle: HeadsUpL10n.permissionContinue,
        secondaryActionTitle: HeadsUpL10n.permissionUseInApp,
        primaryActionAccessibilityHint: HeadsUpL10n.permissionContinueHint,
        secondaryActionAccessibilityHint: nil,
    )

    public static func settings(
        for _: HeadsUpPermissionSettingsState,
    ) -> HeadsUpPermissionPresentation {
        HeadsUpPermissionPresentation(
            title: HeadsUpL10n.notificationsOff,
            message: HeadsUpL10n.notificationsFallback,
            primaryActionTitle: HeadsUpL10n.openNotificationSettings,
            secondaryActionTitle: nil,
            primaryActionAccessibilityHint: nil,
            secondaryActionAccessibilityHint: nil,
        )
    }
}

struct HeadsUpPresentationCopy {
    let title, detail, statusAccessibilityLabel: String
}

enum HeadsUpL10n {
    static let visualTitle = string("headsUp.visual.title", default: "Visual reset")
    static let movementTitle = string("headsUp.movement.title", default: "Movement opportunity")
    static let mergedTitle = string("headsUp.merged.title", default: "Visual reset and movement")

    static let visualNotificationBody = string(
        "headsUp.notification.visual_body",
        default: "A short break from near focus.",
    )
    static let movementNotificationBody = string(
        "headsUp.notification.movement_body",
        default: "Move in a way that works for you.",
    )
    static let mergedNotificationBody = string(
        "headsUp.notification.merged_body",
        default: "Both are due. One break covers them.",
    )

    static let startNow = string("headsUp.action.start_now", default: "Start now")
    static let inFiveMinutes = string("headsUp.action.in_five_minutes", default: "In 5 minutes")
    static let moreOptions = string("headsUp.action.more_options", default: "More options")
    static let now = string("headsUp.action.now", default: "Now")
    static let later = string("headsUp.action.later", default: "Later")
    static let afterMeeting = string("headsUp.action.after_meeting", default: "After this meeting")
    static let presentingOneHour = string("headsUp.action.presenting_one_hour", default: "Presenting for 1 hour")

    static let landed = string("headsUp.phase.landed", default: "now, or whenever suits")
    static let holdBusyFormat = string(
        "headsUp.phase.hold_busy_format",
        default: "On hold · busy until %@",
    )
    static let manualPauseUntilFormat = string(
        "headsUp.phase.manual_pause_until_format",
        default: "Paused until %@",
    )
    static let manualPauseIndefinite = string(
        "headsUp.phase.manual_pause_indefinite",
        default: "Paused until you resume",
    )
    static let systemInactive = string(
        "headsUp.phase.system_inactive",
        default: "Quiet while the Mac is inactive",
    )
    static let presentationMode = string(
        "headsUp.phase.presentation_mode",
        default: "Presenting, reminders off",
    )
    static let focusFilter = string(
        "headsUp.phase.focus_filter",
        default: "Quiet in Focus",
    )
    static let calendarBusy = string(
        "headsUp.phase.calendar_busy",
        default: "Quiet during Calendar busy time",
    )
    static let excludedApplication = string(
        "headsUp.phase.excluded_application",
        default: "Quiet in this app",
    )
    static let outsideWorkingHours = string(
        "headsUp.phase.outside_working_hours",
        default: "Outside working hours",
    )
    static let snoozed = string("headsUp.phase.snoozed", default: "Snoozed")
    static let pausedTitle = string("headsUp.phase.paused_title", default: "Paused")
    static let quietTitle = string("headsUp.phase.quiet_title", default: "Quiet")
    static let onHoldTitle = string("headsUp.phase.on_hold_title", default: "On hold")
    static let presentingTitle = string("headsUp.phase.presenting_title", default: "Presenting")
    static let untilDetailFormat = string(
        "headsUp.phase.until_detail_format",
        default: "until %@",
    )
    static let untilResumeDetail = string(
        "headsUp.phase.until_resume_detail",
        default: "until you resume",
    )
    static let inactiveDetail = string(
        "headsUp.phase.inactive_detail",
        default: "while the Mac is inactive",
    )
    static let presentationModeDetail = string(
        "headsUp.phase.presentation_mode_detail",
        default: "reminders off",
    )
    static let focusDetail = string("headsUp.phase.focus_detail", default: "in Focus")
    static let busyUntilDetailFormat = string(
        "headsUp.phase.busy_until_detail_format",
        default: "busy until %@",
    )
    static let calendarBusyDetail = string(
        "headsUp.phase.calendar_busy_detail",
        default: "during Calendar busy time",
    )
    static let excludedApplicationDetail = string(
        "headsUp.phase.excluded_application_detail",
        default: "in this app",
    )
    static let statusAccessibilityFormat = string(
        "headsUp.accessibility.status_format",
        default: "%@, %@",
    )
    static let appearanceApproachAnnouncementFormat = string(
        "headsUp.announcement.appearance_approach_format",
        default: "%@ in %d seconds. %@",
    )
    static let appearanceLandedAnnouncementFormat = string(
        "headsUp.announcement.appearance_landed_format",
        default: "%@ %@. %@",
    )
    static let availableActionsAnnouncement = string(
        "headsUp.announcement.available_actions",
        default: "Now, button. Later, menu button.",
    )
    static let secondsFormat = string("headsUp.phase.seconds_format", default: "in %d s")
    static let minutesFormat = string("headsUp.action.minutes_format", default: "%d minutes")

    static let permissionExplainerTitle = string(
        "headsUp.permission.explainer_title",
        default: "Heads-up before a break",
    )
    static let permissionExplainerMessage = string(
        "headsUp.permission.explainer_message",
        default: "Uses notifications if you allow them. Without them, an in-app heads-up appears instead.",
    )
    static let permissionContinue = string(
        "headsUp.permission.continue",
        default: "Continue",
    )
    static let permissionContinueHint = string(
        "headsUp.permission.continue_hint",
        default: "Opens the system notification permission prompt.",
    )
    static let permissionUseInApp = string(
        "headsUp.permission.use_in_app",
        default: "Use in-app heads-up",
    )
    static let notificationsOff = string(
        "headsUp.permission.notifications_off",
        default: "Notifications are off",
    )
    static let notificationsFallback = string(
        "headsUp.permission.fallback",
        default: "Heads-ups appear in the app instead.",
    )
    static let openNotificationSettings = string(
        "headsUp.permission.open_settings",
        default: "Open Notification Settings…",
    )
}

extension HeadsUpL10n {
    static func presentation(
        scope: HeadsUpScope,
        phase: HeadsUpPhase,
        formatDeadline: (Date) -> String,
    ) -> HeadsUpPresentationCopy {
        switch phase {
        case let .approaching(mark):
            scopePresentation(title: title(for: scope), detail: seconds(mark.seconds))
        case .landedWaiting:
            scopePresentation(title: title(for: scope), detail: landed)
        case let .hold(hold):
            holdPresentation(hold, formatDeadline: formatDeadline)
        }
    }

    static func minutes(_ value: Int) -> String {
        String.localizedStringWithFormat(minutesFormat, value)
    }

    static func appearanceAnnouncement(
        scope: HeadsUpScope,
        phase: HeadsUpPhase,
        formatDeadline: (Date) -> String,
    ) -> HeadsUpAnnouncement {
        let localizedText = switch phase {
        case let .approaching(mark):
            String.localizedStringWithFormat(
                appearanceApproachAnnouncementFormat,
                title(for: scope),
                mark.seconds,
                availableActionsAnnouncement,
            )
        case .landedWaiting:
            formatted(
                appearanceLandedAnnouncementFormat,
                title(for: scope),
                landed,
                availableActionsAnnouncement,
            )
        case let .hold(hold):
            holdDetail(hold, formatDeadline: formatDeadline)
        }
        return HeadsUpAnnouncement(kind: .appearance, localizedText: localizedText)
    }

    static func holdAnnouncement(
        _ hold: HeadsUpHold,
        formatDeadline: (Date) -> String,
    ) -> HeadsUpAnnouncement {
        HeadsUpAnnouncement(
            kind: .holdChange,
            localizedText: holdDetail(hold, formatDeadline: formatDeadline),
        )
    }
}

private extension HeadsUpL10n {
    private static func seconds(_ value: Int) -> String {
        String.localizedStringWithFormat(secondsFormat, value)
    }

    private static func holdPresentation(
        _ hold: HeadsUpHold,
        formatDeadline: (Date) -> String,
    ) -> HeadsUpPresentationCopy {
        let display: (title: String, detail: String) = switch hold {
        case let .manualPause(until?):
            (pausedTitle, formatted(untilDetailFormat, formatDeadline(until)))
        case .manualPause(until: nil):
            (pausedTitle, untilResumeDetail)
        case .systemInactiveOrLocked:
            (quietTitle, inactiveDetail)
        case .explicitPresentationMode:
            (presentingTitle, presentationModeDetail)
        case .focusFilter:
            (quietTitle, focusDetail)
        case let .calendarBusy(until?):
            (onHoldTitle, formatted(busyUntilDetailFormat, formatDeadline(until)))
        case .calendarBusy(until: nil):
            (quietTitle, calendarBusyDetail)
        case .excludedApplication:
            (quietTitle, excludedApplicationDetail)
        case .outsideWorkingHours:
            (outsideWorkingHours, "")
        case .snooze:
            (snoozed, "")
        }
        return HeadsUpPresentationCopy(
            title: display.title,
            detail: display.detail,
            statusAccessibilityLabel: holdDetail(hold, formatDeadline: formatDeadline),
        )
    }

    private static func holdDetail(
        _ hold: HeadsUpHold,
        formatDeadline: (Date) -> String,
    ) -> String {
        switch hold {
        case let .manualPause(until?):
            String.localizedStringWithFormat(manualPauseUntilFormat, formatDeadline(until))
        case .manualPause(until: nil):
            manualPauseIndefinite
        case .systemInactiveOrLocked:
            systemInactive
        case .explicitPresentationMode:
            presentationMode
        case .focusFilter:
            focusFilter
        case let .calendarBusy(until?):
            String.localizedStringWithFormat(holdBusyFormat, formatDeadline(until))
        case .calendarBusy(until: nil):
            calendarBusy
        case .excludedApplication:
            excludedApplication
        case .outsideWorkingHours:
            outsideWorkingHours
        case .snooze:
            snoozed
        }
    }

    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }

    private static func formatted(_ format: String, _ values: CVarArg...) -> String {
        String(format: format, locale: .current, arguments: values)
    }
}

private extension HeadsUpL10n {
    static func title(for scope: HeadsUpScope) -> String {
        switch scope {
        case .visual: visualTitle
        case .movement: movementTitle
        case .merged: mergedTitle
        }
    }

    static func scopePresentation(title: String, detail: String) -> HeadsUpPresentationCopy {
        HeadsUpPresentationCopy(
            title: title,
            detail: detail,
            statusAccessibilityLabel: String.localizedStringWithFormat(
                statusAccessibilityFormat,
                title,
                detail,
            ),
        )
    }
}
