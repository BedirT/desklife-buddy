import DesignSystem
import SwiftUI

struct SettingsPrivacyModalOverlay: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool
    let focusedControl: FocusState<SettingsPrivacyFocusTarget?>.Binding

    var body: some View {
        ZStack {
            Color.dsStaticDesktopScrim
                .ignoresSafeArea()

            if model.isExportDisclosurePresented {
                exportReview
            } else if let operation = model.pendingDestructiveOperation {
                destructiveConfirmation(operation)
            }
        }
        .padding(DSSpacing.xxl)
        .focusSection()
        .onKeyPress(keys: [.tab], phases: .down) { press in
            let targets = SettingsPrivacyFocusTarget.modalTargets(
                isExport: model.isExportDisclosurePresented,
                canRetry: model.canRetryPrivacyOperation,
                columnsExpanded: model.isExportColumnsExpanded,
                canChooseDestination: model.exportRequest != nil,
            )
            focusedControl.wrappedValue = SettingsPrivacyFocusTarget.nextModalTarget(
                after: focusedControl.wrappedValue,
                in: targets,
                reverse: press.modifiers.contains(.shift),
            )
            return .handled
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("settings.privacy.modal")
    }

    private var exportReview: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                dialogHeader(
                    title: SettingsPrivacyL10n.reviewExportTitle,
                    detail: SettingsPrivacyL10n.reviewExportDetail,
                    systemImage: "square.and.arrow.up",
                    tint: .dsAccent,
                )

                if model.isExportColumnsExpanded {
                    ScrollView {
                        exportContents
                    }
                    .frame(maxHeight: SettingsPrivacyLayoutMetrics.exportOptionsMaxHeight)
                } else {
                    exportContents
                }

                exportActions
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(
                    Color.dsSeparator,
                    lineWidth: increaseContrast
                        ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                        : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                )
        }
        .frame(
            maxWidth: SettingsPrivacyLayoutMetrics.exportDialogMaxWidth,
            maxHeight: SettingsPrivacyLayoutMetrics.exportDialogMaxHeight,
        )
        .accessibilityIdentifier("settings.privacy.export.reviewDialog")
    }

    private var exportContents: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            SettingsPrivacyExportSummaryHeader(
                retainedHistoryCount: model.retainedHistoryCount,
                canExport: model.exportRequest != nil,
                increaseContrast: increaseContrast,
            )

            SettingsPrivacyExportOptions(
                model: model,
                increaseContrast: increaseContrast,
                focusedControl: focusedControl,
            )

            if let feedback = exportFeedback {
                dialogFeedback(feedback)
            }
        }
    }

    private var exportActions: some View {
        HStack(spacing: DSSpacing.sm) {
            Button {
                model.dismissExportDisclosure()
            } label: {
                secondaryActionLabel(SettingsPrivacyL10n.cancel)
            }
            .buttonStyle(.plain)
            .focused(focusedControl, equals: .cancel)
            .keyboardShortcut(.cancelAction)
            .disabled(model.privacyOperation.isInProgress)
            .accessibilityIdentifier("settings.privacy.export.cancel")

            Spacer(minLength: DSSpacing.md)

            if model.canRetryPrivacyOperation {
                Button {
                    Task { await model.retryPrivacyOperation() }
                } label: {
                    accentActionLabel(SettingsFeatureL10n.retry)
                }
                .buttonStyle(.plain)
                .focused(focusedControl, equals: .retry)
                .accessibilityIdentifier("settings.privacy.export.retry")
            } else {
                Button {
                    Task { await model.exportHistory() }
                } label: {
                    accentActionLabel(SettingsPrivacyL10n.chooseExportDestination)
                }
                .buttonStyle(.plain)
                .focused(focusedControl, equals: .chooseDestination)
                .disabled(model.privacyOperation.isInProgress || model.exportRequest == nil)
                .accessibilityIdentifier("settings.privacy.export.chooseDestination")
            }
        }
    }

    private func destructiveConfirmation(_ operation: SettingsDestructiveOperation) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                dialogHeader(
                    title: operation.confirmationTitle,
                    detail: operation.confirmationBody,
                    systemImage: operation.systemImage,
                    tint: .dsDanger,
                )

                if let feedback = destructiveFeedback(for: operation) {
                    dialogFeedback(feedback)
                }

                confirmationActions(operation)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(
                    Color.dsDanger.opacity(
                        increaseContrast
                            ? SettingsPrivacyLayoutMetrics.dangerOutlineContrastOpacity
                            : SettingsPrivacyLayoutMetrics.dangerOutlineOpacity,
                    ),
                    lineWidth: increaseContrast
                        ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                        : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                )
        }
        .frame(maxWidth: SettingsPrivacyLayoutMetrics.confirmationDialogMaxWidth)
        .accessibilityIdentifier("settings.privacy.confirmation.\(operation.identifierSuffix)")
    }

    private func confirmationActions(_ operation: SettingsDestructiveOperation) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Button {
                model.cancelPendingDestructiveOperation()
            } label: {
                secondaryActionLabel(SettingsPrivacyL10n.cancel)
            }
            .buttonStyle(.plain)
            .focused(focusedControl, equals: .cancel)
            .keyboardShortcut(.cancelAction)
            .disabled(model.privacyOperation.isInProgress)
            .accessibilityIdentifier("settings.privacy.confirmation.cancel")

            Spacer(minLength: DSSpacing.md)

            if model.canRetryPrivacyOperation {
                Button {
                    Task { await model.retryPrivacyOperation() }
                } label: {
                    accentActionLabel(SettingsFeatureL10n.retry)
                }
                .buttonStyle(.plain)
                .focused(focusedControl, equals: .retry)
                .accessibilityIdentifier("settings.privacy.confirmation.retry")
            } else {
                Button(role: .destructive) {
                    Task { await model.confirmPendingDestructiveOperation() }
                } label: {
                    SettingsPrivacyCompactActionLabel(
                        title: operation.actionTitle,
                        tint: .dsDanger,
                        fillOpacity: SettingsPrivacyLayoutMetrics.destructiveActionFillOpacity,
                        borderOpacity: SettingsPrivacyLayoutMetrics.destructiveActionBorderOpacity,
                        textScale: textScale,
                        increaseContrast: increaseContrast,
                    )
                }
                .buttonStyle(.plain)
                .focused(focusedControl, equals: .confirm)
                .disabled(model.privacyOperation.isInProgress)
                .accessibilityIdentifier("settings.privacy.confirmation.confirm")
            }
        }
    }
}

private extension SettingsPrivacyModalOverlay {
    private func dialogHeader(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
    ) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .font(DSTypography.title)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .font(DSTypography.title)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(detail)
                    .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func dialogFeedback(_ message: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            if model.privacyOperation.isInProgress {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: modalFeedbackIcon)
                    .foregroundStyle(modalFeedbackTint)
                    .accessibilityHidden(true)
            }
            Text(message)
                .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            modalFeedbackTint.opacity(SettingsPrivacyLayoutMetrics.feedbackFillOpacity),
            in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .strokeBorder(
                    modalFeedbackTint.opacity(SettingsPrivacyLayoutMetrics.feedbackBorderOpacity),
                    lineWidth: increaseContrast
                        ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                        : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                )
        }
    }

    private func secondaryActionLabel(_ title: String) -> some View {
        SettingsPrivacyCompactActionLabel(
            title: title,
            tint: .dsTextSecondary,
            fillOpacity: SettingsPrivacyLayoutMetrics.neutralActionFillOpacity,
            borderOpacity: SettingsPrivacyLayoutMetrics.neutralActionBorderOpacity,
            textScale: textScale,
            increaseContrast: increaseContrast,
        )
    }

    private func accentActionLabel(_ title: String) -> some View {
        SettingsPrivacyCompactActionLabel(
            title: title,
            tint: .dsAccent,
            fillOpacity: SettingsPrivacyLayoutMetrics.exportActionFillOpacity,
            borderOpacity: SettingsPrivacyLayoutMetrics.exportActionBorderOpacity,
            textScale: textScale,
            increaseContrast: increaseContrast,
        )
    }

    private var modalFeedbackTint: Color {
        switch model.privacyOperation {
        case .temporarilyBusy: .dsWarning
        case .failed: .dsDanger
        case .exporting, .deletingHistory, .resettingAll: .dsAccent
        case .idle, .exportSucceeded, .historyDeletionSucceeded, .resetSucceeded: .dsTextSecondary
        }
    }

    private var modalFeedbackIcon: String {
        switch model.privacyOperation {
        case .temporarilyBusy: "clock.badge.exclamationmark"
        case .failed: "exclamationmark.triangle"
        case .idle, .exporting, .exportSucceeded, .deletingHistory, .historyDeletionSucceeded,
             .resettingAll, .resetSucceeded:
            "info.circle"
        }
    }

    private var exportFeedback: String? {
        switch model.privacyOperation {
        case .exporting:
            SettingsPrivacyL10n.exporting
        case .temporarilyBusy(.exportHistory):
            SettingsPrivacyL10n.exportTemporarilyBusy
        case .failed(.exportHistory):
            SettingsPrivacyL10n.exportFailed
        case .idle, .exportSucceeded, .deletingHistory, .historyDeletionSucceeded,
             .resettingAll, .resetSucceeded, .temporarilyBusy, .failed:
            nil
        }
    }

    private func destructiveFeedback(for operation: SettingsDestructiveOperation) -> String? {
        switch (operation, model.privacyOperation) {
        case (.deleteHistory, .deletingHistory):
            SettingsPrivacyL10n.deletingHistory
        case (.deleteHistory, .temporarilyBusy(.deleteHistory)):
            SettingsPrivacyL10n.deleteTemporarilyBusy
        case (.deleteHistory, .failed(.deleteHistory)):
            SettingsPrivacyL10n.deleteFailed
        case (.resetAll, .resettingAll):
            SettingsPrivacyL10n.resettingAll
        case (.resetAll, .temporarilyBusy(.resetAll)):
            SettingsPrivacyL10n.resetTemporarilyBusy
        case (.resetAll, .failed(.resetAll)):
            SettingsPrivacyL10n.resetFailed
        default:
            nil
        }
    }
}

private extension SettingsDestructiveOperation {
    var confirmationTitle: String {
        switch self {
        case .deleteHistory: SettingsPrivacyL10n.deleteHistoryConfirmationTitle
        case .resetAll: SettingsPrivacyL10n.resetAllConfirmationTitle
        }
    }

    var confirmationBody: String {
        switch self {
        case .deleteHistory: SettingsPrivacyL10n.deleteHistoryConfirmationBody
        case .resetAll: SettingsPrivacyL10n.resetAllConfirmationBody
        }
    }

    var actionTitle: String {
        switch self {
        case .deleteHistory: SettingsPrivacyL10n.deleteHistoryAction
        case .resetAll: SettingsPrivacyL10n.resetAllAction
        }
    }

    var systemImage: String {
        switch self {
        case .deleteHistory: "trash"
        case .resetAll: "arrow.counterclockwise"
        }
    }

    var identifierSuffix: String {
        switch self {
        case .deleteHistory: "deleteHistory"
        case .resetAll: "resetAll"
        }
    }
}

#Preview("Privacy & data: Export review") {
    SettingsFeatureView(model: .preview(.privacyExportReview), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Privacy & data: Export requires a column") {
    SettingsFeatureView(model: .preview(.privacyExportNoColumns), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Privacy & data: Delete confirmation") {
    SettingsFeatureView(model: .preview(.privacyDeleteConfirmation), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Privacy & data: Reset confirmation") {
    SettingsFeatureView(model: .preview(.privacyResetConfirmation), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}
