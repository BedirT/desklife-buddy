import Foundation
import SwiftUI

/// Motion tokens: the app's entire animation vocabulary.
///
/// Animation work means choosing (or proposing) a token — never inventing curves
/// inline. That keeps motion reviewable as a one-line diff ("reveal: response
/// 0.42 -> 0.36") instead of squinting at video. Tuning how a token *feels* is a
/// human-on-device decision; see the $motion skill for the workflow.
public enum DSMotion {
    public static let breakFieldBlurRadius: CGFloat = 30
    public static let breakFieldDesktopFrostDuration: TimeInterval = 0.85
    public static let breakFieldFrostHoldDuration: TimeInterval = 0.12
    public static let breakFieldBlurredFieldCrossfadeDuration: TimeInterval = 0.62
    public static let breakFieldFieldSharpenDuration: TimeInterval = 1.10
    public static let breakFieldFieldSoftenDuration: TimeInterval = 0.42
    public static let breakFieldDesktopDefrostDuration: TimeInterval = 0.52
    public static let breakFieldExitDuration: TimeInterval =
        breakFieldFieldSoftenDuration + breakFieldDesktopDefrostDuration
    public static let breakFieldEnterDuration: TimeInterval =
        breakFieldDesktopFrostDuration
            + breakFieldFrostHoldDuration
            + breakFieldBlurredFieldCrossfadeDuration
            + breakFieldFieldSharpenDuration
    public static let breakFieldReducedEnterDuration: TimeInterval = 0.80
    public static let breakFieldInstructionDelay: TimeInterval = 0.14
    public static let breakFieldControlDelay: TimeInterval = 0.28

    /// Snappy spring with a slight settle. User-initiated reveals:
    /// expanding rows, cards, popovers.
    public static let reveal = Animation.spring(response: 0.42, dampingFraction: 0.85)

    /// Quick acknowledgement. Taps, toggles, selection state. Near-critically
    /// damped on purpose — feedback, not flourish.
    public static let tap = Animation.spring(response: 0.28, dampingFraction: 0.92)

    /// Calm exit for dismissals and removals. Never bouncy: things leaving
    /// should not draw attention.
    public static let dismiss = Animation.easeOut(duration: 0.22)

    /// Large-scale/navigation-level transitions.
    public static let transition = Animation.spring(response: 0.55, dampingFraction: 0.95)

    /// Full-screen desktop frost, blurred-field crossfade, then field sharpening.
    public static let breakFieldEnter = Animation.easeInOut(duration: breakFieldEnterDuration)

    /// Background-only sharpening after the frosted desktop reveals the break field.
    public static let breakFieldFieldSharpen = Animation.easeInOut(
        duration: breakFieldFieldSharpenDuration,
    )

    /// Travel-free dissolve for small supporting reveals when Reduce Motion is active.
    public static let breakFieldReducedEnter = Animation.easeInOut(
        duration: breakFieldReducedEnterDuration,
    )

    /// Soft independent arrival for break instructions and controls inside the field dissolve.
    public static let breakFieldForegroundEnter = Animation.easeOut(duration: 0.62)

    /// Foreground recedes quickly once the user's terminal action is already accepted.
    public static let breakFieldForegroundExit = Animation.easeIn(duration: 0.28)

    /// The selected field softens as the desktop frost returns above it.
    public static let breakFieldFieldSoften = Animation.easeIn(
        duration: breakFieldFieldSoftenDuration,
    )

    /// Restrained one-shot arrival for the fixed heads-up capsule.
    public static let headsUpEnter = Animation.easeOut(duration: 0.32)

    /// Short highlight response to a bounded pointer sample. The capsule never moves.
    public static let headsUpGlint = Animation.easeOut(duration: 0.12)

    /// Single contented eye-crinkle for the wordless completion capsule.
    public static let headsUpCompletionCrinkle = Animation.easeInOut(duration: 0.40)

    /// The horizon is the only continuous motion during a break.
    public static func breakHorizon(duration: TimeInterval) -> Animation {
        .linear(duration: duration)
    }

    /// All tokens by name, for the gallery and motion verification tooling.
    public static let catalog: [(name: String, intent: String)] = [
        ("reveal", "user-initiated reveals — snappy, slight settle"),
        ("tap", "instant feedback — near-critically damped"),
        ("dismiss", "exits — calm ease-out, never bouncy"),
        ("transition", "navigation-scale changes — smooth, no overshoot"),
        ("breakFieldEnter", "break field arrival: desktop frost, field dissolve, sharpen"),
        ("breakFieldFieldSharpen", "break field background: blurred image to sharp image"),
        ("breakFieldFieldSoften", "break field exit: sharp image softens beneath frost"),
        ("breakFieldForegroundExit", "break field exit: foreground recedes after acceptance"),
        ("breakFieldReducedEnter", "reduced-motion supporting reveal: travel-free dissolve"),
        ("headsUpEnter", "heads-up arrival: restrained one-shot reveal"),
        ("headsUpGlint", "heads-up highlight: bounded pointer response"),
        ("headsUpCompletionCrinkle", "completion capsule: one contented eye-crinkle"),
        ("breakHorizon", "break progress — one linear fill, never looping"),
    ]
}
