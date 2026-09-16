import DesignSystem
import Domain
import Foundation
import SwiftUI

public struct SettingsFeatureView: View {
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dsTextScale) private var textScale
    @State private var model: SettingsFeatureModel
    @FocusState private var focusedSidebarSection: SettingsSection?
    @FocusState private var focusedPrivacyControl: SettingsPrivacyFocusTarget?
    @State private var privacyFocusRestoreTarget: SettingsPrivacyFocusTarget?
    private let loadsAutomatically: Bool
    private let increaseContrastOverride: Bool?
    private let deterministicSplitLayout: Bool
    private let focusedSidebarSectionOverride: SettingsSection?
    private let excludedApplicationPresentations: [SettingsExcludedApplicationPresentation]
    private let excludedApplicationPicker: SettingsExcludedApplicationPicker?
    private let integrationsRuntime: SettingsIntegrationsRuntime
    private let integrationsActions: SettingsIntegrationsActions
    /// Live pairing sheet model from the App composition root. Nil hides the
    /// pairing row wherever the seam is unwired.
    private let companionPairingModel: CompanionPairingSheetModel?
    private let trustCenterSnapshot: TrustCenterSnapshot
    private let trustCenterActions: TrustCenterActions
    private let trustCenterRulesSnapshot: TrustCenterRulesSnapshot?
    private let trustCenterRulesActions: TrustCenterRulesActions
    private let evidenceTopic: SettingsEvidenceTopic

    public init(
        model: SettingsFeatureModel,
        loadsAutomatically: Bool = true,
        increaseContrastOverride: Bool? = nil,
        deterministicSplitLayout: Bool = false,
        focusedSidebarSectionOverride: SettingsSection? = nil,
        excludedApplicationPresentations: [SettingsExcludedApplicationPresentation] = [],
        excludedApplicationPicker: SettingsExcludedApplicationPicker? = nil,
        integrationsRuntime: SettingsIntegrationsRuntime = .unavailable,
        integrationsActions: SettingsIntegrationsActions = .none,
        companionPairingModel: CompanionPairingSheetModel? = nil,
        trustCenterSnapshot: TrustCenterSnapshot? = nil,
        trustCenterActions: TrustCenterActions = .none,
        trustCenterRulesSnapshot: TrustCenterRulesSnapshot? = nil,
        trustCenterRulesActions: TrustCenterRulesActions = .none,
        evidenceTopic: SettingsEvidenceTopic = .visualResets,
    ) {
        _model = State(initialValue: model)
        self.loadsAutomatically = loadsAutomatically
        self.increaseContrastOverride = increaseContrastOverride
        self.deterministicSplitLayout = deterministicSplitLayout
        self.focusedSidebarSectionOverride = focusedSidebarSectionOverride
        self.excludedApplicationPresentations = excludedApplicationPresentations
        self.excludedApplicationPicker = excludedApplicationPicker
        self.integrationsRuntime = integrationsRuntime
        self.integrationsActions = integrationsActions
        self.companionPairingModel = companionPairingModel
        self.trustCenterSnapshot = trustCenterSnapshot ?? TrustCenterSnapshot.preview(.empty)
        self.trustCenterActions = trustCenterActions
        self.trustCenterRulesSnapshot = trustCenterRulesSnapshot
        self.trustCenterRulesActions = trustCenterRulesActions
        self.evidenceTopic = evidenceTopic
    }

    public var body: some View {
        ZStack {
            HStack(alignment: .top, spacing: DSSpacing.xl) {
                sidebar
                    .frame(width: sidebarWidth)

                detail
            }
            .padding(DSSpacing.xl)
            .allowsHitTesting(!showsPrivacyModal)
            .accessibilityHidden(showsPrivacyModal)

            if showsPrivacyModal {
                SettingsPrivacyModalOverlay(
                    model: model,
                    increaseContrast: increaseContrast,
                    focusedControl: $focusedPrivacyControl,
                )
            }
        }
        .frame(minWidth: 780, minHeight: 560)
        .background {
            SettingsCanvasBackground()
                .ignoresSafeArea()
        }
        .task {
            if loadsAutomatically, model.phase == .loading {
                await model.load()
            }
        }
        .onExitCommand {
            handleExitCommand()
        }
        .defaultFocus($focusedSidebarSection, model.selectedSection)
        .onChange(of: showsPrivacyModal) { _, isPresented in
            if isPresented {
                privacyFocusRestoreTarget = privacyModalOrigin
                Task { @MainActor in
                    await Task.yield()
                    focusedPrivacyControl = .initialModalTarget
                }
            } else if let fallbackTarget = privacyFocusRestoreTarget {
                let restorationTarget = SettingsPrivacyFocusTarget.restorationTarget(
                    after: model.privacyOperation,
                    fallback: fallbackTarget,
                )
                privacyFocusRestoreTarget = nil
                Task { @MainActor in
                    await Task.yield()
                    focusedPrivacyControl = restorationTarget
                }
            }
        }
    }

    private var sidebar: some View {
        sidebarContent
            .accessibilityElement(children: .contain)
    }

    private var sidebarContent: some View {
        ViewThatFits(in: .vertical) {
            VStack(alignment: .leading, spacing: sidebarGroupSpacing) {
                primarySidebarGroups
                Spacer(minLength: sidebarGroupSpacing)
                helpSidebarGroup
            }
            .padding(.vertical, sidebarVerticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            ScrollView {
                VStack(alignment: .leading, spacing: sidebarGroupSpacing) {
                    primarySidebarGroups
                    helpSidebarGroup
                }
                .padding(.vertical, sidebarVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var primarySidebarGroups: some View {
        SettingsSidebarGroup(
            title: SettingsFeatureL10n.breaks,
            sections: [.schedule, .breakContent, .contextAndExclusions],
            model: model,
            focusedSection: $focusedSidebarSection,
            focusedSectionOverride: focusedSidebarSectionOverride,
        )
        SettingsSidebarGroup(
            title: SettingsFeatureL10n.app,
            sections: [.accessibility, .integrations],
            model: model,
            focusedSection: $focusedSidebarSection,
            focusedSectionOverride: focusedSidebarSectionOverride,
        )
        SettingsSidebarGroup(
            title: SettingsFeatureL10n.dataAndPrivacy,
            sections: [.privacyAndData, .sensingAndIntelligence],
            model: model,
            focusedSection: $focusedSidebarSection,
            focusedSectionOverride: focusedSidebarSectionOverride,
        )
    }

    private var helpSidebarGroup: some View {
        SettingsSidebarGroup(
            title: SettingsFeatureL10n.help,
            sections: [.whyTheseDefaults, .safetyAndSupport],
            model: model,
            focusedSection: $focusedSidebarSection,
            focusedSectionOverride: focusedSidebarSectionOverride,
        )
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            detailHeader

            Group {
                switch model.phase {
                case .loading:
                    ProgressView(SettingsFeatureL10n.loading)
                        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("settings.loading")
                case .loadFailed:
                    VStack(spacing: DSSpacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(DSTypography.title)
                            .accessibilityHidden(true)
                        Text(SettingsFeatureL10n.loadFailedTitle)
                            .font(DSTypography.title)
                        Text(SettingsFeatureL10n.loadFailedMessage)
                            .font(textScale == .largest ? DSTypography.title : DSTypography.body)
                            .foregroundStyle(Color.dsTextSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(SettingsFeatureL10n.retry) {
                            Task { await model.load() }
                        }
                        .accessibilityIdentifier("settings.load.retry")
                    }
                    .padding(DSSpacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("settings.load.error")
                case .ready where model.selectedSection == .schedule:
                    ScheduleSettingsView(
                        model: model,
                        increaseContrast: increaseContrast,
                    )
                case .ready where model.selectedSection == .breakContent:
                    BreakContentSettingsView(
                        model: model,
                        increaseContrast: increaseContrast,
                    )
                case .ready where model.selectedSection == .contextAndExclusions:
                    ContextAndExclusionsSettingsView(
                        model: model,
                        increaseContrast: increaseContrast,
                        applicationPresentations: excludedApplicationPresentations,
                        applicationPicker: excludedApplicationPicker,
                    )
                case .ready where model.selectedSection == .accessibility:
                    AccessibilitySettingsView(
                        model: model,
                        increaseContrast: increaseContrast,
                    )
                case .ready where model.selectedSection == .privacyAndData:
                    PrivacyAndDataSettingsView(
                        model: model,
                        increaseContrast: increaseContrast,
                        focusedControl: $focusedPrivacyControl,
                    )
                case .ready where model.selectedSection == .integrations:
                    IntegrationsSettingsView(
                        model: model,
                        runtime: integrationsRuntime,
                        actions: integrationsActions,
                        increaseContrast: increaseContrast,
                        companionPairing: companionPairingModel,
                    )
                case .ready where model.selectedSection == .sensingAndIntelligence:
                    TrustCenterView(
                        snapshot: trustCenterSnapshot,
                        actions: trustCenterActions,
                        increaseContrast: increaseContrast,
                        rulesSnapshot: trustCenterRulesSnapshot,
                        rulesActions: trustCenterRulesActions,
                    )
                case .ready where model.selectedSection == .whyTheseDefaults:
                    WhyDefaultsSettingsView(
                        increaseContrast: increaseContrast,
                        selectedTopic: evidenceTopic,
                    )
                case .ready where model.selectedSection == .safetyAndSupport:
                    SafetySupportSettingsView(increaseContrast: increaseContrast)
                case .ready:
                    DSEmptyState(
                        systemImage: model.selectedSection.systemImage,
                        title: SettingsFeatureL10n.comingLaterTitle,
                        message: SettingsFeatureL10n.comingLaterMessage,
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("settings.section.placeholder")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(SettingsPageLayout.contentInset(for: textScale))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.dsContentCanvas, in: detailShape)
        .accessibilityElement(children: .contain)
    }
}

private extension SettingsFeatureView {
    @ViewBuilder
    var detailHeader: some View {
        if model.isContentLibraryPresented, model.selectedSection == .breakContent {
            GeometryReader { geometry in
                Text(detailTitle)
                    .font(DSTypography.largeTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: geometry.size.width < SettingsContentLibraryLayout.wideMinimumWidth
                            ? .center
                            : .leading,
                    )
                    .accessibilityIdentifier("settings.detail.title")
            }
            .frame(height: 31)
        } else {
            Text(detailTitle)
                .font(DSTypography.largeTitle)
                .foregroundStyle(Color.dsTextPrimary)
                .accessibilityIdentifier("settings.detail.title")
        }
    }

    var increaseContrast: Bool {
        increaseContrastOverride ?? (systemContrast == .increased)
    }

    var detailTitle: String {
        if model.selectedSection == .breakContent, model.isContentLibraryPresented {
            return SettingsFeatureL10n.contentLibrary
        }
        return SettingsFeatureL10n.title(for: model.selectedSection)
    }

    var showsPrivacyModal: Bool {
        model.selectedSection == .privacyAndData
            && (model.isExportDisclosurePresented || model.pendingDestructiveOperation != nil)
    }

    var privacyModalOrigin: SettingsPrivacyFocusTarget? {
        SettingsPrivacyFocusTarget.restoreTarget(
            exportDisclosurePresented: model.isExportDisclosurePresented,
            destructiveOperation: model.pendingDestructiveOperation,
        )
    }

    func handleExitCommand() {
        guard showsPrivacyModal else {
            dismiss()
            return
        }
        guard !model.privacyOperation.isInProgress else { return }
        if model.isExportDisclosurePresented {
            model.dismissExportDisclosure()
        } else {
            model.cancelPendingDestructiveOperation()
        }
    }

    var sidebarWidth: CGFloat {
        if textScale == .largest {
            return 252
        }
        return deterministicSplitLayout ? 212 : 216
    }

    var sidebarVerticalPadding: CGFloat { DSSpacing.lg }
    var sidebarGroupSpacing: CGFloat { textScale == .largest ? DSSpacing.lg : DSSpacing.md }

    var detailShape: ConcentricRectangle {
        ConcentricRectangle(
            corners: .concentric(minimum: .fixed(DSRadius.lg)),
            isUniform: true,
        )
    }
}

private struct SettingsSidebarGroup: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dsTextScale) private var textScale
    let title: String
    let sections: [SettingsSection]
    @Bindable var model: SettingsFeatureModel
    let focusedSection: FocusState<SettingsSection?>.Binding
    let focusedSectionOverride: SettingsSection?

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(DSTypography.caption.weight(.semibold))
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.horizontal, DSSpacing.xs)
                .padding(.bottom, DSSpacing.xs)

            ForEach(sections) { section in
                Button {
                    model.selectedSection = section
                } label: {
                    HStack(spacing: DSSpacing.sm) {
                        sidebarTileShape
                            .fill(section.tileGradient)
                            .frame(width: tileSize, height: tileSize)
                            .overlay {
                                Image(systemName: section.systemImage)
                                    .font(DSTypography.caption.weight(.semibold))
                                    .foregroundStyle(Color.dsStaticText)
                                    .accessibilityHidden(true)
                            }
                        Text(SettingsFeatureL10n.title(for: section))
                            .font(textScale == .largest ? DSTypography.headline : DSTypography.subtext)
                            .foregroundStyle(Color.dsTextPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                        Spacer(minLength: 0)
                    }
                    .padding(DSSpacing.sm)
                    .background(
                        model.selectedSection == section ? Color.dsSurfaceSecondary.opacity(0.78) : Color.clear,
                        in: sidebarControlShape,
                    )
                    .overlay {
                        if focusedSection.wrappedValue == section || focusedSectionOverride == section {
                            sidebarControlShape.stroke(
                                Color.dsAccent,
                                lineWidth: colorSchemeContrast == .increased ? 2 : 1,
                            )
                        }
                    }
                    .contentShape(sidebarControlShape)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .focused(focusedSection, equals: section)
                .onMoveCommand { direction in
                    switch direction {
                    case .up:
                        model.moveSidebarSelection(by: -1)
                    case .down:
                        model.moveSidebarSelection(by: 1)
                    default:
                        return
                    }
                    focusedSection.wrappedValue = model.selectedSection
                }
                .accessibilityAddTraits(model.selectedSection == section ? .isSelected : [])
                .accessibilityIdentifier("settings.sidebar.\(section.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sidebarControlShape: ConcentricRectangle {
        ConcentricRectangle(
            corners: .concentric(minimum: .fixed(DSRadius.lg)),
            isUniform: true,
        )
    }

    private var sidebarTileShape: ConcentricRectangle {
        ConcentricRectangle(
            corners: .concentric(minimum: .fixed(DSSpacing.sm)),
            isUniform: true,
        )
    }

    private var tileSize: CGFloat {
        textScale == .largest ? DSSpacing.xxl : DSSpacing.xl
    }
}

#Preview("Settings shell") {
    SettingsFeatureView(model: .preview(.balanced), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}
