import DesignSystem
import Domain
import Foundation
import SwiftUI

struct ScheduleSettingsView: View {
    @Environment(\.dsTextScale) private var textScale
    @AccessibilityFocusState private var operationFeedbackFocused: Bool
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool

    var body: some View {
        VStack(spacing: 0) {
            if model.operationState != .idle {
                SettingsOperationFeedback(model: model)
                    .padding(DSSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.dsSurface,
                        in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
                    )
                    .padding(.bottom, DSSpacing.md)
                    .accessibilityElement(children: .contain)
                    .accessibilityFocused($operationFeedbackFocused)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    rhythmSection
                    scheduleForm
                    advancedScheduleSection
                }
                .padding(.bottom, contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .allowsHitTesting(model.controlsEnabled)
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .onChange(of: model.operationState) { _, operationState in
            operationFeedbackFocused = switch operationState {
            case .temporarilyBusy, .failed: true
            case .idle, .applying: false
            }
        }
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            sectionTitle(SettingsFeatureL10n.rhythm)

            PrimaryProfileChoices(
                model: model,
                increaseContrast: increaseContrast,
            )

            Text(SettingsFeatureL10n.independentClocks)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scheduleForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            formSectionTitle(SettingsFeatureL10n.timing)

            formValueRow(
                SettingsFeatureL10n.visualReset,
                summary: model.visualTimingSummary,
                identifier: "settings.schedule.visualTiming",
            )

            Divider()

            formValueRow(
                SettingsFeatureL10n.movement,
                summary: model.movementTimingSummary,
                identifier: "settings.schedule.movementTiming",
            )

            Divider()
                .padding(.vertical, DSSpacing.sm)

            formSectionTitle(SettingsFeatureL10n.delivery)

            formToggleRow(
                SettingsFeatureL10n.headsUp,
                summary: model.headsUpSummary,
                isOn: Binding(
                    get: { model.preferences?.schedule.headsUpEnabled ?? false },
                    set: { enabled in Task { await model.setHeadsUpEnabled(enabled) } },
                ),
                identifier: "settings.schedule.headsUpEnabled",
            )

            Divider()

            formToggleRow(
                SettingsFeatureL10n.waitForLowFriction,
                summary: nil,
                isOn: Binding(
                    get: { model.preferences?.context.waitsForLowFrictionMoment ?? false },
                    set: { enabled in Task { await model.setWaitsForLowFrictionMoment(enabled) } },
                ),
                identifier: "settings.schedule.waitsForLowFrictionMoment",
            )

            Text(SettingsFeatureL10n.estimatorExplanation)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DSSpacing.sm)
                .accessibilityIdentifier("settings.schedule.activityEstimatorExplanation")
        }
        .padding(formPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.dsSurface,
            in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous),
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
        }
    }

    private var advancedScheduleSection: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { model.isAdvancedScheduleExpanded },
                set: { expanded in
                    if model.controlsEnabled {
                        model.isAdvancedScheduleExpanded = expanded
                    }
                },
            ),
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                AdvancedProfileChoiceButton(
                    profile: .researchInformedHighFrequency,
                    title: SettingsFeatureL10n.highFrequency,
                    model: model,
                )

                Button {
                    model.beginCustomEditing()
                } label: {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(Color.dsTextSecondary)
                            .accessibilityHidden(true)
                        Text(SettingsFeatureL10n.custom)
                        Spacer(minLength: DSSpacing.md)
                        DSSelectionIndicator(selected: model.selectedProfileID == .custom)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.schedule.profile.custom")
                .accessibilityAddTraits(model.selectedProfileID == .custom ? .isSelected : [])

                if model.isCustomEditing {
                    customEditor
                }
            }
            .padding(.top, DSSpacing.md)
        } label: {
            Text(SettingsFeatureL10n.advanced)
                .accessibilityIdentifier("settings.schedule.moreOptions")
        }
        .padding(DSSpacing.lg)
        .background(
            Color.dsSurface,
            in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(textScale == .largest ? DSTypography.headline : DSTypography.caption)
            .foregroundStyle(Color.dsTextSecondary)
    }

    private func formSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
            .foregroundStyle(Color.dsTextPrimary)
            .padding(.bottom, DSSpacing.sm)
    }

    private func formValueRow(_ title: String, summary: String?, identifier: String) -> some View {
        formRowLabel(title, summary: summary)
            .padding(.vertical, formRowVerticalPadding)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
    }

    private func formToggleRow(
        _ title: String,
        summary: String?,
        isOn: Binding<Bool>,
        identifier: String,
    ) -> some View {
        Toggle(isOn: isOn) {
            formRowLabel(title, summary: summary)
        }
        .toggleStyle(.switch)
        .tint(Color.dsAccent)
        .padding(.vertical, formRowVerticalPadding)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func formRowLabel(_ title: String, summary: String?) -> some View {
        if textScale == .largest {
            formRowStack(title, summary: summary)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.lg) {
                    Text(title)
                        .foregroundStyle(Color.dsTextPrimary)
                        .layoutPriority(1)
                    Spacer(minLength: DSSpacing.md)
                    if let summary {
                        Text(summary)
                            .font(secondaryFont)
                            .foregroundStyle(Color.dsTextSecondary)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }

                formRowStack(title, summary: summary)
            }
        }
    }

    private func formRowStack(_ title: String, summary: String?) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .foregroundStyle(Color.dsTextPrimary)
            if let summary {
                Text(summary)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    private var contentPadding: CGFloat {
        SettingsPageLayout.contentInset(for: textScale)
    }

    private var sectionSpacing: CGFloat {
        SettingsPageLayout.sectionGap(for: textScale)
    }

    private var formPadding: CGFloat {
        textScale == .largest ? DSSpacing.xl : DSSpacing.md
    }

    private var formRowVerticalPadding: CGFloat {
        textScale == .largest ? DSSpacing.sm : DSSpacing.xs
    }
}

private struct SettingsOperationFeedback: View {
    @Bindable var model: SettingsFeatureModel

    @ViewBuilder
    var body: some View {
        switch model.operationState {
        case .idle:
            EmptyView()
        case .applying:
            HStack(spacing: DSSpacing.sm) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
                Text(SettingsFeatureL10n.applying)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(SettingsFeatureL10n.applying)
            .accessibilityIdentifier("settings.schedule.applyState.applying")
        case .temporarilyBusy:
            retryRow(
                SettingsFeatureL10n.temporarilyBusy,
                identifier: "settings.schedule.applyState.temporarilyBusy",
            )
        case .failed:
            retryRow(
                SettingsFeatureL10n.applyFailed,
                identifier: "settings.schedule.applyState.failed",
            )
        }
    }

    private func retryRow(_ message: String, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.md) {
            Text(message)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
            Spacer(minLength: DSSpacing.md)
            Button(SettingsFeatureL10n.retry) {
                Task { await model.retryLastChange() }
            }
            .disabled(!model.canRetryLastChange)
            .accessibilityIdentifier("settings.schedule.applyState.retry")
        }
    }
}

#Preview("Schedule component") {
    ScheduleSettingsView(
        model: .preview(.balanced),
        increaseContrast: false,
    )
    .frame(width: 780, height: 560)
}

#Preview("Schedule compact window") {
    SettingsFeatureView(
        model: .preview(.balanced),
        loadsAutomatically: false,
        deterministicSplitLayout: true,
    )
    .frame(width: 780, height: 592)
}
