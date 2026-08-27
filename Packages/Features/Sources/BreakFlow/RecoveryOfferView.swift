import DesignSystem
import SwiftUI

struct RecoveryOfferView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dsTextScale) private var textScale
    @State private var model: BreakFlowModel
    @FocusState private var fiveFocused: Bool
    @FocusState private var tenFocused: Bool
    @FocusState private var notNowFocused: Bool

    private let accessibilityOverride: BreakFlowAccessibility?
    private let focusedControlOverride: BreakFlowControl?

    init(
        model: BreakFlowModel,
        accessibilityOverride: BreakFlowAccessibility?,
        focusedControlOverride: BreakFlowControl?,
    ) {
        _model = State(initialValue: model)
        self.accessibilityOverride = accessibilityOverride
        self.focusedControlOverride = focusedControlOverride
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BreakFlowField(staticPresentation: accessibility.staticPresentation)
                    .accessibilityHidden(true)
                if usesLargeTextLayout {
                    accessibilityLayout
                } else {
                    standardLayout(in: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recovery.surface")
        .defaultFocus($fiveFocused, true)
    }

    private func standardLayout(in size: CGSize) -> some View {
        ZStack {
            instructionStack
                .frame(maxWidth: min(1100, size.width - 80))
                .position(x: size.width / 2, y: size.height * 0.325)
            controls
                .position(x: size.width / 2, y: size.height * 0.855)
        }
    }

    private var accessibilityLayout: some View {
        VStack(spacing: DSSpacing.lg) {
            instructionStack
                .frame(maxWidth: 960)
            Spacer(minLength: DSSpacing.md)
            controls
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.top, DSSpacing.xl)
        .padding(.bottom, DSSpacing.lg)
    }

    private var instructionStack: some View {
        VStack(spacing: DSSpacing.xxl) {
            Text(BreakFlowL10n.recoveryEyebrow.uppercased())
                .font(DSTypography.breakEyebrow(pointSize: eyebrowSize))
                .tracking(2)
                .foregroundStyle(eyebrowInk)
            Text(BreakFlowL10n.recoveryHeadline)
                .font(DSTypography.breakInstruction(pointSize: instructionSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryInk)
                .frame(maxWidth: 980)
                .fixedSize(horizontal: false, vertical: true)
            Text(BreakFlowL10n.recoveryGuidance)
                .font(DSTypography.breakSupporting(pointSize: supportingSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryInk)
                .frame(maxWidth: 760)
                .fixedSize(horizontal: false, vertical: true)
        }
        .background { staticTextBackdrop }
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: DSSpacing.sm) {
            DSBreakPill(
                BreakFlowL10n.recoveryMinutesAway(model.recoveryDurationsSeconds[0]),
                accessibilityLabel: BreakFlowL10n.recoveryMinutesAccessibility(
                    model.recoveryDurationsSeconds[0],
                ),
                accessibilityIdentifier: durationIdentifier(model.recoveryDurationsSeconds[0]),
                focus: $fiveFocused,
                focusOverride: focus(for: .recoveryFive, actual: fiveFocused),
                reduceTransparency: opaqueControls,
                increaseContrast: accessibility.increaseContrast,
                action: { model.chooseRecovery(durationSeconds: model.recoveryDurationsSeconds[0]) },
            )
            DSBreakPill(
                BreakFlowL10n.recoveryMinutesAway(model.recoveryDurationsSeconds[1]),
                accessibilityLabel: BreakFlowL10n.recoveryMinutesAccessibility(
                    model.recoveryDurationsSeconds[1],
                ),
                accessibilityIdentifier: durationIdentifier(model.recoveryDurationsSeconds[1]),
                focus: $tenFocused,
                focusOverride: focus(for: .recoveryTen, actual: tenFocused),
                reduceTransparency: opaqueControls,
                increaseContrast: accessibility.increaseContrast,
                action: { model.chooseRecovery(durationSeconds: model.recoveryDurationsSeconds[1]) },
            )
            DSBreakPill(
                BreakFlowL10n.notNow,
                keycap: BreakFlowL10n.escapeKey,
                accessibilityLabel: BreakFlowL10n.notNow,
                accessibilityHint: BreakFlowL10n.escapeKeyAccessibility,
                accessibilityIdentifier: "recovery.notNow",
                focus: $notNowFocused,
                focusOverride: focus(for: .recoveryNotNow, actual: notNowFocused),
                reduceTransparency: opaqueControls,
                increaseContrast: accessibility.increaseContrast,
                action: model.dismissRecovery,
            )
            .keyboardShortcut(.cancelAction)
        }
    }

    private var accessibility: BreakFlowAccessibility {
        accessibilityOverride ?? BreakFlowAccessibility(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
        )
    }

    private var eyebrowSize: CGFloat {
        textScale.apply(to: DSTypography.breakEyebrowSize)
    }

    private var instructionSize: CGFloat {
        textScale.apply(to: DSTypography.breakLongInstructionSize)
    }

    private var supportingSize: CGFloat {
        textScale.apply(to: DSTypography.breakSupportingSize)
    }

    private var opaqueControls: Bool {
        accessibility.reduceTransparency || accessibility.staticPresentation
    }

    private var usesLargeTextLayout: Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge
    }

    private var primaryInk: Color {
        if accessibility.staticPresentation { return .dsStaticText }
        return accessibility.increaseContrast ? .dsBreakTextPrimaryIncreased : .dsBreakTextPrimary
    }

    private var eyebrowInk: Color {
        if accessibility.staticPresentation { return .dsStaticText }
        return accessibility.increaseContrast ? .dsBreakEyebrowIncreased : .dsBreakEyebrow
    }

    @ViewBuilder
    private var staticTextBackdrop: some View {
        if accessibility.staticPresentation {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .fill(Color.dsStaticTextScrim)
                .padding(.horizontal, -DSSpacing.lg)
                .padding(.vertical, -DSSpacing.md)
        }
    }

    private func focus(for control: BreakFlowControl, actual: Bool) -> Bool? {
        focusedControlOverride.map { $0 == control } ?? actual
    }

    private func durationIdentifier(_ durationSeconds: TimeInterval) -> String {
        "recovery.duration.\(Int(durationSeconds))"
    }
}

#Preview("BR-12 · Recovery offer") {
    RecoveryOfferView(
        model: .preview(.recoveryOffer),
        accessibilityOverride: nil,
        focusedControlOverride: .recoveryFive,
    )
    .frame(width: 1440, height: 900)
}

#Preview("BR-12 · Dark") {
    RecoveryOfferView(
        model: .preview(.recoveryOffer),
        accessibilityOverride: nil,
        focusedControlOverride: .recoveryFive,
    )
    .environment(\.colorScheme, .dark)
    .frame(width: 1440, height: 900)
}

#Preview("BR-12 · Static presentation") {
    RecoveryOfferView(
        model: .preview(.recoveryOffer),
        accessibilityOverride: .init(staticPresentation: true),
        focusedControlOverride: .recoveryNotNow,
    )
    .frame(width: 1440, height: 900)
}

#Preview("BR-12 · Largest text") {
    RecoveryOfferView(
        model: .preview(.recoveryOffer),
        accessibilityOverride: .init(
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
        ),
        focusedControlOverride: .recoveryFive,
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(width: 1440, height: 900)
}
