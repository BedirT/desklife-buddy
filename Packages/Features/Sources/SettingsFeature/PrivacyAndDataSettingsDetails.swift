import DesignSystem
import SwiftUI

extension PrivacyAndDataSettingsView {
    var storedDetailsDisclosure: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    showsStoredDetails.toggle()
                } label: {
                    disclosureLabel(
                        title: SettingsPrivacyL10n.whatIsStored,
                        detail: SettingsPrivacyL10n.whatIsStoredDetail,
                        systemImage: "internaldrive",
                        isExpanded: showsStoredDetails,
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showsStoredDetails {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        storedDataRows

                        Text(SettingsPrivacyL10n.storedBoundary)
                            .font(secondaryFont)
                            .foregroundStyle(Color.dsTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, DSSpacing.md)
                }
            }
        }
        .accessibilityIdentifier("settings.privacy.storedData")
    }

    @ViewBuilder
    var storedDataRows: some View {
        if containsAnyStoredData([
            .settingsAndPreferences,
            .excludedApplicationBundleIdentifiers,
            .integrationSelections,
            .onboardingCompletionMarker,
            .notificationAuthorizationMetadata,
        ]) {
            storedDataRow(
                title: SettingsPrivacyL10n.preferencesTitle,
                detail: SettingsPrivacyL10n.preferencesDetail,
                systemImage: "slider.horizontal.3",
            )
        }

        if containsAnyStoredData([.runtimeRecoveryState]) {
            storedDataRow(
                title: SettingsPrivacyL10n.timingTitle,
                detail: SettingsPrivacyL10n.timingDetail,
                systemImage: "clock",
            )
        }

        if containsAnyStoredData([.opportunityHistory]) {
            storedDataRow(
                title: SettingsPrivacyL10n.opportunityHistoryTitle,
                detail: SettingsPrivacyL10n.opportunityHistoryDetail,
                systemImage: "list.bullet.rectangle",
            )
        }

        if containsAnyStoredData([.estimatedActiveUseHistory]) {
            storedDataRow(
                title: SettingsPrivacyL10n.estimatedActiveUseHistoryTitle,
                detail: SettingsPrivacyL10n.estimatedActiveUseHistoryDetail,
                systemImage: "chart.bar.xaxis",
            )
        }
    }

    func storedDataRow(title: String, detail: String, systemImage: String) -> some View {
        SettingsPrivacyStoredDataRow(
            title: title,
            detail: detail,
            systemImage: systemImage,
            textScale: textScale,
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var dataControlsDisclosure: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    showsDataControls.toggle()
                } label: {
                    disclosureLabel(
                        title: SettingsPrivacyL10n.dataControls,
                        detail: SettingsPrivacyL10n.dataControlsDetail,
                        systemImage: "arrow.counterclockwise",
                        isExpanded: showsDataControls,
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focused(focusedControl, equals: .dataControlsDisclosure)

                if showsDataControls {
                    VStack(spacing: DSSpacing.md) {
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
                    .padding(.top, DSSpacing.md)
                }
            }
        }
        .accessibilityIdentifier("settings.privacy.dataControls")
    }

    func disclosureLabel(title: String, detail: String, systemImage: String, isExpanded: Bool) -> some View {
        HStack(alignment: .center, spacing: SettingsPageLayout.rowGap) {
            Image(systemName: systemImage)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: SettingsPageLayout.rowIconWidth)
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

            Spacer(minLength: DSSpacing.md)

            Image(systemName: "chevron.right")
                .foregroundStyle(Color.dsTextSecondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
    }

    func containsAnyStoredData(_ ids: Set<SettingsStoredDataID>) -> Bool {
        model.storedDataSummary.contains { ids.contains($0.id) }
    }
}
