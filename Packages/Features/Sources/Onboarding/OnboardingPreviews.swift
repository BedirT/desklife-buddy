import DesignSystem
import SwiftUI

private struct OnboardingPreviewScene: View {
    let state: OnboardingPreviewState
    var textScale: DSTextScale = .standard
    var increaseContrast = false
    var focus: OnboardingFocusTarget?

    var body: some View {
        OnboardingView(
            model: .preview(state),
            increaseContrastOverride: increaseContrast,
            focusPreviewOverride: focus,
        )
        .environment(\.dsTextScale, textScale)
        .frame(width: 1000, height: 700)
    }
}

#Preview("ON-01 — Promise") { OnboardingPreviewScene(state: .promise) }
#Preview("ON-02 — Honesty") { OnboardingPreviewScene(state: .honesty) }
#Preview("ON-03 — Gentle") { OnboardingPreviewScene(state: .rhythmGentle) }
#Preview("ON-03 — Balanced") { OnboardingPreviewScene(state: .rhythmBalanced) }
#Preview("ON-03 — Frequent movement") { OnboardingPreviewScene(state: .rhythmFrequentMovement) }
#Preview("ON-04 — Walk or wheel") { OnboardingPreviewScene(state: .movementWalkOrEquivalent) }
#Preview("ON-04 — Seated movement") { OnboardingPreviewScene(state: .movementSeatedActive) }
#Preview("ON-04 — Mixed movement") { OnboardingPreviewScene(state: .movementMixed) }
#Preview("ON-04 — Position change") { OnboardingPreviewScene(state: .movementPositionChangeOnly) }
#Preview("ON-05 — Standard comfort") { OnboardingPreviewScene(state: .comfortStandard) }
#Preview("ON-05 — Static comfort") { OnboardingPreviewScene(state: .comfortStatic) }
#Preview("ON-05 — Reduce Motion") { OnboardingPreviewScene(state: .comfortReduceMotion) }
#Preview("ON-05 — Reduce Transparency") { OnboardingPreviewScene(state: .comfortReduceTransparency) }
#Preview("ON-06 — Ready") { OnboardingPreviewScene(state: .ready) }
#Preview("Completion submitting") { OnboardingPreviewScene(state: .completionSubmitting) }
#Preview("Skip submitting") { OnboardingPreviewScene(state: .skipSubmitting) }
#Preview("Completion activating") { OnboardingPreviewScene(state: .completionActivating) }
#Preview("Skip activating") { OnboardingPreviewScene(state: .skipActivating) }
#Preview("ON-07 — Completed") { OnboardingPreviewScene(state: .completed) }
#Preview("ON-07 — Skipped") { OnboardingPreviewScene(state: .skipped) }
#Preview("Completion retry") { OnboardingPreviewScene(state: .completionFailure) }
#Preview("Skip retry") { OnboardingPreviewScene(state: .skipFailure) }
#Preview("Completion activation retry") {
    OnboardingPreviewScene(state: .completionActivationFailure)
}

#Preview("Skip activation retry") { OnboardingPreviewScene(state: .skipActivationFailure) }
#Preview("Largest text") {
    OnboardingPreviewScene(state: .movementMixed, textScale: .largest)
}

#Preview("Increase Contrast") {
    OnboardingPreviewScene(state: .rhythmBalanced, increaseContrast: true)
}

#Preview("Keyboard focus") {
    OnboardingPreviewScene(
        state: .rhythmBalanced,
        focus: .rhythm(.balanced),
    )
}
