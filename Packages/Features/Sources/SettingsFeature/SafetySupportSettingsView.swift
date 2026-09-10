import DesignSystem
import SwiftUI

struct SafetySupportSettingsView: View {
    @Environment(\.dsTextScale) private var textScale
    let increaseContrast: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                Text(SettingsSafetyL10n.introduction)
                    .font(textScale == .largest ? DSTypography.title : DSTypography.body)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                safetyTier(
                    title: SettingsSafetyL10n.routine,
                    detail: SettingsSafetyL10n.routineDetail,
                    systemImage: "checkmark.circle",
                    accent: .dsTextSecondary,
                )

                safetyTier(
                    title: SettingsSafetyL10n.persistent,
                    detail: SettingsSafetyL10n.persistentDetail,
                    systemImage: "person.crop.circle.badge.questionmark",
                    accent: .dsWarning,
                )

                safetyTier(
                    title: SettingsSafetyL10n.urgent,
                    detail: SettingsSafetyL10n.urgentDetail,
                    systemImage: "exclamationmark.triangle",
                    accent: .dsDanger,
                    urgent: true,
                )
            }
            .padding(.vertical, contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("settings.safety")
    }

    private func safetyTier(
        title: String,
        detail: String,
        systemImage: String,
        accent: Color,
        urgent: Bool = false,
    ) -> some View {
        DSCard {
            HStack(alignment: .top, spacing: DSSpacing.md) {
                Image(systemName: systemImage)
                    .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                    .foregroundStyle(accent)
                    .frame(width: SettingsPageLayout.rowIconWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text(title)
                        .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                        .foregroundStyle(urgent ? Color.dsDanger : Color.dsTextPrimary)
                    Text(detail)
                        .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                        .foregroundStyle(Color.dsTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(
                    urgent ? Color.dsDanger : Color.dsSeparator,
                    lineWidth: urgent || increaseContrast ? 2 : 1,
                )
        }
        .accessibilityElement(children: .combine)
    }

    private var contentPadding: CGFloat { SettingsPageLayout.contentInset(for: textScale) }
    private var sectionSpacing: CGFloat { SettingsPageLayout.sectionGap(for: textScale) }
}

#Preview("Safety & support") {
    SafetySupportSettingsView(increaseContrast: false)
        .frame(width: 700, height: 620)
}

#Preview("Safety & support — Increase Contrast") {
    SafetySupportSettingsView(increaseContrast: true)
        .frame(width: 700, height: 620)
}
