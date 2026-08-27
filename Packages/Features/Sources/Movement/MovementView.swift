import DesignSystem
import Foundation
import SwiftUI

public struct MovementView: View {
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) var eyebrowSize = DSTypography.breakEyebrowSize
    @ScaledMetric(relativeTo: .largeTitle) var instructionSize = DSTypography.breakLongInstructionSize
    @ScaledMetric(relativeTo: .body) var supportingSize = DSTypography.breakSupportingSize
    @ScaledMetric(relativeTo: .caption) var metaSize = DSTypography.breakMetaSize
    @ScaledMetric(relativeTo: .caption) var safetySize = DSTypography.breakSafetySize
    @State var model: MovementModel
    @State var focusPresentation: MovementFocusPresentation
    @State var showsInitialFocusFallback = true
    @FocusState var walkOrWheelFocused: Bool
    @FocusState var smallSpaceFocused: Bool
    @FocusState var seatedFocused: Bool
    @FocusState var quickDurationFocused: Bool
    @FocusState var doneEarlyFocused: Bool
    @FocusState var alreadyMovedFocused: Bool
    @FocusState var skipFocused: Bool
    @FocusState var positionChangeFocused: Bool

    let standardField: AnyView
    let staticField: AnyView
    let accessibilityOverride: MovementAccessibility?
    let focusedControlOverride: MovementControl?

    public init(
        model: MovementModel,
        standardField: AnyView? = nil,
        staticField: AnyView? = nil,
        accessibilityOverride: MovementAccessibility? = nil,
        focusedControlOverride: MovementControl? = nil,
        focusPresentation: MovementFocusPresentation = .init(),
        opensAutomatically: Bool = true,
    ) {
        if opensAutomatically {
            model.open()
        }
        _model = State(initialValue: model)
        _focusPresentation = State(initialValue: focusPresentation)
        self.standardField = standardField ?? AnyView(MovementWorkingField())
        self.staticField = staticField ?? AnyView(MovementStaticField())
        self.accessibilityOverride = accessibilityOverride
        self.focusedControlOverride = focusedControlOverride
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                field
                    .accessibilityHidden(true)

                if usesLargeTextLayout {
                    accessibilityLayout
                } else {
                    standardLayout(in: proxy.size)
                }

                if !effectiveAccessibility.staticPresentation {
                    DSHorizonProgress(
                        progress: model.progress,
                        increaseContrast: usesContrastSafeTokens,
                    )
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.711)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("movement.surface")
        .defaultFocus($doneEarlyFocused, true)
        .onKeyPress(.return) {
            model.doneEarlyFromKeyboard()
            return .handled
        }
        .onKeyPress(
            characters: CharacterSet(charactersIn: "123qQaApP"),
            phases: .down,
        ) { press in
            handleDeclarationKey(press)
        }
        .onAppear {
            model.updateAccessibility(effectiveAccessibility)
            updateFocusPresentation(focusPresentation.showsDefaultAction)
        }
        .onChange(of: effectiveAccessibility) { _, accessibility in
            model.updateAccessibility(accessibility)
        }
        .onChange(of: walkOrWheelFocused) { _, focused in hideFallbackIfFocused(focused) }
        .onChange(of: smallSpaceFocused) { _, focused in hideFallbackIfFocused(focused) }
        .onChange(of: seatedFocused) { _, focused in hideFallbackIfFocused(focused) }
        .onChange(of: quickDurationFocused) { _, focused in hideFallbackIfFocused(focused) }
        .onChange(of: doneEarlyFocused) { _, focused in hideFallbackIfFocused(focused) }
        .onChange(of: alreadyMovedFocused) { _, focused in hideFallbackIfFocused(focused) }
        .onChange(of: skipFocused) { _, focused in hideFallbackIfFocused(focused) }
        .onChange(of: positionChangeFocused) { _, focused in hideFallbackIfFocused(focused) }
        .onChange(of: focusPresentation.showsDefaultAction) { _, visible in
            updateFocusPresentation(visible)
        }
    }
}

private extension MovementView {
    @ViewBuilder
    var field: some View {
        if effectiveAccessibility.staticPresentation {
            staticField
        } else {
            standardField
        }
    }

    func standardLayout(in size: CGSize) -> some View {
        ZStack {
            instructionStack
                .frame(maxWidth: min(1100, size.width - 80))
                .position(x: size.width / 2, y: size.height * 0.325)

            choiceAndGuidance
                .frame(maxWidth: min(1020, size.width - 80))
                .position(x: size.width / 2, y: size.height * 0.51)

            controlStack
                .frame(maxWidth: size.width - 80)
                .position(x: size.width / 2, y: size.height * 0.855)
        }
    }

    var accessibilityLayout: some View {
        VStack(spacing: DSSpacing.sm) {
            instructionStack
                .frame(maxWidth: 960)
            choiceAndGuidance
            Spacer(minLength: DSSpacing.sm)
            controlStack
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.top, DSSpacing.xl)
        .padding(.bottom, DSSpacing.lg)
    }

    var instructionStack: some View {
        VStack(spacing: DSSpacing.xl) {
            Text(MovementL10n.eyebrow.uppercased())
                .font(DSTypography.breakEyebrow(pointSize: eyebrowSize))
                .tracking(2)
                .foregroundStyle(eyebrowInk)

            Text(attributedInstruction)
                .font(DSTypography.breakInstruction(pointSize: instructionSize))
                .tracking(-1.4)
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryInk)
                .lineLimit(3)
                .shadow(color: .dsBreakTextShadow, radius: 18, y: 1)
        }
        .background {
            staticTextBackdrop(
                horizontalExpansion: DSSpacing.lg,
                verticalExpansion: DSSpacing.sm,
                radius: DSRadius.lg,
            )
        }
        .accessibilityElement(children: .combine)
    }

    var choiceAndGuidance: some View {
        VStack(spacing: DSSpacing.lg) {
            choiceLayout

            Text(MovementL10n.guidance(model.guidance))
                .font(DSTypography.breakSupporting(pointSize: supportingSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryInk)
                .frame(maxWidth: usesLargeTextLayout ? 500 : 760)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .dsBreakTextShadow, radius: 18, y: 1)
                .background {
                    staticTextBackdrop(
                        horizontalExpansion: DSSpacing.md,
                        verticalExpansion: DSSpacing.xs,
                    )
                }
                .accessibilityIdentifier("movement.guidance")
        }
    }

    @ViewBuilder
    var choiceLayout: some View {
        if usesLargeTextLayout {
            Grid(
                horizontalSpacing: DSSpacing.sm,
                verticalSpacing: DSSpacing.sm,
            ) {
                GridRow {
                    walkOrWheelChoice
                    smallSpaceChoice
                }
                GridRow {
                    seatedChoice
                    Color.clear
                        .frame(height: 64)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: 940)
        } else {
            HStack(spacing: DSSpacing.md) {
                walkOrWheelChoice
                smallSpaceChoice
                seatedChoice
            }
        }
    }

    var walkOrWheelChoice: some View {
        choiceChip(
            .walkOrWheel,
            keycap: MovementL10n.oneKey,
            glyph: .walkOrWheel,
            focus: $walkOrWheelFocused,
        )
    }

    var smallSpaceChoice: some View {
        choiceChip(
            .smallSpace,
            keycap: MovementL10n.twoKey,
            glyph: .smallSpace,
            focus: $smallSpaceFocused,
        )
    }

    var seatedChoice: some View {
        choiceChip(
            .seated,
            keycap: MovementL10n.threeKey,
            glyph: .seated,
            focus: $seatedFocused,
        )
    }

    func choiceChip(
        _ choice: MovementChoice,
        keycap: String,
        glyph: DSMovementChoiceGlyph.Kind,
        focus: FocusState<Bool>.Binding,
    ) -> some View {
        DSBreakChoiceChip(
            MovementL10n.choiceTitle(choice),
            keycap: keycap,
            selected: model.selectedChoice == choice,
            accessibilityLabel: MovementL10n.choiceAccessibility(choice),
            accessibilityIdentifier: "movement.choice.\(choice.identifier)",
            focus: focus,
            focusOverride: focusOverride(for: choice.control, actual: focus.wrappedValue),
            reduceTransparency: usesOpaqueControlBackgrounds,
            increaseContrast: usesContrastSafeTokens,
            action: { model.select(choice) },
            glyph: { DSMovementChoiceGlyph(glyph) },
        )
    }

    var controlStack: some View {
        VStack(spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.lg) {
                DSBreakCountdown(
                    remainingSeconds: model.remainingSeconds,
                    accessibilityIdentifier: "movement.countdown",
                    increaseContrast: usesContrastSafeTokens,
                )
                .background {
                    staticTextBackdrop(
                        horizontalExpansion: DSSpacing.sm,
                        verticalExpansion: DSSpacing.xs,
                    )
                }

                DSBreakPill(
                    MovementL10n.twoMinutesInstead,
                    keycap: MovementL10n.quickKey,
                    accessibilityLabel: MovementL10n.quickAccessibility,
                    accessibilityIdentifier: "movement.quickDuration",
                    focus: $quickDurationFocused,
                    focusOverride: focusOverride(
                        for: .quickDuration,
                        actual: quickDurationFocused,
                    ),
                    reduceTransparency: usesOpaqueControlBackgrounds,
                    increaseContrast: usesContrastSafeTokens,
                    selected: model.selectedDurationSeconds == model.quickDurationSeconds,
                    action: model.selectQuickDuration,
                )
            }

            Text(MovementL10n.automaticEnding)
                .font(DSTypography.breakMeta(pointSize: metaSize))
                .foregroundStyle(secondaryInk)
                .background {
                    staticTextBackdrop(
                        horizontalExpansion: DSSpacing.sm,
                        verticalExpansion: 2,
                    )
                }

            HStack(spacing: DSSpacing.sm) {
                DSBreakPill(
                    MovementL10n.doneEarly,
                    keycap: "↩",
                    accessibilityLabel: MovementL10n.doneEarlyAccessibility,
                    accessibilityHint: MovementL10n.returnKey,
                    accessibilityIdentifier: "movement.doneEarly",
                    focus: $doneEarlyFocused,
                    focusOverride: focusOverride(for: .doneEarly, actual: doneEarlyFocused),
                    reduceTransparency: usesOpaqueControlBackgrounds,
                    increaseContrast: usesContrastSafeTokens,
                    action: model.doneEarly,
                )

                DSBreakPill(
                    MovementL10n.alreadyMoved,
                    keycap: MovementL10n.alreadyMovedKey,
                    accessibilityLabel: MovementL10n.alreadyMovedAccessibility,
                    accessibilityIdentifier: "movement.alreadyMoved",
                    focus: $alreadyMovedFocused,
                    focusOverride: focusOverride(for: .alreadyMoved, actual: alreadyMovedFocused),
                    reduceTransparency: usesOpaqueControlBackgrounds,
                    increaseContrast: usesContrastSafeTokens,
                    action: model.alreadyMoved,
                )

                DSBreakPill(
                    MovementL10n.skip,
                    keycap: MovementL10n.escapeKey,
                    accessibilityLabel: MovementL10n.skipAccessibility,
                    accessibilityHint: MovementL10n.escapeKeyAccessibility,
                    accessibilityIdentifier: "movement.skip",
                    focus: $skipFocused,
                    focusOverride: focusOverride(for: .skip, actual: skipFocused),
                    reduceTransparency: usesOpaqueControlBackgrounds,
                    increaseContrast: usesContrastSafeTokens,
                    action: model.skip,
                )
                .keyboardShortcut(.cancelAction)
            }

            DSBreakQuietPill(
                MovementL10n.positionChange,
                detail: MovementL10n.loggedSeparately,
                keycap: MovementL10n.positionChangeKey,
                accessibilityLabel: MovementL10n.positionChangeAccessibility,
                accessibilityIdentifier: "movement.positionChange",
                focus: $positionChangeFocused,
                focusOverride: focusOverride(
                    for: .positionChange,
                    actual: positionChangeFocused,
                ),
                reduceTransparency: usesOpaqueControlBackgrounds,
                increaseContrast: usesContrastSafeTokens,
                action: model.positionChanged,
            )

            Text(MovementL10n.safety)
                .font(DSTypography.breakSafety(pointSize: safetySize))
                .multilineTextAlignment(.center)
                .foregroundStyle(secondaryInk)
                .frame(maxWidth: usesLargeTextLayout ? 680 : 1160)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("movement.safety")
                .padding(.top, DSSpacing.xs)
                .background {
                    staticTextBackdrop(
                        horizontalExpansion: DSSpacing.sm,
                        verticalExpansion: 2,
                    )
                }
        }
    }

}

#Preview("Working field - walk or wheel") {
    MovementView(model: .preview(), opensAutomatically: false)
        .frame(width: 1440, height: 900)
}
