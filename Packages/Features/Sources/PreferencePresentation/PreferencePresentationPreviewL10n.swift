import FeatureLocalization
import Foundation

enum PreferencePresentationPreviewL10n {
    static let gentle = string("settings.profile.gentle", default: "Gentle")
    static let balanced = string("settings.profile.balanced", default: "Balanced")
    static let frequentMovement = string(
        "settings.profile.frequent",
        default: "Frequent movement",
    )
    static let balancedDetail = profileDetail(visualMinutes: "25", movementMinutes: "60")
    static let walkOrWheel = string(
        "settings.break_content.movement.walk_or_wheel",
        default: "Walk or wheel",
    )
    static let walkOrWheelDetail = string(
        "settings.break_content.movement.walk_or_wheel_detail",
        default: "Easy movement away from the desk, including an equivalent active movement.",
    )
    static let staticPresentation = string(
        "settings.accessibility.presentation.static",
        default: "Static",
    )
    static let staticPresentationDetail = string(
        "settings.accessibility.presentation.static_detail",
        default: "Uses no image field or app motion. Break text and controls appear over a softened desktop.",
    )
    static let darker = string("settings.accessibility.brightness.darker", default: "Darker")
    static let brighter = string("settings.accessibility.brightness.brighter", default: "Brighter")
    static let brightness = string(
        "settings.accessibility.background_brightness",
        default: "Background brightness",
    )

    static func profileTitle(for stage: PreferenceRhythmStage) -> String {
        switch stage {
        case .gentle: gentle
        case .balanced: balanced
        case .frequentMovement: frequentMovement
        }
    }

    static func profileDetail(for stage: PreferenceRhythmStage) -> String {
        switch stage {
        case .gentle: profileDetail(visualMinutes: "30", movementMinutes: "75")
        case .balanced: balancedDetail
        case .frequentMovement: profileDetail(visualMinutes: "25", movementMinutes: "35")
        }
    }

    private static func profileDetail(visualMinutes: String, movementMinutes: String) -> String {
        String(
            format: string(
                "settings.profile.subtitle_format",
                default: "about %@ min · about %@ min",
            ),
            locale: Locale(identifier: "en_US"),
            visualMinutes,
            movementMinutes,
        )
    }

    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }
}
