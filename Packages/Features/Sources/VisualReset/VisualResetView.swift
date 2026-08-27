import DesignSystem
import SwiftUI

public struct VisualResetView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dsTextScale) private var textScale
    @State private var model: VisualResetModel
    @State private var focusPresentation: VisualResetFocusPresentation
    @State private var showsInitialFocusFallback = true
    @FocusState private var doneEarlyFocused: Bool
    @FocusState private var skipFocused: Bool

    private let standardField: AnyView
    private let staticField: AnyView?
    private let accessibilityOverride: VisualResetAccessibility?
    let context: VisualResetContext

    public init(
        model: VisualResetModel,
        standardField: AnyView? = nil,
        staticField: AnyView? = nil,
        accessibilityOverride: VisualResetAccessibility? = nil,
        focusPresentation: VisualResetFocusPresentation = .init(),
        opensAutomatically: Bool = true,
        context: VisualResetContext = .standalone,
    ) {
        if opensAutomatically {
            model.open()
        }
        _model = State(initialValue: model)
        _focusPresentation = State(initialValue: focusPresentation)
        self.standardField = standardField ?? AnyView(VisualResetWorkingField())
        self.staticField = staticField
        self.accessibilityOverride = accessibilityOverride
        self.context = context
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                field
                    .accessibilityHidden(true)
                if !usesLargeTextLayout {
                    DSHorizonProgress(
                        progress: model.progress,
                        increaseContrast: effectiveAccessibility.increaseContrast,
                    )
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.622)
                }

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
        .accessibilityIdentifier(surfaceIdentifier)
        .defaultFocus($doneEarlyFocused, true)
        .onKeyPress(.return) {
            model.doneEarlyFromKeyboard()
            return .handled
        }
        .onAppear {
            model.updateAccessibility(effectiveAccessibility)
            updateFocusPresentation(focusPresentation.showsDefaultAction)
        }
        .onChange(of: effectiveAccessibility) { _, accessibility in
            model.updateAccessibility(accessibility)
        }
        .onChange(of: doneEarlyFocused) { _, focused in
            if focused {
                showsInitialFocusFallback = false
            }
        }
        .onChange(of: skipFocused) { _, focused in
            if focused {
                showsInitialFocusFallback = false
            }
        }
        .onChange(of: focusPresentation.showsDefaultAction) { _, visible in
            updateFocusPresentation(visible)
        }
    }

    @ViewBuilder
    private var field: some View {
        if effectiveAccessibility.staticPresentation, let staticField {
            staticField
        } else {
            standardField
        }
    }

    private func standardLayout(in size: CGSize) -> some View {
        ZStack {
            instructionStack
                .frame(maxWidth: min(1000, size.width - 80))
                .position(x: size.width / 2, y: size.height * 0.41)

            controlStack
                .position(x: size.width / 2, y: size.height * 0.80)

            alternative
                .frame(maxWidth: size.width - 80)
                .position(x: size.width / 2, y: size.height * 0.943)
        }
    }

    private var accessibilityLayout: some View {
        VStack(spacing: DSSpacing.lg) {
            instructionStack
                .frame(maxWidth: 500)
            Spacer(minLength: DSSpacing.md)
            DSHorizonProgress(
                progress: model.progress,
                increaseContrast: effectiveAccessibility.increaseContrast,
            )
            controlStack
            alternative
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.top, DSSpacing.xl)
        .padding(.bottom, 40)
    }

    private var instructionStack: some View {
        VStack(spacing: DSSpacing.xl) {
            Text(VisualResetL10n.eyebrow.uppercased())
                .font(DSTypography.breakEyebrow(pointSize: eyebrowSize))
                .tracking(2)
                .foregroundStyle(eyebrowInk)

            Text(attributedInstruction)
                .font(DSTypography.breakInstruction(pointSize: instructionSize))
                .tracking(-1.4)
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryInk)
                .lineLimit(3)

            guidanceContent
                .font(DSTypography.breakSupporting(pointSize: supportingSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(secondaryInk)
                .frame(maxWidth: 600)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .dsBreakTextShadow, radius: 18, y: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var controlStack: some View {
        VStack(spacing: DSSpacing.sm) {
            DSBreakCountdown(
                remainingSeconds: model.remainingSeconds,
                accessibilityIdentifier: "visualReset.countdown",
                increaseContrast: effectiveAccessibility.increaseContrast,
            )

            Text(VisualResetL10n.automaticEnding)
                .font(DSTypography.breakMeta(pointSize: metaSize))
                .foregroundStyle(secondaryInk)

            HStack(spacing: DSSpacing.sm) {
                DSBreakPill(
                    VisualResetL10n.doneEarly,
                    keycap: "↩",
                    accessibilityLabel: VisualResetL10n.doneEarly,
                    accessibilityHint: VisualResetL10n.returnKey,
                    accessibilityIdentifier: "visualReset.doneEarly",
                    focus: $doneEarlyFocused,
                    focusOverride: focusPresentation.showsDefaultAction
                        && (doneEarlyFocused || showsInitialFocusFallback),
                    reduceTransparency: effectiveAccessibility.reduceTransparency,
                    increaseContrast: effectiveAccessibility.increaseContrast,
                    action: model.doneEarly,
                )
                .onKeyPress(.space) {
                    model.doneEarlyFromKeyboard()
                    return .handled
                }

                DSBreakPill(
                    VisualResetL10n.skip,
                    keycap: VisualResetL10n.escapeKey,
                    accessibilityLabel: VisualResetL10n.skipAccessibility,
                    accessibilityHint: VisualResetL10n.escapeKeyAccessibility,
                    accessibilityIdentifier: "visualReset.skip",
                    focus: $skipFocused,
                    focusOverride: focusPresentation.showsDefaultAction && skipFocused,
                    reduceTransparency: effectiveAccessibility.reduceTransparency,
                    increaseContrast: effectiveAccessibility.increaseContrast,
                    action: model.skip,
                )
                .keyboardShortcut(.cancelAction)
            }
            .padding(.top, DSSpacing.xs)
        }
    }

    private var alternative: some View {
        Text(VisualResetL10n.alternative)
            .font(DSTypography.breakMeta(pointSize: metaSize))
            .multilineTextAlignment(.center)
            .foregroundStyle(secondaryInk)
    }

    private var attributedInstruction: AttributedString {
        var instruction = AttributedString(VisualResetL10n.instruction)
        if let emphasis = instruction.range(of: VisualResetL10n.instructionEmphasis) {
            instruction[emphasis].font = DSTypography.breakInstructionEmphasis(pointSize: instructionSize)
        }
        return instruction
    }

    @ViewBuilder
    private var guidanceContent: some View {
        if model.phase == .finalSeconds {
            VStack(spacing: 0) {
                Text(VisualResetL10n.guidanceLead)
                Text(VisualResetL10n.blinkPrompt)
                    .font(DSTypography.breakSupportingEmphasis(pointSize: supportingSize))
                    .foregroundStyle(primaryInk)
            }
        } else {
            Text(VisualResetL10n.guidance)
        }
    }

    private var effectiveAccessibility: VisualResetAccessibility {
        var accessibility = accessibilityOverride ?? VisualResetAccessibility(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
            staticPresentation: model.accessibility.staticPresentation,
        )
        accessibility.staticPresentation = accessibility.staticPresentation && staticField != nil
        return accessibility
    }

    private func updateFocusPresentation(_ visible: Bool) {
        guard visible else {
            doneEarlyFocused = false
            skipFocused = false
            return
        }
        Task {
            await Task.yield()
            guard focusPresentation.showsDefaultAction else { return }
            doneEarlyFocused = true
        }
    }

    private var primaryInk: Color {
        effectiveAccessibility.increaseContrast
            ? .dsBreakTextPrimaryIncreased
            : .dsBreakTextPrimary
    }

    private var secondaryInk: Color {
        effectiveAccessibility.increaseContrast
            ? .dsBreakTextSecondaryIncreased
            : .dsBreakTextSecondary
    }

    private var eyebrowInk: Color {
        effectiveAccessibility.increaseContrast
            ? .dsBreakEyebrowIncreased
            : .dsBreakEyebrow
    }
}

private extension VisualResetView {
    var usesLargeTextLayout: Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge
    }

    var eyebrowSize: CGFloat {
        textScale.apply(to: DSTypography.breakEyebrowSize)
    }

    var instructionSize: CGFloat {
        textScale.apply(to: DSTypography.breakInstructionSize)
    }

    var supportingSize: CGFloat {
        textScale.apply(to: DSTypography.breakSupportingSize)
    }

    var metaSize: CGFloat {
        textScale.apply(to: DSTypography.breakMetaSize)
    }
}

private struct VisualResetWorkingField: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [.dsBreakSkyTop, .dsBreakSkyMiddle, .dsBreakSkyHorizon],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                )

                RadialGradient(
                    colors: [.dsBreakGlow.opacity(0.48), .clear],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.32,
                )
                .frame(height: proxy.size.height * 0.65)

                LinearGradient(
                    colors: [.dsBreakGroundTop, .dsBreakGroundBottom],
                    startPoint: .top,
                    endPoint: .bottom,
                )
                .frame(height: proxy.size.height * 0.378)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Working field - running") {
    VisualResetView(model: .preview())
        .frame(width: 1440, height: 900)
}

#Preview("Working field - dark") {
    VisualResetView(model: .preview())
        .environment(\.colorScheme, .dark)
        .frame(width: 1440, height: 900)
}

#Preview("Working field - final seconds") {
    VisualResetView(model: .preview(.finalSeconds))
        .frame(width: 1440, height: 900)
}

#Preview("BR-09 - Merged visual segment") {
    VisualResetView(model: .preview(), context: .merged)
        .frame(width: 1440, height: 900)
}

#Preview("Working field - Increase Contrast") {
    VisualResetView(
        model: .preview(),
        accessibilityOverride: .init(increaseContrast: true),
    )
    .frame(width: 1440, height: 900)
}

#Preview("Working field - Reduce Transparency") {
    VisualResetView(
        model: .preview(),
        accessibilityOverride: .init(reduceTransparency: true),
    )
    .frame(width: 1440, height: 900)
}

#Preview("Working field - Reduce Motion") {
    VisualResetView(
        model: .preview(accessibility: .init(reduceMotion: true)),
        accessibilityOverride: .init(reduceMotion: true),
    )
    .frame(width: 1440, height: 900)
}

#Preview("Working field - largest text") {
    VisualResetView(model: .preview())
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 1440, height: 900)
}

#Preview("Working field - combined accessibility") {
    VisualResetView(
        model: .preview(),
        accessibilityOverride: .init(
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
        ),
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(width: 1440, height: 900)
}
