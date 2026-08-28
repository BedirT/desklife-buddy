import FeatureLocalization
import Foundation

enum SettingsFeatureL10n {
    static let navigationTitle = string("settings.navigation_title", default: "Settings")
    static let scheduleAndBreaks = string(
        "settings.sidebar.schedule_breaks",
        default: "Schedule & breaks",
    )
    static let personalize = string("settings.sidebar.personalize", default: "Personalize")
    static let learnAndSupport = string(
        "settings.sidebar.learn_support",
        default: "Learn & support",
    )
    static let schedule = string("settings.section.schedule", default: "Schedule")
    static let breakContent = string("settings.section.break_content", default: "Break content")
    static let contextAndExclusions = string(
        "settings.section.context_and_exclusions",
        default: "Context & exclusions",
    )
    static let accessibility = string("settings.section.accessibility", default: "Accessibility")
    static let privacyAndData = string("settings.section.privacy_and_data", default: "Privacy & data")
    static let integrations = string("settings.section.integrations", default: "Integrations")
    static let whyTheseDefaults = string("settings.section.why_defaults", default: "Why these defaults?")
    static let safetyAndSupport = string("settings.section.safety_support", default: "Safety & support")
    static let loading = string("settings.loading", default: "Loading settings…")
    static let loadFailedTitle = string("settings.load_failed.title", default: "Settings couldn't be loaded")
    static let loadFailedMessage = string(
        "settings.load_failed.message",
        default: "Your existing settings have not been changed.",
    )
    static let retry = string("settings.retry", default: "Try again")
    static let comingLaterTitle = string("settings.coming_later.title", default: "This section is coming next")
    static let comingLaterMessage = string(
        "settings.coming_later.message",
        default: "Schedule is ready now. The remaining local settings are being built in order.",
    )
    static let rhythm = string("settings.schedule.rhythm", default: "Rhythm")
    static let timing = string("settings.schedule.timing", default: "Timing")
    static let delivery = string("settings.schedule.delivery", default: "Delivery")
    static let gentle = string("settings.profile.gentle", default: "Gentle")
    static let balanced = string("settings.profile.balanced", default: "Balanced")
    static let frequentMovement = string("settings.profile.frequent", default: "Frequent movement")
    static let highFrequency = string(
        "settings.profile.high_frequency",
        default: "Research-informed high frequency",
    )
    static let custom = string("settings.profile.custom", default: "Custom")
    static let advanced = string("settings.schedule.advanced", default: "Advanced schedules")
    static let independentClocks = string(
        "settings.schedule.independent_clocks",
        default: "Two clocks run independently. A visual reset never completes movement.",
    )
    static let visualReset = string("settings.schedule.visual_reset", default: "Visual reset")
    static let movement = string("settings.schedule.movement", default: "Movement")
    static let headsUp = string("settings.schedule.heads_up", default: "Heads-up before a break")
    static let waitForLowFriction = string(
        "settings.schedule.low_friction",
        default: "Wait for a low-friction moment",
    )
    static let workingHoursOnly = string(
        "settings.schedule.working_hours_only",
        default: "Only during working hours",
    )
    static let estimatorExplanation = string(
        "settings.schedule.estimator_explanation",
        default: "Timing is based on estimated active computer use: key and pointer input only. It can't tell whether you are sitting, standing, or looking at the screen.",
    )
    static let whyTheseNumbers = string("settings.schedule.why_numbers", default: "Why these numbers?")
    static let visualSoftDue = string("settings.custom.visual.soft_due", default: "Visual start offering after (min)")
    static let visualTarget = string("settings.custom.visual.target", default: "Visual target (min)")
    static let movementTarget = string("settings.custom.movement.target", default: "Movement target (min)")
    static let visualLatestPreferred = string(
        "settings.custom.visual.latest_preferred",
        default: "Visual prefer by (min)",
    )
    static let visualDuration = string("settings.custom.visual.duration", default: "Visual duration (sec)")
    static let movementSoftDue = string(
        "settings.custom.movement.soft_due",
        default: "Movement start offering after (min)",
    )
    static let movementLatestPreferred = string(
        "settings.custom.movement.latest_preferred",
        default: "Movement prefer by (min)",
    )
    static let movementSuggestedDuration = string(
        "settings.custom.movement.suggested_duration",
        default: "Suggested duration (min)",
    )
    static let movementQuickDuration = string(
        "settings.custom.movement.quick_duration",
        default: "Quick option (min)",
    )
    static let applyCustom = string("settings.custom.apply", default: "Save custom timing")
    static let customInvalid = string(
        "settings.custom.invalid",
        default: "Enter positive intervals and durations to use this schedule.",
    )
    static func customFieldRequired(_ field: String) -> String {
        format("settings.custom.field.required", default: "%@ is required.", field)
    }

    static func customFieldInvalidNumber(_ field: String) -> String {
        format("settings.custom.field.invalid_number", default: "%@ must be a number.", field)
    }

    static func customFieldPositiveFinite(_ field: String) -> String {
        format("settings.custom.field.positive_finite", default: "%@ must be a positive number.", field)
    }

    static func customFieldValueTooLarge(_ field: String) -> String {
        format("settings.custom.field.value_too_large", default: "%@ is too large to use.", field)
    }

    static func customFieldOrderedWindow(_ field: String) -> String {
        format(
            "settings.custom.field.ordered_window",
            default: "%@ must keep start, target, and prefer-by in order.",
            field,
        )
    }

    static let visualVeryFrequentNote = string(
        "settings.custom.visual.very_frequent_note",
        default: "Visual resets are set more often than the research-informed high-frequency schedule. You can keep this timing.",
    )
    static let movementVeryFrequentNote = string(
        "settings.custom.movement.very_frequent_note",
        default: "Movement is set more often than the research-informed high-frequency schedule. You can keep this timing.",
    )
    static let visualEffectivelyDisabledNote = string(
        "settings.custom.visual.effectively_disabled_note",
        default: "At this interval, a visual reset may rarely appear during a workday. You can keep this timing.",
    )
    static let movementEffectivelyDisabledNote = string(
        "settings.custom.movement.effectively_disabled_note",
        default: "At this interval, a movement opportunity may rarely appear during a workday. You can keep this timing.",
    )
    static let applying = string("settings.operation.applying", default: "Applying…")
    static let temporarilyBusy = string(
        "settings.operation.busy",
        default: "A break or heads-up action is in progress. Try this change again shortly.",
    )
    static let applyFailed = string(
        "settings.operation.failed",
        default: "That change wasn't applied. Your previous settings are still active.",
    )

    static func profileSubtitle(visualMinutes: String, movementMinutes: String) -> String {
        format(
            "settings.profile.subtitle_format",
            default: "about %@ min · about %@ min",
            visualMinutes,
            movementMinutes,
        )
    }

    static func profileAccessibilityLabel(name: String, visualMinutes: String, movementMinutes: String) -> String {
        format(
            "settings.profile.accessibility_format",
            default: "%@, about %@ minutes visual, about %@ minutes movement",
            name,
            visualMinutes,
            movementMinutes,
        )
    }

    static func visualTimingSummary(intervalMinutes: String, durationSeconds: String) -> String {
        format(
            "settings.timing.visual_format",
            default: "about every %@ min, for %@ s",
            intervalMinutes,
            durationSeconds,
        )
    }

    static func movementTimingSummary(intervalMinutes: String, durationMinutes: String) -> String {
        format(
            "settings.timing.movement_format",
            default: "about every %@ min, suggested %@ min",
            intervalMinutes,
            durationMinutes,
        )
    }

    static func headsUpSummary(seconds: String) -> String {
        format("settings.timing.heads_up_format", default: "About %@ seconds", seconds)
    }

    static func title(for section: SettingsSection) -> String {
        switch section {
        case .schedule: schedule
        case .breakContent: breakContent
        case .contextAndExclusions: contextAndExclusions
        case .accessibility: accessibility
        case .privacyAndData: privacyAndData
        case .integrations: integrations
        case .whyTheseDefaults: whyTheseDefaults
        case .safetyAndSupport: safetyAndSupport
        }
    }

    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }

    private static func format(
        _ key: String,
        default value: String,
        _ arguments: CVarArg...,
    ) -> String {
        String(format: string(key, default: value), locale: .current, arguments: arguments)
    }
}
