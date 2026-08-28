import DesignSystem
import Domain
import PreferencePresentation
import SwiftUI

struct AccessibilityPresentationButton: View {
    let presentation: AccessibleBreakPresentation
    let selected: Bool
    let increaseContrast: Bool
    let action: () -> Void

    var body: some View {
        PreferencePresentationChoiceButton(
            systemImage: presentation.systemImage,
            title: presentation.title,
            detail: presentation.detail,
            selected: selected,
            increaseContrast: increaseContrast,
            accessibilityIdentifier: "settings.accessibility.presentation.\(presentation.rawValue)",
            action: action,
        )
    }
}

extension AccessibleBreakPresentation {
    var title: String {
        switch self {
        case .standard: SettingsAccessibilityL10n.standard
        case .staticPresentation: SettingsAccessibilityL10n.staticPresentation
        case .textOnly: SettingsAccessibilityL10n.textOnly
        }
    }

    var detail: String {
        switch self {
        case .standard: SettingsAccessibilityL10n.standardDetail
        case .staticPresentation: SettingsAccessibilityL10n.staticPresentationDetail
        case .textOnly: SettingsAccessibilityL10n.textOnlyDetail
        }
    }

    var systemImage: String {
        switch self {
        case .standard: "rectangle.inset.filled"
        case .staticPresentation: "rectangle.dashed"
        case .textOnly: "text.alignleft"
        }
    }
}

extension TimerAnnouncementPreference {
    var title: String {
        switch self {
        case .coarseMilestones: SettingsAccessibilityL10n.coarseMilestones
        case .none: SettingsAccessibilityL10n.noTimerAnnouncements
        }
    }

    var detail: String {
        switch self {
        case .coarseMilestones: SettingsAccessibilityL10n.coarseMilestonesDetail
        case .none: SettingsAccessibilityL10n.noTimerAnnouncementsDetail
        }
    }
}

#Preview("Accessibility presentation choices") {
    HStack(alignment: .top, spacing: DSSpacing.md) {
        ForEach(AccessibleBreakPresentation.allCases, id: \.rawValue) { presentation in
            AccessibilityPresentationButton(
                presentation: presentation,
                selected: presentation == .staticPresentation,
                increaseContrast: false,
                action: {},
            )
            .frame(maxWidth: .infinity)
        }
    }
    .padding(DSSpacing.xl)
    .frame(width: 800, height: 260)
    .background(Color.dsBackground)
}
