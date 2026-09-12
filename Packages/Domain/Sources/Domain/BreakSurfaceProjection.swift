import Foundation

/// Projected movement durations for one break surface.
///
/// The surface renders from these two values only. It never receives the
/// engine's schedule type, so no presenter can reach past the facade into
/// clocks or configuration behavior.
public struct MovementDurations: Equatable, Sendable {
    /// The first duration option: the default a fresh surface opens with.
    public let recommendedSeconds: TimeInterval
    /// The second duration option: the quick alternative.
    public let quickSeconds: TimeInterval

    public init(recommendedSeconds: TimeInterval, quickSeconds: TimeInterval) {
        self.recommendedSeconds = recommendedSeconds
        self.quickSeconds = quickSeconds
    }

    /// Projects the recommended and quick durations from a coordinator-owned
    /// schedule. Mirrors the surface contract: at least two positive finite
    /// options, in configured order. Pure value mapping — no engine access.
    public static func projected(from schedule: OpportunitySchedule) -> MovementDurations {
        precondition(schedule.durationOptionsSeconds.count >= 2)
        let recommended = schedule.durationOptionsSeconds[0]
        let quick = schedule.durationOptionsSeconds[1]
        precondition(recommended.isFinite && recommended > 0)
        precondition(quick.isFinite && quick > 0)
        return MovementDurations(recommendedSeconds: recommended, quickSeconds: quick)
    }
}

/// Pure read projections from coordinator-owned configuration to break
/// surfaces.
///
/// Every function maps validated configuration values to surface inputs
/// without touching the engine, clocks, or reducer. Surfaces render from
/// these receipts and states; presenters never read past the facade.
public enum BreakSurfaceProjection {
    /// Projects the single duration a visual break opens with.
    public static func visualDurationSeconds(from schedule: OpportunitySchedule) -> TimeInterval {
        precondition(!schedule.durationOptionsSeconds.isEmpty)
        return schedule.durationOptionsSeconds[0]
    }

    /// Projects the configured snooze options unchanged.
    public static func snoozeOptionsSeconds(
        from delivery: OpportunityDeliveryConfiguration,
    ) -> [TimeInterval] {
        delivery.snoozeOptionsSeconds
    }
}
