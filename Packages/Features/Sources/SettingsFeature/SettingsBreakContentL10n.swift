import FeatureLocalization
import Foundation

extension SettingsFeatureL10n {
    static let preferredMovement = breakString(
        "settings.break_content.preferred_movement",
        default: "Preferred movement",
    )
    static let preferredMovementExplanation = breakString(
        "settings.break_content.preferred_movement_explanation",
        default: "Each path has equal status. You can choose a different one during any movement opportunity.",
    )
    static let movementWalkOrWheel = breakString(
        "settings.break_content.movement.walk_or_wheel",
        default: "Walk or wheel",
    )
    static let movementWalkOrWheelDetail = breakString(
        "settings.break_content.movement.walk_or_wheel_detail",
        default: "Easy movement away from the desk, including an equivalent active movement.",
    )
    static let movementSeated = breakString(
        "settings.break_content.movement.seated",
        default: "Seated movement",
    )
    static let movementSeatedDetail = breakString(
        "settings.break_content.movement.seated_detail",
        default: "Active seated movement appears first.",
    )
    static let movementMixed = breakString(
        "settings.break_content.movement.mixed",
        default: "Mix movement paths",
    )
    static let movementMixedDetail = breakString(
        "settings.break_content.movement.mixed_detail",
        default: "Walk or wheel, small-space, and seated cards can appear.",
    )
    static let movementPosition = breakString(
        "settings.break_content.movement.position",
        default: "Change position",
    )
    static let positionChangeHonesty = breakString(
        "settings.break_content.movement.position_detail",
        default: "Logged on its own. It doesn't complete this movement opportunity.",
    )
    static let contentChoices = breakString("settings.break_content.choices", default: "Content choices")
    static let quickMovementOption = breakString(
        "settings.break_content.quick_option",
        default: "Show the 2-minute movement option",
    )
    static let quickMovementOptionDetail = breakString(
        "settings.break_content.quick_option_detail",
        default: "Two minutes is a useful quick option alongside the suggested 5 minutes.",
    )
    static let breathingContent = breakString(
        "settings.break_content.breathing",
        default: "Include optional breathing content",
    )
    static let breathingContentDetail = breakString(
        "settings.break_content.breathing_detail",
        default: "Comfortable slower breathing and sensory-reset cards may appear.",
    )
    static let standingDeskMode = breakString(
        "settings.break_content.standing_desk",
        default: "Standing-desk mode",
    )
    static let standingDeskModeDetail = breakString(
        "settings.break_content.standing_desk_detail",
        default: "Standing is one position, not a movement completion. Movement opportunities still appear.",
    )
    static let contentLibrary = breakString(
        "settings.break_content.library.title",
        default: "Content library",
    )
    static let contentLibrarySummary = breakString(
        "settings.break_content.library.summary",
        default: "Browse the 22 current break cards. The library is read-only.",
    )
    static let browseContentLibrary = breakString(
        "settings.break_content.library.browse",
        default: "Browse library",
    )
    static let backToBreakContent = breakString(
        "settings.break_content.library.back",
        default: "Break content",
    )
    static let allContentCards = breakString(
        "settings.break_content.library.all_cards",
        default: "All cards",
    )
    static let selectLibraryCard = breakString(
        "settings.break_content.library.select_card",
        default: "Select a card to read its instructions.",
    )
    static let instructions = breakString("settings.break_content.library.instructions", default: "Instructions")
    static let alternative = breakString("settings.break_content.library.alternative", default: "Alternative")
    static let safety = breakString("settings.break_content.library.safety", default: "Safety")
    static let safetyAndNotes = breakString(
        "settings.break_content.library.safety_notes",
        default: "Safety and notes",
    )
    static let source = breakString("settings.break_content.library.source", default: "Source")
    static let movementSafety = breakString(
        "settings.break_content.library.movement_safety",
        default: "Move comfortably and use support if needed. Stop or choose another option if you feel pain, dizziness, unusual shortness of breath, weakness, or instability.",
    )

    static func contentLibraryCategory(_ category: SettingsContentLibraryCategory) -> String {
        switch category {
        case .visualReset:
            breakString("settings.break_content.library.category.visual", default: "Visual reset")
        case .twoMinuteMovement:
            breakString("settings.break_content.library.category.two_minute", default: "Two-minute movement")
        case .fiveMinuteMovement:
            breakString("settings.break_content.library.category.five_minute", default: "Five-minute movement")
        case .positionChange:
            breakString("settings.break_content.library.category.position", default: "Position change")
        case .optionalCalming:
            breakString("settings.break_content.library.category.calming", default: "Optional calming")
        }
    }

    static func contentLibrarySource(cardID: String) -> String {
        let value = breakString(
            "settings.break_content.library.source_format",
            default: "Research content library · Card %@",
        )
        return String(format: value, locale: .current, cardID)
    }

    static func contentCardString(id: String, field: String, fallback: String) -> String {
        breakString("settings.break_content.library.card.\(id.lowercased()).\(field)", default: fallback)
    }

    private static func breakString(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }
}
