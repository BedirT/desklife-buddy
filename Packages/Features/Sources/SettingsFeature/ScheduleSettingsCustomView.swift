import DesignSystem
import Domain
import Foundation
import SwiftUI

extension ScheduleSettingsView {
    var customEditor: some View {
        CustomScheduleEditor(model: model)
    }
}

private struct CustomScheduleEditor: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            customNote

            Group {
                if textScale == .largest {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        visualFields
                        movementFields
                    }
                } else {
                    HStack(alignment: .top, spacing: DSSpacing.md) {
                        visualFields
                        movementFields
                    }
                }
            }

            HStack {
                Spacer()
                Button(SettingsFeatureL10n.applyCustom) {
                    Task { await model.applyCustomDraft() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canApplyCustom)
                .accessibilityIdentifier("settings.schedule.custom.apply")
            }
        }
        .accessibilityIdentifier("settings.schedule.custom.editor")
    }

    private var visualFields: some View {
        fieldPanel(title: SettingsFeatureL10n.visualReset) {
            customField(
                SettingsFeatureL10n.visualSoftDue,
                field: .visualSoftDue,
                identifier: "settings.schedule.custom.visual.softDueMinutes",
            )
            customField(
                SettingsFeatureL10n.visualTarget,
                field: .visualTarget,
                identifier: "settings.schedule.custom.visual.targetMinutes",
            )
            customField(
                SettingsFeatureL10n.visualLatestPreferred,
                field: .visualLatestPreferred,
                identifier: "settings.schedule.custom.visual.latestPreferredMinutes",
            )
            customField(
                SettingsFeatureL10n.visualDuration,
                field: .visualDuration,
                identifier: "settings.schedule.custom.visual.durationSeconds",
            )
        }
    }

    private var movementFields: some View {
        fieldPanel(title: SettingsFeatureL10n.movement) {
            customField(
                SettingsFeatureL10n.movementSoftDue,
                field: .movementSoftDue,
                identifier: "settings.schedule.custom.movement.softDueMinutes",
            )
            customField(
                SettingsFeatureL10n.movementTarget,
                field: .movementTarget,
                identifier: "settings.schedule.custom.movement.targetMinutes",
            )
            customField(
                SettingsFeatureL10n.movementLatestPreferred,
                field: .movementLatestPreferred,
                identifier: "settings.schedule.custom.movement.latestPreferredMinutes",
            )
            customField(
                SettingsFeatureL10n.movementSuggestedDuration,
                field: .movementSuggestedDuration,
                identifier: "settings.schedule.custom.movement.suggestedDurationMinutes",
            )
            customField(
                SettingsFeatureL10n.movementQuickDuration,
                field: .movementQuickDuration,
                identifier: "settings.schedule.custom.movement.quickDurationMinutes",
            )
        }
    }

    private func fieldPanel(
        title: String,
        @ViewBuilder content: () -> some View,
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(title)
                .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            content()
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.dsSurfaceSecondary,
            in: RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous),
        )
    }

    private func customField(
        _ label: String,
        field: CustomScheduleField,
        identifier: String,
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                Text(label)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DSSpacing.xs)
                numberField(field, label: label, identifier: identifier)
            }

            if let issue = model.customIssue(for: field) {
                Text(fieldIssueMessage(issue, label: label))
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
    }

    private func numberField(
        _ field: CustomScheduleField,
        label: String,
        identifier: String,
    ) -> some View {
        TextField(
            text: Binding(
                get: { model.customFieldText(for: field) },
                set: { model.editCustomFieldText(field, text: $0) },
            ),
            prompt: Text(verbatim: ""),
        ) {
            Text(label)
        }
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.trailing)
        .frame(width: textScale == .largest ? DSSpacing.xxl * 4 : DSSpacing.xxl * 3)
        .accessibilityHint(fieldAccessibilityHint(field, label: label))
        .accessibilityIdentifier(identifier)
    }

    private func fieldAccessibilityHint(_ field: CustomScheduleField, label: String) -> String {
        guard let issue = model.customIssue(for: field) else { return "" }
        return fieldIssueMessage(issue, label: label)
    }

    private func fieldIssueMessage(_ issue: CustomScheduleFieldIssue, label: String) -> String {
        switch issue {
        case .required: SettingsFeatureL10n.customFieldRequired(label)
        case .invalidNumber: SettingsFeatureL10n.customFieldInvalidNumber(label)
        case .positiveFinite: SettingsFeatureL10n.customFieldPositiveFinite(label)
        case .valueTooLarge: SettingsFeatureL10n.customFieldValueTooLarge(label)
        case .orderedWindow: SettingsFeatureL10n.customFieldOrderedWindow(label)
        }
    }

    @ViewBuilder
    private var customNote: some View {
        if model.customValidation != .valid {
            note(SettingsFeatureL10n.customInvalid, identifier: "settings.schedule.custom.validationError")
        } else {
            ForEach(Array(model.scheduleAdvisories.enumerated()), id: \.offset) { _, advisory in
                advisoryNotes(advisory)
            }
        }
    }

    @ViewBuilder
    private func advisoryNotes(_ advisory: ScheduleAdvisory) -> some View {
        switch advisory {
        case let .veryFrequent(types):
            if types.contains(.visual) {
                note(
                    SettingsFeatureL10n.visualVeryFrequentNote,
                    identifier: "settings.schedule.advisory.visual.veryFrequent",
                )
            }
            if types.contains(.movement) {
                note(
                    SettingsFeatureL10n.movementVeryFrequentNote,
                    identifier: "settings.schedule.advisory.movement.veryFrequent",
                )
            }
        case let .effectivelyDisabled(types):
            if types.contains(.visual) {
                note(
                    SettingsFeatureL10n.visualEffectivelyDisabledNote,
                    identifier: "settings.schedule.advisory.visual.effectivelyDisabled",
                )
            }
            if types.contains(.movement) {
                note(
                    SettingsFeatureL10n.movementEffectivelyDisabledNote,
                    identifier: "settings.schedule.advisory.movement.effectivelyDisabled",
                )
            }
        }
    }

    private func note(_ text: String, identifier: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(secondaryFont)
            .foregroundStyle(Color.dsTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }
}

#Preview("Custom schedule editor") {
    ScheduleSettingsView(
        model: .preview(.customValid),
        increaseContrast: false,
    )
    .frame(width: 780, height: 560)
}
