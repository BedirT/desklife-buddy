import Foundation

/// Numeric countdown formatting: mm:ss, clamped at zero, no words to localize.
/// Shared by the app countdown pane and the Live Activity widget.
public enum PhoneTimeFormat {
    public static func mmss(_ ticks: TimeInterval) -> String {
        let total = max(0, Int(ticks.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
