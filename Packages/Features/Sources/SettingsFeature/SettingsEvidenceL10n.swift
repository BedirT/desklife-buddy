import FeatureLocalization
import Foundation

enum SettingsEvidenceL10n {
    static let overview = string("settings.evidence.overview", default: "What shaped the defaults")
    static let overviewDetail = string(
        "settings.evidence.overview_detail",
        default: "The app supports general wellness and healthier work-break routines. The evidence supports useful ranges and honest uncertainty, not one universal schedule.",
    )
    static let conclusion = string("settings.evidence.conclusion", default: "What we use")
    static let uncertainty = string("settings.evidence.uncertainty", default: "What remains uncertain")
    static let sources = string("settings.evidence.sources", default: "Sources")
    static let backToTopics = string("settings.evidence.back", default: "All topics")

    static let visualTitle = string("settings.evidence.visual.title", default: "Visual resets")
    static let visualSummary = string(
        "settings.evidence.visual.summary",
        default: "A useful range, not a magic timer.",
    )
    static let visualConclusion = string(
        "settings.evidence.visual.conclusion",
        default: "The default offers short visual resets within a 20–30 minute window of estimated active computer use.",
    )
    static let visualUncertainty = string(
        "settings.evidence.visual.uncertainty",
        default: "The evidence supports a window, not an exact number. The 20-20-20 rule is memorable, but it is not a uniquely proven optimum.",
    )
    static let visualSources = string(
        "settings.evidence.visual.sources",
        default: "Visual-break evidence · S012–S017",
    )

    static let movementTitle = string("settings.evidence.movement.title", default: "Movement")
    static let movementSummary = string(
        "settings.evidence.movement.summary",
        default: "Easy movement, with more than one valid duration.",
    )
    static let movementConclusion = string(
        "settings.evidence.movement.conclusion",
        default: "The Balanced schedule offers about five minutes of easy movement around each hour, with a useful two-minute quick option.",
    )
    static let movementUncertainty = string(
        "settings.evidence.movement.uncertainty",
        default: "No single movement schedule is universally best. The more frequent schedule is an explicit higher-burden choice, not a superior outcome claim.",
    )
    static let movementSources = string(
        "settings.evidence.movement.sources",
        default: "Movement-break evidence · S001–S010",
    )

    static let standingTitle = string(
        "settings.evidence.standing.title",
        default: "Standing and moving are different",
    )
    static let standingSummary = string(
        "settings.evidence.standing.summary",
        default: "Position change is useful context, not movement completion.",
    )
    static let standingConclusion = string(
        "settings.evidence.standing.conclusion",
        default: "Changing position can add variety. It is logged separately and never completes a movement opportunity.",
    )
    static let standingUncertainty = string(
        "settings.evidence.standing.uncertainty",
        default: "Standing reduces sitting time, but evidence for broader outcomes from standing alone remains uncertain.",
    )
    static let standingSources = string(
        "settings.evidence.standing.sources",
        default: "Standing and movement evidence · S011, S034",
    )

    static let postureTitle = string("settings.evidence.posture.title", default: "Why there is no posture score")
    static let postureSummary = string(
        "settings.evidence.posture.summary",
        default: "Comfort, fit, and variation instead of policing.",
    )
    static let postureConclusion = string(
        "settings.evidence.posture.conclusion",
        default: "The app favors comfortable setup and position variation. It does not rate posture or enforce one ideal position.",
    )
    static let postureUncertainty = string(
        "settings.evidence.posture.uncertainty",
        default: "There is no universal correct posture, and intervention evidence is mixed.",
    )
    static let postureSources = string(
        "settings.evidence.posture.sources",
        default: "Posture and workstation evidence · S023–S032",
    )

    static let blueLightTitle = string(
        "settings.evidence.blue_light.title",
        default: "Why there is no blue-light framing",
    )
    static let blueLightSummary = string(
        "settings.evidence.blue_light.summary",
        default: "Display comfort without damage or protection claims.",
    )
    static let blueLightConclusion = string(
        "settings.evidence.blue_light.conclusion",
        default: "The app focuses on breaks, readability, glare, and comfort. It does not claim that ordinary consumer-screen blue light damages your eyes.",
    )
    static let blueLightUncertainty = string(
        "settings.evidence.blue_light.uncertainty",
        default: "Display color and evening light can affect comfort or timing, but that is different from a retinal-damage claim.",
    )
    static let blueLightSources = string(
        "settings.evidence.blue_light.sources",
        default: "Blue-light evidence · S018–S022",
    )

    static let estimationTitle = string(
        "settings.evidence.estimation.title",
        default: "What activity estimation can know",
    )
    static let estimationSummary = string(
        "settings.evidence.estimation.summary",
        default: "Recent computer interaction, not the body.",
    )
    static let estimationConclusion = string(
        "settings.evidence.estimation.conclusion",
        default: "Timing is based on estimated active computer use: key and pointer input only.",
    )
    static let estimationUncertainty = string(
        "settings.evidence.estimation.uncertainty",
        default: "It cannot tell whether you are sitting, standing, moving, or looking at the screen. Time away from the keyboard is not proof that you moved.",
    )
    static let estimationSources = string(
        "settings.evidence.estimation.sources",
        default: "Activity-estimation limits · C013, C033, C034",
    )

    static let libraryTitle = string("settings.evidence.library.title", default: "Source library")
    static let librarySummary = string(
        "settings.evidence.library.summary",
        default: "How evidence, claims, and product decisions are separated.",
    )
    static let libraryConclusion = string(
        "settings.evidence.library.conclusion",
        default: "The source library keeps evidence references, allowed claims, and product decisions traceable by identifier.",
    )
    static let libraryUncertainty = string(
        "settings.evidence.library.uncertainty",
        default: "A source library makes decisions inspectable. It does not remove uncertainty or establish a universal schedule.",
    )
    static let librarySources = string(
        "settings.evidence.library.sources",
        default: "Evidence review · S001–S080\nClaims register · C001–C050\nProduct health protocol · sections 4–12",
    )

    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }
}
