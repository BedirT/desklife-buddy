import FeatureLocalization

enum VisualResetL10n {
    static let eyebrow = FeatureL10n.string("visualReset.eyebrow", default: "Visual reset")
    static let instruction = FeatureL10n.string(
        "visualReset.instruction",
        default: "Look at something comfortably far away.",
    )
    static let instructionEmphasis = FeatureL10n.string(
        "visualReset.instruction_emphasis",
        default: "comfortably",
    )
    static let guidance = FeatureL10n.string(
        "visualReset.guidance",
        default: "Let the small details come into view without forcing focus. Blink slowly two or three times.",
    )
    static let guidanceLead = FeatureL10n.string(
        "visualReset.guidance_lead",
        default: "Let the small details come into view without forcing focus.",
    )
    static let blinkPrompt = FeatureL10n.string(
        "visualReset.blink_prompt",
        default: "Blink slowly two or three times.",
    )
    static let automaticEnding = FeatureL10n.string(
        "visualReset.automatic_ending",
        default: "Ends on its own.",
    )
    static let doneEarly = FeatureL10n.string("visualReset.done_early", default: "Done early")
    static let skip = FeatureL10n.string("visualReset.skip", default: "Skip")
    static let skipAccessibility = FeatureL10n.string(
        "visualReset.skip_accessibility",
        default: "Skip this reset",
    )
    static let alternative = FeatureL10n.string(
        "visualReset.alternative",
        default: "If looking far away isn't practical, closing your eyes gently works too.",
    )
    static let returnKey = FeatureL10n.string("visualReset.return_key", default: "Return")
    static let escapeKey = FeatureL10n.string("visualReset.escape_key", default: "esc")
    static let escapeKeyAccessibility = FeatureL10n.string(
        "visualReset.escape_key_accessibility",
        default: "Escape",
    )

    static func openedAnnouncement(_ seconds: Int) -> String {
        if seconds == 20 {
            return FeatureL10n.string(
                "visualReset.announcement.opened_twenty",
                default: "Visual reset. Look at something comfortably far away. Twenty seconds.",
            )
        }
        let format = FeatureL10n.string(
            "visualReset.announcement.opened",
            default: "Visual reset. Look at something comfortably far away. %d seconds.",
        )
        return String(format: format, locale: .current, seconds)
    }

    static let tenSecondsAnnouncement = FeatureL10n.string(
        "visualReset.announcement.ten_seconds",
        default: "10 seconds remaining.",
    )
    static let finishedAnnouncement = FeatureL10n.string(
        "visualReset.announcement.finished",
        default: "Finished.",
    )
    static let doneEarlyAnnouncement = FeatureL10n.string(
        "visualReset.announcement.done_early",
        default: "Done early.",
    )
    static let skippedAnnouncement = FeatureL10n.string(
        "visualReset.announcement.skipped",
        default: "Skipped.",
    )
}

public extension VisualResetAnnouncement {
    var localizedText: String {
        switch self {
        case let .opened(durationSeconds): VisualResetL10n.openedAnnouncement(durationSeconds)
        case .tenSecondsRemaining: VisualResetL10n.tenSecondsAnnouncement
        case .finished: VisualResetL10n.finishedAnnouncement
        case .doneEarly: VisualResetL10n.doneEarlyAnnouncement
        case .skipped: VisualResetL10n.skippedAnnouncement
        }
    }
}
