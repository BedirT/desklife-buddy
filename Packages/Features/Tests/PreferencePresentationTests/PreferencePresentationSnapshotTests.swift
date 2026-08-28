#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import PreferencePresentation

    @Suite("Preference presentation components", .serialized)
    struct PreferencePresentationSnapshotTests {
        @Test func componentCatalog() {
            assertScreenSnapshot(
                of: componentCatalogView,
                layout: .fixed(width: 800, height: 700),
            )
        }

        private var componentCatalogView: some View {
            VStack(spacing: DSSpacing.lg) {
                HStack(alignment: .top, spacing: DSSpacing.md) {
                    ForEach(PreferenceRhythmStage.allCases) { stage in
                        PreferenceRhythmProfileButton(
                            stage: stage,
                            title: PreferencePresentationPreviewL10n.profileTitle(for: stage),
                            subtitle: PreferencePresentationPreviewL10n.profileDetail(for: stage),
                            accessibilityLabel: PreferencePresentationPreviewL10n.profileTitle(for: stage),
                            selected: stage == .balanced,
                            increaseContrast: false,
                            accessibilityIdentifier: "preferencePresentation.snapshot.rhythm.\(stage.id)",
                            action: {},
                        )
                    }
                }

                HStack(alignment: .top, spacing: DSSpacing.md) {
                    PreferenceMovementChoiceButton(
                        title: PreferencePresentationPreviewL10n.walkOrWheel,
                        detail: PreferencePresentationPreviewL10n.walkOrWheelDetail,
                        selected: true,
                        increaseContrast: false,
                        accessibilityIdentifier: "preferencePresentation.snapshot.movement",
                        action: {},
                    )
                    PreferencePresentationChoiceButton(
                        systemImage: "rectangle.dashed",
                        title: PreferencePresentationPreviewL10n.staticPresentation,
                        detail: PreferencePresentationPreviewL10n.staticPresentationDetail,
                        selected: true,
                        increaseContrast: false,
                        accessibilityIdentifier: "preferencePresentation.snapshot.presentation",
                        action: {},
                    )
                }

                PreferenceBrightnessWell(
                    value: .constant(0.35),
                    darkerTitle: PreferencePresentationPreviewL10n.darker,
                    brighterTitle: PreferencePresentationPreviewL10n.brighter,
                    accessibilityLabel: PreferencePresentationPreviewL10n.brightness,
                    accessibilityValue: PreferencePresentationPreviewL10n.brightness,
                    accessibilityIdentifier: "preferencePresentation.snapshot.brightness",
                    increaseContrast: false,
                    onEditingChanged: { _ in },
                )
            }
            .padding(DSSpacing.xl)
            .frame(width: 800, height: 700)
            .background(Color.dsBackground)
        }
    }
#endif
