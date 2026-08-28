import DesignSystem
import Domain
import SwiftUI

struct AccessibilitySettingsView: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool
    @State private var brightnessDraft: Double?

    var body: some View {
        VStack(spacing: 0) {
            if model.operationState != .idle {
                AccessibilitySettingsOperationFeedback(model: model)
                    .padding(.bottom, DSSpacing.md)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    presentationSection
                    timerSection
                    movementOrderSection
                    systemAndKeyboardSection
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .allowsHitTesting(model.controlsEnabled)
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .background(Color.dsBackground)
        .accessibilityIdentifier("settings.accessibility")
    }

    private var presentationSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            sectionHeading(
                SettingsAccessibilityL10n.breakPresentation,
                detail: SettingsAccessibilityL10n.breakPresentationDetail,
            )

            Group {
                if textScale == .largest {
                    VStack(spacing: DSSpacing.md) { presentationChoices }
                } else {
                    HStack(alignment: .top, spacing: DSSpacing.md) { presentationChoices }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(SettingsAccessibilityL10n.breakPresentation)

            if accessibilityPreferences.presentation == .staticPresentation {
                brightnessCard
            }
        }
    }

    @ViewBuilder
    private var presentationChoices: some View {
        ForEach(AccessibleBreakPresentation.allCases, id: \.rawValue) { presentation in
            AccessibilityPresentationButton(
                presentation: presentation,
                selected: accessibilityPreferences.presentation == presentation,
                increaseContrast: increaseContrast,
            ) {
                Task { await model.setAccessibleBreakPresentation(presentation) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var brightnessCard: some View {
        outlinedCard {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.md) {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        Text(SettingsAccessibilityL10n.backgroundBrightness)
                            .foregroundStyle(Color.dsTextPrimary)
                        Text(SettingsAccessibilityL10n.backgroundBrightnessDetail)
                            .font(secondaryFont)
                            .foregroundStyle(Color.dsTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DSSpacing.md)
                    Text(brightnessValue)
                        .font(secondaryFont.monospacedDigit())
                        .foregroundStyle(Color.dsTextSecondary)
                }

                AccessibilityWarmBrightnessWell(
                    value: Binding(
                        get: { brightnessDraft ?? accessibilityPreferences.staticOverlayBrightness },
                        set: { brightnessDraft = $0 },
                    ),
                    valueText: brightnessValue,
                    increaseContrast: increaseContrast,
                    onEditingChanged: saveBrightnessWhenEditingEnds,
                )
            }
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            sectionHeading(
                SettingsAccessibilityL10n.timerAnnouncements,
                detail: SettingsAccessibilityL10n.timerAnnouncementsDetail,
            )

            AccessibilityTimerAnnouncementTiles(
                selection: Binding(
                    get: { accessibilityPreferences.timerAnnouncements },
                    set: { preference in Task { await model.setTimerAnnouncements(preference) } },
                ),
                increaseContrast: increaseContrast,
            )
        }
    }

    private var movementOrderSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(SettingsAccessibilityL10n.movementOrder)
                .font(sectionTitleFont)
                .foregroundStyle(Color.dsTextSecondary)

            outlinedCard {
                Toggle(
                    isOn: Binding(
                        get: { accessibilityPreferences.seatedContentFirst },
                        set: { enabled in Task { await model.setSeatedContentFirst(enabled) } },
                    ),
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        Text(SettingsAccessibilityL10n.seatedContentFirst)
                            .foregroundStyle(Color.dsTextPrimary)
                        Text(SettingsAccessibilityL10n.seatedContentFirstDetail)
                            .font(secondaryFont)
                            .foregroundStyle(Color.dsTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("settings.accessibility.seatedFirst")
            }
        }
    }

    private var systemAndKeyboardSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(SettingsAccessibilityL10n.systemAndKeyboard)
                .font(sectionTitleFont)
                .foregroundStyle(Color.dsTextSecondary)

            outlinedCard {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    informationRow(
                        title: SettingsAccessibilityL10n.systemDisplaySettings,
                        detail: SettingsAccessibilityL10n.systemDisplaySettingsDetail,
                        systemImage: "circle.lefthalf.filled",
                        identifier: "settings.accessibility.systemDisplay",
                    )

                    Divider().overlay(Color.dsSeparator)

                    informationRow(
                        title: SettingsAccessibilityL10n.keyboardAccess,
                        detail: SettingsAccessibilityL10n.keyboardAccessDetail,
                        systemImage: "keyboard",
                        identifier: "settings.accessibility.keyboard",
                    )
                }
            }
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(sectionTitleFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(detail)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func outlinedCard(@ViewBuilder content: () -> some View) -> some View {
        DSCard(content: content)
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
            }
    }

    private func informationRow(
        title: String,
        detail: String,
        systemImage: String,
        identifier: String,
    ) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .frame(width: DSSpacing.xl)
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(detail)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var accessibilityPreferences: AccessibilityPreferences {
        model.preferences?.accessibility ?? .defaults
    }

    private var brightnessValue: String {
        let value = brightnessDraft ?? accessibilityPreferences.staticOverlayBrightness
        return SettingsAccessibilityL10n.brightnessValue(Int((value * 100).rounded()))
    }

    private func saveBrightnessWhenEditingEnds(_ isEditing: Bool) {
        guard !isEditing, let brightnessDraft else { return }
        Task {
            await model.setStaticOverlayBrightness(brightnessDraft)
            self.brightnessDraft = nil
        }
    }

    private var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    private var contentPadding: CGFloat { textScale == .largest ? DSSpacing.xl : DSSpacing.lg }
    private var sectionSpacing: CGFloat { textScale == .largest ? DSSpacing.xxl : DSSpacing.xl }
}

private struct AccessibilitySettingsOperationFeedback: View {
    @Bindable var model: SettingsFeatureModel

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: model.operationState == .applying ? "arrow.triangle.2.circlepath" : "info.circle")
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)
            Text(message)
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DSSpacing.md)
            if model.canRetryLastChange {
                Button(SettingsFeatureL10n.retry) { Task { await model.retryLastChange() } }
                    .accessibilityIdentifier("settings.accessibility.applyState.retry")
            }
        }
        .padding(DSSpacing.md)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .accessibilityIdentifier("settings.accessibility.applyState")
    }

    private var message: String {
        switch model.operationState {
        case .idle: ""
        case .applying: SettingsFeatureL10n.applying
        case .temporarilyBusy: SettingsFeatureL10n.temporarilyBusy
        case .failed: SettingsFeatureL10n.applyFailed
        }
    }
}

#Preview("Accessibility — Standard") {
    SettingsFeatureView(model: .preview(.accessibilityStandard), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Accessibility — Static") {
    SettingsFeatureView(model: .preview(.accessibilityStatic), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Accessibility — Text only") {
    SettingsFeatureView(model: .preview(.accessibilityTextOnly), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Accessibility — Static, darkest") {
    SettingsFeatureView(
        model: .preview(.accessibilityStaticMinimumBrightness),
        loadsAutomatically: false,
    )
    .frame(width: 1000, height: 700)
}

#Preview("Accessibility — Static, brightest") {
    SettingsFeatureView(
        model: .preview(.accessibilityStaticMaximumBrightness),
        loadsAutomatically: false,
    )
    .frame(width: 1000, height: 700)
}

#Preview("Accessibility — Applying") {
    SettingsFeatureView(model: .preview(.accessibilityApplying), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Accessibility — Temporarily busy") {
    SettingsFeatureView(
        model: .preview(.accessibilityTemporarilyBusy),
        loadsAutomatically: false,
    )
    .frame(width: 1000, height: 700)
}

#Preview("Accessibility — Apply failure") {
    SettingsFeatureView(model: .preview(.accessibilityApplyFailed), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}
