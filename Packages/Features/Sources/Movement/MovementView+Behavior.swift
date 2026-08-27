import DesignSystem
import SwiftUI

extension MovementView {
    var attributedInstruction: AttributedString {
        var instruction = AttributedString(MovementL10n.instruction)
        if let emphasis = instruction.range(of: MovementL10n.instructionEmphasis) {
            instruction[emphasis].font = DSTypography.breakInstructionEmphasis(
                pointSize: instructionSize,
            )
        }
        return instruction
    }

    var effectiveAccessibility: MovementAccessibility {
        accessibilityOverride ?? MovementAccessibility(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
            staticPresentation: model.accessibility.staticPresentation,
        )
    }

    var usesLargeTextLayout: Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge
    }

    var primaryInk: Color {
        if effectiveAccessibility.staticPresentation { return .dsStaticText }
        return usesContrastSafeTokens ? .dsBreakTextPrimaryIncreased : .dsBreakTextPrimary
    }

    var secondaryInk: Color {
        if effectiveAccessibility.staticPresentation { return .dsStaticText }
        return usesContrastSafeTokens
            ? Color.dsBreakTextSecondaryIncreased
            : Color.dsBreakTextSecondary
    }

    var eyebrowInk: Color {
        if effectiveAccessibility.staticPresentation { return .dsStaticText }
        return usesContrastSafeTokens ? Color.dsBreakEyebrowIncreased : Color.dsBreakEyebrow
    }

    var usesContrastSafeTokens: Bool {
        effectiveAccessibility.increaseContrast || effectiveAccessibility.staticPresentation
    }

    var usesOpaqueControlBackgrounds: Bool {
        effectiveAccessibility.reduceTransparency || effectiveAccessibility.staticPresentation
    }

    @ViewBuilder
    func staticTextBackdrop(
        horizontalExpansion: CGFloat,
        verticalExpansion: CGFloat,
        radius: CGFloat = DSRadius.sm,
    ) -> some View {
        if effectiveAccessibility.staticPresentation {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.dsStaticTextScrim)
                .padding(.horizontal, -horizontalExpansion)
                .padding(.vertical, -verticalExpansion)
        }
    }

    func focusOverride(for control: MovementControl, actual: Bool) -> Bool? {
        if let focusedControlOverride { return focusedControlOverride == control }
        if control == .doneEarly {
            return focusPresentation.showsDefaultAction && (actual || showsInitialFocusFallback)
        }
        return actual
    }

    func hideFallbackIfFocused(_ focused: Bool) {
        if focused { showsInitialFocusFallback = false }
    }

    func updateFocusPresentation(_ visible: Bool) {
        guard visible else {
            doneEarlyFocused = false
            return
        }
        Task {
            await Task.yield()
            guard focusPresentation.showsDefaultAction else { return }
            doneEarlyFocused = true
        }
    }

    func handleDeclarationKey(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isEmpty else { return .ignored }
        switch press.characters.lowercased() {
        case "1": model.selectFromKeyboard(.walkOrWheel)
        case "2": model.selectFromKeyboard(.smallSpace)
        case "3": model.selectFromKeyboard(.seated)
        case "q": model.selectQuickDurationFromKeyboard()
        case "a": model.alreadyMovedFromKeyboard()
        case "p": model.positionChangedFromKeyboard()
        default: return .ignored
        }
        return .handled
    }
}
