import DesignSystem
import Foundation
import SwiftUI

enum MovementStandardLayoutMetrics {
    static let instructionYFraction: CGFloat = 0.325
    static let choicesYFraction: CGFloat = 0.51
    static let controlsYFraction: CGFloat = 0.855

    static func y(_ fraction: CGFloat, in height: CGFloat) -> CGFloat {
        DSBreakForegroundLayout.y(fraction, in: height)
    }
}

public struct MovementView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.dsTextScale) var textScale
    @Environment(\.dsBreakEntrance) var breakEntrance
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
    @FocusState var visualOnlyFocused: Bool

    let standardField: AnyView?
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
        self.standardField = standardField
        self.staticField = staticField ?? AnyView(MovementStaticField())
        self.accessibilityOverride = accessibilityOverride
        self.focusedControlOverride = focusedControlOverride
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                field
                    .accessibilityHidden(true)
                Group {
                    if usesLargeTextLayout {
                        accessibilityLayout
                    } else {
                        standardLayout(in: proxy.size)
                    }

                    if !effectiveAccessibility.staticPresentation, !usesLargeTextLayout {
                        DSHorizonProgress(
                            progress: model.progress,
                            increaseContrast: usesContrastSafeTokens,
                        )
                        .dsBreakEntrance(phase: breakEntrance.phase, element: .control)
                        .position(
                            x: proxy.size.width / 2,
                            y: MovementStandardLayoutMetrics.y(0.711, in: proxy.size.height),
                        )
                    }
                }
                .environment(\.colorScheme, overlayColorScheme)
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
        .onChange(of: visualOnlyFocused) { _, focused in hideFallbackIfFocused(focused) }
        .onChange(of: focusPresentation.showsDefaultAction) { _, visible in
            updateFocusPresentation(visible)
        }
    }

    var overlayColorScheme: ColorScheme {
        effectiveAccessibility.staticPresentation ? colorScheme : .dark
    }
}

private extension MovementView {
    @ViewBuilder
    var field: some View {
        if effectiveAccessibility.staticPresentation {
            staticField
        } else if let standardField {
            standardField
        } else {
            MovementWorkingField(choice: model.selectedChoice)
        }
    }

    func standardLayout(in size: CGSize) -> some View {
        ZStack {
            instructionStack
                .frame(maxWidth: min(1100, size.width - 80))
                .position(
                    x: size.width / 2,
                    y: MovementStandardLayoutMetrics.y(
                        MovementStandardLayoutMetrics.instructionYFraction,
                        in: size.height,
                    ),
                )

            choiceAndGuidance
                .frame(maxWidth: min(1020, size.width - 80))
                .position(
                    x: size.width / 2,
                    y: MovementStandardLayoutMetrics.y(
                        MovementStandardLayoutMetrics.choicesYFraction,
                        in: size.height,
                    ),
                )

            controlStack
                .frame(maxWidth: size.width - 80)
                .position(
                    x: size.width / 2,
                    y: MovementStandardLayoutMetrics.y(
                        MovementStandardLayoutMetrics.controlsYFraction,
                        in: size.height,
                    ),
                )
        }
    }

    var accessibilityLayout: some View {
        VStack(spacing: DSSpacing.sm) {
            instructionStack
                .frame(maxWidth: 960)
            choiceAndGuidance
            Spacer(minLength: DSSpacing.sm)
            if !effectiveAccessibility.staticPresentation {
                DSHorizonProgress(
                    progress: model.progress,
                    increaseContrast: usesContrastSafeTokens,
                )
            }
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
        .dsBreakEntrance(phase: breakEntrance.phase, element: .instruction)
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
        .dsBreakEntrance(phase: breakEntrance.phase, element: .control)
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

                mergedVisualOnlyAction

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
        .dsBreakEntrance(phase: breakEntrance.phase, element: .control)
    }
}

#Preview("Working field - walk or wheel") {
    MovementView(model: .preview(), opensAutomatically: false)
        .frame(width: 1440, height: 900)
}
