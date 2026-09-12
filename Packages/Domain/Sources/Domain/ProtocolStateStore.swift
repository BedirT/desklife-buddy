import Foundation

/// Restart-safe debt used only to decide whether one optional recovery suggestion is eligible.
public struct RecoveryState: Equatable, Sendable {
    public internal(set) var accumulatedEligibleActiveUseSeconds: TimeInterval
    public internal(set) var movementDeferralCount: Int
    public internal(set) var wasOfferedThisSession: Bool

    public init(
        accumulatedEligibleActiveUseSeconds: TimeInterval = 0,
        movementDeferralCount: Int = 0,
        wasOfferedThisSession: Bool = false,
    ) {
        self.accumulatedEligibleActiveUseSeconds = max(0, accumulatedEligibleActiveUseSeconds)
        self.movementDeferralCount = max(0, movementDeferralCount)
        self.wasOfferedThisSession = wasOfferedThisSession
    }
}

/// Restart-safe protocol counters and their current in-process presentation phases.
public struct ProtocolState: Equatable, Sendable {
    public let profileID: ProtocolProfileID
    public let visualClock: OpportunityClockState
    public let movementClock: OpportunityClockState
    public let visualSnoozeDeadline: Date?
    public let movementSnoozeDeadline: Date?
    public let recoveryState: RecoveryState
    public let recoveryLastObservedAt: Date?
    public let notAppropriateOpportunities: Set<OpportunityType>
    public let headsUpDeliveryState: HeadsUpDeliveryState
    /// Crash-replay fence/dedup authority from the action reducer. The engine
    /// snapshot below always carries an empty fence: the coordinator
    /// transaction boundary overlays `actionReducer.fenceState` here before
    /// persisting (Story 2.6 wiring), so a committed ActionID resubmitted
    /// post-restore replays instead of recommitting.
    public var coordinatorFence: CoordinatorFenceState

    /// Creates a state snapshot from two independent opportunity clocks.
    public init(
        profileID: ProtocolProfileID = .balanced,
        visualClock: OpportunityClockState = OpportunityClockState(),
        movementClock: OpportunityClockState = OpportunityClockState(),
        visualSnoozeDeadline: Date? = nil,
        movementSnoozeDeadline: Date? = nil,
        recoveryState: RecoveryState = RecoveryState(),
        recoveryLastObservedAt: Date? = nil,
        notAppropriateOpportunities: Set<OpportunityType> = [],
        headsUpDeliveryState: HeadsUpDeliveryState = HeadsUpDeliveryState(),
        coordinatorFence: CoordinatorFenceState = CoordinatorFenceState(),
    ) {
        self.profileID = profileID
        self.visualClock = visualClock
        self.movementClock = movementClock
        self.visualSnoozeDeadline = visualSnoozeDeadline
        self.movementSnoozeDeadline = movementSnoozeDeadline
        self.recoveryState = recoveryState
        self.recoveryLastObservedAt = recoveryLastObservedAt
        self.notAppropriateOpportunities = Set(
            notAppropriateOpportunities.filter(\.supportsNotAppropriateSuppression),
        )
        self.headsUpDeliveryState = headsUpDeliveryState
        self.coordinatorFence = coordinatorFence
    }
}

/// Persistence seam for restoring counters without inferring unobserved elapsed use.
public protocol ProtocolStateStore {
    /// Loads retained counters in a safe non-interrupting restart phase.
    func loadState() async throws -> ProtocolState?

    /// Saves the latest observed counters without a wall-clock catch-up anchor.
    func saveState(_ state: ProtocolState) async throws

    /// Deletes all retained protocol state.
    func deleteState() async throws
}

/// In-memory protocol state for deterministic tests and future Previews.
public final class InMemoryProtocolStateStore: ProtocolStateStore {
    private var state: ProtocolState?

    /// Creates a store with optional deterministic state.
    public init(state: ProtocolState? = nil) {
        self.state = state
    }

    public func loadState() async throws -> ProtocolState? {
        state
    }

    public func saveState(_ state: ProtocolState) async throws {
        self.state = state
    }

    public func deleteState() async throws {
        state = nil
    }
}

public extension ProtocolEngine {
    /// Creates an engine from counters restored without the estimator's monotonic baseline.
    init(configuration: ProtocolConfiguration, state: ProtocolState) {
        self.init(
            configuration: configuration,
            profileID: state.profileID,
            visualClock: state.visualClock,
            movementClock: state.movementClock,
            visualSnoozeDeadline: state.visualSnoozeDeadline,
            movementSnoozeDeadline: state.movementSnoozeDeadline,
            recoveryState: state.recoveryState,
            recoveryLastObservedAt: state.recoveryLastObservedAt,
            notAppropriateOpportunities: state.notAppropriateOpportunities,
            headsUpDeliveryState: state.headsUpDeliveryState,
        )
    }

    /// Captures the two clocks without persisting estimator baselines or wall-clock anchors.
    var state: ProtocolState {
        ProtocolState(
            profileID: profileID,
            visualClock: visualClock,
            movementClock: movementClock,
            visualSnoozeDeadline: visualSnoozeDeadline,
            movementSnoozeDeadline: movementSnoozeDeadline,
            recoveryState: recoveryState,
            recoveryLastObservedAt: recoveryLastObservedAt,
            notAppropriateOpportunities: notAppropriateOpportunities,
            headsUpDeliveryState: headsUpDeliveryState,
        )
    }
}
