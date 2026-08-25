import SwiftUI

/// Motion tokens: the app's entire animation vocabulary.
///
/// Animation work means choosing (or proposing) a token — never inventing curves
/// inline. That keeps motion reviewable as a one-line diff ("reveal: response
/// 0.42 -> 0.36") instead of squinting at video. Tuning how a token *feels* is a
/// human-on-device decision; see the $motion skill for the workflow.
public enum DSMotion {
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

    /// All tokens by name, for the gallery and motion verification tooling.
    public static let catalog: [(name: String, intent: String)] = [
        ("reveal", "user-initiated reveals — snappy, slight settle"),
        ("tap", "instant feedback — near-critically damped"),
        ("dismiss", "exits — calm ease-out, never bouncy"),
        ("transition", "navigation-scale changes — smooth, no overshoot"),
    ]
}
