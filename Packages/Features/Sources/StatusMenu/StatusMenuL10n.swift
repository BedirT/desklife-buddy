import Domain
import FeatureLocalization
import Foundation

enum StatusMenuL10n {
    static let visualReset = string("status_menu.visual_reset", default: "Visual reset")
    static let movement = string("status_menu.movement", default: "Movement")
    static let positionChange = string("status_menu.position_change", default: "Position change")
    static let recoverySuggestion = string(
        "status_menu.recovery_suggestion",
        default: "Recovery suggestion",
    )
    static let due = string("status_menu.due", default: "Due")
    static let startNow = string("status_menu.start_now", default: "Start now")
    static let later = string("status_menu.later", default: "Later")
    static let moreOptions = string("status_menu.more_options", default: "More options")
    static let snoozeFiveMinutes = string("status_menu.snooze_five_minutes", default: "5 minutes")
    static let snoozeTenMinutes = string("status_menu.snooze_ten_minutes", default: "10 minutes")
    static let snoozeFifteenMinutes = string("status_menu.snooze_fifteen_minutes", default: "15 minutes")
    static let startVisualReset = string("status_menu.start_visual_reset", default: "Start a visual reset")
    static let startMovement = string("status_menu.start_movement", default: "Start movement")
    static let movementRecommended = string("status_menu.movement_recommended", default: "5 minutes")
    static let movementQuick = string("status_menu.movement_quick", default: "2 minutes")
    static let movementPosition = string("status_menu.movement_position", default: "Position change")
    static let pause = string("status_menu.pause", default: "Pause")
    static let resume = string("status_menu.resume", default: "Resume")
    static let pauseThirtyMinutes = string("status_menu.pause_thirty_minutes", default: "For 30 minutes")
    static let pauseOneHour = string("status_menu.pause_one_hour", default: "For 1 hour")
    static let pauseRestOfDay = string("status_menu.pause_rest_of_day", default: "For the rest of the day")
    static let pauseUntilResume = string("status_menu.pause_until_resume", default: "Until I resume")
    static let presenting = string("status_menu.presenting", default: "Presenting")
    static let workingHoursOnly = string("status_menu.working_hours_only", default: "Only during working hours")
    static let weeklyRhythm = string("status_menu.weekly_rhythm", default: "Weekly rhythm…")
    static let settings = string("status_menu.settings", default: "Settings…")
    static let quit = string("status_menu.quit", default: "Quit")
    static let accessibilityLabel = string("status_menu.accessibility_label", default: "Break status")
    static func next(aboutMinutes: Int) -> String {
        format("status_menu.next_format", default: "Next: about %d minutes", aboutMinutes)
    }

    static func estimatedActiveUse(minutes: Int) -> String {
        format(
            "status_menu.estimated_active_use_format",
            default: "%d minutes of estimated active computer use",
            minutes,
        )
    }

    static func suppression(
        _ reason: SuppressionReason,
        manualPause: StatusMenuManualPause? = nil,
    ) -> String {
        switch reason {
        case .manualPause:
            switch manualPause {
            case let .until(date):
                format(
                    "status_menu.suppression.manual_pause_until_format",
                    default: "Paused until %@",
                    DateFormatter.localizedString(
                        from: date,
                        dateStyle: .none,
                        timeStyle: .short,
                    ),
                )
            case .untilResume:
                string("status_menu.suppression.manual_pause", default: "Paused until you resume")
            case nil:
                string("status_menu.suppression.manual_pause_generic", default: "Paused")
            }
        case .systemInactiveOrLocked:
            string("status_menu.suppression.system_inactive", default: "Quiet while the Mac is inactive")
        case .explicitPresentationMode:
            string("status_menu.suppression.presentation", default: "Presenting, reminders off")
        case .focusFilter:
            string("status_menu.suppression.focus", default: "Quiet in Focus")
        case .calendarBusy:
            string("status_menu.suppression.calendar", default: "Quiet during Calendar busy time")
        case .excludedApplication:
            string("status_menu.suppression.excluded_app", default: "Quiet in this app")
        case .outsideWorkingHours:
            string("status_menu.suppression.outside_hours", default: "Outside working hours")
        case .snooze:
            string("status_menu.suppression.snooze", default: "Snoozed")
        case .lowFrictionWait:
            string("status_menu.suppression.low_friction", default: "Waiting for a pause")
        }
    }

    static func accessibilityClock(_ summary: StatusClockSummary) -> String {
        let label = switch summary.opportunity {
        case .visual: visualReset
        case .movement: movement
        case .positionChange: positionChange
        case .recovery: recoverySuggestion
        }
        return switch summary.timing {
        case let .next(aboutMinutes):
            format(
                "status_menu.accessibility_next_format",
                default: "%@ in about %d minutes.",
                label,
                aboutMinutes,
            )
        case .due:
            format(
                "status_menu.accessibility_due_format",
                default: "%@ due.",
                label,
            )
        }
    }

    static func accessibilityEstimatedActiveUse(minutes: Int) -> String {
        format(
            "status_menu.accessibility_estimated_active_use_format",
            default: "Estimated active computer use, %d minutes.",
            minutes,
        )
    }

    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }

    private static func format(
        _ key: String,
        default value: String,
        _ arguments: CVarArg...,
    ) -> String {
        String(
            format: string(key, default: value),
            locale: .current,
            arguments: arguments,
        )
    }
}

/// Localized labels shared with AppKit's native menu composition.
public enum StatusMenuCopy {
    public static let startNow = StatusMenuL10n.startNow
    public static let later = StatusMenuL10n.later
    public static let moreOptions = StatusMenuL10n.moreOptions
    public static let snoozeFiveMinutes = StatusMenuL10n.snoozeFiveMinutes
    public static let snoozeTenMinutes = StatusMenuL10n.snoozeTenMinutes
    public static let snoozeFifteenMinutes = StatusMenuL10n.snoozeFifteenMinutes
    public static let startVisualReset = StatusMenuL10n.startVisualReset
    public static let startMovement = StatusMenuL10n.startMovement
    public static let movementRecommended = StatusMenuL10n.movementRecommended
    public static let movementQuick = StatusMenuL10n.movementQuick
    public static let movementPosition = StatusMenuL10n.movementPosition
    public static let pause = StatusMenuL10n.pause
    public static let resume = StatusMenuL10n.resume
    public static let pauseThirtyMinutes = StatusMenuL10n.pauseThirtyMinutes
    public static let pauseOneHour = StatusMenuL10n.pauseOneHour
    public static let pauseRestOfDay = StatusMenuL10n.pauseRestOfDay
    public static let pauseUntilResume = StatusMenuL10n.pauseUntilResume
    public static let presenting = StatusMenuL10n.presenting
    public static let workingHoursOnly = StatusMenuL10n.workingHoursOnly
    public static let weeklyRhythm = StatusMenuL10n.weeklyRhythm
    public static let settings = StatusMenuL10n.settings
    public static let quit = StatusMenuL10n.quit
    public static let accessibilityLabel = StatusMenuL10n.accessibilityLabel

    public static func accessibilityValue(for snapshot: StatusMenuSnapshot) -> String {
        var components = [
            StatusMenuL10n.accessibilityClock(snapshot.visual),
            StatusMenuL10n.accessibilityClock(snapshot.movement),
            StatusMenuL10n.accessibilityEstimatedActiveUse(
                minutes: snapshot.estimatedActiveUseMinutes,
            ),
        ]
        if let suppression = snapshot.activeSuppression {
            components.append(
                StatusMenuL10n.suppression(
                    suppression,
                    manualPause: snapshot.manualPause,
                ) + ".",
            )
        }
        return components.joined(separator: " ")
    }
}
