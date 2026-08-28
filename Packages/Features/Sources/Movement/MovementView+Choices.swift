import DesignSystem
import SwiftUI

extension MovementView {
    @ViewBuilder
    var choiceLayout: some View {
        if usesLargeTextLayout {
            HStack(spacing: DSSpacing.sm) {
                if model.choiceOrder.first == .seated {
                    seatedChoice
                    walkOrWheelChoice
                    smallSpaceChoice
                } else {
                    walkOrWheelChoice
                    smallSpaceChoice
                    seatedChoice
                }
            }
            .frame(maxWidth: 1240)
        } else {
            HStack(spacing: DSSpacing.md) {
                if model.choiceOrder.first == .seated {
                    seatedChoice
                    walkOrWheelChoice
                    smallSpaceChoice
                } else {
                    walkOrWheelChoice
                    smallSpaceChoice
                    seatedChoice
                }
            }
        }
    }

    private var walkOrWheelChoice: some View {
        choiceChip(
            .walkOrWheel,
            keycap: MovementL10n.oneKey,
            glyph: .walkOrWheel,
            focus: $walkOrWheelFocused,
        )
    }

    private var smallSpaceChoice: some View {
        choiceChip(
            .smallSpace,
            keycap: MovementL10n.twoKey,
            glyph: .smallSpace,
            focus: $smallSpaceFocused,
        )
    }

    private var seatedChoice: some View {
        choiceChip(
            .seated,
            keycap: MovementL10n.threeKey,
            glyph: .seated,
            focus: $seatedFocused,
        )
    }

    private func choiceChip(
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
}
