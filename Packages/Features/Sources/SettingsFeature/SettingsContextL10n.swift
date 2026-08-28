import FeatureLocalization
import Foundation

enum SettingsContextL10n {
    static let automaticQuieting = string(
        "settings.context.automatic_quieting",
        default: "Automatic quieting",
    )
    static let automaticQuietingDetail = string(
        "settings.context.automatic_quieting_detail",
        default: "Choose when reminders should stay out of the way. These controls use choices you make and recent key or pointer activity, never app content.",
    )
    static let presentationMode = string(
        "settings.context.presentation_mode",
        default: "Quiet reminders while presenting",
    )
    static let presentationModeDetail = string(
        "settings.context.presentation_mode_detail",
        default: "When you choose Presenting from the status menu, reminders stay quiet until you turn it off.",
    )
    static let lowFrictionDetail = string(
        "settings.context.low_friction_detail",
        default: "When a break is due, wait within its timing window for a pause in recent key or pointer activity.",
    )
    static let manualPause = string("settings.context.manual_pause", default: "Manual pause")
    static let manualPauseDetail = string(
        "settings.context.manual_pause_detail",
        default: "Pause for a time or until you resume from the status menu. Break clocks do not accumulate during a manual pause.",
    )
    static let idleBehavior = string("settings.context.idle_behavior", default: "Long idle")
    static let idleBehaviorDetail = string(
        "settings.context.idle_behavior_detail",
        default: "After a long idle, the app may reset when the next break is presented. It never records movement.",
    )
    static let excludedApps = string("settings.context.excluded_apps", default: "Excluded apps")
    static let excludedAppsDetail = string(
        "settings.context.excluded_apps_detail",
        default: "Reminders stay quiet while a chosen app is frontmost. Only its bundle identifier is stored, not window titles or content.",
    )
    static let noExcludedApps = string(
        "settings.context.no_excluded_apps",
        default: "No excluded apps",
    )
    static let noExcludedAppsDetail = string(
        "settings.context.no_excluded_apps_detail",
        default: "Reminders can appear in any app unless another quieting choice applies.",
    )
    static let chooseApp = string("settings.context.choose_app", default: "Choose app…")
    static let unavailableApp = string("settings.context.unavailable_app", default: "Unavailable app")
    static let returnBehavior = string(
        "settings.context.return_behavior",
        default: "After quiet time ends, reminders return after a short grace period. If visual and movement are both due, the app offers at most one combined break. Never a stack of prompts.",
    )

    static func removeApp(_ name: String) -> String {
        format(
            "settings.context.remove_app_format",
            default: "Remove %@ from excluded apps",
            name,
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
