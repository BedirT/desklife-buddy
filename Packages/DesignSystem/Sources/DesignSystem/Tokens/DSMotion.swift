import Foundation
import SwiftUI

/// Motion tokens: the app's entire animation vocabulary.
///
/// Animation work means choosing (or proposing) a token — never inventing curves
/// inline. That keeps motion reviewable as a one-line diff ("reveal: response
/// 0.42 -> 0.36") instead of squinting at video. Tuning how a token *feels* is a
/// human-on-device decision; see the $motion skill for the workflow.
public enum DSMotion {
    public static let breakFieldDesktopFrostDuration: TimeInterval = 1.15
    public static let breakFieldFrostHoldDuration: TimeInterval = 0.20
    public static let breakFieldBlurredFieldCrossfadeDuration: TimeInterval = 0.75
    public static let breakFieldFieldSharpenDuration: TimeInterval = 1.10
    public static let breakFieldEnterDuration: TimeInterval =
        breakFieldDesktopFrostDuration
            + breakFieldFrostHoldDuration
            + breakFieldBlurredFieldCrossfadeDuration
            + breakFieldFieldSharpenDuration
    public static let breakFieldReducedEnterDuration: TimeInterval = 0.80
    public static let breakFieldExitDuration: TimeInterval = 0.45

    public static let breakFieldInstructionDelay: TimeInterval = 0.18
    public static let breakFieldControlDelay: TimeInterval = 0.34

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

    /// Reduce Motion keeps the same travel-free dissolve and is never faster than standard.
    public static let breakFieldReducedEnter = Animation.easeInOut(
        duration: breakFieldReducedEnterDuration,
    )

    /// One-way break dismissal. Escape never waits for this animation to finish.
    public static let breakFieldExit = Animation.easeIn(duration: breakFieldExitDuration)

    /// Soft independent arrival for break instructions and controls inside the field dissolve.
    public static let breakFieldForegroundEnter = Animation.easeOut(duration: 0.62)

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
        ("breakFieldReducedEnter", "reduced-motion field arrival: travel-free cross-dissolve"),
        ("breakFieldExit", "break field exit: calm dissolve back to the desktop"),
        ("headsUpEnter", "heads-up arrival: restrained one-shot reveal"),
        ("headsUpGlint", "heads-up highlight: bounded pointer response"),
        ("headsUpCompletionCrinkle", "completion capsule: one contented eye-crinkle"),
        ("breakHorizon", "break progress — one linear fill, never looping"),
    ]
}
