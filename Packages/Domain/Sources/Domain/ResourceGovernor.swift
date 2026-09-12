import Foundation

/// One budgeted work class the governor meters (Story 8).
///
/// Each class names one seam point: lease issuance (the lease-authority
/// `issue` path), bus admission (the bus/firewall `admit` path), fusion
/// (the `fuse` cadence), and firewall evaluation (the `evaluate` path).
public enum GovernorWorkClass: String, CaseIterable, Hashable, Sendable {
    case leaseIssuance
    case busAdmission
    case fusion
    case firewallEvaluation
}

/// Safety work that bypasses budgets entirely (Story 8).
///
/// Revocation drains and lease-expiry purges protect the consent and
/// lifetime invariants: throttling them could hold revoked evidence live
/// or dead leases votable, so they admit without bound and never consume
/// a token.
public enum GovernorSafetyWork: String, CaseIterable, Hashable, Sendable {
    case revocationDrain
    case leaseExpiryPurge
}

/// Why budgeted work was deferred instead of admitted (Story 8).
public enum GovernorDeferReason: String, Equatable, Sendable {
    case budgetExhausted
}

/// One governor verdict (Story 8).
///
/// Deferred work is observable through the per-class deferred counters —
/// never a silent drop.
public enum GovernorDecision: Equatable, Sendable {
    case admit
    case deferred(GovernorDeferReason)
}

/// How deeply the governor is shedding load (Story 8).
///
/// Fusion cadence sheds first: it is the cheapest work to slow and the
/// furthest from a consent or lifetime invariant. Broader shedding adds
/// the remaining budgeted classes; safety work never sheds.
public enum GovernorDegradedMode: String, Equatable, Sendable {
    case normal
    case shedFusion
    case shedBroadly
}

/// One work class's token budget (Story 8).
public struct GovernorBudget: Equatable, Sendable {
    /// Maximum held tokens. Full at construction and after each refill.
    public let capacity: Int
    /// Tokens restored per elapsed refill cadence.
    public let refillAmount: Int
    /// Ticks per refill step. Tick-injected: the governor never reads a clock.
    public let refillCadenceTicks: TimeInterval

    public init(capacity: Int, refillAmount: Int, refillCadenceTicks: TimeInterval) {
        precondition(capacity > 0, "GovernorBudget capacity must be positive")
        precondition(refillAmount > 0, "GovernorBudget refillAmount must be positive")
        precondition(refillCadenceTicks > 0, "GovernorBudget refillCadenceTicks must be positive")
        self.capacity = capacity
        self.refillAmount = refillAmount
        self.refillCadenceTicks = refillCadenceTicks
    }
}

/// Tick-injected resource governor beside `PermissionBroker` (Story 8).
///
/// A value-semantic token bucket per work class: each `admit` consumes one
/// token when the class holds one and defers observably when it holds
/// none. `advance(atTicks:)` refills every class by whole elapsed
/// cadences, capped at capacity. Backward ticks refill nothing, so
/// identical tick sequences decide identically. Safety work admits through
/// `admitSafety` without touching any budget.
public struct ResourceGovernor: Sendable {
    /// Shipped budget table: lease and admission refill per 60 ticks,
    /// fusion and evaluation per 30, so the shed-first classes cycle
    /// twice as often under sustained pressure.
    public static let defaultBudgets: [GovernorWorkClass: GovernorBudget] = [
        .leaseIssuance: GovernorBudget(capacity: 4, refillAmount: 4, refillCadenceTicks: 60),
        .busAdmission: GovernorBudget(capacity: 16, refillAmount: 16, refillCadenceTicks: 60),
        .fusion: GovernorBudget(capacity: 8, refillAmount: 8, refillCadenceTicks: 30),
        .firewallEvaluation: GovernorBudget(capacity: 8, refillAmount: 8, refillCadenceTicks: 30),
    ]

    private let budgets: [GovernorWorkClass: GovernorBudget]
    private var tokens: [GovernorWorkClass: Int]
    private var lastRefillTicks: [GovernorWorkClass: TimeInterval]
    private var admitted: [GovernorWorkClass: Int] = [:]
    private var deferred: [GovernorWorkClass: Int] = [:]
    private var safetyAdmitted: [GovernorSafetyWork: Int] = [:]

    public init(
        budgets: [GovernorWorkClass: GovernorBudget] = defaultBudgets,
        startedAtTicks: TimeInterval = 0,
    ) {
        precondition(
            GovernorWorkClass.allCases.allSatisfy { budgets[$0] != nil },
            "ResourceGovernor requires a budget for every work class",
        )
        self.budgets = budgets
        var full: [GovernorWorkClass: Int] = [:]
        var starts: [GovernorWorkClass: TimeInterval] = [:]
        for work in GovernorWorkClass.allCases {
            full[work] = budgets[work]?.capacity ?? 0
            starts[work] = startedAtTicks
        }
        tokens = full
        lastRefillTicks = starts
    }

    /// Admits or defers one unit of budgeted work at the presented ticks.
    @discardableResult
    public mutating func admit(_ work: GovernorWorkClass, atTicks ticks: TimeInterval) -> GovernorDecision {
        refill(work, atTicks: ticks)
        guard let held = tokens[work], held > 0 else {
            deferred[work, default: 0] += 1
            return .deferred(.budgetExhausted)
        }
        tokens[work] = held - 1
        admitted[work, default: 0] += 1
        return .admit
    }

    /// Refills every class to the presented ticks without consuming.
    public mutating func advance(atTicks ticks: TimeInterval) {
        for work in GovernorWorkClass.allCases {
            refill(work, atTicks: ticks)
        }
    }

    /// Admits one unit of safety work unconditionally (Story 8).
    ///
    /// Always `.admit`, even at zero budget: revocation and expiry paths
    /// are never throttled. Counted separately so audits can tell safety
    /// volume from budgeted volume.
    @discardableResult
    public mutating func admitSafety(_ work: GovernorSafetyWork, atTicks _: TimeInterval) -> GovernorDecision {
        safetyAdmitted[work, default: 0] += 1
        return .admit
    }

    /// Admitted units of one budgeted class.
    public func admittedCount(for work: GovernorWorkClass) -> Int {
        admitted[work, default: 0]
    }

    /// Deferred units of one budgeted class. Every defer is counted: no
    /// over-budget work disappears silently.
    public func deferredCount(for work: GovernorWorkClass) -> Int {
        deferred[work, default: 0]
    }

    /// Deferred units across every budgeted class.
    public var totalDeferredCount: Int {
        GovernorWorkClass.allCases.reduce(0) { $0 + deferredCount(for: $1) }
    }

    /// Admitted units of one safety class.
    public func safetyAdmittedCount(for work: GovernorSafetyWork) -> Int {
        safetyAdmitted[work, default: 0]
    }

    /// Current degraded mode from live token levels (Story 8).
    ///
    /// Any budgeted pressure sheds fusion cadence first — including
    /// pressure on a sibling class while fusion still holds tokens — so
    /// fusion is always earliest in the shed order. Fusion plus sibling
    /// exhaustion deepens to broad shedding. Safety volume never affects
    /// the mode.
    public var degradedMode: GovernorDegradedMode {
        let exhausted = Set(GovernorWorkClass.allCases.filter { tokens[$0, default: 0] <= 0 })
        if exhausted.isEmpty {
            return .normal
        }
        if exhausted == [.fusion] || !exhausted.contains(.fusion) {
            return .shedFusion
        }
        return .shedBroadly
    }

    private mutating func refill(_ work: GovernorWorkClass, atTicks ticks: TimeInterval) {
        guard let budget = budgets[work] else { return }
        let last = lastRefillTicks[work, default: ticks]
        guard ticks >= last else { return }
        let steps = Int((ticks - last) / budget.refillCadenceTicks)
        guard steps > 0 else { return }
        tokens[work] = min(budget.capacity, tokens[work, default: 0] + steps * budget.refillAmount)
        lastRefillTicks[work] = last + TimeInterval(steps) * budget.refillCadenceTicks
    }
}
