import DesignSystem
import Domain
import SwiftUI

struct PrivacyAndDataSettingsView: View {
    @Environment(\.dsTextScale) var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool
    let focusedControl: FocusState<SettingsPrivacyFocusTarget?>.Binding
    @State var showsStoredDetails: Bool
    @State var showsDataControls: Bool

    init(
        model: SettingsFeatureModel,
        increaseContrast: Bool,
        focusedControl: FocusState<SettingsPrivacyFocusTarget?>.Binding,
        initiallyShowsStoredDetails: Bool = false,
        initiallyShowsDataControls: Bool = false,
    ) {
        self.model = model
        self.increaseContrast = increaseContrast
        self.focusedControl = focusedControl
        _showsStoredDetails = State(initialValue: initiallyShowsStoredDetails)
        _showsDataControls = State(initialValue: initiallyShowsDataControls)
    }

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
                    localStorageSummary
                    historyCard
                    storedDetailsDisclosure
                    dataControlsDisclosure
                }
                .padding(.vertical, contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .accessibilityIdentifier("settings.privacy")
    }

    private var localStorageSummary: some View {
        DSCard {
            HStack(alignment: .top, spacing: SettingsPageLayout.rowGap) {
                Image(systemName: "lock.shield")
                    .font(DSTypography.title)
                    .foregroundStyle(Color.dsAccent)
                    .frame(width: SettingsPageLayout.rowIconWidth)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(SettingsPrivacyL10n.storedOnThisMac)
                        .font(sectionTitleFont)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(SettingsPrivacyL10n.localStorageSummary)
                        .font(secondaryFont)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.privacy.localSummary")
    }

    private var historyCard: some View {
        outlinedCard {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                sectionHeader(
                    title: SettingsPrivacyL10n.historyTitle,
                    detail: SettingsPrivacyL10n.historyDetail,
                    systemImage: "clock.arrow.circlepath",
                )

                retentionRow
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

    private var retentionRow: some View {
        HStack(alignment: .center, spacing: SettingsPageLayout.rowGap) {
            Color.clear
                .frame(width: SettingsPageLayout.rowIconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(SettingsPrivacyL10n.keepHistoryFor)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(retentionSelection.wrappedValue.detail)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker(SettingsPrivacyL10n.keepHistoryFor, selection: retentionSelection) {
                ForEach(SettingsPrivacyRetentionChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .allowsHitTesting(model.controlsEnabled)
            .frame(minWidth: SettingsPageLayout.trailingControlWidth)
            .accessibilityIdentifier("settings.privacy.retention.picker")
        }
    }

    private var retentionSelection: Binding<SettingsPrivacyRetentionChoice> {
        Binding(
            get: {
                SettingsPrivacyRetentionChoice.allCases.first {
                    $0.policy == model.historyRetention
                } ?? .thirtyDays
            },
            set: { choice in
                Task { await model.setHistoryRetention(choice.policy) }
            },
        )
    }

    private var exportRow: some View {
        HStack(alignment: .center, spacing: SettingsPageLayout.rowGap) {
            Image(systemName: "square.and.arrow.up")
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: SettingsPageLayout.rowIconWidth)
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
            .allowsHitTesting(model.controlsEnabled)
            .accessibilityIdentifier("settings.privacy.export.review")
        }
    }

    private var noHistoryRow: some View {
        HStack(alignment: .top, spacing: SettingsPageLayout.rowGap) {
            Image(systemName: "tray")
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: SettingsPageLayout.rowIconWidth)
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
}

extension PrivacyAndDataSettingsView {
    private func sectionHeader(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: SettingsPageLayout.rowGap) {
            Image(systemName: systemImage)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsAccent)
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

    var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    private var contentPadding: CGFloat { SettingsPageLayout.contentInset(for: textScale) }
    private var sectionSpacing: CGFloat { SettingsPageLayout.sectionGap(for: textScale) }
}

private struct SettingsPrivacyPreviewHost: View {
    @FocusState private var focusedControl: SettingsPrivacyFocusTarget?
    let storedDetailsExpanded: Bool
    let dataControlsExpanded: Bool

    var body: some View {
        PrivacyAndDataSettingsView(
            model: .preview(.privacyDefault),
            increaseContrast: false,
            focusedControl: $focusedControl,
            initiallyShowsStoredDetails: storedDetailsExpanded,
            initiallyShowsDataControls: dataControlsExpanded,
        )
        .frame(width: 740, height: 700)
    }
}

#Preview("Privacy & data, calm overview") {
    SettingsFeatureView(model: .preview(.privacyDefault), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Privacy & data, stored details") {
    SettingsPrivacyPreviewHost(storedDetailsExpanded: true, dataControlsExpanded: false)
}

#Preview("Privacy & data, data controls") {
    SettingsPrivacyPreviewHost(storedDetailsExpanded: false, dataControlsExpanded: true)
}

#Preview("Privacy & data, no retained history") {
    SettingsFeatureView(model: .preview(.privacyNoHistory), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}
