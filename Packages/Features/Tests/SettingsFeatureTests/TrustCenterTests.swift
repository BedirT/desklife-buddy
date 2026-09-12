import Domain
import Foundation
import Testing
@testable import SettingsFeature

/// Epic 3 story 7 RED-first: the Trust Center presentation contract.
///
/// The center maps the story-6 broker into capability states, a sanitized
/// live inspector (verdict classes, counts, windows — never readings,
/// confidence, providers, or payloads), JIT guidance per capability state,
/// kill-switch presentation, and a newest-first consent-receipt list.
@Suite("Trust center state mapping")
struct TrustCenterTests {
    private func makeBroker() throws -> PermissionBroker {
        try PermissionBroker(deviceID: UUID(), epochCode: "test-epoch")
    }

    private func makeStore(now: Date) -> InMemoryLedgerConsentReceiptStore {
        InMemoryLedgerConsentReceiptStore(now: { now })
    }

    @Test("Fresh broker presents every capability as unknown with closed paths")
    func freshBrokerPresentsUnknown() throws {
        let broker = try makeBroker()
        let snapshot = TrustCenterSnapshot(broker: broker)

        #expect(snapshot.capabilities.count == PermissionCapability.allCases.count)
        for presentation in snapshot.capabilities {
            #expect(presentation.consentState == .unknown)
            #expect(presentation.educationOwed)
            #expect(!presentation.pathOpen)
            #expect(!presentation.killSwitchEngaged)
        }
        #expect(!snapshot.isKillSwitchEngaged)
        #expect(!snapshot.suppressionActive)
        #expect(snapshot.educationOwedCapabilities.count == PermissionCapability.allCases.count)
    }

    @Test("Sensing grant opens only the lease path; effect grant opens only emission")
    func grantOpensOwnPathOnly() async throws {
        let now = Date()
        let store = makeStore(now: now)
        var broker = try makeBroker()
        try await broker.grant(.sensingPresence, atTicks: 100, recordedAt: now, store: store)
        try await broker.grant(.effectHold, atTicks: 100, recordedAt: now, store: store)

        let snapshot = TrustCenterSnapshot(broker: broker)
        let sensing = snapshot.capabilities.first { $0.capability == .sensingPresence }
        let effect = snapshot.capabilities.first { $0.capability == .effectHold }
        let untouched = snapshot.capabilities.first { $0.capability == .sensingMotion }

        #expect(sensing?.consentState == .granted)
        #expect(sensing?.pathOpen == true)
        #expect(effect?.consentState == .granted)
        #expect(effect?.pathOpen == true)
        #expect(untouched?.consentState == .unknown)
        #expect(untouched?.pathOpen == false)
        // Consent-split isolation: the sensing grant must not open the
        // untouched effect path, and vice versa.
        #expect(!broker.canEmitEffect(for: .effectRestart))
        #expect(!broker.canIssueLease(for: .sensingMotion))
    }

    @Test("Denied and revoked capabilities close their path and owe settings guidance")
    func deniedAndRevokedClosePaths() async throws {
        let now = Date()
        let store = makeStore(now: now)
        var broker = try makeBroker()
        try await broker.deny(.sensingMotion, atTicks: 100, recordedAt: now, store: store)
        try await broker.grant(.sensingAmbient, atTicks: 100, recordedAt: now, store: store)
        try await broker.revoke(.sensingAmbient, atTicks: 200, recordedAt: now, store: store)

        let snapshot = TrustCenterSnapshot(broker: broker)
        let denied = snapshot.capabilities.first { $0.capability == .sensingMotion }
        let revoked = snapshot.capabilities.first { $0.capability == .sensingAmbient }

        #expect(denied?.consentState == .denied)
        #expect(denied?.pathOpen == false)
        #expect(denied?.educationOwed == false)
        #expect(revoked?.consentState == .revoked)
        #expect(revoked?.pathOpen == false)
        #expect(snapshot.guidance(for: .sensingMotion) == .settingsGuidance)
        #expect(snapshot.guidance(for: .sensingAmbient) == .settingsGuidance)
    }

    @Test("Guidance matrix: educating owes the explainer, granted owes nothing")
    func educationGuidanceMatrix() async throws {
        let now = Date()
        let store = makeStore(now: now)
        var broker = try makeBroker()
        broker.beginEducation(for: .sensingPresence)
        try await broker.grant(.effectHold, atTicks: 100, recordedAt: now, store: store)

        let snapshot = TrustCenterSnapshot(broker: broker)
        // unknown owes the explainer.
        #expect(snapshot.guidance(for: .sensingMotion) == .explainerOwed)
        // educating owes the explainer.
        #expect(snapshot.guidance(for: .sensingPresence) == .explainerOwed)
        #expect(snapshot.capabilities.first { $0.capability == .sensingPresence }?.consentState == .educating)
        // granted owes nothing.
        #expect(snapshot.guidance(for: .effectHold) == .none)
        #expect(snapshot.educationOwedCapabilities.contains(.sensingMotion))
        #expect(snapshot.educationOwedCapabilities.contains(.sensingPresence))
        #expect(!snapshot.educationOwedCapabilities.contains(.effectHold))
    }

    @Test("Kill switch engages suppression, closes every path, and marks every row")
    func killSwitchPresentation() async throws {
        let now = Date()
        let store = makeStore(now: now)
        var broker = try makeBroker()
        try await broker.grant(.sensingPresence, atTicks: 100, recordedAt: now, store: store)
        try await broker.grant(.effectHold, atTicks: 100, recordedAt: now, store: store)
        _ = try await broker.engageKillSwitch(atTicks: 200, recordedAt: now, store: store)

        let snapshot = TrustCenterSnapshot(broker: broker)
        #expect(snapshot.isKillSwitchEngaged)
        #expect(snapshot.suppressionActive)
        #expect(broker.activeSuppressionReasons == [.manualPause])
        for presentation in snapshot.capabilities {
            #expect(!presentation.pathOpen)
            #expect(presentation.killSwitchEngaged)
        }
        // Resume is never silent: revoked stays revoked after disengage.
        broker.disengageKillSwitch()
        let resumed = TrustCenterSnapshot(broker: broker)
        #expect(!resumed.isKillSwitchEngaged)
        #expect(resumed.capabilities.first { $0.capability == .sensingPresence }?.consentState == .revoked)
    }

    @Test("Receipts list newest-first over closed scopes and statuses")
    func receiptOrdering() throws {
        let broker = try makeBroker()
        let device = UUID().uuidString
        func receipt(scope: String, status: String, at offset: TimeInterval) throws -> LedgerConsentReceiptRecord {
            try LedgerConsentReceiptRecord(
                id: UUID(),
                recordedAt: Date(timeIntervalSince1970: 1_700_000_000 + offset),
                providerCode: "fake-presence",
                scopeCode: scope,
                scopeRevision: 1,
                grantedTicks: 100 + offset,
                expiryTicks: 190 + offset,
                epochCode: "test-epoch",
                deviceID: device,
                statusCode: status,
                revokedTicks: status == "granted" ? nil : 100 + offset,
            )
        }
        let oldest = try receipt(scope: "sensing-presence", status: "granted", at: 0)
        let middle = try receipt(scope: "sensing-motion", status: "revoked", at: 60)
        let newest = try receipt(scope: "effect-hold", status: "granted", at: 120)

        let snapshot = TrustCenterSnapshot(broker: broker, receipts: [oldest, newest, middle])
        #expect(snapshot.receipts.map(\.scopeCode) == ["effect-hold", "sensing-motion", "sensing-presence"])
        #expect(snapshot.receipts.first?.statusCode == "granted")
        for presentation in snapshot.receipts {
            #expect(LedgerConsentReceiptRecord.scopes.contains(presentation.scopeCode))
            #expect(LedgerConsentReceiptRecord.statuses.contains(presentation.statusCode))
        }
    }

    @Test("Inspector projections carry only verdict classes, counts, and windows")
    func sanitizedInspectorProjections() throws {
        let broker = try makeBroker()
        let device = UUID().uuidString
        let record = try LedgerPolicyDecisionRecord(
            id: UUID(),
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000),
            actionUUID: UUID(),
            actionDeviceID: device,
            actionCounter: 3,
            holdDecisionUUID: nil,
            kindCode: "holdBegin",
            effectCode: "quiet",
            leaseGrantedTicks: 100,
            leaseExpiryTicks: 190,
            assessmentDigest: "opaque-digest",
            evaluatedTicks: 120,
        )
        let status = TrustCenterInspectorStatus.make(broker: broker, policyDecisions: [record])

        #expect(status.bus.admittedCount == 1)
        #expect(status.bus.lastVerdictClassCode == "quiet")
        #expect(status.firewall.holdEventCount == 1)
        #expect(status.firewall.lastEffectClassCode == "quiet")
        #expect(status.firewall.windowSeconds == 90)
        #expect(status.lease.activeLeaseCount == 0)
        #expect(status.lease.issuanceBlocked == broker.isSensingSilent)

        // Closed-vocabulary pin: verdict classes stay inside the
        // ledger-admitted effect classes plus the empty marker.
        let admitted = Set(LedgerPolicyDecisionRecord.effects + ["none"])
        #expect(admitted.contains(status.bus.lastVerdictClassCode))
        #expect(admitted.contains(status.firewall.lastEffectClassCode))

        // Field-allowlist pin: any future reading/confidence/provider
        // field fails this test by construction.
        #expect(trustCenterFieldLabels(status.lease) == ["activeLeaseCount", "issuanceBlocked", "openWindowCount"])
        #expect(trustCenterFieldLabels(status.bus) == ["admittedCount", "lastVerdictClassCode", "pendingCount"])
        #expect(trustCenterFieldLabels(status.firewall) == ["holdEventCount", "lastEffectClassCode", "windowSeconds"])
        let dump = String(describing: status)
        for banned in ["reading", "confidence", "provider", "payload", "fused", "evidence"] {
            #expect(!dump.localizedCaseInsensitiveContains(banned), "inspector leaks \(banned)")
        }
    }

    @Test("Empty ledgers present an idle inspector with the none verdict class")
    func emptyInspectorIsIdle() throws {
        let broker = try makeBroker()
        let status = TrustCenterInspectorStatus.make(broker: broker, policyDecisions: [])
        #expect(status == .idle)
        #expect(status.bus.lastVerdictClassCode == "none")
        #expect(status.firewall.lastEffectClassCode == "none")
        #expect(status.firewall.windowSeconds == 0)

        let snapshot = TrustCenterSnapshot(broker: broker)
        #expect(snapshot.receipts.isEmpty)
        #expect(snapshot.inspectorStatus == .idle)
    }

    @Test("Disengage restores the Allow path: re-grant reopens after resume")
    func disengageRestoresReconsent() async throws {
        let now = Date()
        let store = makeStore(now: now)
        var broker = try makeBroker()
        try await broker.grant(.sensingPresence, atTicks: 100, recordedAt: now, store: store)
        _ = try await broker.engageKillSwitch(atTicks: 200, recordedAt: now, store: store)
        do {
            try await broker.grant(.sensingPresence, atTicks: 300, recordedAt: now, store: store)
            Issue.record("grant must be refused while the kill switch is engaged")
        } catch {}
        broker.disengageKillSwitch()
        try await broker.grant(.sensingPresence, atTicks: 400, recordedAt: now, store: store)

        let snapshot = TrustCenterSnapshot(broker: broker)
        #expect(!snapshot.isKillSwitchEngaged)
        #expect(snapshot.capabilities.first { $0.capability == .sensingPresence }?.consentState == .granted)
        #expect(snapshot.capabilities.first { $0.capability == .sensingPresence }?.pathOpen == true)
    }

    @Test("Delete feedback names the removed receipt and decision counts")
    func deleteFeedbackCounts() {
        let feedback = TrustCenterL10n.deleteDone(receipts: 3, decisions: 2)
        #expect(feedback.contains("3"))
        #expect(feedback.contains("2"))
    }

    @Test("Same-tick receipt batches keep ledger order deterministically")
    func sameTickBatchesAreStable() throws {
        let device = UUID().uuidString
        func receipt(_ scope: String, revision: UInt64, at offset: TimeInterval = 0) throws -> LedgerConsentReceiptRecord {
            try LedgerConsentReceiptRecord(
                id: UUID(),
                recordedAt: Date(timeIntervalSince1970: 1_700_000_000 + offset),
                providerCode: "fake-presence",
                scopeCode: scope,
                scopeRevision: revision,
                grantedTicks: 100,
                expiryTicks: 190,
                epochCode: "test-epoch",
                deviceID: device,
                statusCode: "revoked",
                revokedTicks: 100,
            )
        }
        // Kill-switch batches share one tick: ties must keep ledger order,
        // not sort-algorithm order, and repeat runs must agree.
        let batch = try [receipt("sensing-presence", revision: 1), receipt("sensing-motion", revision: 1), receipt("effect-hold", revision: 2)]
        let first = TrustCenterReceiptPresentation.ordered(batch).map(\.scopeCode)
        let second = TrustCenterReceiptPresentation.ordered(batch).map(\.scopeCode)
        #expect(first == ["sensing-presence", "sensing-motion", "effect-hold"])
        #expect(second == first)
        // Newest-first still dominates across ticks regardless of input order.
        let mixed = try [receipt("effect-hold", revision: 2), receipt("sensing-presence", revision: 1, at: 120)]
        #expect(TrustCenterReceiptPresentation.ordered(mixed).map(\.scopeCode) == ["sensing-presence", "effect-hold"])
    }

    @Test("Receipt row identifiers stay unique over multi-row-per-scope history")
    func receiptIdentifiersAreUnique() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let rows = [
            TrustCenterReceiptPresentation(scopeCode: "sensing-presence", scopeRevision: 1, statusCode: "granted", recordedAt: base),
            TrustCenterReceiptPresentation(scopeCode: "sensing-presence", scopeRevision: 1, statusCode: "revoked", recordedAt: base.addingTimeInterval(60)),
            TrustCenterReceiptPresentation(scopeCode: "sensing-presence", scopeRevision: 2, statusCode: "granted", recordedAt: base.addingTimeInterval(120)),
        ]
        #expect(Set(rows.map(\.rowIdentifier)).count == 3)
    }
}

private func trustCenterFieldLabels(_ value: some Any) -> [String] {
    Mirror(reflecting: value).children.compactMap(\.label).sorted()
}
