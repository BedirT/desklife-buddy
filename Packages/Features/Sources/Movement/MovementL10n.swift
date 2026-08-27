import FeatureLocalization
import Foundation

enum MovementL10n {
    static let navigationTitle = FeatureL10n.string(
        "movement.navigation_title",
        default: "Movement",
    )
    static let eyebrow = FeatureL10n.string(
        "movement.eyebrow",
        default: "Movement opportunity",
    )
    static let instruction = FeatureL10n.string(
        "movement.instruction",
        default: "Move in a way that works for you.",
    )
    static let instructionEmphasis = FeatureL10n.string(
        "movement.instruction_emphasis",
        default: "works for you",
    )

    static let walkOrWheelTitle = FeatureL10n.string(
        "movement.choice.walk_or_wheel",
        default: "Walk or wheel",
    )
    static let smallSpaceTitle = FeatureL10n.string(
        "movement.choice.small_space",
        default: "Small space",
    )
    static let seatedTitle = FeatureL10n.string(
        "movement.choice.seated",
        default: "Seated",
    )

    static let walkOrWheelGuidance = FeatureL10n.string(
        "movement.guidance.walk_or_wheel",
        default: "Walk or wheel — away from the desk, at an easy, comfortable pace.",
    )
    static let smallSpaceGuidance = FeatureL10n.string(
        "movement.guidance.small_space",
        default: "Small space — march or step gently in place, or use a seated equivalent.",
    )
    static let seatedGuidance = FeatureL10n.string(
        "movement.guidance.seated",
        default: "Seated — alternate lifting each foot, move the ankles, reach the arms easily.",
    )

    static let twoMinutesInstead = FeatureL10n.string(
        "movement.two_minutes_instead",
        default: "2 minutes instead",
    )
    static let automaticEnding = FeatureL10n.string(
        "movement.automatic_ending",
        default: "Ends on its own.",
    )
    static let doneEarly = FeatureL10n.string(
        "movement.done_early",
        default: "Done early",
    )
    static let alreadyMoved = FeatureL10n.string(
        "movement.already_moved",
        default: "I already moved",
    )
    static let skip = FeatureL10n.string(
        "movement.skip",
        default: "Skip",
    )
    static let positionChange = FeatureL10n.string(
        "movement.position_change",
        default: "Change position instead",
    )
    static let loggedSeparately = FeatureL10n.string(
        "movement.logged_separately",
        default: "logged separately",
    )
    static let positionChangeWithLogging = FeatureL10n.string(
        "movement.position_change_with_logging",
        default: "Change position instead · logged separately",
    )
    static let safety = FeatureL10n.string(
        "movement.safety",
        default: "Move comfortably and use support if needed. Stop or choose another option if you feel pain, dizziness, unusual shortness of breath, weakness, or instability.",
    )

    static let oneKey = FeatureL10n.string("movement.key.one", default: "1")
    static let twoKey = FeatureL10n.string("movement.key.two", default: "2")
    static let threeKey = FeatureL10n.string("movement.key.three", default: "3")
    static let quickKey = FeatureL10n.string("movement.key.quick", default: "Q")
    static let returnKey = FeatureL10n.string("movement.key.return", default: "Return")
    static let alreadyMovedKey = FeatureL10n.string("movement.key.already_moved", default: "A")
    static let positionChangeKey = FeatureL10n.string("movement.key.position_change", default: "P")
    static let escapeKey = FeatureL10n.string("movement.key.escape", default: "esc")
    static let escapeKeyAccessibility = FeatureL10n.string(
        "movement.key.escape_accessibility",
        default: "Escape",
    )

    static let walkOrWheelAccessibility = FeatureL10n.string(
        "movement.accessibility.walk_or_wheel",
        default: "Walk or wheel, 1",
    )
    static let smallSpaceAccessibility = FeatureL10n.string(
        "movement.accessibility.small_space",
        default: "Small space, 2",
    )
    static let seatedAccessibility = FeatureL10n.string(
        "movement.accessibility.seated",
        default: "Seated, 3",
    )
    static let quickAccessibility = FeatureL10n.string(
        "movement.accessibility.two_minutes_instead",
        default: "Two minutes instead, Q",
    )
    static let doneEarlyAccessibility = FeatureL10n.string(
        "movement.accessibility.done_early",
        default: "Done early, Return",
    )
    static let alreadyMovedAccessibility = FeatureL10n.string(
        "movement.accessibility.already_moved",
        default: "I already moved, A",
    )
    static let skipAccessibility = FeatureL10n.string(
        "movement.accessibility.skip",
        default: "Skip, Escape",
    )
    static let positionChangeAccessibility = FeatureL10n.string(
        "movement.accessibility.position_change",
        default: "Change position instead, P — logged separately",
    )

    static let previewError = FeatureL10n.string(
        "movement.preview_error",
        default: "Couldn't load movement.",
    )

    static func choiceTitle(_ choice: MovementChoice) -> String {
        switch choice {
        case .walkOrWheel: walkOrWheelTitle
        case .smallSpace: smallSpaceTitle
        case .seated: seatedTitle
        }
    }

    static func guidance(_ guidance: MovementGuidance) -> String {
        switch guidance {
        case .walkOrWheel: walkOrWheelGuidance
        case .smallSpace: smallSpaceGuidance
        case .seated: seatedGuidance
        }
    }

    static func choiceAccessibility(_ choice: MovementChoice) -> String {
        switch choice {
        case .walkOrWheel: walkOrWheelAccessibility
        case .smallSpace: smallSpaceAccessibility
        case .seated: seatedAccessibility
        }
    }

    static func openedAnnouncement(_ seconds: Int) -> String {
        switch seconds {
        case 300:
            FeatureL10n.string(
                "movement.announcement.opened_five_minutes",
                default: "Movement opportunity. Move in a way that works for you. Five minutes.",
            )
        case 120:
            FeatureL10n.string(
                "movement.announcement.opened_two_minutes",
                default: "Movement opportunity. Move in a way that works for you. Two minutes.",
            )
        default:
            String(
                format: FeatureL10n.string(
                    "movement.announcement.opened_seconds",
                    default: "Movement opportunity. Move in a way that works for you. %d seconds.",
                ),
                locale: .current,
                seconds,
            )
        }
    }

    static func selectionAnnouncement(_ choice: MovementChoice) -> String {
        let format = FeatureL10n.string(
            "movement.announcement.selection",
            default: "%1$@. %2$@",
        )
        return String(
            format: format,
            locale: .current,
            choiceTitle(choice),
            guidance(MovementGuidance(choice: choice)),
        )
    }

    static let oneMinuteAnnouncement = FeatureL10n.string(
        "movement.announcement.one_minute",
        default: "One minute remaining.",
    )
    static let finishedAnnouncement = FeatureL10n.string(
        "movement.announcement.finished",
        default: "Finished.",
    )
    static let doneEarlyAnnouncement = FeatureL10n.string(
        "movement.announcement.done_early",
        default: "Done early.",
    )
    static let alreadyMovedAnnouncement = FeatureL10n.string(
        "movement.announcement.already_moved",
        default: "I already moved.",
    )
    static let positionChangedAnnouncement = FeatureL10n.string(
        "movement.announcement.position_changed",
        default: "Change position instead. Logged separately.",
    )
    static let skippedAnnouncement = FeatureL10n.string(
        "movement.announcement.skipped",
        default: "Skipped.",
    )
}

public extension MovementAnnouncement {
    var localizedText: String {
        switch self {
        case let .opened(durationSeconds): MovementL10n.openedAnnouncement(durationSeconds)
        case let .selectionChanged(choice): MovementL10n.selectionAnnouncement(choice)
        case .oneMinuteRemaining: MovementL10n.oneMinuteAnnouncement
        case .finished: MovementL10n.finishedAnnouncement
        case .doneEarly: MovementL10n.doneEarlyAnnouncement
        case .alreadyMoved: MovementL10n.alreadyMovedAnnouncement
        case .positionChanged: MovementL10n.positionChangedAnnouncement
        case .skipped: MovementL10n.skippedAnnouncement
        }
    }
}
