import Domain
import Foundation
import Testing
@testable import SettingsFeature

/// Epic 13 R2 RED-first: rule management drives the R1 store.
///
/// `RuleManagementModel` loads R1 proposals from a `RuleProposalStore`,
/// applies the owner Add/Not-now/Never choice, undo, and reset through the
/// `RuleProposalEngine`, and persists every transition back to the store.
/// Caps and cooldowns stay visible per row. Tests run against the
/// in-memory store.
///
/// Fails before implementation: `RuleManagementModel` does not exist.
@Suite("Rule management model")
struct RuleManagementModelTests {
    private let seed = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func proposal(
        counter: UInt64,
        ruleKey: String,
        kindCode: String,
        effectCode: String,
        status: RuleProposalStatus = .pending,
    ) throws -> RuleProposal {
        try RuleProposal(
            id: LedgerIdentity.derive(ledger: .policyDecision, seed: seed, counter: counter),
            recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
            ruleKey: ruleKey,
            kindCode: kindCode,
            effectCode: effectCode,
            supportingEvidenceCount: 2,
            requiredEvidenceCount: 2,
            status: status,
            statusUpdatedTicks: 10_000,
        )
    }

    private func storedProposals() throws -> [RuleProposal] {
        try [
            proposal(counter: 1, ruleKey: "quiet-when-weak", kindCode: "holdBegin", effectCode: "quiet"),
            proposal(counter: 2, ruleKey: "shift-within-window", kindCode: "holdBegin", effectCode: "shift"),
            proposal(
                counter: 3,
                ruleKey: "restart-on-strong-motion",
                kindCode: "sensorStrongMovementRestart",
                effectCode: "restart",
            ),
            proposal(
                counter: 4,
                ruleKey: "release-on-strong-absence",
                kindCode: "holdRelease",
                effectCode: "resume",
            ),
        ]
    }

    private func makeModel(ticks: TimeInterval = 20_000) -> (RuleManagementModel, InMemoryRuleProposalStore) {
        let store = InMemoryRuleProposalStore(now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let model = RuleManagementModel(store: store, ticks: { ticks })
        return (model, store)
    }
    private func seedStore(_ store: InMemoryRuleProposalStore) async throws {
        for record in try storedProposals() {
            try await store.append(record)
        }
    }

    @Test("Empty store loads zero rows")
    func emptyStoreLoadsZeroRows() async throws {
        let store = InMemoryRuleProposalStore(now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let model = RuleManagementModel(store: store, ticks: { 20_000 })
        try await model.load()
        #expect(model.rows.isEmpty)
    }

    @Test("Load publishes one row per stored proposal with evidence, caps, and cooldown")
    func loadPublishesRows() async throws {
        let (model, store) = makeModel()
        try await seedStore(store)
        try await model.load()
        #expect(model.rows.count == 4)
        #expect(model.rows.map(\.ruleKey).sorted() == RuleProposal.rules.keys.sorted())
        for row in model.rows {
            #expect(row.supportingEvidenceCount == 2)
            #expect(row.requiredEvidenceCount == 2)
            let cap = RuleProposalEngine.defaultCaps[row.ruleKey]
            #expect(row.weeklyMax == cap?.weeklyMax)
            #expect(row.cooldownTicks == cap?.cooldownTicks)
            #expect(row.status == .pending)
            #expect(!row.canUndo)
        }
    }

    @Test("Add persists the added status to the R1 store")
    func addPersistsAdded() async throws {
        let (model, store) = makeModel()
        try await seedStore(store)
        try await model.load()
        let applied = try await model.decide(ruleKey: "quiet-when-weak", decision: .add)
        #expect(applied)
        #expect(model.rows.first { $0.ruleKey == "quiet-when-weak" }?.status == .added)
        let stored = try await store.loadProposals()
        #expect(stored.first { $0.ruleKey == "quiet-when-weak" }?.status == .added)
    }

    @Test("Not now persists the snooze and remains undoable")
    func notNowPersistsSnooze() async throws {
        let (model, store) = makeModel()
        try await seedStore(store)
        try await model.load()
        let applied = try await model.decide(ruleKey: "shift-within-window", decision: .notNow)
        #expect(applied)
        #expect(model.rows.first { $0.ruleKey == "shift-within-window" }?.status == .notNow)
        #expect(model.rows.first { $0.ruleKey == "shift-within-window" }?.canUndo == true)
        let stored = try await store.loadProposals()
        #expect(stored.first { $0.ruleKey == "shift-within-window" }?.status == .notNow)
    }

    @Test("Undo reverts Add to pending in both model and store")
    func undoRevertsAdd() async throws {
        let (model, store) = makeModel()
        try await seedStore(store)
        try await model.load()
        _ = try await model.decide(ruleKey: "quiet-when-weak", decision: .add)
        let undone = try await model.undo(ruleKey: "quiet-when-weak")
        #expect(undone)
        #expect(model.rows.first { $0.ruleKey == "quiet-when-weak" }?.status == .pending)
        let stored = try await store.loadProposals()
        #expect(stored.first { $0.ruleKey == "quiet-when-weak" }?.status == .pending)
    }

    @Test("Never persists the permanent decline and refuses undo and re-decide")
    func neverIsPermanent() async throws {
        let (model, store) = makeModel()
        try await seedStore(store)
        try await model.load()
        let applied = try await model.decide(ruleKey: "quiet-when-weak", decision: .never)
        #expect(applied)
        #expect(model.rows.first { $0.ruleKey == "quiet-when-weak" }?.status == .never)
        let undone = try await model.undo(ruleKey: "quiet-when-weak")
        #expect(!undone)
        let redecided = try await model.decide(ruleKey: "quiet-when-weak", decision: .add)
        #expect(!redecided)
        let stored = try await store.loadProposals()
        #expect(stored.first { $0.ruleKey == "quiet-when-weak" }?.status == .never)
    }

    @Test("Reset is the only path out of Never and persists pending")
    func resetEscapesNever() async throws {
        let (model, store) = makeModel()
        try await seedStore(store)
        try await model.load()
        _ = try await model.decide(ruleKey: "quiet-when-weak", decision: .never)
        try await model.reset(ruleKey: "quiet-when-weak")
        #expect(model.rows.first { $0.ruleKey == "quiet-when-weak" }?.status == .pending)
        let stored = try await store.loadProposals()
        #expect(stored.first { $0.ruleKey == "quiet-when-weak" }?.status == .pending)
    }

    @Test("Deciding an unknown rule key changes nothing")
    func unknownRuleKeyIsNoop() async throws {
        let (model, store) = makeModel()
        try await seedStore(store)
        try await model.load()
        let applied = try await model.decide(ruleKey: "no-such-rule", decision: .add)
        #expect(!applied)
        #expect(model.rows.count == 4)
    }
}
