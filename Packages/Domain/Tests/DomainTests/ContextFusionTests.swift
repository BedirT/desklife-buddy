import Foundation
import Testing
@testable import Domain

// Epic 5 story S4 (issue #6, gate G1): layered context fusion in shadow +
// suggest, over the Epic 3 EvidenceFusion path. RED-first: these tests name
// the fusion-layer contract (manual wins, single weak signal ambient-only,
// derivatives collapse, shadow never emits, suggest never holds).

private let ctxDevice = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000c70001")!)
private let ctxEpoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000ec70001")!)

private struct CtxFixture {
    var bus: EvidenceBus
    var frontmostLease: SensingProviderLease
    var mediaLease: SensingProviderLease
    var focusLease: SensingProviderLease
}

private func ctxFixture(capacity: Int = 8) throws -> CtxFixture {
    var authority = SensingLeaseAuthority()
    func issue(_ provider: SensingProviderID) throws -> SensingProviderLease {
        try authority.issue(
            provider: provider,
            epoch: ctxEpoch,
            device: ctxDevice,
            lifetimeSeconds: 60,
            atTicks: 1000,
        )
    }
    let frontmost = try issue(.frontmostApp)
    let media = try issue(.mediaDevice)
    let focus = try issue(.focusFilter)
    return CtxFixture(
        bus: EvidenceBus(capacity: capacity, authority: authority),
        frontmostLease: frontmost,
        mediaLease: media,
        focusLease: focus,
    )
}

private func ctxProposal(
    source: EvidenceSource,
    groupCode: String,
    reading: EvidenceReading = .present,
    confidence: EvidenceConfidence = .high,
    observed: TimeInterval = 1000,
    ttl: TimeInterval = 60,
) throws -> EvidenceProposal {
    try EvidenceProposal(
        kind: source == .mediaDevice ? .ambient : .presence,
        source: source,
        reading: reading,
        quality: .full,
        confidence: confidence,
        coverage: .partial,
        independenceGroup: EvidenceIndependenceGroup(code: groupCode),
        observedTicks: observed,
        timeToLiveSeconds: ttl,
    )
}

private func ctxAdmit(
    fixture: inout CtxFixture,
    proposal: EvidenceProposal,
    atTicks ticks: TimeInterval = 1010,
) -> EvidenceAdmission {
    let lease: SensingProviderLease = switch proposal.source {
    case .frontmostApp: fixture.frontmostLease
    case .mediaDevice: fixture.mediaLease
    case .focusFilter: fixture.focusLease
    default: fixture.frontmostLease
    }
    return fixture.bus.admit(
        proposal,
        lease: lease,
        for: proposal.source.providerID,
        originRevision: 0,
        epoch: ctxEpoch,
        presentingDeviceID: ctxDevice,
        atTicks: ticks,
    )
}

private func ctxNow(_ ticks: TimeInterval = 1010) -> Date {
    Date(timeIntervalSince1970: ticks)
}

@Suite("Layered context fusion (S4: shadow + suggest)")
struct ContextFusionTests {
    @Test("single weak signal stays ambient")
    func singleWeakSignalStaysAmbient() throws {
        var fixture = try ctxFixture()
        let weak = try ctxProposal(source: .frontmostApp, groupCode: "bundle-app", confidence: .low)
        #expect(ctxAdmit(fixture: &fixture, proposal: weak) == .admitted)
        let decision = ContextFusion.evaluate(
            fixture.bus, atTicks: 1010, manualHold: nil, now: ctxNow(), mode: .suggest,
        )
        #expect(decision.effect == .ambientMenuOnly)
        #expect(decision.suggestion == nil)
        #expect(decision.effectiveVotes == 1)
    }

    @Test("manual state outranks inference")
    func manualStateOutranksInference() throws {
        var fixture = try ctxFixture()
        let app = try ctxProposal(source: .frontmostApp, groupCode: "bundle-app")
        let focus = try ctxProposal(source: .focusFilter, groupCode: "focus-filter")
        #expect(ctxAdmit(fixture: &fixture, proposal: app) == .admitted)
        #expect(ctxAdmit(fixture: &fixture, proposal: focus) == .admitted)
        let hold = ManualContextHold(
            mode: .meetingOrCall,
            startedAt: ctxNow(900),
            expiresAt: ctxNow(4600),
        )
        let decision = ContextFusion.evaluate(
            fixture.bus, atTicks: 1010, manualHold: hold, now: ctxNow(), mode: .suggest,
        )
        #expect(decision.effect == .manualHold)
        #expect(decision.manualMode == .meetingOrCall)
        #expect(decision.suggestion == nil)
    }

    @Test("correlated signals cannot self-promote")
    func correlatedSignalsCannotSelfPromote() throws {
        var fixture = try ctxFixture()
        // Both parents plus the FaceTime derivative (own group, parent
        // source): one call-observation family, one vote — never three.
        let parentApp = try ctxProposal(source: .frontmostApp, groupCode: "bundle-app")
        let parentDevice = try ctxProposal(source: .mediaDevice, groupCode: "media-device")
        let derivative = try ctxProposal(source: .frontmostApp, groupCode: "facetime-derivative")
        #expect(ctxAdmit(fixture: &fixture, proposal: parentApp) == .admitted)
        #expect(ctxAdmit(fixture: &fixture, proposal: parentDevice) == .admitted)
        #expect(ctxAdmit(fixture: &fixture, proposal: derivative) == .admitted)
        let decision = ContextFusion.evaluate(
            fixture.bus, atTicks: 1010, manualHold: nil, now: ctxNow(), mode: .suggest,
        )
        #expect(decision.effectiveVotes == 1)
        #expect(decision.effect == .ambientMenuOnly)
        #expect(decision.suggestion == nil)
    }

    @Test("shadow evaluates without emitting")
    func shadowNeverInfluencesEmission() throws {
        var fixture = try ctxFixture()
        let app = try ctxProposal(source: .frontmostApp, groupCode: "bundle-app")
        let focus = try ctxProposal(source: .focusFilter, groupCode: "focus-filter")
        #expect(ctxAdmit(fixture: &fixture, proposal: app) == .admitted)
        #expect(ctxAdmit(fixture: &fixture, proposal: focus) == .admitted)
        let decision = ContextFusion.evaluate(
            fixture.bus, atTicks: 1010, manualHold: nil, now: ctxNow(), mode: .shadow,
        )
        // Counterfactual only: eligible, recorded, but nothing surfaced and
        // nothing emitted toward behavior.
        #expect(decision.wouldHaveSuggested == true)
        #expect(decision.effect == .ambientMenuOnly)
        #expect(decision.suggestion == nil)
        var log = ContextFusionShadowLog()
        log.record(decision: decision, mode: .shadow, atTicks: 1010)
        #expect(log.entries.count == 1)
        #expect(log.entries[0].wouldHaveSuggested == true)
        #expect(log.entries[0].effect == .ambientMenuOnly)
    }

    @Test("suggest surfaces a bounded proposal and never holds")
    func suggestSurfacesWithoutAutoHold() throws {
        var fixture = try ctxFixture()
        let app = try ctxProposal(source: .frontmostApp, groupCode: "bundle-app")
        let focus = try ctxProposal(source: .focusFilter, groupCode: "focus-filter")
        #expect(ctxAdmit(fixture: &fixture, proposal: app) == .admitted)
        #expect(ctxAdmit(fixture: &fixture, proposal: focus) == .admitted)
        let decision = ContextFusion.evaluate(
            fixture.bus, atTicks: 1010, manualHold: nil, now: ctxNow(), mode: .suggest,
        )
        #expect(decision.effect == .suggest)
        #expect(decision.effectiveVotes == 2)
        let suggestion = try #require(decision.suggestion)
        // Qualified copy only: likely/contextual, never a universal meeting
        // fact. No hold exists in this story by construction (S5 owns it).
        #expect(suggestion.headline.hasPrefix("Likely"))
        #expect(!suggestion.headline.contains("in a meeting"))
        #expect(!suggestion.headline.lowercased().contains("on a call"))
        #expect(suggestion.familyCodes == ["call", "focus"])
        #expect(decision.effect != .manualHold)
    }

    @Test("no evidence is silence, not a vote")
    func noEvidenceIsSilence() throws {
        let fixture = try ctxFixture()
        let decision = ContextFusion.evaluate(
            fixture.bus, atTicks: 1010, manualHold: nil, now: ctxNow(), mode: .suggest,
        )
        #expect(decision.effect == .none)
        #expect(decision.effectiveVotes == 0)
        #expect(decision.suggestion == nil)
        #expect(decision.wouldHaveSuggested == false)
    }

    @Test("expired manual hold stops outranking")
    func expiredManualHoldStopsOutranking() throws {
        var fixture = try ctxFixture()
        let app = try ctxProposal(source: .frontmostApp, groupCode: "bundle-app")
        let focus = try ctxProposal(source: .focusFilter, groupCode: "focus-filter")
        #expect(ctxAdmit(fixture: &fixture, proposal: app) == .admitted)
        #expect(ctxAdmit(fixture: &fixture, proposal: focus) == .admitted)
        let expired = ManualContextHold(
            mode: .timedFocus,
            startedAt: ctxNow(100),
            expiresAt: ctxNow(200),
        )
        let decision = ContextFusion.evaluate(
            fixture.bus, atTicks: 1010, manualHold: expired, now: ctxNow(), mode: .suggest,
        )
        #expect(decision.effect == .suggest)
        #expect(decision.manualMode == nil)
    }
}
