import DesignSystem
import SwiftUI

struct ContextAndExclusionsSettingsView: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool
    let applicationPresentations: [SettingsExcludedApplicationPresentation]
    let applicationPicker: SettingsExcludedApplicationPicker?
    @State private var pickedApplications: [SettingsExcludedApplicationPresentation] = []
    @State private var isChoosingApplication = false

    var body: some View {
        VStack(spacing: 0) {
            if model.operationState != .idle {
                ContextSettingsOperationFeedback(model: model)
                    .padding(.bottom, DSSpacing.md)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    automaticQuietingSection
                    excludedApplicationsSection
                    returnBehaviorFooter
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .allowsHitTesting(model.controlsEnabled)
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .background(Color.dsBackground)
        .accessibilityIdentifier("settings.context")
    }

    private var automaticQuietingSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            sectionHeading(
                SettingsContextL10n.automaticQuieting,
                detail: SettingsContextL10n.automaticQuietingDetail,
            )

            outlinedCard {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    contextToggle(
                        ContextRowCopy(
                            title: SettingsContextL10n.presentationMode,
                            detail: SettingsContextL10n.presentationModeDetail,
                            systemImage: "rectangle.inset.filled.and.person.filled",
                        ),
                        isOn: model.preferences?.context.presentationModeSuppressionEnabled ?? false,
                        identifier: "settings.context.presentationMode",
                    ) { enabled in
                        await model.setPresentationModeSuppressionEnabled(enabled)
                    }

                    Divider().overlay(Color.dsSeparator)

                    contextToggle(
                        ContextRowCopy(
                            title: SettingsFeatureL10n.waitForLowFriction,
                            detail: SettingsContextL10n.lowFrictionDetail,
                            systemImage: "timer",
                        ),
                        isOn: model.preferences?.context.waitsForLowFrictionMoment ?? false,
                        identifier: "settings.context.lowFriction",
                    ) { enabled in
                        await model.setWaitsForLowFrictionMoment(enabled)
                    }

                    Divider().overlay(Color.dsSeparator)

                    contextInformationRow(
                        title: SettingsContextL10n.manualPause,
                        detail: SettingsContextL10n.manualPauseDetail,
                        systemImage: "pause.circle",
                        identifier: "settings.context.manualPause",
                    )

                    Divider().overlay(Color.dsSeparator)

                    contextInformationRow(
                        title: SettingsContextL10n.idleBehavior,
                        detail: SettingsContextL10n.idleBehaviorDetail,
                        systemImage: "moon.zzz",
                        identifier: "settings.context.idleBehavior",
                    )
                }
            }
        }
    }

    private var excludedApplicationsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            sectionHeading(
                SettingsContextL10n.excludedApps,
                detail: SettingsContextL10n.excludedAppsDetail,
            )

            outlinedCard {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    if model.excludedApplicationBundleIDs.isEmpty {
                        emptyApplications
                    } else {
                        ForEach(
                            Array(model.excludedApplicationBundleIDs.enumerated()),
                            id: \.element,
                        ) { index, bundleID in
                            excludedApplicationRow(bundleID: bundleID)
                            if index < model.excludedApplicationBundleIDs.count - 1 {
                                Divider().overlay(Color.dsSeparator)
                            }
                        }
                    }

                    if let applicationPicker {
                        if !model.excludedApplicationBundleIDs.isEmpty {
                            Divider().overlay(Color.dsSeparator)
                        }
                        Button(SettingsContextL10n.chooseApp) {
                            chooseApplication(using: applicationPicker)
                        }
                        .disabled(isChoosingApplication)
                        .accessibilityIdentifier("settings.context.excludedApps.choose")
                    }
                }
            }
            .accessibilityIdentifier("settings.context.excludedApps")
        }
    }

    private var emptyApplications: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: "app.dashed")
                .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(SettingsContextL10n.noExcludedApps)
                    .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(SettingsContextL10n.noExcludedAppsDetail)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.context.excludedApps.empty")
    }

    private func excludedApplicationRow(bundleID: String) -> some View {
        let presentation = presentation(for: bundleID)
        let name = presentation?.displayName ?? SettingsContextL10n.unavailableApp
        return HStack(spacing: DSSpacing.md) {
            (presentation?.icon ?? Image(systemName: "app"))
                .resizable()
                .scaledToFit()
                .frame(width: DSSpacing.xxl, height: DSSpacing.xxl)
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(name)
                    .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(bundleID)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: DSSpacing.md)

            Button {
                Task { await model.removeExcludedApplicationBundleID(bundleID) }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(SettingsContextL10n.removeApp(name))
            .accessibilityIdentifier("settings.context.excludedApps.remove.\(bundleID)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.context.excludedApps.\(bundleID)")
    }

    private var returnBehaviorFooter: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: "arrow.forward.circle")
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)
            Text(SettingsContextL10n.returnBehavior)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DSSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.context.returnBehavior")
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            Text(detail)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func outlinedCard(@ViewBuilder content: () -> some View) -> some View {
        DSCard(content: content)
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
            }
    }

    private func contextToggle(
        _ copy: ContextRowCopy,
        isOn: Bool,
        identifier: String,
        action: @escaping (Bool) async -> Void,
    ) -> some View {
        Toggle(
            isOn: Binding(
                get: { isOn },
                set: { enabled in Task { await action(enabled) } },
            ),
        ) {
            contextLabel(title: copy.title, detail: copy.detail, systemImage: copy.systemImage)
        }
        .accessibilityIdentifier(identifier)
    }

    private func contextInformationRow(
        title: String,
        detail: String,
        systemImage: String,
        identifier: String,
    ) -> some View {
        contextLabel(title: title, detail: detail, systemImage: systemImage)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
    }

    private func contextLabel(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .frame(width: DSSpacing.xl)
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(detail)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func presentation(for bundleID: String) -> SettingsExcludedApplicationPresentation? {
        (pickedApplications + applicationPresentations).first { $0.bundleID == bundleID }
    }

    private func chooseApplication(using picker: @escaping SettingsExcludedApplicationPicker) {
        guard !isChoosingApplication else { return }
        isChoosingApplication = true
        Task {
            defer { isChoosingApplication = false }
            guard let application = await picker() else { return }
            if !pickedApplications.contains(where: { $0.bundleID == application.bundleID }) {
                pickedApplications.append(application)
            }
            await model.addExcludedApplicationBundleID(application.bundleID)
        }
    }
}

private extension ContextAndExclusionsSettingsView {
    var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    var contentPadding: CGFloat { textScale == .largest ? DSSpacing.xl : DSSpacing.lg }
    var sectionSpacing: CGFloat { textScale == .largest ? DSSpacing.xxl : DSSpacing.xl }
}

private struct ContextRowCopy {
    let title: String
    let detail: String
    let systemImage: String
}

private struct ContextSettingsOperationFeedback: View {
    @Bindable var model: SettingsFeatureModel

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: model.operationState == .applying ? "arrow.triangle.2.circlepath" : "info.circle")
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)
            Text(message)
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DSSpacing.md)
            if model.canRetryLastChange {
                Button(SettingsFeatureL10n.retry) { Task { await model.retryLastChange() } }
                    .accessibilityIdentifier("settings.context.applyState.retry")
            }
        }
        .padding(DSSpacing.md)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .accessibilityIdentifier("settings.context.applyState")
    }

    private var message: String {
        switch model.operationState {
        case .idle: ""
        case .applying: SettingsFeatureL10n.applying
        case .temporarilyBusy: SettingsFeatureL10n.temporarilyBusy
        case .failed: SettingsFeatureL10n.applyFailed
        }
    }
}

#Preview("Context & exclusions — Empty") {
    SettingsFeatureView(
        model: .preview(.contextEmpty),
        loadsAutomatically: false,
        excludedApplicationPicker: {
            SettingsExcludedApplicationPresentation(
                bundleID: "com.apple.dt.Xcode",
                displayName: "Xcode",
                icon: Image(systemName: "hammer"),
            )
        },
    )
    .frame(width: 1000, height: 700)
}

#Preview("Context & exclusions — Populated") {
    SettingsFeatureView(
        model: .preview(.contextPopulated),
        loadsAutomatically: false,
        excludedApplicationPresentations: [
            SettingsExcludedApplicationPresentation(
                bundleID: "com.apple.dt.Xcode",
                displayName: "Xcode",
                icon: Image(systemName: "hammer"),
            ),
            SettingsExcludedApplicationPresentation(
                bundleID: "us.zoom.xos",
                displayName: "Zoom",
                icon: Image(systemName: "video"),
            ),
        ],
        excludedApplicationPicker: { nil },
    )
    .frame(width: 1000, height: 700)
}
