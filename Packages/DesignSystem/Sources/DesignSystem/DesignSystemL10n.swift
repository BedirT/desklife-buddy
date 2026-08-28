import Foundation

enum DesignSystemL10n {
    static func string(_ key: String, default defaultValue: String) -> String {
        Bundle.module.localizedString(forKey: key, value: defaultValue, table: "Localizable")
    }

    static let galleryTitle = string("gallery.title", default: "Design System")

    static func spacingPoints(_ value: Int) -> String {
        String(format: string("spacing.points_format", default: "%dpt"), locale: .current, value)
    }

    enum Buttons {
        static let continueTitle = string("buttons.continue", default: "Continue")
        static let addItem = string("buttons.add_item", default: "Add item")
        static let delete = string("buttons.delete", default: "Delete")
        static let primary = string("buttons.primary", default: "Primary")
        static let secondary = string("buttons.secondary", default: "Secondary")
        static let destructive = string("buttons.destructive", default: "Destructive")
    }

    enum Tags {
        static let neutral = string("tags.neutral", default: "Neutral")
        static let new = string("tags.new", default: "New")
        static let done = string("tags.done", default: "Done")
        static let warning = string("tags.warning", default: "Warning")
        static let expiring = string("tags.expiring", default: "Expiring")
        static let failed = string("tags.failed", default: "Failed")
    }

    enum Card {
        static let previewTitle = string("card.preview_title", default: "Card title")
        static let previewText = string(
            "card.preview_text",
            default: "Supporting text that wraps onto multiple lines when needed.",
        )
        static let galleryText = string(
            "card.gallery_text",
            default: "Cards are flat surfaces; contrast does the separating.",
        )
    }

    enum EmptyState {
        static let previewTitle = string("empty_state.preview_title", default: "Nothing here yet")
        static let previewMessage = string(
            "empty_state.preview_message",
            default: "Items you add will show up in this list.",
        )
        static let previewAction = string("empty_state.preview_action", default: "Add your first item")
    }

    enum BreakField {
        static let doneEarly = string("break_field.done_early", default: "Done early")
        static let skip = string("break_field.skip", default: "Skip")
        static let walkOrWheel = string("break_field.walk_or_wheel", default: "Walk or wheel")
        static let walkOrWheelAccessibility = string(
            "break_field.walk_or_wheel_accessibility",
            default: "Walk or wheel, 1",
        )
        static let smallSpace = string("break_field.small_space", default: "Small space")
        static let smallSpaceAccessibility = string(
            "break_field.small_space_accessibility",
            default: "Small space, 2",
        )
        static let seated = string("break_field.seated", default: "Seated")
        static let seatedAccessibility = string("break_field.seated_accessibility", default: "Seated, 3")
        static let changePosition = string("break_field.change_position", default: "Change position instead")
        static let loggedSeparately = string("break_field.logged_separately", default: "· logged separately")
        static let changePositionAccessibility = string(
            "break_field.change_position_accessibility",
            default: "Change position instead, P. Logged separately",
        )
    }

    enum HeadsUp {
        static let visualReset = string("heads_up.visual_reset", default: "Visual reset")
        static let time45 = string("heads_up.time_45", default: "· in 45 s")
        static let time30 = string("heads_up.time_30", default: "· in 30 s")
        static let time15 = string("heads_up.time_15", default: "· in 15 s")
        static let time5 = string("heads_up.time_5", default: "· in 5 s")
        static let now = string("heads_up.now", default: "Now")
        static let later = string("heads_up.later", default: "Later")
        static let fiveMinutes = string("heads_up.five_minutes", default: "5 minutes")
        static let tenMinutes = string("heads_up.ten_minutes", default: "10 minutes")
        static let fifteenMinutes = string("heads_up.fifteen_minutes", default: "15 minutes")
        static let onHold = string("heads_up.on_hold", default: "On hold")
        static let busyUntil = string("heads_up.busy_until", default: "· busy until 3:00")
        static let paused = string("heads_up.paused", default: "· paused until you resume")
        static let accessibility45 = string(
            "heads_up.accessibility_45",
            default: "Visual reset in 45 seconds",
        )
        static let accessibility30 = string(
            "heads_up.accessibility_30",
            default: "Visual reset in 30 seconds",
        )
        static let accessibility15 = string(
            "heads_up.accessibility_15",
            default: "Visual reset in 15 seconds",
        )
        static let accessibility5 = string(
            "heads_up.accessibility_5",
            default: "Visual reset in 5 seconds",
        )
        static let accessibilityHold = string(
            "heads_up.accessibility_hold",
            default: "On hold: busy until 3:00",
        )
        static let accessibilityPaused = string(
            "heads_up.accessibility_paused",
            default: "On hold: paused until you resume",
        )
        static let accessibilityStartNow = string(
            "heads_up.accessibility_start_now",
            default: "Start now",
        )
        static let accessibilityLater = string("heads_up.accessibility_later", default: "Later")

        static let laterOptions = [fiveMinutes, tenMinutes, fifteenMinutes]
    }

    enum Typography {
        static let largeTitle = string("typography.large_title", default: "Large Title")
        static let title = string("typography.title", default: "Title")
        static let headline = string("typography.headline", default: "Headline")
        static let body = string("typography.body", default: "Body")
        static let subtext = string("typography.subtext", default: "Subtext")
        static let caption = string("typography.caption", default: "Caption")
        static let breakLongInstruction = string(
            "typography.break_long_instruction",
            default: "Long instruction",
        )
        static let breakChoice = string("typography.break_choice", default: "Break choice")
        static let breakSafety = string("typography.break_safety", default: "Break safety")
        static let headsUpText = string("typography.heads_up_text", default: "Heads-up text")
        static let headsUpAction = string("typography.heads_up_action", default: "Heads-up action")
    }

    enum Sections {
        static let protocolMark = string("sections.protocol_mark", default: "Protocol mark")
        static let colors = string("sections.colors", default: "Colors")
        static let typography = string("sections.typography", default: "Typography")
        static let spacing = string("sections.spacing", default: "Spacing")
        static let motion = string("sections.motion", default: "Motion")
        static let buttons = string("sections.buttons", default: "Buttons")
        static let tags = string("sections.tags", default: "Tags")
        static let card = string("sections.card", default: "Card")
        static let emptyState = string("sections.empty_state", default: "Empty state")
        static let breakControls = string("sections.break_controls", default: "Break controls")
        static let movementChoices = string("sections.movement_choices", default: "Movement choices")
        static let headsUpCapsules = string("sections.heads_up_capsules", default: "Heads-up capsules")
    }
}
