import Foundation

/// Pure countdown math for companion snapshots (Epic 4 wave 1).
///
/// Countdowns are derived, never stored: given the Mac-owned total and the
/// elapsed ticks, these helpers clamp the projection so a late or
/// out-of-order observation can never show negative time or run past full.
public enum CompanionCountdownMath {
    /// Remaining ticks, clamped at zero so overdue reads as done, not negative.
    public static func remaining(totalTicks: TimeInterval, elapsedTicks: TimeInterval) -> TimeInterval {
        max(0, totalTicks - elapsedTicks)
    }

    /// Elapsed fraction in 0...1; a non-positive total yields zero progress.
    public static func progress(totalTicks: TimeInterval, elapsedTicks: TimeInterval) -> Double {
        guard totalTicks > 0 else { return 0 }
        return min(1, max(0, elapsedTicks / totalTicks))
    }

    /// Whether the window has fully elapsed.
    public static func isOverdue(totalTicks: TimeInterval, elapsedTicks: TimeInterval) -> Bool {
        elapsedTicks >= totalTicks
    }
}
