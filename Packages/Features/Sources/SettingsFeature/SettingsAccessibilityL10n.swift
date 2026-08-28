import FeatureLocalization
import Foundation

enum SettingsAccessibilityL10n {
    static let breakPresentation = string(
        "settings.accessibility.break_presentation",
        default: "Break presentation",
    )
    static let breakPresentationDetail = string(
        "settings.accessibility.break_presentation_detail",
        default: "Choose how every break appears. Each option keeps the full instructions and controls.",
    )
    static let standard = string("settings.accessibility.presentation.standard", default: "Standard")
    static let standardDetail = string(
        "settings.accessibility.presentation.standard_detail",
        default: "Uses the full visual field and its one-time transitions.",
    )
    static let staticPresentation = string(
        "settings.accessibility.presentation.static",
        default: "Static",
    )
    static let staticPresentationDetail = string(
        "settings.accessibility.presentation.static_detail",
        default: "Uses no image field or app motion. Break text and controls appear over a softened desktop.",
    )
    static let textOnly = string(
        "settings.accessibility.presentation.text_only",
        default: "Text only",
    )
    static let textOnlyDetail = string(
        "settings.accessibility.presentation.text_only_detail",
        default: "Shows the complete break as text and controls, without illustration or app motion.",
    )
    static let backgroundBrightness = string(
        "settings.accessibility.background_brightness",
        default: "Background brightness",
    )
    static let backgroundBrightnessDetail = string(
        "settings.accessibility.background_brightness_detail",
        default: "Adjust the softened desktop behind Static breaks.",
    )
    static let darker = string("settings.accessibility.brightness.darker", default: "Darker")
    static let brighter = string("settings.accessibility.brightness.brighter", default: "Brighter")
    static let timerAnnouncements = string(
        "settings.accessibility.timer_announcements",
        default: "Timer announcements",
    )
    static let timerAnnouncementsDetail = string(
        "settings.accessibility.timer_announcements_detail",
        default: "Choose whether VoiceOver announces timer progress.",
    )
    static let coarseMilestones = string(
        "settings.accessibility.timer.coarse",
        default: "Coarse milestones",
    )
    static let coarseMilestonesDetail = string(
        "settings.accessibility.timer.coarse_detail",
        default: "Announces a few useful timer milestones, never every second.",
    )
    static let noTimerAnnouncements = string(
        "settings.accessibility.timer.none",
        default: "Off",
    )
    static let noTimerAnnouncementsDetail = string(
        "settings.accessibility.timer.none_detail",
        default: "Does not announce timer progress. Other VoiceOver labels and state changes remain available.",
    )
    static let movementOrder = string(
        "settings.accessibility.movement_order",
        default: "Movement order",
    )
    static let seatedContentFirst = string(
        "settings.accessibility.seated_first",
        default: "Show seated movement first",
    )
    static let seatedContentFirstDetail = string(
        "settings.accessibility.seated_first_detail",
        default: "Moves seated movement to the first content position. Every movement path keeps equal status.",
    )
    static let systemAndKeyboard = string(
        "settings.accessibility.system_keyboard",
        default: "System & keyboard",
    )
    static let systemDisplaySettings = string(
        "settings.accessibility.system_display",
        default: "System display settings",
    )
    static let systemDisplaySettingsDetail = string(
        "settings.accessibility.system_display_detail",
        default: "Reduce Motion and Increase Contrast are followed automatically. Your break-presentation choice stays separate.",
    )
    static let keyboardAccess = string(
        "settings.accessibility.keyboard",
        default: "Keyboard access",
    )
    static let keyboardAccessDetail = string(
        "settings.accessibility.keyboard_detail",
        default: "Breaks show their available keys. Escape always dismisses. No global shortcuts are assigned by default.",
    )

    static func brightnessValue(_ percentage: Int) -> String {
        format(
            "settings.accessibility.brightness.value_format",
            default: "%d%% brightness",
            percentage,
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
        String(format: string(key, default: value), locale: .current, arguments: arguments)
    }
}
