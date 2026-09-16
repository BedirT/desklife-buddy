import Foundation

/// Closed terminal claims a companion device may settle offline (Epic 4 closeout).
///
/// Rank mirrors `OpportunityActionKind.terminalClaimRank` so the companion order
/// can never contradict the Mac reducer: skipped < snoozed < notAppropriate <
/// positionChanged < alreadyMoved < completed < timerFinished. Arrival order
/// never ranks; wall time never ranks (skew/DST/clock-change safe by construction).
public enum CompanionTerminalClaim: String, Equatable, Hashable, Sendable, CaseIterable {
    case skipped
    case snoozed
    case notAppropriate
    case positionChanged
    case alreadyMoved
    case completed
    case timerFinished

    /// Smallest wins, matching the Mac terminal-claim order.
    var claimRank: Int {
        switch self {
        case .skipped: 0
        case .snoozed: 5
        case .notAppropriate: 10
        case .positionChanged: 20
        case .alreadyMoved: 30
        case .completed: 40
        case .timerFinished: 50
        }
    }

    /// The single product fact this claim settles, if the reconciler picks it.
    public var productFactKind: OpportunityEventKind {
        switch self {
        case .skipped: .skipped
        case .snoozed: .snoozed
        case .notAppropriate: .notAppropriate
        case .positionChanged: .positionChanged
        case .alreadyMoved: .userDeclaredAlreadyMoved
        case .completed: .userDeclaredCompleted
        case .timerFinished: .timerFinished
        }
    }
}

/// One offline terminal intent from either device.
public struct CompanionTerminalAction: Equatable, Hashable, Sendable {
    public let id: UUID
    public let deviceID: String
    public let counter: UInt64
    public let claim: CompanionTerminalClaim
    public let originRevision: UInt64

    public init(
        id: UUID = UUID(),
        deviceID: String,
        counter: UInt64,
        claim: CompanionTerminalClaim,
        originRevision: UInt64,
    ) {
        self.id = id
        self.deviceID = deviceID
        self.counter = counter
        self.claim = claim
        self.originRevision = originRevision
    }

    /// The product fact this intent would settle if it wins.
    public var productFactKind: OpportunityEventKind { claim.productFactKind }
}

/// The reconciled outcome: one winner, deterministic losers, one fact max.
public struct CompanionTerminalSettlement: Equatable, Sendable {
    public let winner: CompanionTerminalAction
    public let losers: [CompanionTerminalAction]

    /// Exactly the winner's fact and nothing else. Losers emit no facts;
    /// callers retain them via `losers` for audit only.
    public var productFacts: [OpportunityEventKind] { [winner.productFactKind] }
}

/// Order-independent convergent reconciliation for offline terminal actions.
///
/// Total order per intent: claim rank, then fresher origin revision, then
/// device ID, then action ID. Sorting plus ID dedup is commutative,
/// associative, and idempotent, so every delivery permutation of one batch
/// settles the same winner. Duplicates never double-apply. Wall time is not
/// an input, so skew, DST, reboot, force-quit, and clock changes cannot move
/// the winner. Phones never mutate Mac clocks here: this returns which intent
/// wins; the Mac commits the single product fact through the one
/// `OpportunityActionReducer` path.
public enum CompanionTerminalReconciliation {
    /// Settles one batch. Precondition: non-empty (an empty batch has no winner).
    public static func reconcile(_ actions: [CompanionTerminalAction]) -> CompanionTerminalSettlement {
        precondition(!actions.isEmpty, "CompanionTerminalReconciliation needs at least one action")
        var seen = Set<UUID>()
        var unique: [CompanionTerminalAction] = []
        unique.reserveCapacity(actions.count)
        for action in actions where seen.insert(action.id).inserted {
            unique.append(action)
        }
        let ordered = unique.sorted(by: precedes(_:_:))
        return CompanionTerminalSettlement(winner: ordered[0], losers: Array(ordered.dropFirst()))
    }

    private static func precedes(_ lhs: CompanionTerminalAction, _ rhs: CompanionTerminalAction) -> Bool {
        if lhs.claim.claimRank != rhs.claim.claimRank {
            return lhs.claim.claimRank < rhs.claim.claimRank
        }
        if lhs.originRevision != rhs.originRevision {
            return lhs.originRevision > rhs.originRevision
        }
        if lhs.deviceID != rhs.deviceID {
            return lhs.deviceID < rhs.deviceID
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
