import Foundation

#if canImport(ActivityKit)
    import ActivityKit
#endif

/// Live Activity attributes for the take-with-you break countdown.
///
/// Plain `Codable`/`Hashable` value: the `ActivityAttributes` conformance is
/// added only where ActivityKit exists, so macOS host tests compile this
/// package without the iOS-only framework.
public struct BreakCountdownAttributes: Codable, Hashable, Sendable {
    /// The pairing this countdown belongs to.
    public let pairingID: UUID
    /// Portable countdown length, owned by the Mac session.
    public let totalTicks: TimeInterval

    public init(pairingID: UUID, totalTicks: TimeInterval) {
        self.pairingID = pairingID
        self.totalTicks = totalTicks
    }

    /// Live countdown state: remaining ticks plus truthful certainty flags.
    public struct ContentState: Codable, Hashable, Sendable {
        /// Ticks left, clamped at zero — never negative.
        public var remainingTicks: TimeInterval
        /// The window has fully elapsed.
        public var isOverdue: Bool
        /// A terminal note was sent but the Mac has not confirmed it.
        /// Never presented as receipt: only the ack clears it.
        public var awaitingReceipt: Bool

        public init(remainingTicks: TimeInterval, isOverdue: Bool, awaitingReceipt: Bool) {
            self.remainingTicks = remainingTicks
            self.isOverdue = isOverdue
            self.awaitingReceipt = awaitingReceipt
        }
    }
}

#if canImport(ActivityKit)
    extension BreakCountdownAttributes: ActivityAttributes {}
#endif
