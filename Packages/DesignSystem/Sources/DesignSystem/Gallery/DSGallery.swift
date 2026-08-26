import SwiftUI

/// The component catalog: one place to see every token and component.
///
/// Two jobs:
/// 1. Lookup — before building any UI, check here whether a component already
///    exists. Reinventing an existing component is the top cause of design drift.
/// 2. Regression — the gallery snapshots in DesignSystemTests are the design
///    system's visual contract; any token change shows up as a gallery diff.
public struct DSGallery: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                TokensSection()
                ComponentsSection()
                MovementControlsSection()
            }
            .padding(DSSpacing.lg)
        }
        .background(Color.dsBackground)
        .navigationTitle(DesignSystemL10n.galleryTitle)
    }

    /// Token swatches: colors, type ramp, spacing, radii, motion vocabulary.
    public struct TokensSection: View {
        public init() {}

        private let colors: [(String, Color)] = [
            ("background", .dsBackground),
            ("surface", .dsSurface),
            ("surfaceSecondary", .dsSurfaceSecondary),
            ("textPrimary", .dsTextPrimary),
            ("textSecondary", .dsTextSecondary),
            ("menuTextPrimary", .dsMenuTextPrimary),
            ("menuTextSecondary", .dsMenuTextSecondary),
            ("menuTrack", .dsMenuTrack),
            ("visualBar", .dsVisualBar),
            ("movementBar", .dsMovementBar),
            ("breakTextPrimary", .dsBreakTextPrimary),
            ("breakTextPrimaryIC", .dsBreakTextPrimaryIncreased),
            ("breakSkyTop", .dsBreakSkyTop),
            ("breakSkyHorizon", .dsBreakSkyHorizon),
            ("breakGroundBottom", .dsBreakGroundBottom),
            ("breakHorizonFill", .dsBreakHorizonFill),
            ("breakHorizonTrackIC", .dsBreakHorizonTrackIncreased),
            ("movementSkyTop", .dsMovementSkyTop),
            ("movementSkyMiddle", .dsMovementSkyMiddle),
            ("movementSkyHorizon", .dsMovementSkyHorizon),
            ("movementGroundTop", .dsMovementGroundTop),
            ("movementGroundBottom", .dsMovementGroundBottom),
            ("movementGlow", .dsMovementGlow),
            ("movementControlSolid", .dsMovementControlSolid),
            ("movementChoiceScrim", .dsMovementChoiceScrim),
            ("movementChoiceFill", .dsMovementChoiceGlassFill),
            ("movementSelectedFill", .dsMovementChoiceSelectedFill),
            ("movementSelected", .dsMovementChoiceSelected),
            ("movementChoiceCheck", .dsMovementChoiceCheck),
            ("movementGlyphInk", .dsMovementGlyphInk),
            ("movementWalkTop", .dsMovementWalkTileTop),
            ("movementWalkBottom", .dsMovementWalkTileBottom),
            ("movementSmallTop", .dsMovementSmallSpaceTileTop),
            ("movementSmallBottom", .dsMovementSmallSpaceTileBottom),
            ("movementSeatedTop", .dsMovementSeatedTileTop),
            ("movementSeatedBottom", .dsMovementSeatedTileBottom),
            ("accent", .dsAccent),
            ("positive", .dsPositive),
            ("warning", .dsWarning),
            ("danger", .dsDanger),
        ]

        public var body: some View {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                header(DesignSystemL10n.Sections.colors)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: DSSpacing.md) {
                    ForEach(colors, id: \.0) { name, color in
                        VStack(spacing: DSSpacing.xs) {
                            RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                                .fill(color)
                                .frame(height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                                        .strokeBorder(Color.dsSeparator),
                                )
                            Text(name)
                                .font(DSTypography.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

                header(DesignSystemL10n.Sections.typography)
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text(DesignSystemL10n.Typography.largeTitle).font(DSTypography.largeTitle)
                    Text(DesignSystemL10n.Typography.title).font(DSTypography.title)
                    Text(DesignSystemL10n.Typography.headline).font(DSTypography.headline)
                    Text(DesignSystemL10n.Typography.body).font(DSTypography.body)
                    Text(DesignSystemL10n.Typography.subtext).font(DSTypography.subtext)
                    Text(DesignSystemL10n.Typography.caption).font(DSTypography.caption)
                    Text(DesignSystemL10n.Typography.breakLongInstruction)
                        .font(DSTypography.breakInstruction(pointSize: DSTypography.breakLongInstructionSize))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(DesignSystemL10n.Typography.breakChoice)
                        .font(DSTypography.breakChoice(pointSize: DSTypography.breakChoiceSize))
                    Text(DesignSystemL10n.Typography.breakSafety)
                        .font(DSTypography.breakSafety(pointSize: DSTypography.breakSafetySize))
                }
                .foregroundStyle(Color.dsTextPrimary)

                header(DesignSystemL10n.Sections.spacing)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    spacingBar("xs", DSSpacing.xs)
                    spacingBar("sm", DSSpacing.sm)
                    spacingBar("md", DSSpacing.md)
                    spacingBar("lg", DSSpacing.lg)
                    spacingBar("xl", DSSpacing.xl)
                    spacingBar("xxl", DSSpacing.xxl)
                }

                header(DesignSystemL10n.Sections.motion)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    ForEach(DSMotion.catalog, id: \.name) { token in
                        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                            Text(token.name)
                                .font(DSTypography.caption.weight(.semibold))
                                .foregroundStyle(Color.dsAccent)
                            Text(token.intent)
                                .font(DSTypography.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                    }
                }
            }
        }

        private func spacingBar(_ name: String, _ value: CGFloat) -> some View {
            HStack(spacing: DSSpacing.sm) {
                Text(name)
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .frame(width: 28, alignment: .leading)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.dsAccent.opacity(0.6))
                    .frame(width: value * 4, height: 8)
                Text(DesignSystemL10n.spacingPoints(Int(value)))
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
    }

    /// Every reusable component in representative states.
    public struct ComponentsSection: View {
        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                header(DesignSystemL10n.Sections.protocolMark)
                HStack(spacing: DSSpacing.xl) {
                    ForEach(DSProtocolMark.State.allCases, id: \.self) { state in
                        DSProtocolMark(state: state, size: 32)
                    }
                }
                .foregroundStyle(Color.dsTextPrimary)

                header(DesignSystemL10n.Sections.buttons)
                VStack(spacing: DSSpacing.sm) {
                    DSButton(DesignSystemL10n.Buttons.primary, style: .primary) {}
                    DSButton(DesignSystemL10n.Buttons.secondary, systemImage: "plus", style: .secondary) {}
                    DSButton(DesignSystemL10n.Buttons.destructive, style: .destructive) {}
                }

                header(DesignSystemL10n.Sections.breakControls)
                VStack(spacing: DSSpacing.md) {
                    DSBreakCountdown(remainingSeconds: 12)
                    DSHorizonProgress(progress: 0.4)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))], spacing: DSSpacing.sm) {
                        DSBreakPill(
                            DesignSystemL10n.BreakField.doneEarly,
                            keycap: "↩",
                            accessibilityLabel: DesignSystemL10n.BreakField.doneEarly,
                            accessibilityIdentifier: "designSystem.break.doneEarly",
                        ) {}
                        DSBreakPill(
                            DesignSystemL10n.BreakField.skip,
                            keycap: "esc",
                            accessibilityLabel: DesignSystemL10n.BreakField.skip,
                            accessibilityIdentifier: "designSystem.break.skip",
                            reduceTransparency: true,
                        ) {}
                        DSBreakPill(
                            DesignSystemL10n.Buttons.continueTitle,
                            keycap: "↩",
                            accessibilityLabel: DesignSystemL10n.Buttons.continueTitle,
                            accessibilityIdentifier: "designSystem.break.focused",
                            focusOverride: true,
                        ) {}
                        DSBreakPill(
                            DesignSystemL10n.Buttons.secondary,
                            keycap: "esc",
                            accessibilityLabel: DesignSystemL10n.Buttons.secondary,
                            accessibilityIdentifier: "designSystem.break.increasedContrast",
                            increaseContrast: true,
                        ) {}
                    }
                }
                .padding(DSSpacing.lg)
                .background(Color.dsBreakGroundTop, in: RoundedRectangle(cornerRadius: DSRadius.md))

                header(DesignSystemL10n.Sections.tags)
                HStack(spacing: DSSpacing.sm) {
                    DSTag(DesignSystemL10n.Tags.neutral)
                    DSTag(DesignSystemL10n.Tags.new, style: .accent)
                    DSTag(DesignSystemL10n.Tags.done, style: .positive)
                    DSTag(DesignSystemL10n.Tags.warning, style: .warning)
                    DSTag(DesignSystemL10n.Tags.failed, style: .danger)
                }

                header(DesignSystemL10n.Sections.card)
                DSCard {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text(DesignSystemL10n.Card.previewTitle)
                            .font(DSTypography.headline)
                            .foregroundStyle(Color.dsTextPrimary)
                        Text(DesignSystemL10n.Card.galleryText)
                            .font(DSTypography.subtext)
                            .foregroundStyle(Color.dsTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                header(DesignSystemL10n.Sections.emptyState)
                DSEmptyState(
                    systemImage: "tray",
                    title: DesignSystemL10n.EmptyState.previewTitle,
                    message: DesignSystemL10n.EmptyState.previewMessage,
                    actionTitle: DesignSystemL10n.Buttons.addItem,
                    action: {},
                )
            }
        }
    }
}

private func header(_ title: String) -> some View {
    Text(title)
        .font(DSTypography.title)
        .foregroundStyle(Color.dsTextPrimary)
}

#Preview("Gallery") {
    NavigationStack { DSGallery() }
}
