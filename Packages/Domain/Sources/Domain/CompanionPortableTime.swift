import Foundation

/// Portable session timing: the Mac ships duration + wall anchor + revision;
/// each recipient derives its own monotonic countdown locally (Epic 4 closeout).
///
/// The wall anchor is audit context only and never drives ordering, so skew,
/// DST, reboot, force-quit, and clock changes cannot move the winner. Ordering
/// uses `CompanionTerminalReconciliation` (rank/revision/IDs), never walls.
public struct CompanionPortableDeadline: Equatable, Hashable, Sendable {
    /// Portable countdown length in ticks, owned by the Mac session.
    public let totalTicks: TimeInterval
    /// Wall anchor for audit display only; never reconstructed into countdown time.
    public let originWall: Date
    /// Session revision this deadline belongs to; older revisions are stale.
    public let originRevision: UInt64

    public init(totalTicks: TimeInterval, originWall: Date, originRevision: UInt64) {
        self.totalTicks = totalTicks
        self.originWall = originWall
        self.originRevision = originRevision
    }

    /// Remaining ticks from the recipient's own monotonic elapsed count.
    public func remaining(localElapsedTicks: TimeInterval) -> TimeInterval {
        CompanionCountdownMath.remaining(totalTicks: totalTicks, elapsedTicks: localElapsedTicks)
    }

    /// Elapsed fraction from the recipient's own monotonic count.
    public func progress(localElapsedTicks: TimeInterval) -> Double {
        CompanionCountdownMath.progress(totalTicks: totalTicks, elapsedTicks: localElapsedTicks)
    }

    /// Whether the recipient's own monotonic count has fully elapsed.
    public func isOverdue(localElapsedTicks: TimeInterval) -> Bool {
        CompanionCountdownMath.isOverdue(totalTicks: totalTicks, elapsedTicks: localElapsedTicks)
    }

    /// Whether this deadline belongs to an outdated revision.
    public func isStale(knownRevision: UInt64) -> Bool {
        originRevision < knownRevision
    }
}

/// What one device may truthfully say about remote certainty.
///
/// Pending and stale states never claim receipt. Only `acknowledged` — backed
/// by a supported transport acknowledgment — claims remote receipt. Watch
/// forwarding is never `acknowledged` without that ack (owner gate Q4).
public enum CompanionCertainty: Equatable, Hashable, Sendable {
    /// Truthful local state while disconnected; no remote claim.
    case localPending
    /// Sent but unacknowledged; explicit pending, never receipt.
    case remotePending
    /// Known outdated; explicit stale, never receipt.
    case stale
    /// Supported acknowledgment observed; the only receipt-claiming state.
    case acknowledged

    /// Whether this state claims the remote side received anything.
    public var claimsReceipt: Bool {
        self == .acknowledged
    }
}
