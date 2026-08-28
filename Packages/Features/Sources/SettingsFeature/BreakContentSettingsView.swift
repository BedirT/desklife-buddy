import DesignSystem
import Domain
import PreferencePresentation
import SwiftUI

struct BreakContentSettingsView: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool

    var body: some View {
        Group {
            if model.isContentLibraryPresented {
                SettingsContentLibraryView(model: model, increaseContrast: increaseContrast)
            } else {
                preferences
            }
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .background(Color.dsBackground)
        .accessibilityIdentifier("settings.breakContent")
    }

    private var preferences: some View {
        VStack(spacing: 0) {
            if model.operationState != .idle {
                BreakContentOperationFeedback(model: model)
                    .padding(.bottom, DSSpacing.md)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    preferredMovementSection
                    contentChoicesSection
                    libraryEntry
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .allowsHitTesting(model.controlsEnabled)
        }
    }

    private var preferredMovementSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(SettingsFeatureL10n.preferredMovement)
                .font(sectionTitleFont)
                .foregroundStyle(Color.dsTextSecondary)

            Text(SettingsFeatureL10n.preferredMovementExplanation)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if textScale == .largest {
                    VStack(spacing: DSSpacing.md) { movementChoices }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: DSSpacing.md,
                    ) {
                        movementChoices
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(SettingsFeatureL10n.preferredMovement)
        }
    }

    @ViewBuilder
    private var movementChoices: some View {
        ForEach(PreferredMovementContent.allCases, id: \.rawValue) { preference in
            MovementPreferenceButton(
                preference: preference,
                selected: model.breakContentPreferences?.preferredMovement == preference,
                increaseContrast: increaseContrast,
            ) {
                Task { await model.setPreferredMovement(preference) }
            }
        }
    }

    private var contentChoicesSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(SettingsFeatureL10n.contentChoices)
                .font(sectionTitleFont)
                .foregroundStyle(Color.dsTextSecondary)

            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    settingsToggle(
                        title: SettingsFeatureL10n.quickMovementOption,
                        detail: SettingsFeatureL10n.quickMovementOptionDetail,
                        isOn: model.breakContentPreferences?.showsQuickMovementOption ?? false,
                        identifier: "settings.breakContent.quickMovementOption",
                    ) { enabled in
                        await model.setShowsQuickMovementOption(enabled)
                    }

                    Divider().overlay(Color.dsSeparator)

                    settingsToggle(
                        title: SettingsFeatureL10n.breathingContent,
                        detail: SettingsFeatureL10n.breathingContentDetail,
                        isOn: model.breakContentPreferences?.includesBreathingContent ?? false,
                        identifier: "settings.breakContent.breathingContent",
                    ) { enabled in
                        await model.setIncludesBreathingContent(enabled)
                    }

                    Divider().overlay(Color.dsSeparator)

                    settingsToggle(
                        title: SettingsFeatureL10n.standingDeskMode,
                        detail: SettingsFeatureL10n.standingDeskModeDetail,
                        isOn: model.breakContentPreferences?.standingDeskModeEnabled ?? false,
                        identifier: "settings.breakContent.standingDeskMode",
                    ) { enabled in
                        await model.setStandingDeskModeEnabled(enabled)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
            }
        }
    }

    private var libraryEntry: some View {
        DSCard {
            Group {
                if textScale == .largest {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        libraryEntryCopy
                        browseLibraryButton
                    }
                } else {
                    HStack(spacing: DSSpacing.xl) {
                        libraryEntryCopy
                        Spacer(minLength: DSSpacing.md)
                        browseLibraryButton
                    }
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
        }
        .accessibilityIdentifier("settings.breakContent.libraryEntry")
    }

    private var libraryEntryCopy: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Label(SettingsFeatureL10n.contentLibrary, systemImage: "books.vertical")
                .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            Text(SettingsFeatureL10n.contentLibrarySummary)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var browseLibraryButton: some View {
        Button(SettingsFeatureL10n.browseContentLibrary) {
            model.openContentLibrary()
        }
        .accessibilityIdentifier("settings.breakContent.browseLibrary")
    }

    private func settingsToggle(
        title: String,
        detail: String,
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
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(detail)
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.headline : DSTypography.caption
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    private var contentPadding: CGFloat { textScale == .largest ? DSSpacing.xl : DSSpacing.lg }
    private var sectionSpacing: CGFloat { textScale == .largest ? DSSpacing.xxl : DSSpacing.xl }
}

private struct MovementPreferenceButton: View {
    let preference: PreferredMovementContent
    let selected: Bool
    let increaseContrast: Bool
    let action: () -> Void

    var body: some View {
        PreferenceMovementChoiceButton(
            title: preference.localizedTitle,
            detail: preference.localizedDetail,
            selected: selected,
            increaseContrast: increaseContrast,
            accessibilityIdentifier: "settings.breakContent.movement.\(preference.rawValue)",
            action: action,
        )
    }
}

private struct BreakContentOperationFeedback: View {
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
            }
        }
        .padding(DSSpacing.md)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .accessibilityIdentifier("settings.breakContent.applyState")
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

private extension PreferredMovementContent {
    var localizedTitle: String {
        switch self {
        case .walkOrEquivalent: SettingsFeatureL10n.movementWalkOrWheel
        case .seatedActive: SettingsFeatureL10n.movementSeated
        case .mixed: SettingsFeatureL10n.movementMixed
        case .positionChangeOnly: SettingsFeatureL10n.movementPosition
        }
    }

    var localizedDetail: String {
        switch self {
        case .walkOrEquivalent: SettingsFeatureL10n.movementWalkOrWheelDetail
        case .seatedActive: SettingsFeatureL10n.movementSeatedDetail
        case .mixed: SettingsFeatureL10n.movementMixedDetail
        case .positionChangeOnly: SettingsFeatureL10n.positionChangeHonesty
        }
    }
}

#Preview("Break content — Default") {
    SettingsFeatureView(model: .preview(.breakContentDefault), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Break content — Customized") {
    SettingsFeatureView(model: .preview(.breakContentCustomized), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}
