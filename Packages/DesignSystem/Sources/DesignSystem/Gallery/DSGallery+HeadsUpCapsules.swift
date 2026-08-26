import SwiftUI

public extension DSGallery {
    /// The complete static capsule vocabulary; runtime timing and placement stay feature/App-owned.
    struct HeadsUpCapsulesSection: View {
        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text(DesignSystemL10n.Sections.headsUpCapsules)
                    .font(DSTypography.title)
                    .foregroundStyle(Color.dsTextPrimary)

                capsuleRow {
                    capsule(
                        suffix: "approach",
                        detail: DesignSystemL10n.HeadsUp.time45,
                        indicator: .sun(horizontal: 0.18, descent: 0),
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility45,
                    )
                    capsule(
                        suffix: "countdown30",
                        detail: DesignSystemL10n.HeadsUp.time30,
                        indicator: .sun(horizontal: 0.5, descent: 0.33),
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility30,
                    )
                    capsule(
                        suffix: "hover",
                        detail: DesignSystemL10n.HeadsUp.time15,
                        indicator: .sun(horizontal: 0.72, descent: 0.65),
                        showsActions: true,
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility15,
                    )
                    capsule(
                        suffix: "landed",
                        detail: DesignSystemL10n.HeadsUp.time5,
                        indicator: .sun(horizontal: 0.5, descent: 1),
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility5,
                    )
                }

                capsuleRow {
                    capsule(
                        suffix: "hold",
                        title: DesignSystemL10n.HeadsUp.onHold,
                        detail: DesignSystemL10n.HeadsUp.busyUntil,
                        indicator: .hold,
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibilityHold,
                    )
                    capsule(
                        suffix: "textOnly",
                        detail: DesignSystemL10n.HeadsUp.time45,
                        indicator: nil,
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility45,
                    )
                }

                capsuleRow {
                    capsule(
                        suffix: "reducedTransparency",
                        detail: DesignSystemL10n.HeadsUp.time15,
                        indicator: .sun(horizontal: 0.5, descent: 0.5),
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility15,
                        reduceTransparency: true,
                    )
                    capsule(
                        suffix: "increasedContrast",
                        title: DesignSystemL10n.HeadsUp.onHold,
                        detail: DesignSystemL10n.HeadsUp.paused,
                        indicator: .hold,
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibilityPaused,
                        increaseContrast: true,
                    )
                    capsule(
                        suffix: "reducedMotionHigh",
                        detail: DesignSystemL10n.HeadsUp.time45,
                        indicator: .sun(horizontal: 0.5, descent: 0),
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility45,
                    )
                    capsule(
                        suffix: "reducedMotionMiddle",
                        detail: DesignSystemL10n.HeadsUp.time15,
                        indicator: .sun(horizontal: 0.5, descent: 0.5),
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility15,
                    )
                    capsule(
                        suffix: "reducedMotionLanded",
                        detail: DesignSystemL10n.HeadsUp.time5,
                        indicator: .sun(horizontal: 0.5, descent: 1),
                        statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility5,
                    )
                }

                capsule(
                    suffix: "largeText",
                    detail: DesignSystemL10n.HeadsUp.time15,
                    indicator: .sun(horizontal: 0.5, descent: 0.5),
                    showsActions: true,
                    statusAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibility15,
                )
                .dynamicTypeSize(.accessibility5)
                .frame(width: 250, alignment: .leading)
            }
        }

        private func capsuleRow(@ViewBuilder content: () -> some View) -> some View {
            HStack(spacing: DSSpacing.lg, content: content)
        }

        private func capsule(
            suffix: String,
            title: String = DesignSystemL10n.HeadsUp.visualReset,
            detail: String,
            indicator: DSHeadsUpCapsule.Indicator?,
            showsActions: Bool = false,
            statusAccessibilityLabel: String,
            reduceTransparency: Bool = false,
            increaseContrast: Bool = false,
        ) -> some View {
            DSHeadsUpCapsule(
                title: title,
                detail: detail,
                indicator: indicator,
                showsActions: showsActions,
                nowTitle: DesignSystemL10n.HeadsUp.now,
                laterTitle: DesignSystemL10n.HeadsUp.later,
                laterOptions: DesignSystemL10n.HeadsUp.laterOptions,
                statusAccessibilityLabel: statusAccessibilityLabel,
                nowAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibilityStartNow,
                laterAccessibilityLabel: DesignSystemL10n.HeadsUp.accessibilityLater,
                accessibilityIdentifier: "designSystem.headsUp.\(suffix)",
                reduceTransparency: reduceTransparency,
                increaseContrast: increaseContrast,
                nowAction: {},
                laterAction: { _ in },
            )
        }
    }
}

#Preview("Heads-up capsules gallery") {
    DSGallery.HeadsUpCapsulesSection()
        .padding(DSSpacing.lg)
        .frame(width: 1120)
        .background(Color.dsBackground)
}
