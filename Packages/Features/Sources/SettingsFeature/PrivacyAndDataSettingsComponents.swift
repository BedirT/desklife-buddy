import DesignSystem
import SwiftUI

enum SettingsPrivacyLayoutMetrics {
    static let standardOutlineWidth: CGFloat = 1
    static let contrastOutlineWidth: CGFloat = 2
    static let selectedFillOpacity = 0.10
    static let dangerOutlineOpacity = 0.42
    static let dangerOutlineContrastOpacity = 0.78
    static let exportDialogMaxWidth = confirmationDialogMaxWidth + DSSpacing.xxl
    static let exportDialogMaxHeight: CGFloat = 600
    static let exportOptionsMaxHeight: CGFloat = 440
    static let confirmationDialogMaxWidth: CGFloat = 560
    static let manifestLabelWidth = DSSpacing.xxl * 2
    static let minimumActionTargetHeight = DSSpacing.xxl + DSSpacing.md
    static let visualActionHeight = DSSpacing.xxl + DSSpacing.xs
    static let actionButtonWidth = DSSpacing.xxl * 4
    static let actionButtonCornerRadius = DSRadius.sm + (DSSpacing.xs / 2)
    static let exportActionFillOpacity = 0.08
    static let exportActionBorderOpacity = 0.48
    static let destructiveActionFillOpacity = 0.035
    static let destructiveActionBorderOpacity = 0.50
    static let neutralActionFillOpacity = 0.035
    static let neutralActionBorderOpacity = 0.24
    static let feedbackFillOpacity = 0.07
    static let feedbackBorderOpacity = 0.28
    static let disabledActionOpacity = 0.46
}

struct SettingsPrivacyStoredDataRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let textScale: DSTextScale

    var body: some View {
        HStack(alignment: .top, spacing: SettingsPageLayout.rowGap) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.dsAccent)
                .frame(width: SettingsPageLayout.rowIconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .font(textScale == .largest ? DSTypography.headline : DSTypography.subtext.weight(.semibold))
                    .foregroundStyle(Color.dsTextPrimary)
                Text(detail)
                    .font(textScale == .largest ? DSTypography.body : DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SettingsPrivacyRetentionButton: View {
    let choice: SettingsPrivacyRetentionChoice
    let selected: Bool
    let increaseContrast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                DSSelectionIndicator(selected: selected)

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(choice.title)
                        .font(DSTypography.headline)
                    Text(choice.detail)
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.dsTextPrimary)
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, minHeight: DSSpacing.xxl * 2, alignment: .topLeading)
            .background(
                selected ? Color.dsAccent.opacity(SettingsPrivacyLayoutMetrics.selectedFillOpacity) : Color
                    .dsSurfaceSecondary,
                in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
            )
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .stroke(
                        selected ? Color.dsAccent : Color.dsSeparator,
                        lineWidth: selected || increaseContrast
                            ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                            : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
        .accessibilityHint(choice.detail)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.privacy.retention.\(choice.identifierSuffix)")
    }
}

struct SettingsPrivacyDataControlRow: View {
    let title: String
    let detail: String
    let actionTitle: String
    let systemImage: String
    let enabled: Bool
    let textScale: DSTextScale
    let increaseContrast: Bool
    let identifier: String
    let focusedControl: FocusState<SettingsPrivacyFocusTarget?>.Binding
    let focusTarget: SettingsPrivacyFocusTarget
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: SettingsPageLayout.rowGap) {
            Image(systemName: systemImage)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: SettingsPageLayout.rowIconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(detail)
                    .font(textScale == .largest ? DSTypography.body : DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Button(role: .destructive, action: action) {
                SettingsPrivacyCompactActionLabel(
                    title: actionTitle,
                    tint: .dsDanger,
                    fillOpacity: SettingsPrivacyLayoutMetrics.destructiveActionFillOpacity,
                    borderOpacity: SettingsPrivacyLayoutMetrics.destructiveActionBorderOpacity,
                    textScale: textScale,
                    increaseContrast: increaseContrast,
                )
            }
            .buttonStyle(.plain)
            .focused(focusedControl, equals: focusTarget)
            .disabled(!enabled)
            .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsPrivacyCompactActionLabel: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let tint: Color
    let fillOpacity: Double
    let borderOpacity: Double
    let textScale: DSTextScale
    let increaseContrast: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: SettingsPrivacyLayoutMetrics.actionButtonCornerRadius,
                style: .continuous,
            )
            .fill(tint.opacity(fillOpacity))
            .overlay {
                RoundedRectangle(
                    cornerRadius: SettingsPrivacyLayoutMetrics.actionButtonCornerRadius,
                    style: .continuous,
                )
                .strokeBorder(
                    tint.opacity(borderOpacity),
                    lineWidth: increaseContrast
                        ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                        : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                )
            }
            .frame(height: SettingsPrivacyLayoutMetrics.visualActionHeight)

            Text(title)
                .font(textScale == .largest ? DSTypography.body.weight(.semibold) : DSTypography.subtext
                    .weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(
            width: textScale == .largest
                ? SettingsPrivacyLayoutMetrics.actionButtonWidth + DSSpacing.xxl
                : SettingsPrivacyLayoutMetrics.actionButtonWidth,
        )
        .frame(minHeight: SettingsPrivacyLayoutMetrics.minimumActionTargetHeight)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : SettingsPrivacyLayoutMetrics.disabledActionOpacity)
    }
}

struct SettingsPrivacyOperationFeedback: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            if model.operationState == .applying {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(message)
                .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DSSpacing.md)
            if model.canRetryLastChange {
                Button { Task { await model.retryLastChange() } } label: {
                    SettingsPrivacyCompactActionLabel(
                        title: SettingsFeatureL10n.retry,
                        tint: .dsAccent,
                        fillOpacity: SettingsPrivacyLayoutMetrics.exportActionFillOpacity,
                        borderOpacity: SettingsPrivacyLayoutMetrics.exportActionBorderOpacity,
                        textScale: textScale,
                        increaseContrast: increaseContrast,
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.privacy.retention.retry")
            } else if isDismissible {
                Button {
                    model.dismissPrivacyOperationFeedback()
                } label: {
                    Image(systemName: "xmark")
                        .accessibilityLabel(SettingsPrivacyL10n.cancel)
                        .frame(
                            width: SettingsPrivacyLayoutMetrics.minimumActionTargetHeight,
                            height: SettingsPrivacyLayoutMetrics.minimumActionTargetHeight,
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.privacy.feedback.dismiss")
            }
        }
        .padding(.leading, DSSpacing.md)
        .padding(.trailing, DSSpacing.xs)
        .frame(minHeight: SettingsPrivacyLayoutMetrics.minimumActionTargetHeight)
        .background(
            tint.opacity(SettingsPrivacyLayoutMetrics.feedbackFillOpacity),
            in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .strokeBorder(
                    tint.opacity(SettingsPrivacyLayoutMetrics.feedbackBorderOpacity),
                    lineWidth: increaseContrast
                        ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                        : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                )
        }
        .accessibilityIdentifier("settings.privacy.feedback")
    }

    private var message: String {
        if model.operationState != .idle {
            switch model.operationState {
            case .idle: return ""
            case .applying: return SettingsPrivacyL10n.applyingRetention
            case .temporarilyBusy: return SettingsFeatureL10n.temporarilyBusy
            case .failed: return SettingsFeatureL10n.applyFailed
            }
        }
        return switch model.privacyOperation {
        case let .exportSucceeded(destinationName):
            SettingsPrivacyL10n.exportSucceeded(destinationName: destinationName)
        case .historyDeletionSucceeded:
            SettingsPrivacyL10n.historyDeletedAcknowledgement
        case .resetSucceeded:
            SettingsPrivacyL10n.resetAllAcknowledgement
        case .idle, .exporting, .deletingHistory, .resettingAll, .temporarilyBusy, .failed:
            ""
        }
    }

    private var icon: String {
        switch model.operationState {
        case .failed: "exclamationmark.triangle"
        case .temporarilyBusy: "clock.badge.exclamationmark"
        case .idle, .applying: "checkmark.circle"
        }
    }

    private var tint: Color {
        switch model.operationState {
        case .failed: .dsDanger
        case .temporarilyBusy: .dsWarning
        case .applying: .dsAccent
        case .idle: .dsPositive
        }
    }

    private var isDismissible: Bool {
        model.operationState == .idle
    }
}

extension SettingsPrivacyRetentionChoice {
    var title: String {
        switch self {
        case .thirtyDays: SettingsPrivacyL10n.thirtyDays
        case .ninetyDays: SettingsPrivacyL10n.ninetyDays
        case .keepNothing: SettingsPrivacyL10n.keepNothing
        }
    }

    var detail: String {
        switch self {
        case .thirtyDays: SettingsPrivacyL10n.thirtyDaysDetail
        case .ninetyDays: SettingsPrivacyL10n.ninetyDaysDetail
        case .keepNothing: SettingsPrivacyL10n.keepNothingDetail
        }
    }

    var identifierSuffix: String {
        switch self {
        case .thirtyDays: "thirtyDays"
        case .ninetyDays: "ninetyDays"
        case .keepNothing: "keepNothing"
        }
    }
}

#Preview("Privacy & data — Component composition") {
    SettingsFeatureView(model: .preview(.privacyDefault), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}
