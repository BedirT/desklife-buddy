import FeatureLocalization
import Foundation

enum OnboardingL10n {
    static let back = string("onboarding.action.back", default: "Back")
    static let continueTitle = string("onboarding.action.continue", default: "Continue")
    static let finish = string("onboarding.action.finish", default: "Finish")
    static let retry = string("onboarding.action.retry", default: "Try again")
    static let retryActivation = string(
        "onboarding.action.retry_activation",
        default: "Try starting again",
    )
    static let skip = string("onboarding.action.skip", default: "Skip setup")

    static let promiseTitle = string(
        "onboarding.promise.title",
        default: "A private way to remember breaks",
    )
    static let promiseDetail = string(
        "onboarding.promise.detail",
        default: "A private, research-informed way to remember visual and movement breaks without fighting your workflow.",
    )
    static let generalWellness = string(
        "onboarding.promise.wellness",
        default: "Supports general wellness and healthier work-break routines.",
    )
    static let invitations = string(
        "onboarding.promise.invitations",
        default: "Breaks are invitations. Nothing is blocked, and you can leave at any time.",
    )
    static let noAccount = string("onboarding.promise.no_account", default: "Works without an account")

    static let honestyTitle = string(
        "onboarding.honesty.title",
        default: "What this can and cannot know",
    )
    static let estimatedUse = string(
        "onboarding.honesty.estimated_use",
        default: "It estimates active computer use from keyboard and pointer activity.",
    )
    static let cannotKnow = string(
        "onboarding.honesty.cannot_know",
        default: "It cannot tell whether you are sitting, standing, or looking at the screen.",
    )
    static let idleIsNotMovement = string(
        "onboarding.honesty.idle_is_not_movement",
        default: "Time away from the keyboard is not proof that you moved.",
    )
    static let passiveReading = string(
        "onboarding.honesty.passive_reading",
        default: "Passive reading or watching may not register as active computer use.",
    )

    static let rhythmTitle = string("onboarding.rhythm.title", default: "Choose a rhythm")
    static let rhythmDetail = string(
        "onboarding.rhythm.detail",
        default: "Choose a starting schedule. You can change it any time in Settings.",
    )
    static let gentle = string("settings.profile.gentle", default: "Gentle")
    static let balanced = string("settings.profile.balanced", default: "Balanced")
    static let frequentMovement = string("settings.profile.frequent", default: "Frequent movement")

    static let movementTitle = string("onboarding.movement.title", default: "How you move")
    static let movementDetail = string(
        "settings.break_content.preferred_movement_explanation",
        default: "Each path has equal status. You can choose a different one during any movement opportunity.",
    )

    static let comfortTitle = string("onboarding.comfort.title", default: "Make breaks comfortable")
    static let comfortDetail = string(
        "onboarding.comfort.detail",
        default: "These choices change the app only. They do not change macOS settings.",
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
    static let systemDisplayChoices = string(
        "onboarding.comfort.system_choices",
        default: "Current macOS display choices",
    )
    static let systemDisplayDetail = string(
        "onboarding.comfort.system_detail",
        default: "Reduce Motion, Reduce Transparency, and Increase Contrast are read here only and remain controlled by macOS.",
    )
    static let reduceMotion = string("onboarding.comfort.reduce_motion", default: "Reduce Motion")
    static let reduceTransparency = string(
        "onboarding.comfort.reduce_transparency",
        default: "Reduce Transparency",
    )
    static let increaseContrast = string(
        "onboarding.comfort.increase_contrast",
        default: "Increase Contrast",
    )
    static let on = string("onboarding.system.on", default: "On")
    static let off = string("onboarding.system.off", default: "Off")
    static let reduceMotionStartingPoint = string(
        "onboarding.comfort.reduce_motion_start",
        default: "Static is the starting presentation because Reduce Motion is on. You can still choose Standard here without changing macOS.",
    )

    static let readyTitle = string("onboarding.ready.title", default: "Ready when you are")
    static let readyDetail = string(
        "onboarding.ready.detail",
        default: "Your choices are ready to save. Nothing has requested a permission.",
    )
    static let readyIntegrations = string(
        "onboarding.ready.integrations",
        default: "Notifications and launch at login are available later in Settings. Nothing is requested here.",
    )
    static let rhythmSummary = string("onboarding.ready.rhythm", default: "Rhythm")
    static let movementSummary = string("onboarding.ready.movement", default: "Movement")
    static let presentationSummary = string("onboarding.ready.presentation", default: "Presentation")

    static let completedTitle = string("onboarding.completed.title", default: "Working now")
    static let completedDetail = string(
        "onboarding.completed.detail",
        default: "Your choices are saved. You can change them later in Settings.",
    )
    static let skippedTitle = string(
        "onboarding.skipped.title",
        default: "Ready with Balanced defaults",
    )
    static let skippedDetail = string(
        "onboarding.skipped.detail",
        default: "Balanced is selected. Every setup choice remains available later in Settings.",
    )
    static let skippedPermissions = string(
        "onboarding.skipped.permissions",
        default: "No permissions were requested, and there is no reminder to finish setup.",
    )
    static let completionFailure = string(
        "onboarding.failure.completion",
        default: "Your choices weren't saved. Nothing changed.",
    )
    static let skipFailure = string(
        "onboarding.failure.skip",
        default: "The default setup wasn't saved. Nothing changed.",
    )
    static let completionActivationFailure = string(
        "onboarding.failure.activation.completion",
        default: "Your choices are saved, but the app didn't finish starting.",
    )
    static let skipActivationFailure = string(
        "onboarding.failure.activation.skip",
        default: "Balanced defaults are saved, but the app didn't finish starting.",
    )
    static let savingChoices = string("onboarding.submitting.completion", default: "Saving choices…")
    static let savingDefaults = string("onboarding.submitting.skip", default: "Applying defaults…")
    static let activatingChoices = string(
        "onboarding.activating.completion",
        default: "Choices saved. Starting…",
    )
    static let activatingDefaults = string(
        "onboarding.activating.skip",
        default: "Defaults saved. Starting…",
    )

    static func progress(current: Int, total: Int) -> String {
        format("onboarding.progress", default: "Step %d of %d", current, total)
    }

    static func rhythmTitle(_ rhythm: OnboardingRhythm) -> String {
        switch rhythm {
        case .gentle: gentle
        case .balanced: balanced
        case .frequentMovement: frequentMovement
        }
    }

    static func rhythmDetail(
        _ rhythm: OnboardingRhythm,
        timing: OnboardingRhythmTiming,
    ) -> String {
        let values = minuteStrings(timing)
        return String(
            format: string(
                "settings.profile.subtitle_format",
                default: "about %@ min · about %@ min",
            ),
            locale: .current,
            values.0,
            values.1,
        )
    }

    static func rhythmAccessibilityLabel(
        _ rhythm: OnboardingRhythm,
        timing: OnboardingRhythmTiming,
    ) -> String {
        let values = minuteStrings(timing)
        return String(
            format: string(
                "settings.profile.accessibility_format",
                default: "%@, about %@ minutes visual, about %@ minutes movement",
            ),
            locale: .current,
            rhythmTitle(rhythm),
            values.0,
            values.1,
        )
    }

    private static func minuteStrings(_ timing: OnboardingRhythmTiming) -> (String, String) {
        (
            displayMinutes(timing.visualTargetSeconds),
            displayMinutes(timing.movementTargetSeconds),
        )
    }

    private static func displayMinutes(_ seconds: TimeInterval) -> String {
        (seconds / 60).formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0 ... 2)),
        )
    }

    static func movementTitle(_ movement: OnboardingMovement) -> String {
        switch movement {
        case .walkOrEquivalent:
            string("settings.break_content.movement.walk_or_wheel", default: "Walk or wheel")
        case .seatedActive:
            string("settings.break_content.movement.seated", default: "Seated movement")
        case .mixed:
            string("settings.break_content.movement.mixed", default: "Mix movement paths")
        case .positionChangeOnly:
            string("settings.break_content.movement.position", default: "Change position")
        }
    }

    static func movementDetail(_ movement: OnboardingMovement) -> String {
        switch movement {
        case .walkOrEquivalent:
            string(
                "settings.break_content.movement.walk_or_wheel_detail",
                default: "Easy movement away from the desk, including an equivalent active movement.",
            )
        case .seatedActive:
            string(
                "settings.break_content.movement.seated_detail",
                default: "Active seated movement appears first.",
            )
        case .mixed:
            string(
                "settings.break_content.movement.mixed_detail",
                default: "Walk or wheel, small-space, and seated cards can appear.",
            )
        case .positionChangeOnly:
            string(
                "settings.break_content.movement.position_detail",
                default: "Logged on its own. It doesn't complete this movement opportunity.",
            )
        }
    }

    static func presentationTitle(_ presentation: OnboardingPresentation) -> String {
        switch presentation {
        case .standard: standard
        case .staticPresentation: staticPresentation
        }
    }

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
