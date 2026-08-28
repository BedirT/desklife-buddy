import DesignSystem
import Domain
import PreferencePresentation
import SwiftUI

struct AccessibilityTimerAnnouncementTiles: View {
    @Binding var selection: TimerAnnouncementPreference
    let increaseContrast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.md) {
                choice(.coarseMilestones, systemImage: "waveform.badge.magnifyingglass")
                choice(.none, systemImage: "speaker.slash")
            }

            Text(selection.detail)
                .font(DSTypography.subtext)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(SettingsAccessibilityL10n.timerAnnouncements)
        .accessibilityIdentifier("settings.accessibility.timerAnnouncements")
    }

    private func choice(_ option: TimerAnnouncementPreference, systemImage: String) -> some View {
        let selected = selection == option
        return Button { selection = option } label: {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: systemImage)
                    .font(DSTypography.headline)
                    .foregroundStyle(selected ? Color.dsAccent : Color.dsTextSecondary)
                    .frame(width: DSSpacing.xl)
                    .accessibilityHidden(true)

                Text(option.title)

                Spacer(minLength: DSSpacing.sm)

                Image(systemName: selected ? "checkmark" : "circle")
                    .font(DSTypography.headline)
                    .foregroundStyle(selected ? Color.dsAccent : Color.dsTextSecondary)
                    .accessibilityHidden(true)
            }
            .font(DSTypography.headline)
            .foregroundStyle(Color.dsTextPrimary)
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                selected ? Color.dsAccent.opacity(0.10) : Color.dsSurface,
                in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous),
            )
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(
                        selected ? Color.dsAccent : Color.dsSeparator,
                        lineWidth: selected || increaseContrast ? 2 : 1,
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityHint(option.detail)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.accessibility.timerAnnouncements.\(option.rawValue)")
    }
}

struct AccessibilityWarmBrightnessWell: View {
    @Binding var value: Double
    let valueText: String
    let increaseContrast: Bool
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        PreferenceBrightnessWell(
            value: $value,
            darkerTitle: SettingsAccessibilityL10n.darker,
            brighterTitle: SettingsAccessibilityL10n.brighter,
            accessibilityLabel: SettingsAccessibilityL10n.backgroundBrightness,
            accessibilityValue: valueText,
            accessibilityIdentifier: "settings.accessibility.brightness",
            increaseContrast: increaseContrast,
            onEditingChanged: onEditingChanged,
        )
    }
}

#Preview("Accessibility timer announcement tiles") {
    AccessibilityTimerAnnouncementTiles(
        selection: .constant(.coarseMilestones),
        increaseContrast: false,
    )
    .padding(DSSpacing.xl)
    .frame(width: 620)
    .background(Color.dsBackground)
}

#Preview("Accessibility warm brightness well") {
    AccessibilityWarmBrightnessWell(
        value: .constant(0.35),
        valueText: SettingsAccessibilityL10n.brightnessValue(35),
        increaseContrast: false,
        onEditingChanged: { _ in },
    )
    .padding(DSSpacing.xl)
    .frame(width: 620)
    .background(Color.dsBackground)
}
