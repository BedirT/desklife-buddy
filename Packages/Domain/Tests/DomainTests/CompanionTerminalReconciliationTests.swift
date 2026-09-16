import Foundation
import Testing
@testable import Domain

/// Epic 4 closeout Step 1 RED-first: offline terminal actions from either device
/// must converge order-independently to one winner with exactly one product fact.
/// Losers stay only in the companion audit ledger. Written before the reconciler
/// exists, so every test below fails (missing `CompanionTerminalReconciliation`).
@Suite("Companion terminal reconciliation")
struct CompanionTerminalReconciliationTests {
    private static let mac = "22222222-2222-2222-2222-222222222222"
    private static let phone = "11111111-1111-1111-1111-111111111111"

    private static func intent(
        id: UUID = UUID(),
        device: String,
        counter: UInt64,
        claim: CompanionTerminalClaim,
        revision: UInt64 = 7,
    ) -> CompanionTerminalAction {
        CompanionTerminalAction(
            id: id,
            deviceID: device,
            counter: counter,
            claim: claim,
            originRevision: revision,
        )
    }

    @Test("All delivery orders of competing offline terminals pick the same winner")
    func permutationsConvergeToOneWinner() {
        let skip = Self.intent(device: Self.mac, counter: 1, claim: .skipped)
        let moved = Self.intent(device: Self.phone, counter: 1, claim: .alreadyMoved)
        let done = Self.intent(device: Self.phone, counter: 2, claim: .completed)
        let batch = [skip, moved, done]
        var winners = Set<UUID>()
        for order in batch.permutations() {
            let result = CompanionTerminalReconciliation.reconcile(order)
            winners.insert(result.winner.id)
            #expect(result.losers.count == 2)
        }
        #expect(winners.count == 1)
        #expect(winners.first == skip.id)
    }

    @Test("Duplicates, reordered, late, and competing arrivals still converge")
    func duplicateReorderedLateCompetingConverge() {
        let first = Self.intent(device: Self.phone, counter: 1, claim: .completed)
        let second = Self.intent(device: Self.mac, counter: 9, claim: .alreadyMoved)
        let batch = [first, second, first]
        let a = CompanionTerminalReconciliation.reconcile(batch)
        let b = CompanionTerminalReconciliation.reconcile(batch.reversed())
        #expect(a.winner.id == b.winner.id)
        #expect(a.winner.id == second.id)
        #expect(a.losers.map(\.id) == [first.id])
    }

    @Test("Losers are exposed for audit and emit no product facts")
    func losersStayInAuditLedgerOnly() {
        let winner = Self.intent(device: Self.mac, counter: 1, claim: .skipped)
        let loser = Self.intent(device: Self.phone, counter: 1, claim: .completed)
        let result = CompanionTerminalReconciliation.reconcile([winner, loser])
        #expect(result.winner.id == winner.id)
        #expect(result.losers.map(\.id) == [loser.id])
        #expect(result.productFacts.count == 1)
        #expect(result.productFacts.first == winner.productFactKind)
        #expect(!result.productFacts.contains(loser.productFactKind))
    }

    @Test("The winner maps to exactly one product fact")
    func exactlyOneProductFactGuard() {
        let skip = Self.intent(device: Self.phone, counter: 3, claim: .skipped)
        let done = Self.intent(device: Self.mac, counter: 4, claim: .completed)
        let result = CompanionTerminalReconciliation.reconcile([done, skip])
        #expect(result.winner.id == skip.id)
        #expect(result.productFacts.count == 1)
    }
}

private extension Array {
    /// All arrival permutations for small convergence batches.
    func permutations() -> [[Element]] {
        guard count > 1 else { return [self] }
        var out: [[Element]] = []
        for (index, element) in enumerated() {
            var rest = self
            rest.remove(at: index)
            for tail in rest.permutations() {
                out.append([element] + tail)
            }
        }
        return out
    }
}
