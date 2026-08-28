import DesignSystem
import Domain
import Foundation
import SwiftUI

struct ScheduleSettingsView: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool

    var body: some View {
        VStack(spacing: 0) {
            if model.operationState != .idle {
                SettingsOperationFeedback(model: model)
                    .padding(DSSpacing.md)
                    .background(
                        Color.dsSurface,
                        in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
                    )
                    .padding(.bottom, DSSpacing.md)
                    .accessibilityIdentifier("settings.schedule.applyState")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    rhythmSection
                    timingAndDeliverySection
                    whyTheseNumbersButton
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .allowsHitTesting(model.controlsEnabled)
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .background(Color.dsBackground)
        .accessibilityIdentifier("settings.schedule")
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

            DisclosureGroup(
                SettingsFeatureL10n.advanced,
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
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.dsAccent)
                                .opacity(model.selectedProfileID == .custom ? 1 : 0)
                                .accessibilityHidden(true)
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
            .accessibilityIdentifier("settings.schedule.moreOptions")
        }
    }

    private var timingAndDeliverySection: some View {
        Group {
            if textScale == .largest {
                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    timingColumn
                    deliveryColumn
                }
            } else {
                HStack(alignment: .top, spacing: DSSpacing.xxl) {
                    timingColumn
                    deliveryColumn
                }
            }
        }
        .padding(textScale == .largest ? DSSpacing.xl : DSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.dsSurface,
            in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous),
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
        }
        .accessibilityIdentifier("settings.schedule.preferences")
    }

    private var timingColumn: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(SettingsFeatureL10n.timing)
                .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)

            timingRow(
                SettingsFeatureL10n.visualReset,
                summary: model.visualTimingSummary,
                identifier: "settings.schedule.visualTiming",
            )

            timingRow(
                SettingsFeatureL10n.movement,
                summary: model.movementTimingSummary,
                identifier: "settings.schedule.movementTiming",
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deliveryColumn: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(SettingsFeatureL10n.delivery)
                .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)

            Toggle(
                isOn: Binding(
                    get: { model.preferences?.schedule.headsUpEnabled ?? false },
                    set: { enabled in Task { await model.setHeadsUpEnabled(enabled) } },
                ),
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(SettingsFeatureL10n.headsUp)
                    if let headsUpSummary = model.headsUpSummary {
                        Text(headsUpSummary)
                            .font(secondaryFont)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
            }
            .accessibilityIdentifier("settings.schedule.headsUpEnabled")

            Toggle(
                SettingsFeatureL10n.waitForLowFriction,
                isOn: Binding(
                    get: { model.preferences?.context.waitsForLowFrictionMoment ?? false },
                    set: { enabled in Task { await model.setWaitsForLowFrictionMoment(enabled) } },
                ),
            )
            .accessibilityIdentifier("settings.schedule.waitsForLowFrictionMoment")

            Toggle(
                SettingsFeatureL10n.workingHoursOnly,
                isOn: Binding(
                    get: { model.preferences?.schedule.workingHoursOnly ?? false },
                    set: { enabled in Task { await model.setWorkingHoursOnly(enabled) } },
                ),
            )
            .accessibilityIdentifier("settings.schedule.workingHoursOnly")

            Text(SettingsFeatureL10n.estimatorExplanation)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.schedule.activityEstimatorExplanation")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var whyTheseNumbersButton: some View {
        Button {
            if model.controlsEnabled {
                model.selectedSection = .whyTheseDefaults
            }
        } label: {
            Label(SettingsFeatureL10n.whyTheseNumbers, systemImage: "info.circle")
        }
        .buttonStyle(.link)
        .accessibilityIdentifier("settings.schedule.whyTheseNumbers")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(textScale == .largest ? DSTypography.headline : DSTypography.caption)
            .foregroundStyle(Color.dsTextSecondary)
    }

    private func timingRow(_ title: String, summary: String?, identifier: String) -> some View {
        LabeledContent(title) {
            if let summary {
                Text(summary)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    private var contentPadding: CGFloat {
        textScale == .largest ? DSSpacing.xl : DSSpacing.lg
    }

    private var sectionSpacing: CGFloat {
        textScale == .largest ? DSSpacing.xxl : DSSpacing.xl
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
            ProgressView(SettingsFeatureL10n.applying)
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
            Spacer(minLength: DSSpacing.md)
            Button(SettingsFeatureL10n.retry) {
                Task { await model.retryLastChange() }
            }
            .disabled(!model.canRetryLastChange)
            .accessibilityIdentifier("settings.schedule.applyState.retry")
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview("Schedule component") {
    ScheduleSettingsView(
        model: .preview(.balanced),
        increaseContrast: false,
    )
    .frame(width: 780, height: 560)
}
