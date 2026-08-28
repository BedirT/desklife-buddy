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
    private let excludedApplicationPresentations: [SettingsExcludedApplicationPresentation]
    private let excludedApplicationPicker: SettingsExcludedApplicationPicker?
    private let integrationsRuntime: SettingsIntegrationsRuntime
    private let integrationsActions: SettingsIntegrationsActions
    private let evidenceTopic: SettingsEvidenceTopic

    public init(
        model: SettingsFeatureModel,
        loadsAutomatically: Bool = true,
        increaseContrastOverride: Bool? = nil,
        deterministicSplitLayout: Bool = false,
        excludedApplicationPresentations: [SettingsExcludedApplicationPresentation] = [],
        excludedApplicationPicker: SettingsExcludedApplicationPicker? = nil,
        integrationsRuntime: SettingsIntegrationsRuntime = .unavailable,
        integrationsActions: SettingsIntegrationsActions = .none,
        evidenceTopic: SettingsEvidenceTopic = .visualResets,
    ) {
        _model = State(initialValue: model)
        self.loadsAutomatically = loadsAutomatically
        self.increaseContrastOverride = increaseContrastOverride
        self.deterministicSplitLayout = deterministicSplitLayout
        self.excludedApplicationPresentations = excludedApplicationPresentations
        self.excludedApplicationPicker = excludedApplicationPicker
        self.integrationsRuntime = integrationsRuntime
        self.integrationsActions = integrationsActions
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
        .background(Color.dsBackground)
        .task {
            if loadsAutomatically, model.phase == .loading {
                await model.load()
            }
        }
        .onExitCommand {
            handleExitCommand()
        }
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
        .accessibilityIdentifier("settings.window")
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Text(SettingsFeatureL10n.navigationTitle)
                .font(textScale == .largest ? DSTypography.largeTitle : DSTypography.title)
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.horizontal, DSSpacing.sm)

            SettingsSidebarGroup(
                title: SettingsFeatureL10n.scheduleAndBreaks,
                sections: [.schedule, .breakContent, .contextAndExclusions],
                model: model,
                focusedSection: $focusedSidebarSection,
            )

            SettingsSidebarGroup(
                title: SettingsFeatureL10n.personalize,
                sections: [.accessibility, .privacyAndData, .integrations],
                model: model,
                focusedSection: $focusedSidebarSection,
            )

            Spacer(minLength: DSSpacing.lg)

            SettingsSidebarGroup(
                title: SettingsFeatureL10n.learnAndSupport,
                sections: [.whyTheseDefaults, .safetyAndSupport],
                model: model,
                focusedSection: $focusedSidebarSection,
            )
        }
        .padding(DSSpacing.lg)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .glassEffect()
        .accessibilityIdentifier("settings.sidebar")
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Text(SettingsFeatureL10n.title(for: model.selectedSection))
                .font(DSTypography.largeTitle)
                .foregroundStyle(Color.dsTextPrimary)
                .accessibilityIdentifier("settings.detail.title")

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var increaseContrast: Bool {
        increaseContrastOverride ?? (systemContrast == .increased)
    }

    private var showsPrivacyModal: Bool {
        model.selectedSection == .privacyAndData
            && (model.isExportDisclosurePresented || model.pendingDestructiveOperation != nil)
    }

    private var privacyModalOrigin: SettingsPrivacyFocusTarget? {
        SettingsPrivacyFocusTarget.restoreTarget(
            exportDisclosurePresented: model.isExportDisclosurePresented,
            destructiveOperation: model.pendingDestructiveOperation,
        )
    }

    private func handleExitCommand() {
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

    private var sidebarWidth: CGFloat {
        if textScale == .largest {
            return 280
        }
        return deterministicSplitLayout ? 236 : 240
    }
}

private struct SettingsSidebarGroup: View {
    @Environment(\.dsTextScale) private var textScale
    let title: String
    let sections: [SettingsSection]
    @Bindable var model: SettingsFeatureModel
    let focusedSection: FocusState<SettingsSection?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(DSTypography.caption.weight(.semibold))
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.horizontal, DSSpacing.sm)

            ForEach(sections) { section in
                Button {
                    model.selectedSection = section
                } label: {
                    HStack(spacing: DSSpacing.sm) {
                        RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                            .fill(section.tileGradient)
                            .frame(width: DSSpacing.xxl, height: DSSpacing.xxl)
                            .overlay {
                                Image(systemName: section.systemImage)
                                    .font(DSTypography.caption.weight(.semibold))
                                    .foregroundStyle(Color.dsStaticText)
                                    .accessibilityHidden(true)
                            }

                        Text(SettingsFeatureL10n.title(for: section))
                            .font(textScale == .largest ? DSTypography.headline : DSTypography.body)
                            .foregroundStyle(Color.dsTextPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)

                        Spacer(minLength: DSSpacing.xs)

                        Image(systemName: "checkmark")
                            .font(DSTypography.caption.weight(.bold))
                            .foregroundStyle(Color.dsAccent)
                            .opacity(model.selectedSection == section ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
                    .background(
                        model.selectedSection == section ? Color.dsAccent.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
                    )
                    .contentShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
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
    }
}

private extension SettingsSection {
    var systemImage: String {
        switch self {
        case .schedule: "clock"
        case .breakContent: "figure.walk"
        case .contextAndExclusions: "moon"
        case .accessibility: "accessibility"
        case .privacyAndData: "hand.raised"
        case .integrations: "puzzlepiece.extension"
        case .whyTheseDefaults: "info.circle"
        case .safetyAndSupport: "cross.case"
        }
    }

    var tileGradient: LinearGradient {
        let colors: [Color] = switch self {
        case .schedule: [.dsMovementSeatedTileTop, .dsMovementSeatedTileBottom]
        case .breakContent: [.dsMovementWalkTileTop, .dsMovementWalkTileBottom]
        case .contextAndExclusions: [.dsMovementSmallSpaceTileTop, .dsMovementSmallSpaceTileBottom]
        case .accessibility: [.dsMovementSeatedTileTop, .dsMovementSmallSpaceTileBottom]
        case .privacyAndData: [.dsPositive, .dsAccent]
        case .integrations: [.dsMovementWalkTileTop, .dsMovementSmallSpaceTileBottom]
        case .whyTheseDefaults: [.dsWarning, .dsMovementWalkTileBottom]
        case .safetyAndSupport: [.dsDanger, .dsMovementSmallSpaceTileBottom]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

#Preview("Settings shell") {
    SettingsFeatureView(model: .preview(.balanced), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}
