import Foundation

/// Explicit bounded retention choices for raw local opportunity events.
public enum HistoryRetentionPolicy: Int, Codable, CaseIterable, Sendable {
    case keepNothing = 0
    case thirtyDays = 30
    case ninetyDays = 90

    /// Retention window expressed in seconds for App-owned pruning adapters.
    public var retentionDurationSeconds: TimeInterval {
        TimeInterval(rawValue * 24 * 60 * 60)
    }

    /// Filters events at an injected boundary while preserving their storage order.
    public func retainedEvents(_ events: [OpportunityEvent], asOf now: Date) -> [OpportunityEvent] {
        guard self != .keepNothing else { return [] }
        let cutoff = now.addingTimeInterval(-retentionDurationSeconds)
        return events.filter { $0.recordedAt >= cutoff }
    }
}
