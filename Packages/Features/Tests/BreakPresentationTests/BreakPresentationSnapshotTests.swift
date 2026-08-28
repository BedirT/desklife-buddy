#if os(macOS) && SNAPSHOT_TESTS
    import BreakPresentation
    import SnapshotSupport
    import SwiftUI
    import Testing

    @Suite("Break presentation fields", .serialized)
    struct BreakPresentationSnapshotTests {
        private let layout = SnapshotLayout.fixed(width: 1440, height: 900)

        @Test(
            "Every B2 field renders without UI or crop drift",
            arguments: BreakFieldVariant.allCases,
        )
        func field(_ variant: BreakFieldVariant) {
            assertScreenSnapshot(
                of: BreakFieldView(variant: variant)
                    .frame(width: 1440, height: 900),
                named: variant.rawValue,
                layout: layout,
                appearances: [.light],
            )
        }

        @Test func darkAppearance() {
            assertScreenSnapshot(
                of: BreakFieldView(
                    variant: .visualReset,
                    appearanceOverride: .init(colorScheme: .dark),
                )
                .frame(width: 1440, height: 900),
                layout: layout,
                appearances: [.dark],
            )
        }

        @Test func increasedContrast() {
            assertScreenSnapshot(
                of: BreakFieldView(
                    variant: .movementWalkOrWheel,
                    appearanceOverride: .init(
                        colorScheme: .light,
                        increaseContrast: true,
                    ),
                )
                .frame(width: 1440, height: 900),
                layout: layout,
                appearances: [.light],
            )
        }

        @Test func reducedTransparency() {
            assertScreenSnapshot(
                of: BreakFieldView(
                    variant: .movementSmallSpace,
                    appearanceOverride: .init(
                        colorScheme: .light,
                        reduceTransparency: true,
                    ),
                )
                .frame(width: 1440, height: 900),
                layout: layout,
                appearances: [.light],
            )
        }

        @Test func staticBrightnessEndpoints() {
            assertScreenSnapshot(
                of: HStack(spacing: 0) {
                    BreakStaticField(brightness: 0)
                    BreakStaticField(brightness: 1)
                }
                .frame(width: 1440, height: 900),
                layout: layout,
            )
        }
    }
#endif
