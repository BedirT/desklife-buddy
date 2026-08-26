import SwiftUI

public extension DSGallery {
    /// Movement controls at their intended same-row size, plus accessibility variants.
    struct MovementControlsSection: View {
        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text(DesignSystemL10n.Sections.movementChoices)
                    .font(DSTypography.title)
                    .foregroundStyle(Color.dsTextPrimary)
                VStack(spacing: DSSpacing.md) {
                    HStack(spacing: DSSpacing.md) {
                        choice(
                            .walkOrWheel,
                            title: DesignSystemL10n.BreakField.walkOrWheel,
                            keycap: "1",
                            selected: true,
                        )
                        choice(.smallSpace, title: DesignSystemL10n.BreakField.smallSpace, keycap: "2")
                        choice(.seated, title: DesignSystemL10n.BreakField.seated, keycap: "3")
                    }
                    HStack(spacing: DSSpacing.md) {
                        choice(
                            .walkOrWheel,
                            title: DesignSystemL10n.BreakField.walkOrWheel,
                            keycap: "1",
                            suffix: "focused",
                            focusOverride: true,
                        )
                        choice(
                            .smallSpace,
                            title: DesignSystemL10n.BreakField.smallSpace,
                            keycap: "2",
                            suffix: "reducedTransparency",
                            reduceTransparency: true,
                        )
                        choice(
                            .seated,
                            title: DesignSystemL10n.BreakField.seated,
                            keycap: "3",
                            suffix: "increasedContrast",
                            increaseContrast: true,
                        )
                    }
                    HStack(spacing: DSSpacing.md) {
                        quietPill(suffix: "standard")
                        quietPill(suffix: "focused", focusOverride: true)
                    }
                    HStack(spacing: DSSpacing.md) {
                        quietPill(suffix: "reducedTransparency", reduceTransparency: true)
                        quietPill(suffix: "increasedContrast", increaseContrast: true)
                    }
                }
                .padding(DSSpacing.lg)
                .background(Color.dsMovementGroundTop, in: RoundedRectangle(cornerRadius: DSRadius.md))
            }
        }

        private func choice(
            _ kind: DSMovementChoiceGlyph.Kind,
            title: String,
            keycap: String,
            selected: Bool = false,
            suffix: String = "standard",
            focusOverride: Bool? = nil,
            reduceTransparency: Bool = false,
            increaseContrast: Bool = false,
        ) -> some View {
            DSBreakChoiceChip(
                title,
                keycap: keycap,
                selected: selected,
                accessibilityLabel: choiceAccessibilityLabel(kind),
                accessibilityIdentifier: "designSystem.movement.\(kind).\(suffix)",
                focusOverride: focusOverride,
                reduceTransparency: reduceTransparency,
                increaseContrast: increaseContrast,
                action: {},
                glyph: { DSMovementChoiceGlyph(kind) },
            )
        }

        private func quietPill(
            suffix: String,
            focusOverride: Bool? = nil,
            reduceTransparency: Bool = false,
            increaseContrast: Bool = false,
        ) -> some View {
            DSBreakQuietPill(
                DesignSystemL10n.BreakField.changePosition,
                detail: DesignSystemL10n.BreakField.loggedSeparately,
                keycap: "P",
                accessibilityLabel: DesignSystemL10n.BreakField.changePositionAccessibility,
                accessibilityIdentifier: "designSystem.movement.position.\(suffix)",
                focusOverride: focusOverride,
                reduceTransparency: reduceTransparency,
                increaseContrast: increaseContrast,
            ) {}
        }

        private func choiceAccessibilityLabel(_ kind: DSMovementChoiceGlyph.Kind) -> String {
            switch kind {
            case .walkOrWheel: DesignSystemL10n.BreakField.walkOrWheelAccessibility
            case .smallSpace: DesignSystemL10n.BreakField.smallSpaceAccessibility
            case .seated: DesignSystemL10n.BreakField.seatedAccessibility
            }
        }
    }
}

#Preview("Movement controls gallery") {
    DSGallery.MovementControlsSection()
        .padding(DSSpacing.lg)
        .frame(width: 1120)
        .background(Color.dsBackground)
}
