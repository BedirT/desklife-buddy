import Domain
import Foundation
import SettingsFeature
import Testing
@testable import App

/// Epic 13 R3 RED-first: App wiring for rule management.
///
/// The R2 views and `RuleManagementModel` ship unwired (nil rules snapshot
/// hides the Trust Center section; the Weekly audit feed defaults to nil).
/// These tests prove the App-only wiring: Trust Center Add/Not-now/Never,
/// undo, and reset persist through the real `SwiftDataRuleProposalStore`
/// (in-memory container) and survive a round-trip reload, the Weekly audit
/// projects stored proposals, and the Weekly rule route resolves to the
/// Trust Center rules section.
///
/// Fails before implementation: the App exposes no rule store seam, no
/// rules snapshot/actions, no audit feed, and no rule route.
private let ruleWiringT0 = Date(timeIntervalSince1970: 1_800_000_000)

private func ruleWiringProposal(
    ruleKey: String,
    status: RuleProposalStatus = .pending,
    evidence: Int = 2,
) throws -> RuleProposal {
    let mapping = try #require(RuleProposal.rules[ruleKey])
    return try RuleProposal(
        id: UUID(),
        recordedAt: ruleWiringT0,
        ruleKey: ruleKey,
        kindCode: mapping.kind,
        effectCode: mapping.effect,
        supportingEvidenceCount: evidence,
        requiredEvidenceCount: 2,
        status: status,
        statusUpdatedTicks: 0,
    )
}

private func seedRuleWiringStore(
    _ store: SwiftDataRuleProposalStore,
    statuses: [String: RuleProposalStatus] = [:],
) async throws {
    for key in RuleProposal.rules.keys.sorted() {
        try await store.append(ruleWiringProposal(ruleKey: key, status: statuses[key] ?? .pending))
    }
}

private func storedRuleStatus(
    _ store: SwiftDataRuleProposalStore,
    ruleKey: String,
) async throws -> RuleProposalStatus? {
    try await store.loadProposals().first { $0.ruleKey == ruleKey }?.status
}

@Suite("Rule proposal App wiring", .serialized)
struct RuleProposalAppWiringTests {
    @Test("TrustCenter Add persists through the real store and survives reload")
    func trustCenterAddPersistsAndRoundTrips() async throws {
        let store = try SwiftDataRuleProposalStore(inMemory: true, now: { ruleWiringT0 })
        try await seedRuleWiringStore(store)
        let delegate = AppDelegate()
        delegate.ruleProposalStoreOverride = store
        let scene = delegate.buildSettingsSceneModel()
        await scene.loadTrustCenterRules()

        #expect(scene.trustCenterRulesSnapshot?.rows.count == 4)
        await scene.trustCenterRulesActions.decide("quiet-when-weak", .add)

        #expect(try await storedRuleStatus(store, ruleKey: "quiet-when-weak") == .added)
        #expect(scene.trustCenterRulesSnapshot?.rows.first { $0.ruleKey == "quiet-when-weak" }?.status == .added)

        let reloaded = RuleManagementModel(store: store, ticks: { 20_000 })
        try await reloaded.load()
        #expect(reloaded.rows.first { $0.ruleKey == "quiet-when-weak" }?.status == .added)
    }

    @Test("TrustCenter snooze, decline, undo, and reset persist through the real store")
    func trustCenterLifecyclePersists() async throws {
        let store = try SwiftDataRuleProposalStore(inMemory: true, now: { ruleWiringT0 })
        try await seedRuleWiringStore(store)
        let delegate = AppDelegate()
        delegate.ruleProposalStoreOverride = store
        let scene = delegate.buildSettingsSceneModel()
        await scene.loadTrustCenterRules()

        await scene.trustCenterRulesActions.decide("shift-within-window", .notNow)
        #expect(try await storedRuleStatus(store, ruleKey: "shift-within-window") == .notNow)

        await scene.trustCenterRulesActions.undo("shift-within-window")
        #expect(try await storedRuleStatus(store, ruleKey: "shift-within-window") == .pending)

        await scene.trustCenterRulesActions.decide("restart-on-strong-motion", .never)
        #expect(try await storedRuleStatus(store, ruleKey: "restart-on-strong-motion") == .never)

        await scene.trustCenterRulesActions.decide("restart-on-strong-motion", .add)
        #expect(try await storedRuleStatus(store, ruleKey: "restart-on-strong-motion") == .never)

        await scene.trustCenterRulesActions.reset("restart-on-strong-motion")
        #expect(try await storedRuleStatus(store, ruleKey: "restart-on-strong-motion") == .pending)

        let reloaded = RuleManagementModel(store: store, ticks: { 20_000 })
        try await reloaded.load()
        #expect(reloaded.rows.first { $0.ruleKey == "shift-within-window" }?.status == .pending)
        #expect(reloaded.rows.first { $0.ruleKey == "restart-on-strong-motion" }?.status == .pending)
    }

    @Test("Weekly audit projects stored proposals as descriptive counts")
    func weeklyAuditProjectsStoredProposals() async throws {
        let store = try SwiftDataRuleProposalStore(inMemory: true, now: { ruleWiringT0 })
        try await seedRuleWiringStore(store, statuses: [
            "quiet-when-weak": .added,
            "shift-within-window": .notNow,
            "restart-on-strong-motion": .never,
        ])
        let delegate = AppDelegate()
        delegate.ruleProposalStoreOverride = store

        let audit = try #require(await delegate.loadWeeklyAssistantAudit())
        #expect(audit.proposedRuleCount == 4)
        #expect(audit.addedRuleCount == 1)
        #expect(audit.pendingRuleCount == 1)
        #expect(audit.snoozedRuleCount == 1)
        #expect(audit.declinedRuleCount == 1)
        #expect(audit.recordedRowCount == 4)
        #expect(audit.supportingEvidenceCount == 8)
    }

    @Test("Weekly audit stays hidden without a rule store")
    func weeklyAuditNilWithoutStore() async {
        let delegate = AppDelegate()
        #expect(await delegate.loadWeeklyAssistantAudit() == nil)
    }

    @Test("Weekly rule route opens the TrustCenter rules section")
    func weeklyRuleRouteOpensTrustCenterRules() {
        let delegate = AppDelegate()
        delegate.openRuleSettings()
        #expect(delegate.settingsSceneModel.featureModel.selectedSection == .sensingAndIntelligence)
    }
}
