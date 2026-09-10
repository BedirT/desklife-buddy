import DesignSystem
import PreferencePresentation
import SwiftUI

struct PrimaryProfileChoices: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool

    var body: some View {
        Group {
            if textScale == .largest {
                VStack(spacing: DSSpacing.md) { choices(horizontalLayout: true) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: DSSpacing.md) {
                        choices(horizontalLayout: false, fillsHeight: true)
                    }
                    .frame(minWidth: DSSpacing.xxl * 18)
                    .frame(height: DSSpacing.xxl * 5)

                    VStack(spacing: DSSpacing.md) {
                        choices(horizontalLayout: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func choices(horizontalLayout: Bool, fillsHeight: Bool = false) -> some View {
        ProfileChoiceButton(
            profile: .gentle,
            title: SettingsFeatureL10n.gentle,
            model: model,
            increaseContrast: increaseContrast,
            horizontalLayout: horizontalLayout,
            fillsHeight: fillsHeight,
        )
        ProfileChoiceButton(
            profile: .balanced,
            title: SettingsFeatureL10n.balanced,
            model: model,
            increaseContrast: increaseContrast,
            horizontalLayout: horizontalLayout,
            fillsHeight: fillsHeight,
        )
        ProfileChoiceButton(
            profile: .frequentMovement,
            title: SettingsFeatureL10n.frequentMovement,
            model: model,
            increaseContrast: increaseContrast,
            horizontalLayout: horizontalLayout,
            fillsHeight: fillsHeight,
        )
    }
}

private struct ProfileChoiceButton: View {
    let profile: SettingsScheduleChoice
    let title: String
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool
    let horizontalLayout: Bool
    let fillsHeight: Bool

    private var selected: Bool { model.selectedScheduleChoice == profile }

    var body: some View {
        PreferenceRhythmProfileButton(
            stage: profile.preferenceStage,
            title: title,
            subtitle: subtitle,
            accessibilityLabel: accessibilityLabel,
            selected: selected,
            increaseContrast: increaseContrast,
            accessibilityIdentifier: "settings.schedule.profile.\(profile.rawValue)",
            horizontalLayout: horizontalLayout,
            compactVerticalLayout: !horizontalLayout,
            castsSelectionShadow: false,
        ) {
            Task { await model.selectProfile(profile) }
        }
        .frame(maxHeight: fillsHeight ? .infinity : nil)
    }

    private var subtitle: String? {
        profileSubtitle(profile, model: model)
    }

    private var accessibilityLabel: String {
        profileAccessibilityLabel(profile, title: title, model: model)
    }
}

struct AdvancedProfileChoiceButton: View {
    let profile: SettingsScheduleChoice
    let title: String
    @Bindable var model: SettingsFeatureModel

    private var selected: Bool { model.selectedScheduleChoice == profile }

    var body: some View {
        Button {
            Task { await model.selectProfile(profile) }
        } label: {
            HStack(spacing: DSSpacing.sm) {
                PreferenceRhythmStageView(stage: profile.preferenceStage)
                    .frame(width: DSSpacing.xxl * 2, height: DSSpacing.xxl + DSSpacing.sm)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(title)
                        .foregroundStyle(Color.dsTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(DSTypography.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
                Spacer(minLength: DSSpacing.sm)
                DSSelectionIndicator(selected: selected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.schedule.profile.\(profile.rawValue)")
    }

    private var subtitle: String? {
        profileSubtitle(profile, model: model)
    }

    private var accessibilityLabel: String {
        profileAccessibilityLabel(profile, title: title, model: model)
    }
}

private extension SettingsScheduleChoice {
    var preferenceStage: PreferenceRhythmStage {
        switch self {
        case .gentle:
            .gentle
        case .balanced:
            .balanced
        case .frequentMovement, .researchInformedHighFrequency, .custom:
            .frequentMovement
        }
    }
}

private func profileSubtitle(
    _ profile: SettingsScheduleChoice,
    model: SettingsFeatureModel,
) -> String? {
    guard let configuration = model.configuration(for: profile) else { return nil }
    return SettingsFeatureL10n.profileSubtitle(
        visualMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.visual.targetSeconds)),
        movementMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.movement.targetSeconds)),
    )
}

private func profileAccessibilityLabel(
    _ profile: SettingsScheduleChoice,
    title: String,
    model: SettingsFeatureModel,
) -> String {
    guard let configuration = model.configuration(for: profile) else { return title }
    return SettingsFeatureL10n.profileAccessibilityLabel(
        name: title,
        visualMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.visual.targetSeconds)),
        movementMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.movement.targetSeconds)),
    )
}

#Preview("Schedule profile choices") {
    PrimaryProfileChoices(
        model: .preview(.balanced),
        increaseContrast: false,
    )
    .padding(DSSpacing.lg)
    .frame(width: 780)
    .background(Color.dsBackground)
}
