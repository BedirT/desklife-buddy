/// Restart-safe protocol counters and their current in-process presentation phases.
public struct ProtocolState: Equatable, Sendable {
    public let profileID: ProtocolProfileID
    public let visualClock: OpportunityClockState
    public let movementClock: OpportunityClockState

    /// Creates a state snapshot from two independent opportunity clocks.
    public init(
        profileID: ProtocolProfileID = .balanced,
        visualClock: OpportunityClockState = OpportunityClockState(),
        movementClock: OpportunityClockState = OpportunityClockState(),
    ) {
        self.profileID = profileID
        self.visualClock = visualClock
        self.movementClock = movementClock
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
        )
    }

    /// Captures the two clocks without persisting estimator baselines or wall-clock anchors.
    var state: ProtocolState {
        ProtocolState(
            profileID: profileID,
            visualClock: visualClock,
            movementClock: movementClock,
        )
    }
}
