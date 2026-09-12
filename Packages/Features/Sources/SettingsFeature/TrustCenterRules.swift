import Domain
import Foundation
import Observation

/// One proposed-rule row in the Trust Center (Epic 13 R2).
///
/// A presentation projection over the R1 `RuleProposal`: closed rule key,
/// owner status, evidence counts, and the shipped per-rule throttle.
/// Never a payload, reading, or provider.
public struct RuleProposalRowPresentation: Equatable, Sendable {
    public var ruleKey: String
    public var kindCode: String
    public var effectCode: String
    public var status: RuleProposalStatus
    public var supportingEvidenceCount: Int
    public var requiredEvidenceCount: Int
    public var weeklyMax: Int
    public var cooldownTicks: TimeInterval
    public var canUndo: Bool

    public init(
        ruleKey: String,
        kindCode: String,
        effectCode: String,
        status: RuleProposalStatus,
        supportingEvidenceCount: Int,
        requiredEvidenceCount: Int,
        weeklyMax: Int,
        cooldownTicks: TimeInterval,
        canUndo: Bool,
    ) {
        self.ruleKey = ruleKey
        self.kindCode = kindCode
        self.effectCode = effectCode
        self.status = status
        self.supportingEvidenceCount = supportingEvidenceCount
        self.requiredEvidenceCount = requiredEvidenceCount
        self.weeklyMax = weeklyMax
        self.cooldownTicks = cooldownTicks
        self.canUndo = canUndo
    }

    /// Stable row key: the closed rule key can appear at most once.
    public var rowIdentifier: String {
        "trustCenter.rules.\(ruleKey)"
    }
}

/// The rule-management snapshot: proposal rows in canonical rule order.
/// Nil (not empty) means the seam is unwired and the section stays hidden.
public struct TrustCenterRulesSnapshot: Equatable, Sendable {
    public var rows: [RuleProposalRowPresentation]

    public init(rows: [RuleProposalRowPresentation] = []) {
        self.rows = rows
    }

    public static let empty = TrustCenterRulesSnapshot()
}

/// Rule-management entry points. The App runtime wires these to a
/// `RuleManagementModel` over the R1 store; previews and snapshots use
/// `.none`. MainActor-bound like `TrustCenterActions`.
public struct TrustCenterRulesActions: Sendable {
    public var decide: @MainActor @Sendable (String, RuleDecision) async -> Void
    public var undo: @MainActor @Sendable (String) async -> Void
    public var reset: @MainActor @Sendable (String) async -> Void

    public init(
        decide: @escaping @MainActor @Sendable (String, RuleDecision) async -> Void = { _, _ in },
        undo: @escaping @MainActor @Sendable (String) async -> Void = { _ in },
        reset: @escaping @MainActor @Sendable (String) async -> Void = { _ in },
    ) {
        self.decide = decide
        self.undo = undo
        self.reset = reset
    }

    public static let none = TrustCenterRulesActions()
}

/// Rule-management view model over the R1 store (Epic 13 R2).
///
/// Loads stored proposals into a `RuleProposalEngine`, applies the owner
/// Add/Not-now/Never choice, undo, and reset through the engine, and
/// persists every transition back to the store. Ticks arrive injected —
/// the model never reads a clock. Undo availability tracks genuine
/// engine transitions only: a no-op decide never arms undo, and the
/// permanent Never decline is undoable only via an explicit reset.
@Observable
public final class RuleManagementModel {
    public private(set) var rows: [RuleProposalRowPresentation] = []

    private var engine = RuleProposalEngine()
    private var undoableKeys: Set<String> = []
    private let store: any RuleProposalStore
    private let ticks: () -> TimeInterval

    public init(store: any RuleProposalStore, ticks: @escaping () -> TimeInterval = { 0 }) {
        self.store = store
        self.ticks = ticks
    }

    /// Loads every stored proposal into the engine and publishes rows in
    /// canonical rule order. A fresh load clears undo memory: only
    /// transitions made through this model are undoable here.
    public func load() async throws {
        let proposals = try await store.loadProposals()
        engine = RuleProposalEngine()
        undoableKeys.removeAll()
        for proposal in proposals {
            engine.suggest(proposal, atTicks: ticks())
        }
        refresh()
    }

    /// Applies the owner decision and persists it. Returns false when the
    /// key is unknown or the engine refuses (Never is permanent).
    @discardableResult
    public func decide(ruleKey: String, decision: RuleDecision) async throws -> Bool {
        let before = engine.proposal(for: ruleKey)?.status
        guard engine.decide(ruleKey: ruleKey, decision: decision, atTicks: ticks()) else {
            return false
        }
        let after = engine.proposal(for: ruleKey)?.status
        if before != after, after != .never {
            undoableKeys.insert(ruleKey)
        }
        try await persist(ruleKey: ruleKey)
        refresh()
        return true
    }

    /// Reverts the last model-made non-permanent transition and persists
    /// it. Returns false when nothing is undoable.
    @discardableResult
    public func undo(ruleKey: String) async throws -> Bool {
        guard undoableKeys.contains(ruleKey) else { return false }
        guard engine.undo(ruleKey: ruleKey, atTicks: ticks()) else {
            undoableKeys.remove(ruleKey)
            return false
        }
        undoableKeys.remove(ruleKey)
        try await persist(ruleKey: ruleKey)
        refresh()
        return true
    }

    /// Explicitly clears one rule to pending and persists it. The only
    /// path out of Never.
    public func reset(ruleKey: String) async throws {
        engine.reset(ruleKey: ruleKey, atTicks: ticks())
        undoableKeys.remove(ruleKey)
        try await persist(ruleKey: ruleKey)
        refresh()
    }

    private func persist(ruleKey: String) async throws {
        guard let proposal = engine.proposal(for: ruleKey) else { return }
        try await store.update(proposal)
    }

    private func refresh() {
        rows = RuleProposal.rules.keys.sorted().compactMap { key in
            guard let proposal = engine.proposal(for: key) else { return nil }
            let cap = RuleProposalEngine.defaultCaps[key]
            return RuleProposalRowPresentation(
                ruleKey: key,
                kindCode: proposal.kindCode,
                effectCode: proposal.effectCode,
                status: proposal.status,
                supportingEvidenceCount: proposal.supportingEvidenceCount,
                requiredEvidenceCount: proposal.requiredEvidenceCount,
                weeklyMax: cap?.weeklyMax ?? 0,
                cooldownTicks: cap?.cooldownTicks ?? 0,
                canUndo: undoableKeys.contains(key),
            )
        }
    }
}
