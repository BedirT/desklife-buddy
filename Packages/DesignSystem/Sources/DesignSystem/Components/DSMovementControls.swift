import SwiftUI

/// Equal-status movement choice with stable selection, focus, and keyboard affordances.
public struct DSBreakChoiceChip: View {
    private let shape = Capsule(style: .continuous)

    @ScaledMetric(relativeTo: .body) private var pointSize = DSTypography.breakChoiceSize
    @FocusState private var localFocus: Bool

    private let title: String
    private let keycap: String
    private let glyph: AnyView
    private let selected: Bool
    private let accessibilityLabel: String
    private let accessibilityIdentifier: String
    private let focus: FocusState<Bool>.Binding?
    private let focusOverride: Bool?
    private let reduceTransparency: Bool
    private let increaseContrast: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        keycap: String,
        selected: Bool,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        focus: FocusState<Bool>.Binding? = nil,
        focusOverride: Bool? = nil,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder glyph: () -> some View,
    ) {
        self.title = title
        self.keycap = keycap
        self.selected = selected
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.focus = focus
        self.focusOverride = focusOverride
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.action = action
        self.glyph = AnyView(glyph())
    }

    @ViewBuilder
    public var body: some View {
        if reduceTransparency {
            decorated(
                focusedButton
                    .buttonStyle(.plain),
            )
        } else {
            decorated(focusedButton.buttonStyle(.glass))
        }
    }

    @ViewBuilder
    private var focusedButton: some View {
        if let focus {
            selectedButton
                .focused(focus)
                .focusEffectDisabled()
        } else {
            selectedButton
                .focused($localFocus)
                .focusEffectDisabled()
        }
    }

    @ViewBuilder
    private var selectedButton: some View {
        if selected {
            baseButton.accessibilityAddTraits(.isSelected)
        } else {
            baseButton
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                glyph
                Text(title)
                    .font(DSTypography.breakChoice(pointSize: pointSize))
                    .lineLimit(2)
                Spacer(minLength: 16)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dsMovementChoiceCheck)
                    .frame(width: 16, height: 16)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
                DSKeycap(keycap, increaseContrast: increaseContrast)
            }
            .foregroundStyle(primaryInk)
            .padding(.leading, 14)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(shape)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func decorated(_ label: some View) -> some View {
        let bordered = label
            .background { backgroundLayers }
            .overlay {
                shape.strokeBorder(
                    borderInk,
                    lineWidth: increaseContrast ? 2 : 1,
                )
            }
            .clipShape(shape)

        return bordered
            .padding(maximumRingExpansion)
            .overlay {
                if selected {
                    DSControlRing(
                        color: Color.dsMovementChoiceSelected.opacity(0.72),
                        lineWidth: 1,
                        outerInset: selectionRingInset,
                    )
                }
            }
            .overlay {
                if hasFocus {
                    DSControlRing(
                        color: Color.dsBreakFocusRing,
                        lineWidth: focusLineWidth,
                        outerInset: focusRingInset,
                    )
                }
            }
    }

    @ViewBuilder
    private var backgroundLayers: some View {
        if reduceTransparency {
            shape.fill(Color.dsMovementControlSolid)
        } else {
            shape.fill(Color.dsMovementChoiceScrim)
            shape.fill(selected ? Color.dsMovementChoiceSelectedFill : Color.dsMovementChoiceGlassFill)
        }
    }

    private var primaryInk: Color {
        increaseContrast ? .dsBreakTextPrimaryIncreased : .dsBreakTextPrimary
    }

    private var borderInk: Color {
        if selected { return .dsMovementChoiceSelected }
        return increaseContrast ? .dsBreakControlBorderIncreased : .dsBreakControlBorder
    }

    private var hasFocus: Bool {
        focusOverride ?? focus?.wrappedValue ?? localFocus
    }

    private var focusLineWidth: CGFloat {
        increaseContrast ? 3 : 2
    }

    private var maximumRingExpansion: CGFloat {
        5
    }

    private var selectionRingInset: CGFloat {
        maximumRingExpansion - 1 - 1
    }

    private var focusRingInset: CGFloat {
        max(0, maximumRingExpansion - 2 - focusLineWidth)
    }
}

/// Visually tertiary break action that remains a full semantic sibling.
public struct DSBreakQuietPill: View {
    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    @ScaledMetric(relativeTo: .body) private var pointSize = DSTypography.breakActionSize
    @FocusState private var localFocus: Bool

    private let title: String
    private let detail: String
    private let keycap: String
    private let accessibilityLabel: String
    private let accessibilityIdentifier: String
    private let focus: FocusState<Bool>.Binding?
    private let focusOverride: Bool?
    private let reduceTransparency: Bool
    private let increaseContrast: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        detail: String,
        keycap: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        focus: FocusState<Bool>.Binding? = nil,
        focusOverride: Bool? = nil,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.detail = detail
        self.keycap = keycap
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.focus = focus
        self.focusOverride = focusOverride
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.action = action
    }

    public var body: some View {
        let bordered = focusedButton
            .buttonStyle(.plain)
            .background(reduceTransparency ? Color.dsMovementControlSolid : .clear, in: shape)
            .overlay {
                shape.strokeBorder(
                    increaseContrast ? Color.dsBreakControlBorderIncreased : Color.dsBreakControlBorder,
                    lineWidth: increaseContrast ? 2 : 1,
                )
            }
            .clipShape(shape)

        return bordered
            .padding(maximumRingExpansion)
            .overlay {
                if hasFocus {
                    DSControlRing(
                        color: Color.dsBreakFocusRing,
                        lineWidth: focusLineWidth,
                        outerInset: focusRingInset,
                    )
                }
            }
    }

    @ViewBuilder
    private var focusedButton: some View {
        if let focus {
            baseButton.focused(focus).focusEffectDisabled()
        } else {
            baseButton.focused($localFocus).focusEffectDisabled()
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                    .font(DSTypography.breakAction(pointSize: pointSize))
                Text(detail)
                    .font(DSTypography.breakMeta(pointSize: pointSize))
                    .foregroundStyle(secondaryInk)
                DSKeycap(keycap, increaseContrast: increaseContrast)
            }
            .foregroundStyle(primaryInk)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .contentShape(shape)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var primaryInk: Color {
        increaseContrast ? .dsBreakTextPrimaryIncreased : .dsBreakTextPrimary
    }

    private var secondaryInk: Color {
        increaseContrast ? .dsBreakTextSecondaryIncreased : .dsBreakTextSecondary
    }

    private var hasFocus: Bool {
        focusOverride ?? focus?.wrappedValue ?? localFocus
    }

    private var focusLineWidth: CGFloat {
        increaseContrast ? 3 : 2
    }

    private var maximumRingExpansion: CGFloat {
        5
    }

    private var focusRingInset: CGFloat {
        max(0, maximumRingExpansion - 2 - focusLineWidth)
    }
}

private struct DSControlRing: View {
    let color: Color
    let lineWidth: CGFloat
    let outerInset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let pathInset = outerInset + lineWidth / 2
            let rect = CGRect(origin: .zero, size: proxy.size)
                .insetBy(dx: pathInset, dy: pathInset)
            capsulePath(in: rect)
                .stroke(color, lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func capsulePath(in rect: CGRect) -> Path {
        let radius = rect.height / 2
        let control = radius * 0.552_284_75
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.maxX - radius + control, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.midY - control),
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.midY + control),
            control2: CGPoint(x: rect.maxX - radius + control, y: rect.maxY),
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control1: CGPoint(x: rect.minX + radius - control, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.midY + control),
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.midY - control),
            control2: CGPoint(x: rect.minX + radius - control, y: rect.minY),
        )
        path.closeSubpath()
        return path
    }
}

#Preview("Movement controls") {
    VStack(spacing: DSSpacing.md) {
        DSBreakChoiceChip(
            DesignSystemL10n.BreakField.walkOrWheel,
            keycap: "1",
            selected: true,
            accessibilityLabel: DesignSystemL10n.BreakField.walkOrWheelAccessibility,
            accessibilityIdentifier: "designSystem.movement.walk",
            action: {},
            glyph: { DSMovementChoiceGlyph(.walkOrWheel) },
        )
        DSBreakChoiceChip(
            DesignSystemL10n.BreakField.smallSpace,
            keycap: "2",
            selected: false,
            accessibilityLabel: DesignSystemL10n.BreakField.smallSpaceAccessibility,
            accessibilityIdentifier: "designSystem.movement.smallSpace",
            increaseContrast: true,
            action: {},
            glyph: { DSMovementChoiceGlyph(.smallSpace) },
        )
        DSBreakQuietPill(
            DesignSystemL10n.BreakField.changePosition,
            detail: DesignSystemL10n.BreakField.loggedSeparately,
            keycap: "P",
            accessibilityLabel: DesignSystemL10n.BreakField.changePositionAccessibility,
            accessibilityIdentifier: "designSystem.movement.position",
            focusOverride: true,
        ) {}
    }
    .padding(DSSpacing.xl)
    .background(Color.dsMovementGroundTop)
}
