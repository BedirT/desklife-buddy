import FeatureLocalization
import Foundation

enum BreakFlowL10n {
    static let visualOnlyAcknowledgement = FeatureL10n.string(
        "breakFlow.visual_only_acknowledgement",
        default: "Visual reset done. Movement is still open when you want it.",
    )
    static let recoveryEyebrow = FeatureL10n.string(
        "breakFlow.recovery.eyebrow",
        default: "Recovery suggestion",
    )
    static let recoveryHeadline = FeatureL10n.string(
        "breakFlow.recovery.headline",
        default: "A longer reset may feel better after a long computer-use run.",
    )
    static let recoveryGuidance = FeatureL10n.string(
        "breakFlow.recovery.guidance",
        default: "Try 5–10 minutes away from the desk when it works.",
    )
    static let notNow = FeatureL10n.string("breakFlow.recovery.not_now", default: "Not now")
    static let escapeKey = FeatureL10n.string("breakFlow.escape_key", default: "esc")
    static let escapeKeyAccessibility = FeatureL10n.string(
        "breakFlow.escape_key_accessibility",
        default: "Escape",
    )
    static let snoozeTitle = FeatureL10n.string(
        "breakFlow.snooze.title",
        default: "Not a good moment? Snooze or skip.",
    )
    static let bothDue = FeatureL10n.string(
        "breakFlow.snooze.both_due",
        default: "Both are due — one break covers them",
    )
    static let afterMeeting = FeatureL10n.string(
        "breakFlow.snooze.after_meeting",
        default: "After this meeting",
    )
    static let pauseForOneHour = FeatureL10n.string(
        "breakFlow.snooze.pause_for_one_hour",
        default: "Pause for 1 hour",
    )
    static let notAppropriate = FeatureL10n.string(
        "breakFlow.snooze.not_appropriate",
        default: "This one doesn't work for me",
    )
    static let skip = FeatureL10n.string("breakFlow.snooze.skip", default: "Skip")
    static let pausedOneHourAnnouncement = FeatureL10n.string(
        "breakFlow.snooze.paused_one_hour_announcement",
        default: "Paused for 1 hour.",
    )
    static let notedForSessionAnnouncement = FeatureL10n.string(
        "breakFlow.snooze.noted_for_session_announcement",
        default: "Noted for this session.",
    )
    static let skippedAnnouncement = FeatureL10n.string(
        "breakFlow.snooze.skipped_announcement",
        default: "Skipped.",
    )

    static func snoozeMinutes(_ durationSeconds: TimeInterval) -> String {
        let minutes = Int(durationSeconds / 60)
        let format = FeatureL10n.string(
            "breakFlow.snooze.minutes_format",
            default: "%d minutes",
        )
        return String(format: format, locale: .current, minutes)
    }

    static func recoveryMinutesAway(_ durationSeconds: TimeInterval) -> String {
        let minutes = Int(durationSeconds / 60)
        let format = FeatureL10n.string(
            "breakFlow.recovery.minutes_away_format",
            default: "%d minutes away",
        )
        return String(format: format, locale: .current, minutes)
    }

    static func recoveryMinutesAccessibility(_ durationSeconds: TimeInterval) -> String {
        let minutes = Int(durationSeconds / 60)
        let format = FeatureL10n.string(
            "breakFlow.recovery.minutes_accessibility_format",
            default: "Choose %d minutes away",
        )
        return String(format: format, locale: .current, minutes)
    }

    static func snoozeMinutesAccessibility(_ durationSeconds: TimeInterval) -> String {
        let minutes = Int(durationSeconds / 60)
        let format = FeatureL10n.string(
            "breakFlow.snooze.minutes_accessibility_format",
            default: "Snooze for %d minutes",
        )
        return String(format: format, locale: .current, minutes)
    }

    static func snoozedAnnouncement(minutes: Int) -> String {
        let format = FeatureL10n.string(
            "breakFlow.snooze.snoozed_announcement_format",
            default: "Snoozed for %d minutes.",
        )
        return String(format: format, locale: .current, minutes)
    }
}

public extension BreakFlowAnnouncement {
    var localizedText: String {
        switch self {
        case let .snoozed(minutes): BreakFlowL10n.snoozedAnnouncement(minutes: minutes)
        case .pausedOneHour: BreakFlowL10n.pausedOneHourAnnouncement
        case .notedForSession: BreakFlowL10n.notedForSessionAnnouncement
        case .skipped: BreakFlowL10n.skippedAnnouncement
        }
    }
}

public enum BreakFlowCopy {
    public static let snoozeTitle = BreakFlowL10n.snoozeTitle
    public static let bothDue = BreakFlowL10n.bothDue
}
