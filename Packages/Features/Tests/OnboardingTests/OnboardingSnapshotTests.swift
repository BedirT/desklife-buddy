#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import Onboarding

    @Suite("Onboarding walkthrough screens", .serialized)
    struct OnboardingSnapshotTests {
        @Test(arguments: [
            OnboardingPreviewState.promise,
            .honesty,
            .rhythmBalanced,
            .movementWalkOrEquivalent,
            .comfortStandard,
            .ready,
            .skipped,
            .completionFailure,
        ])
        func primaryStates(_ state: OnboardingPreviewState) {
            assertScreenSnapshot(
                of: screen(state),
                named: state.snapshotName,
            )
        }

        @Test(arguments: [
            OnboardingPreviewState.completionSubmitting,
            .skipSubmitting,
            .completionActivating,
            .skipActivating,
            .completed,
            .skipFailure,
            .completionActivationFailure,
            .skipActivationFailure,
        ])
        func dynamicStates(_ state: OnboardingPreviewState) {
            assertScreenSnapshot(
                of: screen(state),
                named: state.snapshotName,
            )
        }

        @Test(arguments: [
            OnboardingPreviewState.rhythmGentle,
            .rhythmFrequentMovement,
            .movementSeatedActive,
            .movementMixed,
            .movementPositionChangeOnly,
            .comfortStatic,
            .comfortStaticMaximumBrightness,
            .comfortReduceMotion,
            .comfortReduceTransparency,
        ])
        func selectionAndSystemStates(_ state: OnboardingPreviewState) {
            assertScreenSnapshot(
                of: screen(state),
                named: state.snapshotName,
                appearances: [.light],
            )
        }

        @Test func largestText() {
            assertScreenSnapshot(
                of: screen(.movementMixed, textScale: .largest),
                named: "movement-mixed-largest-text",
                appearances: [.light],
            )
        }

        @Test func largestTextComfort() {
            assertScreenSnapshot(
                of: screen(.comfortStatic, textScale: .largest),
                named: "comfort-static-largest-text",
                appearances: [.light],
            )
        }

        @Test func compactLargestTextComfort() {
            assertScreenSnapshot(
                of: OnboardingView(model: .preview(.comfortStatic))
                    .environment(\.dsTextScale, .largest)
                    .frame(width: 800, height: 572),
                named: "comfort-static-largest-text-compact",
                appearances: [.light],
            )
        }

        @Test func largestTextReady() {
            assertScreenSnapshot(
                of: screen(.ready, textScale: .largest),
                named: "ready-largest-text",
                appearances: [.light],
            )
        }

        @Test func increaseContrast() {
            assertScreenSnapshot(
                of: screen(.rhythmBalanced, increaseContrast: true),
                named: "rhythm-balanced-increase-contrast",
                appearances: [.light],
            )
        }

        @Test func keyboardFocus() {
            assertScreenSnapshot(
                of: screen(.rhythmBalanced, focus: .rhythm(.balanced)),
                named: "rhythm-balanced-keyboard-focus",
                appearances: [.light],
            )
        }

        private func screen(
            _ state: OnboardingPreviewState,
            textScale: DSTextScale = .standard,
            increaseContrast: Bool = false,
            focus: OnboardingFocusTarget? = nil,
        ) -> some View {
            OnboardingView(
                model: .preview(state),
                increaseContrastOverride: increaseContrast,
                focusPreviewOverride: focus,
            )
            .environment(\.dsTextScale, textScale)
            .frame(width: 1000, height: 700)
            .environment(\._colorSchemeContrast, increaseContrast ? .increased : .standard)
        }
    }

    private extension OnboardingPreviewState {
        var snapshotName: String {
            switch self {
            case .promise: "promise"
            case .honesty: "honesty"
            case .rhythmGentle: "rhythm-gentle"
            case .rhythmBalanced: "rhythm-balanced"
            case .rhythmFrequentMovement: "rhythm-frequent-movement"
            case .movementWalkOrEquivalent: "movement-walk-or-equivalent"
            case .movementSeatedActive: "movement-seated-active"
            case .movementMixed: "movement-mixed"
            case .movementPositionChangeOnly: "movement-position-change-only"
            case .comfortStandard: "comfort-standard"
            case .comfortStatic: "comfort-static"
            case .comfortStaticMaximumBrightness: "comfort-static-maximum-brightness"
            case .comfortReduceMotion: "comfort-reduce-motion"
            case .comfortReduceTransparency: "comfort-reduce-transparency"
            case .ready: "ready"
            case .completionSubmitting: "completion-submitting"
            case .skipSubmitting: "skip-submitting"
            case .completionActivating: "completion-activating"
            case .skipActivating: "skip-activating"
            case .completed: "completed"
            case .skipped: "skipped"
            case .completionFailure: "completion-failure"
            case .skipFailure: "skip-failure"
            case .completionActivationFailure: "completion-activation-failure"
            case .skipActivationFailure: "skip-activation-failure"
            }
        }
    }
#endif
