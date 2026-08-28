import DesignSystem
import Domain
import SwiftUI

struct PrivacyAndDataSettingsView: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool
    let focusedControl: FocusState<SettingsPrivacyFocusTarget?>.Binding

    var body: some View {
        VStack(spacing: 0) {
            if showsOperationFeedback {
                SettingsPrivacyOperationFeedback(
                    model: model,
                    increaseContrast: increaseContrast,
                )
                .padding(.bottom, DSSpacing.md)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    storedDataCard
                    historyCard
                    dataControlsCard
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .background(Color.dsBackground)
        .accessibilityIdentifier("settings.privacy")
    }

    private var storedDataCard: some View {
        outlinedCard {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                sectionHeader(
                    title: SettingsPrivacyL10n.storedOnThisMac,
                    detail: SettingsPrivacyL10n.storedDetail,
                    systemImage: "internaldrive",
                )

                Group {
                    if textScale == .largest {
                        VStack(alignment: .leading, spacing: DSSpacing.lg) {
                            storedDataRows
                        }
                    } else {
                        HStack(alignment: .top, spacing: DSSpacing.md) {
                            storedDataRows
                        }
                    }
                }

                Text(SettingsPrivacyL10n.storedBoundary)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("settings.privacy.storedData")
    }

    @ViewBuilder
    private var storedDataRows: some View {
        if containsAnyStoredData([
            .settingsAndPreferences,
            .excludedApplicationBundleIdentifiers,
            .integrationSelections,
            .onboardingCompletionMarker,
            .notificationAuthorizationMetadata,
        ]) {
            SettingsPrivacyStoredDataRow(
                title: SettingsPrivacyL10n.preferencesTitle,
                detail: SettingsPrivacyL10n.preferencesDetail,
                systemImage: "slider.horizontal.3",
                textScale: textScale,
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }

        if containsAnyStoredData([.runtimeRecoveryState]) {
            SettingsPrivacyStoredDataRow(
                title: SettingsPrivacyL10n.timingTitle,
                detail: SettingsPrivacyL10n.timingDetail,
                systemImage: "clock",
                textScale: textScale,
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }

        if containsAnyStoredData([.opportunityHistory]) {
            SettingsPrivacyStoredDataRow(
                title: SettingsPrivacyL10n.opportunityHistoryTitle,
                detail: SettingsPrivacyL10n.opportunityHistoryDetail,
                systemImage: "list.bullet.rectangle",
                textScale: textScale,
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }

        if containsAnyStoredData([.estimatedActiveUseHistory]) {
            SettingsPrivacyStoredDataRow(
                title: SettingsPrivacyL10n.estimatedActiveUseHistoryTitle,
                detail: SettingsPrivacyL10n.estimatedActiveUseHistoryDetail,
                systemImage: "chart.bar.xaxis",
                textScale: textScale,
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var historyCard: some View {
        outlinedCard {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                sectionHeader(
                    title: SettingsPrivacyL10n.historyTitle,
                    detail: SettingsPrivacyL10n.historyDetail,
                    systemImage: "clock.arrow.circlepath",
                )

                Group {
                    if textScale == .largest {
                        VStack(spacing: DSSpacing.sm) { retentionChoices }
                    } else {
                        HStack(spacing: DSSpacing.sm) { retentionChoices }
                    }
                }
                .disabled(!model.controlsEnabled)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(SettingsPrivacyL10n.historyTitle)

                Divider().overlay(Color.dsSeparator)

                if model.hasRetainedHistory {
                    exportRow
                } else {
                    noHistoryRow
                }
            }
        }
        .accessibilityIdentifier("settings.privacy.history")
    }

    @ViewBuilder
    private var retentionChoices: some View {
        ForEach(SettingsPrivacyRetentionChoice.allCases) { choice in
            SettingsPrivacyRetentionButton(
                choice: choice,
                selected: model.historyRetention == choice.policy,
                increaseContrast: increaseContrast,
            ) {
                Task { await model.setHistoryRetention(choice.policy) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var exportRow: some View {
        HStack(alignment: .center, spacing: DSSpacing.md) {
            Image(systemName: "square.and.arrow.up")
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: DSSpacing.xl)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(SettingsPrivacyL10n.exportHistory)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(SettingsPrivacyL10n.exportHistoryDetail)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Button {
                model.presentExportDisclosure()
            } label: {
                SettingsPrivacyCompactActionLabel(
                    title: SettingsPrivacyL10n.reviewExport,
                    tint: .dsAccent,
                    fillOpacity: SettingsPrivacyLayoutMetrics.exportActionFillOpacity,
                    borderOpacity: SettingsPrivacyLayoutMetrics.exportActionBorderOpacity,
                    textScale: textScale,
                    increaseContrast: increaseContrast,
                )
            }
            .buttonStyle(.plain)
            .focused(focusedControl, equals: .reviewExport)
            .disabled(!model.controlsEnabled)
            .accessibilityIdentifier("settings.privacy.export.review")
        }
    }

    private var noHistoryRow: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: "tray")
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: DSSpacing.xl)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(SettingsPrivacyL10n.noHistoryTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(noHistoryDetail)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.privacy.history.empty")
    }

    private var dataControlsCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                sectionHeader(
                    title: SettingsPrivacyL10n.dataControls,
                    detail: SettingsPrivacyL10n.dataControlsDetail,
                    systemImage: "trash",
                )

                VStack(spacing: DSSpacing.md) {
                    dataControlRows
                }
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
        .accessibilityIdentifier("settings.privacy.dataControls")
    }

    @ViewBuilder
    private var dataControlRows: some View {
        SettingsPrivacyDataControlRow(
            title: SettingsPrivacyL10n.deleteHistory,
            detail: SettingsPrivacyL10n.deleteHistoryDetail,
            actionTitle: SettingsPrivacyL10n.deleteHistoryAction,
            systemImage: "trash",
            enabled: model.hasRetainedHistory && model.controlsEnabled,
            textScale: textScale,
            increaseContrast: increaseContrast,
            identifier: "settings.privacy.delete.request",
            focusedControl: focusedControl,
            focusTarget: .requestDeleteHistory,
        ) {
            model.requestDeleteHistoryConfirmation()
        }

        Divider().overlay(Color.dsSeparator)

        SettingsPrivacyDataControlRow(
            title: SettingsPrivacyL10n.resetAll,
            detail: SettingsPrivacyL10n.resetAllDetail,
            actionTitle: SettingsPrivacyL10n.resetAllAction,
            systemImage: "arrow.counterclockwise",
            enabled: model.controlsEnabled,
            textScale: textScale,
            increaseContrast: increaseContrast,
            identifier: "settings.privacy.reset.request",
            focusedControl: focusedControl,
            focusTarget: .requestResetAll,
        ) {
            model.requestResetAllConfirmation()
        }
    }
}

private extension PrivacyAndDataSettingsView {
    private func sectionHeader(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: systemImage)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsAccent)
                .frame(width: DSSpacing.xl)
                .accessibilityHidden(true)

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
    }

    private func outlinedCard(@ViewBuilder content: () -> some View) -> some View {
        DSCard(content: content)
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(
                        Color.dsSeparator,
                        lineWidth: increaseContrast
                            ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                            : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                    )
            }
    }

    private func containsAnyStoredData(_ ids: Set<SettingsStoredDataID>) -> Bool {
        model.storedDataSummary.contains { ids.contains($0.id) }
    }

    private var noHistoryDetail: String {
        model.historyRetention == .keepNothing
            ? SettingsPrivacyL10n.noHistoryKeepNothing
            : SettingsPrivacyL10n.noHistoryCleared
    }

    private var showsOperationFeedback: Bool {
        if model.operationState != .idle { return true }
        return switch model.privacyOperation {
        case .exportSucceeded, .historyDeletionSucceeded, .resetSucceeded:
            true
        case .idle, .exporting, .deletingHistory, .resettingAll, .temporarilyBusy, .failed:
            false
        }
    }

    private var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    private var contentPadding: CGFloat { textScale == .largest ? DSSpacing.xl : DSSpacing.lg }
    private var sectionSpacing: CGFloat { textScale == .largest ? DSSpacing.xxl : DSSpacing.md }
}

#Preview("Privacy & data, transparency ledger") {
    SettingsFeatureView(model: .preview(.privacyDefault), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Privacy & data, no retained history") {
    SettingsFeatureView(model: .preview(.privacyNoHistory), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}
