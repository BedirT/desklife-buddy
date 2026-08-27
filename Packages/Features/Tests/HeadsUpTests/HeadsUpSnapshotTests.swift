#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import HeadsUp

    @Suite("Heads-up capsule", .serialized)
    struct HeadsUpSnapshotTests {
        private let capsuleLayout = SnapshotLayout.fixed(width: 760, height: 150)
        private let permissionLayout = SnapshotLayout.fixed(width: 560, height: 320)
        private let permissionLargeLayout = SnapshotLayout.fixed(width: 680, height: 520)
        private let dockingLayout = SnapshotLayout.fixed(width: 1000, height: 220)

        private func capsule(_ model: HeadsUpModel) -> some View {
            HeadsUpView(model: model)
                .padding(DSSpacing.xxl)
                .frame(width: 760, height: 150, alignment: .top)
                .background(Color.dsBackground)
        }

        private func permissionSettings(
            _ state: HeadsUpPermissionSettingsState,
            focusedControl: HeadsUpPermissionControl = .openSettings,
            increaseContrast: Bool = false,
        ) -> some View {
            Form {
                HeadsUpPermissionView(
                    surface: .settings(state),
                    focusedControlOverride: focusedControl,
                    increaseContrastOverride: increaseContrast,
                ) { _ in }
            }
            .formStyle(.grouped)
        }

        @Test(
            "Every opportunity scope has an approach state",
            arguments: [HeadsUpScope.visual, .movement, .merged],
        )
        func approachScope(_ scope: HeadsUpScope) {
            assertScreenSnapshot(
                of: capsule(.preview(scope: scope)),
                named: scope.snapshotName,
                layout: capsuleLayout,
                appearances: [.light],
            )
        }

        @Test(
            "Every coarse approach mark is visible without per-second ticking",
            arguments: [45, 30, 15, 5],
        )
        func coarseMark(_ seconds: Int) throws {
            let mark = try #require(HeadsUpApproachMark(seconds: seconds))
            assertScreenSnapshot(
                of: capsule(.preview(
                    scope: .visual,
                    phase: .approaching(mark),
                    approachProgress: mark.snapshotProgress,
                )),
                named: "seconds-\(mark.seconds)",
                layout: capsuleLayout,
                appearances: [.dark],
            )
        }

        @Test func hoveredActions() {
            assertScreenSnapshot(
                of: capsule(.preview(scope: .merged, isHovered: true)),
                layout: capsuleLayout,
            )
        }

        @Test func landedWaiting() {
            assertScreenSnapshot(
                of: capsule(.preview(scope: .visual, phase: .landedWaiting)),
                layout: capsuleLayout,
            )
        }

        @Test func calendarHold() {
            assertScreenSnapshot(
                of: capsule(.preview(
                    scope: .visual,
                    phase: .hold(.calendarBusy(until: meetingEnd)),
                )),
                layout: capsuleLayout,
            )
        }

        @Test func textOnly() {
            assertScreenSnapshot(
                of: capsule(.preview(
                    scope: .visual,
                    accessibility: .init(textOnly: true),
                )),
                layout: capsuleLayout,
            )
        }

        @Test(
            "Reduce Motion uses three static sun positions",
            arguments: [45, 15, 5],
        )
        func reduceMotion(_ seconds: Int) throws {
            let mark = try #require(HeadsUpApproachMark(seconds: seconds))
            assertScreenSnapshot(
                of: capsule(.preview(
                    scope: .visual,
                    phase: .approaching(mark),
                    approachProgress: 0.72,
                    accessibility: .init(reduceMotion: true),
                )),
                named: "seconds-\(seconds)",
                layout: capsuleLayout,
            )
        }

        @Test func reduceTransparency() {
            assertScreenSnapshot(
                of: capsule(.preview(
                    scope: .movement,
                    accessibility: .init(reduceTransparency: true),
                )),
                layout: capsuleLayout,
            )
        }

        @Test func increaseContrast() {
            assertScreenSnapshot(
                of: capsule(.preview(
                    scope: .merged,
                    isHovered: true,
                    accessibility: .init(increaseContrast: true),
                )),
                layout: capsuleLayout,
            )
        }

        @Test func plusThirtyFivePercentText() {
            assertScreenSnapshot(
                of: capsule(.preview(scope: .merged, isHovered: true))
                    .environment(\.dynamicTypeSize, .xxxLarge)
                    .environment(\.dsTextScale, .plusThirtyFivePercent),
                named: "plus-35-percent",
                layout: capsuleLayout,
                appearances: [.light],
            )
        }

        @Test func largestText() {
            assertScreenSnapshot(
                of: capsule(.preview(
                    scope: .merged,
                    isHovered: true,
                    accessibility: .init(
                        reduceMotion: true,
                        reduceTransparency: true,
                        increaseContrast: true,
                        largeText: true,
                    ),
                ))
                .environment(\.dynamicTypeSize, .accessibility3)
                .environment(\.dsTextScale, .largest),
                layout: capsuleLayout,
                appearances: [.dark],
            )
        }

        @Test func menuBarClockPlacementContext() {
            assertScreenSnapshot(
                of: HeadsUpDockingPreview(
                    placement: .menuBarClock,
                    model: .preview(scope: .visual, phase: .approaching(.seconds15)),
                ),
                layout: dockingLayout,
            )
        }

        @Test func permissionExplainer() {
            assertScreenSnapshot(
                of: HeadsUpPermissionView(
                    surface: .inContextExplainer,
                    focusedControlOverride: .useInApp,
                ) { _ in },
                layout: permissionLayout,
            )
        }

        @Test func permissionExplainerPlusThirtyFivePercentText() {
            assertScreenSnapshot(
                of: HeadsUpPermissionView(
                    surface: .inContextExplainer,
                    focusedControlOverride: .useInApp,
                ) { _ in }
                    .environment(\.dsTextScale, .plusThirtyFivePercent),
                named: "plus-35-percent",
                layout: permissionLargeLayout,
                appearances: [.light],
            )
        }

        @Test func permissionExplainerLargestText() {
            assertScreenSnapshot(
                of: HeadsUpPermissionView(
                    surface: .inContextExplainer,
                    focusedControlOverride: .useInApp,
                ) { _ in }
                    .environment(\.dsTextScale, .largest),
                named: "largest",
                layout: permissionLargeLayout,
                appearances: [.dark],
            )
        }

        @Test func permissionExplainerIncreaseContrast() {
            assertScreenSnapshot(
                of: HeadsUpPermissionView(
                    surface: .inContextExplainer,
                    focusedControlOverride: .useInApp,
                    increaseContrastOverride: true,
                ) { _ in },
                named: "increase-contrast",
                layout: permissionLayout,
                appearances: [.dark],
            )
        }

        @Test(
            "Denied and revoked notification settings remain complete",
            arguments: [
                HeadsUpPermissionSettingsState.denied,
                .revoked,
            ],
        )
        func permissionSettings(_ state: HeadsUpPermissionSettingsState) {
            assertScreenSnapshot(
                of: permissionSettings(state),
                named: state.snapshotName,
                layout: permissionLayout,
                appearances: [.light],
            )
        }

        @Test func permissionSettingsLargestText() {
            assertScreenSnapshot(
                of: permissionSettings(.denied)
                    .environment(\.dsTextScale, .largest),
                named: "denied-largest",
                layout: permissionLargeLayout,
                appearances: [.dark],
            )
        }

        @Test func permissionSettingsIncreaseContrast() {
            assertScreenSnapshot(
                of: permissionSettings(.denied, increaseContrast: true),
                named: "denied-increase-contrast",
                layout: permissionLayout,
                appearances: [.dark],
            )
        }
    }

    private extension HeadsUpScope {
        var snapshotName: String {
            switch self {
            case .visual: "visual"
            case .movement: "movement"
            case .merged: "merged"
            }
        }
    }

    private extension HeadsUpApproachMark {
        var snapshotProgress: Double {
            switch seconds {
            case 45: 0
            case 30: 0.33
            case 15: 0.67
            case 5: 0.89
            default: 0
            }
        }
    }

    private extension HeadsUpPermissionSettingsState {
        var snapshotName: String {
            switch self {
            case .denied: "denied"
            case .revoked: "revoked"
            }
        }
    }

    private let meetingEnd = Date(timeIntervalSince1970: 1_800_000_000)
#endif
