import Foundation

public enum SettingsEvidenceTopic: String, CaseIterable, Identifiable, Sendable {
    case visualResets
    case movement
    case standingAndMoving
    case posture
    case blueLight
    case activityEstimation
    case sourceLibrary

    public var id: Self { self }

    var title: String {
        switch self {
        case .visualResets: SettingsEvidenceL10n.visualTitle
        case .movement: SettingsEvidenceL10n.movementTitle
        case .standingAndMoving: SettingsEvidenceL10n.standingTitle
        case .posture: SettingsEvidenceL10n.postureTitle
        case .blueLight: SettingsEvidenceL10n.blueLightTitle
        case .activityEstimation: SettingsEvidenceL10n.estimationTitle
        case .sourceLibrary: SettingsEvidenceL10n.libraryTitle
        }
    }

    var summary: String {
        switch self {
        case .visualResets: SettingsEvidenceL10n.visualSummary
        case .movement: SettingsEvidenceL10n.movementSummary
        case .standingAndMoving: SettingsEvidenceL10n.standingSummary
        case .posture: SettingsEvidenceL10n.postureSummary
        case .blueLight: SettingsEvidenceL10n.blueLightSummary
        case .activityEstimation: SettingsEvidenceL10n.estimationSummary
        case .sourceLibrary: SettingsEvidenceL10n.librarySummary
        }
    }

    var conclusion: String {
        switch self {
        case .visualResets: SettingsEvidenceL10n.visualConclusion
        case .movement: SettingsEvidenceL10n.movementConclusion
        case .standingAndMoving: SettingsEvidenceL10n.standingConclusion
        case .posture: SettingsEvidenceL10n.postureConclusion
        case .blueLight: SettingsEvidenceL10n.blueLightConclusion
        case .activityEstimation: SettingsEvidenceL10n.estimationConclusion
        case .sourceLibrary: SettingsEvidenceL10n.libraryConclusion
        }
    }

    var uncertainty: String {
        switch self {
        case .visualResets: SettingsEvidenceL10n.visualUncertainty
        case .movement: SettingsEvidenceL10n.movementUncertainty
        case .standingAndMoving: SettingsEvidenceL10n.standingUncertainty
        case .posture: SettingsEvidenceL10n.postureUncertainty
        case .blueLight: SettingsEvidenceL10n.blueLightUncertainty
        case .activityEstimation: SettingsEvidenceL10n.estimationUncertainty
        case .sourceLibrary: SettingsEvidenceL10n.libraryUncertainty
        }
    }

    var sources: [String] {
        let sourceText: String = switch self {
        case .visualResets: SettingsEvidenceL10n.visualSources
        case .movement: SettingsEvidenceL10n.movementSources
        case .standingAndMoving: SettingsEvidenceL10n.standingSources
        case .posture: SettingsEvidenceL10n.postureSources
        case .blueLight: SettingsEvidenceL10n.blueLightSources
        case .activityEstimation: SettingsEvidenceL10n.estimationSources
        case .sourceLibrary: SettingsEvidenceL10n.librarySources
        }
        return sourceText.components(separatedBy: "\n")
    }

    var systemImage: String {
        switch self {
        case .visualResets: "eye"
        case .movement: "figure.walk"
        case .standingAndMoving: "arrow.up.and.down"
        case .posture: "chair.lounge"
        case .blueLight: "display"
        case .activityEstimation: "keyboard"
        case .sourceLibrary: "books.vertical"
        }
    }
}
