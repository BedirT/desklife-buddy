import Foundation

/// Numeric countdown formatting: mm:ss, clamped at zero, no words to localize.
/// Shared by the app countdown pane and the Live Activity widget.
///
/// The input is wire-influenced, so it clamps to a day before `Int`
/// conversion: huge doubles would trap, negatives would force instant-overdue.
public enum PhoneTimeFormat {
    /// Upper bound matching `PhoneBreakSession.maximumTotalTicks`.
    public static let maximumTicks: TimeInterval = 86400

    public static func mmss(_ ticks: TimeInterval) -> String {
        let clamped = min(max(ticks, 0), maximumTicks)
        let total = Int(clamped.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
