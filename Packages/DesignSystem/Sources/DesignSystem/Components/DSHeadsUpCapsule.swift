import SwiftUI

/// Presentation-only anatomy for the non-activating heads-up capsule.
public struct DSHeadsUpCapsule: View {
    public enum Indicator: Equatable, Sendable {
        /// Normalized x and descent progress. Callers own clocks and pointer input.
        case sun(horizontal: CGFloat, descent: CGFloat)
        /// Honest suppression state, carried by both a dashed mark and text.
        case hold
    }

    private let shape = Capsule(style: .continuous)

    @Environment(\.dsTextScale) private var textScale
    @State private var nowHovered = false
    @State private var laterHovered = false
    @GestureState private var laterPressed = false

    private let title: String
    private let detail: String
    private let indicator: Indicator?
    private let showsActions: Bool
    private let nowTitle: String
    private let laterTitle: String
    private let laterOptions: [String]
    private let laterOptionAccessibilityIdentifiers: [String]
    private let statusAccessibilityLabel: String
    private let nowAccessibilityLabel: String
    private let laterAccessibilityLabel: String
    private let accessibilityIdentifier: String
    private let reduceTransparency: Bool
    private let increaseContrast: Bool
    private let nowAction: () -> Void
    private let laterAction: (Int) -> Void

    private var textSize: CGFloat {
        textScale.apply(to: DSTypography.headsUpTextSize)
    }

    private var actionSize: CGFloat {
        textScale.apply(to: DSTypography.headsUpActionSize)
    }

    private var minimumHeight: CGFloat {
        textScale.apply(to: 34)
    }

    private var actionHeight: CGFloat {
        textScale.apply(to: 24)
    }

    public init(
        title: String,
        detail: String,
        indicator: Indicator?,
        showsActions: Bool = false,
        nowTitle: String,
        laterTitle: String,
        laterOptions: [String] = [],
        laterOptionAccessibilityIdentifiers: [String] = [],
        statusAccessibilityLabel: String,
        nowAccessibilityLabel: String,
        laterAccessibilityLabel: String,
        accessibilityIdentifier: String,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
        nowAction: @escaping () -> Void,
        laterAction: @escaping (Int) -> Void,
    ) {
        self.title = title
        self.detail = detail
        self.indicator = indicator
        self.showsActions = showsActions
        self.nowTitle = nowTitle
        self.laterTitle = laterTitle
        self.laterOptions = laterOptions
        self.laterOptionAccessibilityIdentifiers = laterOptionAccessibilityIdentifiers
        self.statusAccessibilityLabel = statusAccessibilityLabel
        self.nowAccessibilityLabel = nowAccessibilityLabel
        self.laterAccessibilityLabel = laterAccessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.nowAction = nowAction
        self.laterAction = laterAction
    }

    public var body: some View {
        adaptiveContent
            .padding(.horizontal, 6)
            .frame(minHeight: minimumHeight)
            .background { capsuleBackground }
            .overlay {
                shape.strokeBorder(
                    increaseContrast ? Color.dsCapsuleBorderIncreased : Color.dsCapsuleBorder,
                    lineWidth: increaseContrast ? 2 : 1,
                )
            }
            .clipShape(shape)
            .shadow(color: Color.black.opacity(0.44), radius: 14, y: 8)
            .accessibilityIdentifier(accessibilityIdentifier)
            .accessibilityActions {
                if !showsActions {
                    Button(nowAccessibilityLabel, action: nowAction)
                        .accessibilityIdentifier("\(accessibilityIdentifier).now")

                    ForEach(Array(laterOptions.enumerated()), id: \.offset) { index, option in
                        Button(option) { laterAction(index) }
                            .accessibilityIdentifier(laterOptionIdentifier(at: index))
                    }
                }
            }
    }

    @ViewBuilder
    private var adaptiveContent: some View {
        if indicatorCanBeDropped {
            ViewThatFits(in: .horizontal) {
                capsuleContent(showsIndicator: true)
                capsuleContent(showsIndicator: false)
                stackedCapsuleContent
            }
        } else {
            capsuleContent(showsIndicator: indicator != nil)
        }
    }

    private func capsuleContent(showsIndicator: Bool) -> some View {
        HStack(spacing: 9) {
            if showsIndicator, let indicator {
                indicatorView(indicator)
                    .accessibilityHidden(true)
            }

            statusContent

            if showsActions {
                actionsContent
            }
        }
        .padding(.leading, showsIndicator ? 0 : 7)
        .padding(.trailing, showsActions ? 1 : 7)
    }

    private var stackedCapsuleContent: some View {
        VStack(spacing: 3) {
            statusContent
            if showsActions {
                actionsContent
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
    }

    private var statusContent: some View {
        HStack(spacing: 4) {
            if !title.isEmpty {
                Text(title)
                    .foregroundStyle(Color.dsCapsuleTextPrimary)
            }
            if !title.isEmpty, !canonicalDetail.isEmpty {
                Text(verbatim: "·")
                    .foregroundStyle(detailColor)
                    .accessibilityHidden(true)
            }
            if !canonicalDetail.isEmpty {
                Text(canonicalDetail)
                    .foregroundStyle(detailColor)
                    .monospacedDigit()
            }
        }
        .font(DSTypography.headsUpText(pointSize: textSize))
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusAccessibilityLabel)
        .accessibilityIdentifier("\(accessibilityIdentifier).status")
    }

    private var actionsContent: some View {
        HStack(spacing: 4) {
            actionButton(nowTitle, accessibilityLabel: nowAccessibilityLabel, action: nowAction)

            Menu {
                ForEach(Array(laterOptions.enumerated()), id: \.offset) { index, option in
                    Button(option) { laterAction(index) }
                        .accessibilityIdentifier(laterOptionIdentifier(at: index))
                }
            } label: {
                Text(verbatim: "\(laterTitle) ▾")
                    .font(DSTypography.headsUpAction(pointSize: actionSize))
                    .foregroundStyle(laterActionColor)
                    .padding(.horizontal, 8)
                    .frame(minHeight: actionHeight)
                    .fixedSize(horizontal: true, vertical: true)
                    .background(
                        laterPressed
                            ? Color.dsCapsuleActionPressedFill
                            : laterHovered ? Color.dsCapsuleActionHoverFill : .clear,
                        in: Capsule(style: .continuous),
                    )
                    .contentShape(Capsule(style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .tint(laterActionColor)
            .onHover { laterHovered = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($laterPressed) { _, isPressed, _ in isPressed = true },
            )
            .accessibilityLabel(laterAccessibilityLabel)
            .accessibilityIdentifier("\(accessibilityIdentifier).later")
        }
    }

    private func actionButton(
        _ label: String,
        accessibilityLabel: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(DSTypography.headsUpAction(pointSize: actionSize))
                .foregroundStyle(Color.dsCapsuleActionPrimary)
                .padding(.horizontal, 10)
                .frame(minHeight: actionHeight)
                .fixedSize(horizontal: true, vertical: true)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(DSCapsuleActionButtonStyle(isHovered: nowHovered))
        .onHover { nowHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("\(accessibilityIdentifier).now")
    }

    @ViewBuilder
    private func indicatorView(_ indicator: Indicator) -> some View {
        switch indicator {
        case let .sun(horizontal, descent):
            DSCapsuleSky(horizontal: horizontal, descent: descent)
        case .hold:
            Circle()
                .stroke(
                    Color.dsCapsuleHoldRing,
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]),
                )
                .frame(width: 14, height: 14)
                .padding(.horizontal, 5)
        }
    }

    @ViewBuilder
    private var capsuleBackground: some View {
        if reduceTransparency || increaseContrast {
            shape.fill(Color.dsCapsuleSurfaceOpaque)
        } else {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.dsCapsuleSurface)
        }
    }
}

private extension DSHeadsUpCapsule {
    var indicatorCanBeDropped: Bool {
        if case .sun = indicator { true } else { false }
    }

    var detailColor: Color {
        increaseContrast ? .dsCapsuleTextPrimary : .dsCapsuleTextSecondary
    }

    var canonicalDetail: String {
        let withoutLeadingWhitespace = detail.drop(while: \.isWhitespace)
        guard withoutLeadingWhitespace.first == "·" else { return detail }
        return String(withoutLeadingWhitespace.dropFirst().drop(while: \.isWhitespace))
    }

    var laterActionColor: Color {
        increaseContrast ? .dsCapsuleTextPrimary : .dsCapsuleActionSecondary
    }

    func laterOptionIdentifier(at index: Int) -> String {
        guard laterOptionAccessibilityIdentifiers.indices.contains(index) else {
            return "\(accessibilityIdentifier).later.option.\(index)"
        }
        return laterOptionAccessibilityIdentifiers[index]
    }
}

private struct DSCapsuleActionButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color.dsCapsuleActionPressedFill
                    : isHovered ? Color.dsCapsuleActionHoverFill : Color.dsCapsuleActionFill,
                in: Capsule(style: .continuous),
            )
    }
}

private struct DSCapsuleSky: View {
    let horizontal: CGFloat
    let descent: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let horizontalOffset = DSCapsuleSkyGeometry.inset
                + DSCapsuleSkyGeometry.clamped(horizontal)
                * (proxy.size.width - DSCapsuleSkyGeometry.sunSize
                    - 2 * DSCapsuleSkyGeometry.inset)

            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [.dsCapsuleSkyTop, .dsCapsuleSkyMiddle, .dsCapsuleSkyHorizon],
                    startPoint: .top,
                    endPoint: .bottom,
                )
                Rectangle()
                    .fill(Color.dsCapsuleHoldRing.opacity(0.72))
                    .frame(height: 1)
                    .offset(y: DSCapsuleSkyGeometry.horizonY)
                DSCapsuleSun()
                    .frame(
                        width: DSCapsuleSkyGeometry.sunSize,
                        height: DSCapsuleSkyGeometry.sunSize,
                    )
                    .offset(
                        x: horizontalOffset,
                        y: DSCapsuleSkyGeometry.verticalOffset(for: descent),
                    )
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
    }
}

private struct DSCapsuleSun: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.dsSunCore, .dsSunMiddle, .dsSunEdge],
                    center: UnitPoint(x: 0.38, y: 0.34),
                    startRadius: 0,
                    endRadius: 6,
                ),
            )
            .shadow(color: Color.dsSunGlow, radius: 4)
            .overlay {
                HStack(spacing: 1.3) {
                    Capsule().fill(Color.dsCapsuleSkyMiddle).frame(width: 2.1, height: 0.8)
                    Capsule().fill(Color.dsCapsuleSkyMiddle).frame(width: 2.1, height: 0.8)
                }
                .offset(y: 1)
            }
    }
}

#Preview("Heads-up capsule") {
    VStack(spacing: DSSpacing.lg) {
        DSHeadsUpCapsule(
            title: DesignSystemL10n.HeadsUp.visualReset,
            detail: DesignSystemL10n.HeadsUp.time45,
            indicator: .sun(horizontal: 0.2, descent: 0),
            nowTitle: DesignSystemL10n.HeadsUp.now,
            laterTitle: DesignSystemL10n.HeadsUp.later,
            statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility45,
            nowAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibilityStartNow,
            laterAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibilityLater,
            accessibilityIdentifier: "preview.headsUp.approach",
            nowAction: {},
            laterAction: { _ in },
        )
        DSHeadsUpCapsule(
            title: DesignSystemL10n.HeadsUp.visualReset,
            detail: DesignSystemL10n.HeadsUp.time15,
            indicator: .sun(horizontal: 0.7, descent: 0.65),
            showsActions: true,
            nowTitle: DesignSystemL10n.HeadsUp.now,
            laterTitle: DesignSystemL10n.HeadsUp.later,
            laterOptions: DesignSystemL10n.HeadsUp.laterOptions,
            statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility15,
            nowAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibilityStartNow,
            laterAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibilityLater,
            accessibilityIdentifier: "preview.headsUp.hover",
            nowAction: {},
            laterAction: { _ in },
        )
    }
    .padding(DSSpacing.xl)
    .background(Color.dsBackground)
}
