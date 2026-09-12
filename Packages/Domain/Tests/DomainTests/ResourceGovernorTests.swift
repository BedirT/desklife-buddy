import Foundation
import Testing

@testable import Domain

/// Story 8 RED: tick-injected resource governor beside `PermissionBroker`.
///
/// The governor budgets per-work-class tokens (lease issuance, bus
/// admission, fusion, firewall evaluation) with named capacities + refill
/// cadences. Over-budget work DEFERS with an observable reason — never a
/// silent drop. Safety work (revocation drain, lease-expiry purge) bypasses
/// budgets entirely. Degraded modes shed fusion cadence first. Identical
/// tick sequences decide identically: no clocks, no sleeps, no UUIDs.
///
/// Fails before implementation: `ResourceGovernor`, `GovernorWorkClass`,
/// `GovernorSafetyWork`, `GovernorDecision`, `GovernorDeferReason`,
/// `GovernorDegradedMode`, and `GovernorBudget` do not exist.
private let governorT0: TimeInterval = 1000

private func smallGovernor() -> ResourceGovernor {
    ResourceGovernor(
        budgets: [
            .leaseIssuance: GovernorBudget(capacity: 2, refillAmount: 2, refillCadenceTicks: 60),
            .busAdmission: GovernorBudget(capacity: 2, refillAmount: 2, refillCadenceTicks: 60),
            .fusion: GovernorBudget(capacity: 2, refillAmount: 2, refillCadenceTicks: 30),
            .firewallEvaluation: GovernorBudget(capacity: 2, refillAmount: 2, refillCadenceTicks: 30),
        ],
        startedAtTicks: governorT0,
    )
}

@Suite("Resource governor: budgets defer observably")
struct ResourceGovernorBudgetTests {
    @Test("Exhaustion defers with an observable reason, never a silent drop")
    func exhaustionDefersObservably() {
        var governor = smallGovernor()
        #expect(governor.admit(.fusion, atTicks: governorT0) == .admit)
        #expect(governor.admit(.fusion, atTicks: governorT0) == .admit)
        #expect(governor.admit(.fusion, atTicks: governorT0) == .deferred(.budgetExhausted))
        #expect(governor.admittedCount(for: .fusion) == 2)
        #expect(governor.deferredCount(for: .fusion) == 1)
        #expect(governor.totalDeferredCount == 1)
        // Sibling classes are unaffected by one class's exhaustion.
        #expect(governor.admit(.busAdmission, atTicks: governorT0) == .admit)
        #expect(governor.deferredCount(for: .busAdmission) == 0)
    }

    @Test("Refill at the cadence restores admission")
    func refillRestoresAdmission() {
        var governor = smallGovernor()
        #expect(governor.admit(.leaseIssuance, atTicks: governorT0) == .admit)
        #expect(governor.admit(.leaseIssuance, atTicks: governorT0) == .admit)
        #expect(governor.admit(.leaseIssuance, atTicks: governorT0) == .deferred(.budgetExhausted))
        // A partial cadence does not refill.
        governor.advance(atTicks: governorT0 + 59)
        #expect(governor.admit(.leaseIssuance, atTicks: governorT0 + 59) == .deferred(.budgetExhausted))
        // A full cadence refills to capacity.
        governor.advance(atTicks: governorT0 + 60)
        #expect(governor.admit(.leaseIssuance, atTicks: governorT0 + 60) == .admit)
        #expect(governor.admit(.leaseIssuance, atTicks: governorT0 + 60) == .admit)
        #expect(governor.admit(.leaseIssuance, atTicks: governorT0 + 60) == .deferred(.budgetExhausted))
    }

    @Test("Default budget table is pinned")
    func defaultBudgetTablePinned() {
        let budgets = ResourceGovernor.defaultBudgets
        #expect(budgets.count == GovernorWorkClass.allCases.count)
        #expect(budgets[.leaseIssuance] == GovernorBudget(capacity: 4, refillAmount: 4, refillCadenceTicks: 60))
        #expect(budgets[.busAdmission] == GovernorBudget(capacity: 16, refillAmount: 16, refillCadenceTicks: 60))
        #expect(budgets[.fusion] == GovernorBudget(capacity: 8, refillAmount: 8, refillCadenceTicks: 30))
        #expect(
            budgets[.firewallEvaluation]
                == GovernorBudget(capacity: 8, refillAmount: 8, refillCadenceTicks: 30),
        )
    }
}

@Suite("Resource governor: safety paths bypass budgets")
struct ResourceGovernorSafetyTests {
    @Test("Revocation and expiry admit even at zero budget")
    func safetyAdmitsAtZeroBudget() {
        var governor = smallGovernor()
        // Exhaust every budgeted class.
        for work in GovernorWorkClass.allCases {
            governor.admit(work, atTicks: governorT0)
            governor.admit(work, atTicks: governorT0)
            #expect(governor.admit(work, atTicks: governorT0) == .deferred(.budgetExhausted))
        }
        // Safety work still admits, without bound, and stays observable.
        for _ in 0 ..< 10 {
            #expect(governor.admitSafety(.revocationDrain, atTicks: governorT0) == .admit)
            #expect(governor.admitSafety(.leaseExpiryPurge, atTicks: governorT0) == .admit)
        }
        #expect(governor.safetyAdmittedCount(for: .revocationDrain) == 10)
        #expect(governor.safetyAdmittedCount(for: .leaseExpiryPurge) == 10)
        #expect(governor.totalDeferredCount == GovernorWorkClass.allCases.count)
    }

    @Test("Safety admission never touches budget tokens")
    func safetyNeverConsumesBudget() {
        var governor = smallGovernor()
        for _ in 0 ..< 10 {
            _ = governor.admitSafety(.revocationDrain, atTicks: governorT0)
        }
        #expect(governor.admit(.fusion, atTicks: governorT0) == .admit)
        #expect(governor.admit(.fusion, atTicks: governorT0) == .admit)
        #expect(governor.admit(.fusion, atTicks: governorT0) == .deferred(.budgetExhausted))
    }
}

@Suite("Resource governor: degraded modes and determinism")
struct ResourceGovernorDegradedTests {
    @Test("Degraded modes shed fusion cadence first")
    func degradeOrderFusionFirst() {
        var governor = smallGovernor()
        #expect(governor.degradedMode == .normal)
        // Exhausting only a non-fusion class still sheds fusion first.
        governor.admit(.busAdmission, atTicks: governorT0)
        governor.admit(.busAdmission, atTicks: governorT0)
        #expect(governor.degradedMode == .shedFusion)
        // Exhausting fusion alongside it deepens the shed, never safety.
        governor.admit(.fusion, atTicks: governorT0)
        governor.admit(.fusion, atTicks: governorT0)
        #expect(governor.degradedMode == .shedBroadly)
        // Refill restores normal.
        governor.advance(atTicks: governorT0 + 60)
        #expect(governor.degradedMode == .normal)
    }

    @Test("Identical ticks give identical decisions")
    func tickDeterminism() {
        let script: [(GovernorWorkClass, TimeInterval)] = [
            (.fusion, governorT0),
            (.fusion, governorT0),
            (.fusion, governorT0),
            (.busAdmission, governorT0 + 1),
            (.leaseIssuance, governorT0 + 61),
            (.fusion, governorT0 + 61),
            (.firewallEvaluation, governorT0 + 61),
            (.firewallEvaluation, governorT0 + 61),
            (.firewallEvaluation, governorT0 + 61),
        ]
        var first = smallGovernor()
        var second = smallGovernor()
        var firstDecisions: [GovernorDecision] = []
        var secondDecisions: [GovernorDecision] = []
        for (work, ticks) in script {
            firstDecisions.append(first.admit(work, atTicks: ticks))
            secondDecisions.append(second.admit(work, atTicks: ticks))
        }
        #expect(firstDecisions == secondDecisions)
        for work in GovernorWorkClass.allCases {
            #expect(first.admittedCount(for: work) == second.admittedCount(for: work))
            #expect(first.deferredCount(for: work) == second.deferredCount(for: work))
        }
        #expect(first.degradedMode == second.degradedMode)
    }
}
