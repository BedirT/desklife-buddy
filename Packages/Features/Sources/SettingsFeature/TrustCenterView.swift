import DesignSystem
import Domain
import SwiftUI

/// Sensing & Intelligence center detail (Epic 3 story 7).
///
/// Capability states, the sanitized live inspector, consent receipts,
/// stop/revoke guidance, and the story-5 export/delete entry points.
/// Every interactive element carries a `trustCenter.*` identifier, initial
/// keyboard focus lands on the stop control, and Escape dismisses the
/// delete confirmation.
public struct TrustCenterView: View {
    @Environment(\.dsTextScale) private var textScale
    @FocusState private var focusedControl: TrustCenterFocusTarget?
    private let snapshot: TrustCenterSnapshot
    private let actions: TrustCenterActions
    private let increaseContrast: Bool

    public init(
        snapshot: TrustCenterSnapshot,
        actions: TrustCenterActions = .none,
        increaseContrast: Bool = false,
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.increaseContrast = increaseContrast
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                if snapshot.isKillSwitchEngaged {
                    killSwitchBanner
                }
                TrustCenterCapabilitiesView(
                    snapshot: snapshot,
                    actions: actions,
                    increaseContrast: increaseContrast,
                    focusedControl: $focusedControl,
                )
                TrustCenterInspectorSectionView(
                    snapshot: snapshot,
                    increaseContrast: increaseContrast,
                )
                TrustCenterReceiptsSectionView(snapshot: snapshot)
                guidanceSection
                TrustCenterDataSectionView(
                    actions: actions,
                    focusedControl: $focusedControl,
                )
            }
            .padding(.vertical, contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .accessibilityIdentifier("trustCenter")
        .defaultFocus($focusedControl, .stopEverything)
    }

    private var killSwitchBanner: some View {
        DSCard {
            HStack(alignment: .top, spacing: SettingsPageLayout.rowGap) {
                Image(systemName: "octagon.fill")
                    .font(DSTypography.title)
                    .foregroundStyle(Color.dsDanger)
                    .frame(width: SettingsPageLayout.rowIconWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    HStack(spacing: DSSpacing.sm) {
                        Text(TrustCenterL10n.killSwitchTitle)
                            .font(sectionTitleFont)
                            .foregroundStyle(Color.dsTextPrimary)
                        DSTag(TrustCenterL10n.stateName(.revoked), style: .danger)
                    }
                    Text(TrustCenterL10n.killSwitchMessage)
                        .font(secondaryFont)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trustCenter.killSwitch")
    }

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TrustCenterSectionHeading(
                title: TrustCenterL10n.guidanceTitle,
                detail: TrustCenterL10n.guidanceDetail,
            )
            .accessibilityIdentifier("trustCenter.guidance")
        }
    }

    private var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    private var contentPadding: CGFloat { SettingsPageLayout.contentInset(for: textScale) }
    private var sectionSpacing: CGFloat { SettingsPageLayout.sectionGap(for: textScale) }
}

private struct TrustCenterCapabilitiesView: View {
    @Environment(\.dsTextScale) private var textScale
    let snapshot: TrustCenterSnapshot
    let actions: TrustCenterActions
    let increaseContrast: Bool
    let focusedControl: FocusState<TrustCenterFocusTarget?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TrustCenterSectionHeading(
                title: TrustCenterL10n.capabilitiesTitle,
                detail: TrustCenterL10n.capabilitiesDetail,
            )
            .accessibilityIdentifier("trustCenter.capabilities.heading")

            TrustCenterCard(increaseContrast: increaseContrast) {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    ForEach(snapshot.capabilities, id: \.capability) { presentation in
                        capabilityRow(presentation)
                    }
                    Divider().overlay(Color.dsSeparator)
                    if snapshot.isKillSwitchEngaged {
                        DSButton(TrustCenterL10n.resumeEverything, style: .secondary) {
                            Task { await actions.disengageKillSwitch() }
                        }
                        .focused(focusedControl, equals: .resumeEverything)
                        .accessibilityIdentifier("trustCenter.resumeEverything")
                    } else {
                        DSButton(TrustCenterL10n.stopEverything, style: .destructive) {
                            Task { await actions.engageKillSwitch() }
                        }
                        .focused(focusedControl, equals: .stopEverything)
                        .accessibilityIdentifier("trustCenter.stopEverything")
                    }
                }
            }
        }
        .accessibilityIdentifier("trustCenter.capabilities")
    }

    private func capabilityRow(_ presentation: TrustCenterCapabilityPresentation) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                Text(TrustCenterL10n.capabilityName(presentation.capability))
                    .font(sectionTitleFont)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer(minLength: DSSpacing.md)
                DSTag(
                    TrustCenterL10n.stateName(presentation.consentState),
                    style: tagStyle(for: presentation),
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(TrustCenterL10n.capabilityAccessibility(
                name: TrustCenterL10n.capabilityName(presentation.capability),
                state: presentation.consentState,
            ))

            Text(TrustCenterL10n.capabilityPurpose(presentation.capability))
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(TrustCenterL10n.pathDetail(open: presentation.pathOpen, sensing: presentation.capability.isSensing))
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            guidanceText(for: presentation.capability)

            if !presentation.killSwitchEngaged {
                capabilityActions(presentation)
            }
        }
        .accessibilityIdentifier("trustCenter.capability.\(presentation.capability.rawValue)")
    }

    @ViewBuilder
    private func guidanceText(for capability: PermissionCapability) -> some View {
        switch snapshot.guidance(for: capability) {
        case .explainerOwed:
            Text(TrustCenterL10n.explainer(for: capability))
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .settingsGuidance:
            Text(TrustCenterL10n.settingsGuidance)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func capabilityActions(_ presentation: TrustCenterCapabilityPresentation) -> some View {
        HStack(spacing: DSSpacing.sm) {
            switch presentation.consentState {
            case .unknown, .educating:
                DSButton(TrustCenterL10n.learn, style: .secondary) {
                    actions.beginEducation(presentation.capability)
                }
                .frame(maxWidth: 160)
                .accessibilityIdentifier("trustCenter.capability.\(presentation.capability.rawValue).learn")
                DSButton(TrustCenterL10n.allow, style: .primary) {
                    Task { await actions.grant(presentation.capability) }
                }
                .frame(maxWidth: 160)
                .focused(focusedControl, equals: .capabilityAction(presentation.capability))
                .accessibilityIdentifier("trustCenter.capability.\(presentation.capability.rawValue).allow")
            case .granted:
                DSButton(TrustCenterL10n.stop, style: .destructive) {
                    Task { await actions.revoke(presentation.capability) }
                }
                .frame(maxWidth: 160)
                .focused(focusedControl, equals: .capabilityAction(presentation.capability))
                .accessibilityIdentifier("trustCenter.capability.\(presentation.capability.rawValue).stop")
            case .denied, .revoked:
                DSButton(TrustCenterL10n.allow, style: .primary) {
                    Task { await actions.grant(presentation.capability) }
                }
                .frame(maxWidth: 160)
                .focused(focusedControl, equals: .capabilityAction(presentation.capability))
                .accessibilityIdentifier("trustCenter.capability.\(presentation.capability.rawValue).allow")
            }
        }
    }

    private func tagStyle(for presentation: TrustCenterCapabilityPresentation) -> DSTag.Style {
        if presentation.killSwitchEngaged {
            return .danger
        }
        switch presentation.consentState {
        case .granted:
            return .positive
        case .educating:
            return .accent
        case .revoked:
            return .warning
        case .unknown, .denied:
            return .neutral
        }
    }

    private var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }
}

private struct TrustCenterInspectorSectionView: View {
    @Environment(\.dsTextScale) private var textScale
    let snapshot: TrustCenterSnapshot
    let increaseContrast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TrustCenterSectionHeading(
                title: TrustCenterL10n.inspectorTitle,
                detail: TrustCenterL10n.inspectorDetail,
            )
            TrustCenterCard(increaseContrast: increaseContrast) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    inspectorRow(
                        title: TrustCenterL10n.leaseTitle,
                        detail: TrustCenterL10n.leaseDetail(
                            openWindows: snapshot.inspectorStatus.lease.openWindowCount,
                            blocked: snapshot.inspectorStatus.lease.issuanceBlocked,
                        ),
                        identifier: "trustCenter.inspector.lease",
                    )
                    Divider().overlay(Color.dsSeparator)
                    inspectorRow(
                        title: TrustCenterL10n.busTitle,
                        detail: TrustCenterL10n.busDetail(
                            admitted: snapshot.inspectorStatus.bus.admittedCount,
                            verdict: snapshot.inspectorStatus.bus.lastVerdictClassCode,
                        ),
                        identifier: "trustCenter.inspector.bus",
                    )
                    Divider().overlay(Color.dsSeparator)
                    inspectorRow(
                        title: TrustCenterL10n.firewallTitle,
                        detail: TrustCenterL10n.firewallDetail(
                            holds: snapshot.inspectorStatus.firewall.holdEventCount,
                            windowSeconds: Int(snapshot.inspectorStatus.firewall.windowSeconds),
                        ),
                        identifier: "trustCenter.inspector.firewall",
                    )
                }
            }
        }
        .accessibilityIdentifier("trustCenter.inspector")
    }

    private func inspectorRow(title: String, detail: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(sectionTitleFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(detail)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }
}

private struct TrustCenterReceiptsSectionView: View {
    @Environment(\.dsTextScale) private var textScale
    let snapshot: TrustCenterSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TrustCenterSectionHeading(
                title: TrustCenterL10n.receiptsTitle,
                detail: TrustCenterL10n.receiptsDetail,
            )
            if snapshot.receipts.isEmpty {
                DSEmptyState(
                    systemImage: "tray",
                    title: TrustCenterL10n.receiptsEmptyTitle,
                    message: TrustCenterL10n.receiptsEmptyMessage,
                )
                .accessibilityIdentifier("trustCenter.receipts.empty")
            } else {
                TrustCenterCard(increaseContrast: false) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        ForEach(Array(snapshot.receipts.enumerated()), id: \.offset) { _, receipt in
                            receiptRow(receipt)
                        }
                    }
                }
                .accessibilityIdentifier("trustCenter.receipts")
            }
        }
    }

    private func receiptRow(_ receipt: TrustCenterReceiptPresentation) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(capabilityName(for: receipt.scopeCode))
                    .font(sectionTitleFont)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(Self.receiptDateFormatter.string(from: receipt.recordedAt))
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Spacer(minLength: DSSpacing.md)
            DSTag(TrustCenterL10n.statusName(receipt.statusCode), style: .neutral)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(TrustCenterL10n.receiptAccessibility(
            scope: capabilityName(for: receipt.scopeCode),
            status: receipt.statusCode,
            date: Self.receiptDateFormatter.string(from: receipt.recordedAt),
        ))
        .accessibilityIdentifier(receipt.rowIdentifier)
    }

    private func capabilityName(for scopeCode: String) -> String {
        if let capability = PermissionCapability.allCases.first(where: { $0.scopeCode == scopeCode }) {
            return TrustCenterL10n.capabilityName(capability)
        }
        return scopeCode
    }

    private var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    private static let receiptDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct TrustCenterDataSectionView: View {
    @Environment(\.dsTextScale) private var textScale
    @State private var confirmingDelete = false
    @State private var exportResult: TrustCenterExportResult?
    @State private var deleteResult: TrustCenterDeleteResult?
    let actions: TrustCenterActions
    let focusedControl: FocusState<TrustCenterFocusTarget?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TrustCenterSectionHeading(
                title: TrustCenterL10n.dataTitle,
                detail: TrustCenterL10n.dataDetail,
            )
            TrustCenterCard(increaseContrast: false) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    if let feedback = dataFeedback {
                        Text(feedback)
                            .font(secondaryFont)
                            .foregroundStyle(Color.dsTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("trustCenter.data.feedback")
                    }
                    HStack(spacing: DSSpacing.sm) {
                        DSButton(TrustCenterL10n.export, style: .secondary) {
                            Task {
                                exportResult = await actions.exportTrustData()
                            }
                        }
                        .focused(focusedControl, equals: .exportData)
                        .accessibilityIdentifier("trustCenter.export")
                        DSButton(TrustCenterL10n.delete, style: .destructive) {
                            confirmingDelete = true
                        }
                        .focused(focusedControl, equals: .deleteData)
                        .accessibilityIdentifier("trustCenter.delete")
                    }
                }
            }
        }
        .accessibilityIdentifier("trustCenter.data")
        .onExitCommand {
            if confirmingDelete {
                confirmingDelete = false
            }
        }
        .sheet(isPresented: $confirmingDelete) {
            deleteConfirmation
        }
    }

    private var deleteConfirmation: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(TrustCenterL10n.deleteConfirmTitle)
                .font(sectionTitleFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(TrustCenterL10n.deleteConfirmMessage)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: DSSpacing.sm) {
                DSButton(TrustCenterL10n.cancel, style: .secondary) {
                    confirmingDelete = false
                }
                .focused(focusedControl, equals: .cancelDelete)
                .accessibilityIdentifier("trustCenter.delete.cancel")
                DSButton(TrustCenterL10n.confirmDelete, style: .destructive) {
                    confirmingDelete = false
                    Task {
                        deleteResult = await actions.deleteTrustData()
                    }
                }
                .focused(focusedControl, equals: .confirmDelete)
                .accessibilityIdentifier("trustCenter.delete.confirm")
            }
        }
        .padding(DSSpacing.xl)
        .frame(width: 420)
        .onExitCommand {
            confirmingDelete = false
        }
        .accessibilityIdentifier("trustCenter.delete.confirmation")
    }

    private var dataFeedback: String? {
        if let deleteResult {
            switch deleteResult {
            case let .deleted(receiptCount, decisionCount):
                return TrustCenterL10n.deleteDone(receipts: receiptCount, decisions: decisionCount)
            case .failed, .unavailable:
                return TrustCenterL10n.deleteFailed
            }
        }
        if let exportResult {
            switch exportResult {
            case .saved:
                return TrustCenterL10n.exportSaved
            case .cancelled:
                return TrustCenterL10n.exportCancelled
            case .failed, .unavailable:
                return TrustCenterL10n.exportFailed
            }
        }
        return nil
    }

    private var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }
}

struct TrustCenterSectionHeading: View {
    @Environment(\.dsTextScale) private var textScale
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            Text(detail)
                .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TrustCenterCard<Content: View>: View {
    let increaseContrast: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        DSCard(content: content)
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
            }
    }
}

enum TrustCenterFocusTarget: Hashable {
    case stopEverything
    case resumeEverything
    case capabilityAction(PermissionCapability)
    case exportData
    case deleteData
    case cancelDelete
    case confirmDelete
}

#Preview("Trust center — granted") {
    TrustCenterView(snapshot: .preview(.granted))
        .frame(width: 700, height: 680)
}

#Preview("Trust center — kill switch") {
    TrustCenterView(snapshot: .preview(.killSwitchEngaged))
        .frame(width: 700, height: 680)
}
