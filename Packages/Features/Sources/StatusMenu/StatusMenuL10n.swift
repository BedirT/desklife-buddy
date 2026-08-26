import Domain
import FeatureLocalization
import Foundation

enum StatusMenuL10n {
    static let visualReset = string("status_menu.visual_reset", default: "Visual reset")
    static let movement = string("status_menu.movement", default: "Movement")
    static let positionChange = string("status_menu.position_change", default: "Position change")
    static let recovery = string("status_menu.recovery", default: "Recovery")
    static let due = string("status_menu.due", default: "Due")
    static let startNow = string("status_menu.start_now", default: "Start now")
    static let later = string("status_menu.later", default: "Later")
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
    static let nothingDue = string("status_menu.nothing_due", default: "Nothing due")
    static let paused = string("status_menu.paused", default: "Paused")
    static let visualDue = string("status_menu.visual_due", default: "Visual reset due")
    static let movementDue = string("status_menu.movement_due", default: "Movement due")
    static let bothDue = string("status_menu.both_due", default: "Visual reset and movement due")

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

    static func suppression(_ reason: SuppressionReason) -> String {
        switch reason {
        case .manualPause:
            string("status_menu.suppression.manual_pause", default: "Paused until you resume")
        case .systemInactiveOrLocked:
            string("status_menu.suppression.system_inactive", default: "Quiet while the Mac is inactive")
        case .explicitPresentationMode:
            string("status_menu.suppression.presentation", default: "Presenting — reminders off")
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

    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }

    private static func format(_ key: String, default value: String, _ argument: Int) -> String {
        String(format: string(key, default: value), locale: .current, argument)
    }
}
