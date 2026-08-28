import DesignSystem
import Domain
import Foundation
import SwiftUI

struct SettingsPrivacyExportSummaryHeader: View {
    @Environment(\.dsTextScale) private var textScale
    let retainedHistoryCount: Int
    let canExport: Bool
    let increaseContrast: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DSSpacing.md) {
                identity
                Spacer(minLength: DSSpacing.md)
                eventCount
                readyStatus
            }
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                identity
                HStack(spacing: DSSpacing.md) {
                    eventCount
                    Spacer(minLength: 0)
                    readyStatus
                }
            }
        }
        .padding(DSSpacing.md)
        .background(
            Color.dsSurface,
            in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .strokeBorder(
                    Color.dsSeparator,
                    lineWidth: increaseContrast
                        ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                        : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.privacy.export.summary")
    }

    private var identity: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "doc")
                .font(DSTypography.title)
                .foregroundStyle(Color.dsAccent)
                .accessibilityHidden(true)
            Text(SettingsPrivacyL10n.exportHistorySummaryTitle)
                .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
        }
    }

    private var eventCount: some View {
        Text(SettingsPrivacyL10n.exportEventCount(retainedHistoryCount))
            .font(textScale == .largest ? DSTypography.body : DSTypography.caption)
            .foregroundStyle(Color.dsTextSecondary)
            .fixedSize()
    }

    private var readyStatus: some View {
        Text(statusTitle)
            .font(textScale == .largest ? DSTypography.body.weight(.semibold) : DSTypography.caption.weight(.semibold))
            .foregroundStyle(statusTint)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(
                statusTint.opacity(SettingsPrivacyLayoutMetrics.exportActionFillOpacity),
                in: Capsule(),
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        statusTint.opacity(SettingsPrivacyLayoutMetrics.exportActionBorderOpacity),
                        lineWidth: increaseContrast
                            ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                            : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                    )
            }
            .fixedSize()
    }

    private var statusTitle: String {
        canExport
            ? SettingsPrivacyL10n.exportReadyStatus
            : SettingsPrivacyL10n.exportNeedsColumnsStatus
    }

    private var statusTint: Color {
        canExport ? .dsAccent : .dsDanger
    }
}

private extension HistoryExportFormat {
    var title: String {
        switch self {
        case .csv: SettingsPrivacyL10n.csv
        case .json: SettingsPrivacyL10n.json
        }
    }
}

struct SettingsPrivacyExportOptions: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool
    let focusedControl: FocusState<SettingsPrivacyFocusTarget?>.Binding

    var body: some View {
        VStack(spacing: 0) {
            receiptRow(
                title: SettingsPrivacyL10n.exportContains,
                detail: SettingsPrivacyL10n.exportContainsDetail,
            )
            Divider().overlay(Color.dsSeparator)
            receiptRow(
                title: SettingsPrivacyL10n.exportExcludes,
                detail: SettingsPrivacyL10n.exportExcludesDetail,
            )
            Divider().overlay(Color.dsSeparator)
            formatRow
            Divider().overlay(Color.dsSeparator)
            columnsDisclosure
        }
        .background(
            Color.dsSurfaceSecondary,
            in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .strokeBorder(
                    Color.dsSeparator,
                    lineWidth: increaseContrast
                        ? SettingsPrivacyLayoutMetrics.contrastOutlineWidth
                        : SettingsPrivacyLayoutMetrics.standardOutlineWidth,
                )
        }
        .accessibilityIdentifier("settings.privacy.export.options")
    }

    private func receiptRow(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.md) {
            Text(title)
                .font(labelFont)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: SettingsPrivacyLayoutMetrics.manifestLabelWidth, alignment: .leading)
            Text(detail)
                .font(valueFont)
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(DSSpacing.md)
        .accessibilityElement(children: .combine)
    }

    private var formatRow: some View {
        HStack(alignment: .center, spacing: DSSpacing.md) {
            Text(SettingsPrivacyL10n.exportFormat)
                .font(labelFont)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: SettingsPrivacyLayoutMetrics.manifestLabelWidth, alignment: .leading)

            Picker(
                SettingsPrivacyL10n.exportFormat,
                selection: Binding(
                    get: { model.selectedExportFormat },
                    set: { model.setExportFormat($0) },
                ),
            ) {
                ForEach(HistoryExportFormat.allCases, id: \.rawValue) { format in
                    Text(format.title).tag(format)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .focused(focusedControl, equals: .format)
            .disabled(!model.controlsEnabled || model.canRetryPrivacyOperation)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("settings.privacy.export.format")
        }
        .padding(DSSpacing.md)
    }

    private var columnsDisclosure: some View {
        VStack(spacing: 0) {
            Button {
                model.toggleExportColumns()
            } label: {
                HStack(spacing: DSSpacing.md) {
                    Text(SettingsPrivacyL10n.exportColumns)
                        .font(labelFont)
                        .foregroundStyle(Color.dsTextSecondary)
                        .frame(
                            width: SettingsPrivacyLayoutMetrics.manifestLabelWidth,
                            alignment: .leading,
                        )
                    Text(SettingsPrivacyL10n.exportSelectedColumnCount(
                        model.selectedExportFields.count,
                        total: HistoryExportField.allCases.count,
                    ))
                    .font(valueFont)
                    .foregroundStyle(Color.dsTextPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: model.isExportColumnsExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.dsTextSecondary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused(focusedControl, equals: .columns)
            .disabled(!model.controlsEnabled || model.canRetryPrivacyOperation)
            .padding(DSSpacing.md)
            .accessibilityLabel(SettingsPrivacyL10n.exportColumns)
            .accessibilityValue(SettingsPrivacyL10n.exportSelectedColumnCount(
                model.selectedExportFields.count,
                total: HistoryExportField.allCases.count,
            ))
            .accessibilityHint(
                model.isExportColumnsExpanded
                    ? SettingsPrivacyL10n.exportCollapseColumnsHint
                    : SettingsPrivacyL10n.exportExpandColumnsHint,
            )
            .accessibilityIdentifier("settings.privacy.export.columns")

            if model.isExportColumnsExpanded {
                Divider().overlay(Color.dsSeparator)
                LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: DSSpacing.sm) {
                    ForEach(model.exportFieldDisclosures, id: \.field) { disclosure in
                        fieldToggle(disclosure)
                    }
                }
                .padding(DSSpacing.md)
                .accessibilityIdentifier("settings.privacy.export.columnChoices")

                if model.selectedExportFields.isEmpty {
                    Text(SettingsPrivacyL10n.exportSelectAtLeastOneColumn)
                        .font(valueFont)
                        .foregroundStyle(Color.dsDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.bottom, DSSpacing.md)
                        .accessibilityIdentifier("settings.privacy.export.noColumns")
                }
            }
        }
    }

    private func fieldToggle(_ disclosure: SettingsExportFieldDisclosure) -> some View {
        Toggle(
            isOn: Binding(
                get: { model.selectedExportFields.contains(disclosure.field) },
                set: { selected in
                    guard selected != model.selectedExportFields.contains(disclosure.field) else {
                        return
                    }
                    model.toggleExportField(disclosure.field)
                },
            ),
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(fieldTitle(disclosure.field))
                    .font(valueFont.weight(.semibold))
                    .foregroundStyle(Color.dsTextPrimary)
                Text(disclosure.explanation)
                    .font(textScale == .largest ? DSTypography.body : DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.checkbox)
        .focused(focusedControl, equals: .field(disclosure.field))
        .disabled(!model.controlsEnabled || model.canRetryPrivacyOperation)
        .accessibilityIdentifier("settings.privacy.export.column.\(disclosure.field.rawValue)")
    }

    private var fieldColumns: [GridItem] {
        if textScale == .largest {
            return [GridItem(.flexible(), alignment: .topLeading)]
        }
        return [
            GridItem(.flexible(), spacing: DSSpacing.md, alignment: .topLeading),
            GridItem(.flexible(), alignment: .topLeading),
        ]
    }

    private func fieldTitle(_ field: HistoryExportField) -> String {
        switch field {
        case .id: SettingsPrivacyL10n.exportIDTitle
        case .recordedAt: SettingsPrivacyL10n.exportRecordedAtTitle
        case .kind: SettingsPrivacyL10n.exportKindTitle
        case .source: SettingsPrivacyL10n.exportSourceTitle
        case .opportunity: SettingsPrivacyL10n.exportOpportunityTitle
        case .selectedDurationSeconds: SettingsPrivacyL10n.exportSelectedDurationTitle
        }
    }

    private var labelFont: Font {
        textScale == .largest ? DSTypography.body.weight(.semibold) : DSTypography.caption.weight(.semibold)
    }

    private var valueFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }
}

#Preview("Privacy & data: Export columns expanded") {
    SettingsFeatureView(model: .preview(.privacyExportColumnsExpanded), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}
