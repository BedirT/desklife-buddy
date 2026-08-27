import DesignSystem
import SwiftUI

public enum HeadsUpPermissionControl: Hashable, Sendable {
    case useInApp
    case continueRequest
    case openSettings
}

public enum HeadsUpPermissionSurface: Equatable, Sendable {
    case inContextExplainer
    case settings(HeadsUpPermissionSettingsState)

    var presentation: HeadsUpPermissionPresentation {
        switch self {
        case .inContextExplainer:
            .inContextExplainer
        case let .settings(state):
            .settings(for: state)
        }
    }

    var primaryAction: HeadsUpPermissionAction {
        switch self {
        case .inContextExplainer:
            .continueToSystemRequest
        case .settings:
            .openNotificationSettings
        }
    }

    var secondaryAction: HeadsUpPermissionAction? {
        switch self {
        case .inContextExplainer:
            .useInAppHeadsUp
        case .settings:
            nil
        }
    }

    var cancelAction: HeadsUpPermissionAction {
        switch self {
        case .inContextExplainer:
            .useInAppHeadsUp
        case .settings:
            .dismiss
        }
    }

    var initialFocus: HeadsUpPermissionControl {
        switch self {
        case .inContextExplainer:
            .useInApp
        case .settings:
            .openSettings
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .inContextExplainer:
            "headsUp.permission.explainer"
        case .settings(.denied):
            "headsUp.permission.denied"
        case .settings(.revoked):
            "headsUp.permission.revoked"
        }
    }
}

public enum HeadsUpPermissionAction: Equatable, Sendable {
    case continueToSystemRequest
    case useInAppHeadsUp
    case openNotificationSettings
    case dismiss
}

public struct HeadsUpPermissionView: View {
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Environment(\.dsTextScale) private var textScale
    @FocusState private var focusedControl: HeadsUpPermissionControl?

    private let surface: HeadsUpPermissionSurface
    private let focusedControlOverride: HeadsUpPermissionControl?
    private let increaseContrastOverride: Bool
    private let onAction: (HeadsUpPermissionAction) -> Void

    public init(
        surface: HeadsUpPermissionSurface,
        focusedControlOverride: HeadsUpPermissionControl? = nil,
        increaseContrastOverride: Bool = false,
        onAction: @escaping (HeadsUpPermissionAction) -> Void,
    ) {
        self.surface = surface
        self.focusedControlOverride = focusedControlOverride
        self.increaseContrastOverride = increaseContrastOverride
        self.onAction = onAction
    }

    public var body: some View {
        Group {
            switch surface {
            case .inContextExplainer:
                explainerSurface
            case .settings:
                settingsSection
            }
        }
        .onAppear {
            focusedControl = focusedControlOverride ?? surface.initialFocus
        }
        .onExitCommand {
            onAction(surface.cancelAction)
        }
    }

    private var explainerSurface: some View {
        ZStack {
            Color.dsBackground

            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    Image(systemName: symbolName)
                        .font(DSTypography.headsUpText(pointSize: titleSize))
                        .foregroundStyle(Color.dsAccent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text(surface.presentation.title)
                            .font(DSTypography.headsUpText(pointSize: titleSize))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.dsTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(surface.presentation.message)
                            .font(DSTypography.headsUpText(pointSize: bodySize))
                            .foregroundStyle(supportingTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    explainerActions
                }
            }
            .frame(maxWidth: 440)
            .overlay {
                if permissionContrast.isIncreased {
                    RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                        .stroke(Color.dsTextPrimary, lineWidth: 2)
                }
            }
            .accessibilityIdentifier(surface.accessibilityIdentifier)
        }
        .frame(minWidth: 480, minHeight: 280)
    }

    @ViewBuilder
    private var settingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(surface.presentation.message)
                    .font(DSTypography.headsUpText(pointSize: bodySize))
                    .foregroundStyle(supportingTextColor)
                    .fixedSize(horizontal: false, vertical: true)

                settingsButton
            }
            .padding(.vertical, DSSpacing.sm)
            .accessibilityIdentifier(surface.accessibilityIdentifier)
        } header: {
            Label {
                Text(surface.presentation.title)
                    .font(DSTypography.headsUpText(pointSize: bodySize))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.dsTextPrimary)
            } icon: {
                Image(systemName: symbolName)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var explainerActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DSSpacing.sm) {
                useInAppButton
                continueButton
            }
            VStack(spacing: DSSpacing.sm) {
                useInAppButton
                continueButton
            }
        }
    }

    @ViewBuilder
    private var useInAppButton: some View {
        if let title = surface.presentation.secondaryActionTitle {
            if let action = surface.secondaryAction {
                explainerButton(
                    title: title,
                    control: .useInApp,
                    accessibilityHint: surface.presentation.secondaryActionAccessibilityHint,
                ) {
                    onAction(action)
                }
            }
        }
    }

    private var continueButton: some View {
        explainerButton(
            title: surface.presentation.primaryActionTitle,
            control: .continueRequest,
            accessibilityHint: surface.presentation.primaryActionAccessibilityHint,
        ) {
            onAction(surface.primaryAction)
        }
    }

    private func explainerButton(
        title: String,
        control: HeadsUpPermissionControl,
        accessibilityHint: String?,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DSTypography.headsUpAction(pointSize: actionSize))
                .foregroundStyle(Color.dsTextPrimary)
                .frame(maxWidth: .infinity, minHeight: actionHeight)
                .padding(.horizontal, DSSpacing.md)
                .background(Color.dsSurfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                        .stroke(
                            Color.dsAccent,
                            lineWidth: controlIsFocused(control)
                                ? permissionContrast.isIncreased ? 3 : 2
                                : 0,
                        )
                }
        }
        .buttonStyle(.plain)
        .focused($focusedControl, equals: control)
        .accessibilityHintIfPresent(accessibilityHint)
        .accessibilityIdentifier(identifier(for: control))
    }

    private var settingsButton: some View {
        Button {
            onAction(surface.primaryAction)
        } label: {
            Text(surface.presentation.primaryActionTitle)
                .foregroundStyle(Color.accentColor)
        }
        .font(DSTypography.headsUpAction(pointSize: actionSize))
        .buttonStyle(.bordered)
        .tint(Color.accentColor)
        .focused($focusedControl, equals: .openSettings)
        .overlay {
            if controlIsFocused(.openSettings) {
                RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                    .stroke(
                        Color.accentColor,
                        lineWidth: permissionContrast.isIncreased ? 3 : 2,
                    )
            }
        }
        .accessibilityHintIfPresent(surface.presentation.primaryActionAccessibilityHint)
        .accessibilityIdentifier(identifier(for: .openSettings))
    }

    private var titleSize: CGFloat {
        textScale.apply(to: DSTypography.headsUpTextSize + DSSpacing.sm)
    }

    private var bodySize: CGFloat {
        textScale.apply(to: DSTypography.headsUpTextSize)
    }

    private var actionSize: CGFloat {
        textScale.apply(to: DSTypography.headsUpTextSize)
    }

    private var actionHeight: CGFloat {
        textScale.apply(to: DSSpacing.xxl + DSSpacing.sm)
    }

    private var supportingTextColor: Color {
        permissionContrast.isIncreased ? .dsTextPrimary : .dsTextSecondary
    }

    private var permissionContrast: HeadsUpPermissionContrast {
        HeadsUpPermissionContrast(
            systemIncreased: systemContrast == .increased,
            previewOverride: increaseContrastOverride,
        )
    }

    private var symbolName: String {
        switch surface {
        case .inContextExplainer:
            "bell.badge"
        case .settings:
            "bell.slash"
        }
    }

    private func identifier(for control: HeadsUpPermissionControl) -> String {
        switch control {
        case .useInApp:
            "\(surface.accessibilityIdentifier).secondary"
        case .continueRequest, .openSettings:
            "\(surface.accessibilityIdentifier).primary"
        }
    }

    private func controlIsFocused(_ control: HeadsUpPermissionControl) -> Bool {
        if let focusedControlOverride {
            return focusedControlOverride == control
        }
        return focusedControl == control
    }
}

struct HeadsUpPermissionContrast: Equatable {
    let isIncreased: Bool

    init(systemIncreased: Bool, previewOverride: Bool) {
        isIncreased = systemIncreased || previewOverride
    }
}

private extension View {
    @ViewBuilder
    func accessibilityHintIfPresent(_ hint: String?) -> some View {
        if let hint {
            accessibilityHint(hint)
        } else {
            self
        }
    }
}

#Preview("PM-01 — in-context explainer") {
    HeadsUpPermissionView(surface: .inContextExplainer) { _ in }
        .frame(width: 560, height: 320)
}

#Preview("PM-01 — largest text") {
    HeadsUpPermissionView(surface: .inContextExplainer) { _ in }
        .environment(\.dsTextScale, .largest)
        .frame(width: 680, height: 520)
}

#Preview("PM-01 — Increase Contrast") {
    HeadsUpPermissionView(
        surface: .inContextExplainer,
        increaseContrastOverride: true,
    ) { _ in }
        .frame(width: 560, height: 320)
}

#Preview("PM-02 — denied") {
    HeadsUpPermissionSettingsPreview(state: .denied)
}

#Preview("PM-02 — revoked") {
    HeadsUpPermissionSettingsPreview(state: .revoked)
}

#Preview("PM-02 — Increase Contrast") {
    HeadsUpPermissionSettingsPreview(state: .denied, increaseContrast: true)
}

private struct HeadsUpPermissionSettingsPreview: View {
    let state: HeadsUpPermissionSettingsState
    var increaseContrast = false

    var body: some View {
        Form {
            HeadsUpPermissionView(
                surface: .settings(state),
                increaseContrastOverride: increaseContrast,
            ) { _ in }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 320)
    }
}
