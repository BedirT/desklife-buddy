import SwiftUI

public struct DSKeycap: View {
    private let title: String
    private let increaseContrast: Bool

    public init(_ title: String, increaseContrast: Bool = false) {
        self.title = title
        self.increaseContrast = increaseContrast
    }

    public var body: some View {
        Text(title)
            .font(DSTypography.caption.weight(.medium))
            .foregroundStyle(
                increaseContrast
                    ? Color.dsBreakTextSecondaryIncreased
                    : Color.dsBreakTextSecondary,
            )
            .frame(minWidth: 24, minHeight: 20)
            .padding(.horizontal, 6)
            .background(Color.dsBreakKeycap, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityHidden(true)
    }
}

public struct DSBreakPill: View {
    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    @ScaledMetric(relativeTo: .body) private var pointSize = DSTypography.breakActionSize
    @FocusState private var localFocus: Bool

    private let title: String
    private let keycap: String
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let accessibilityIdentifier: String
    private let focus: FocusState<Bool>.Binding?
    private let focusOverride: Bool?
    private let reduceTransparency: Bool
    private let increaseContrast: Bool
    private let enabled: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        keycap: String,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        accessibilityIdentifier: String,
        focus: FocusState<Bool>.Binding? = nil,
        focusOverride: Bool? = nil,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
        enabled: Bool = true,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.keycap = keycap
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.accessibilityIdentifier = accessibilityIdentifier
        self.focus = focus
        self.focusOverride = focusOverride
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.enabled = enabled
        self.action = action
    }

    @ViewBuilder
    public var body: some View {
        if reduceTransparency {
            bordered(
                button
                    .buttonStyle(.plain)
                    .background(Color.dsBreakControlSolid, in: shape),
            )
        } else if increaseContrast {
            bordered(button.buttonStyle(.glass))
        } else {
            bordered(button.buttonStyle(.glass))
        }
    }

    @ViewBuilder
    private var button: some View {
        if let focus {
            accessibleButton
                .focused(focus)
                .focusEffectDisabled()
        } else {
            accessibleButton
                .focused($localFocus)
                .focusEffectDisabled()
        }
    }

    @ViewBuilder
    private var accessibleButton: some View {
        if let accessibilityHint {
            baseButton.accessibilityHint(accessibilityHint)
        } else {
            baseButton
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            styledLabel
        }
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private var styledLabel: some View {
        let label = HStack(spacing: 10) {
            Text(title)
                .font(DSTypography.breakAction(pointSize: pointSize))
            DSKeycap(keycap, increaseContrast: increaseContrast)
        }
        .foregroundStyle(
            increaseContrast
                ? Color.dsBreakTextPrimaryIncreased
                : Color.dsBreakTextPrimary,
        )
        .padding(.horizontal, 22)
        .frame(minHeight: 44)
        .contentShape(shape)

        label
    }

    private func bordered(_ label: some View) -> some View {
        label
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(
                        increaseContrast
                            ? Color.dsBreakControlBorderIncreased
                            : Color.dsBreakControlBorder,
                        lineWidth: increaseContrast ? 2 : 1,
                    )
            }
            .clipShape(shape)
            .padding(focusExpansion)
            .overlay {
                if hasFocus {
                    focusShape
                        .strokeBorder(Color.dsBreakFocusRing, lineWidth: focusLineWidth)
                        .clipShape(focusShape)
                }
            }
            .padding(-focusExpansion)
    }

    private var hasFocus: Bool {
        focusOverride ?? focus?.wrappedValue ?? localFocus
    }

    private var focusLineWidth: CGFloat {
        increaseContrast ? 3 : 2
    }

    private var focusExpansion: CGFloat {
        focusLineWidth + 2
    }

    private var focusShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22 + focusExpansion, style: .continuous)
    }
}

#Preview("Break pills") {
    HStack(spacing: DSSpacing.md) {
        DSBreakPill(
            DesignSystemL10n.Buttons.continueTitle,
            keycap: "↩",
            accessibilityLabel: DesignSystemL10n.Buttons.continueTitle,
            accessibilityIdentifier: "designSystem.breakPill.continue",
        ) {}
        DSBreakPill(
            DesignSystemL10n.Buttons.secondary,
            keycap: "esc",
            accessibilityLabel: DesignSystemL10n.Buttons.secondary,
            accessibilityIdentifier: "designSystem.breakPill.secondary",
            reduceTransparency: true,
            increaseContrast: true,
        ) {}
    }
    .padding(DSSpacing.xl)
    .background(Color.dsBreakControlSolid)
}
