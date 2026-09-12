import Foundation
import Testing
@testable import Domain

/// Story 3.3 fusion tests (F1–F8 fix pass).
///
/// Fusion accepts a bus, never caller-built atoms: candidates re-validate
/// stamped provenance against the bus-held authority, so post-admit
/// revocation and expiry un-vote. Per-bus minted sequences mean cross-bus
/// convergence is verdict-level (reading, confidence, groups,
/// representative content) — never ID-level.
private let fuseDeviceA = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000faa001")!)
private let fuseEpochA = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000efaa001")!)

private struct FusionFixture {
    var bus: EvidenceBus
    var presenceLease: SensingProviderLease
    var motionLease: SensingProviderLease
    var ambientLease: SensingProviderLease
    var hardwareLease: SensingProviderLease
}

private func fusionFixture(capacity: Int = 8) throws -> FusionFixture {
    var authority = SensingLeaseAuthority()
    func issue(_ provider: SensingProviderID) throws -> SensingProviderLease {
        try authority.issue(
            provider: provider,
            epoch: fuseEpochA,
            device: fuseDeviceA,
            lifetimeSeconds: 60,
            atTicks: 1000,
        )
    }
    let presence = try issue(.fakePresence)
    let motion = try issue(.fakeMotion)
    let ambient = try issue(.fakeAmbient)
    let hardware = try issue(.motionHardware)
    return FusionFixture(
        bus: EvidenceBus(capacity: capacity, authority: authority),
        presenceLease: presence,
        motionLease: motion,
        ambientLease: ambient,
        hardwareLease: hardware,
    )
}

private func fuseProposal(
    reading: EvidenceReading = .present,
    quality: EvidenceQuality = .full,
    confidence: EvidenceConfidence = .medium,
    coverage: EvidenceCoverage = .full,
    group: EvidenceIndependenceGroup = .fakeAlpha,
    source: EvidenceSource = .fakePresence,
    observed: TimeInterval = 1000,
    ttl: TimeInterval = 60,
) throws -> EvidenceProposal {
    try EvidenceProposal(
        kind: .presence,
        source: source,
        reading: reading,
        quality: quality,
        confidence: confidence,
        coverage: coverage,
        independenceGroup: group,
        observedTicks: observed,
        timeToLiveSeconds: ttl,
    )
}

private func fuseAdmit(
    fixture: inout FusionFixture,
    proposal: EvidenceProposal,
    atTicks ticks: TimeInterval = 1010,
) -> EvidenceAdmission {
    let lease: SensingProviderLease = switch proposal.source {
    case .fakePresence: fixture.presenceLease
    case .fakeMotion: fixture.motionLease
    case .fakeAmbient: fixture.ambientLease
    case .motionHardware: fixture.hardwareLease
    }
    return fixture.bus.admit(
        proposal,
        lease: lease,
        for: proposal.source.providerID,
        originRevision: 0,
        epoch: fuseEpochA,
        presentingDeviceID: fuseDeviceA,
        atTicks: ticks,
    )
}

private func fuseReading(fixture: FusionFixture, atTicks ticks: TimeInterval = 1010) -> FusedAssessment {
    EvidenceFusion.fuse(fixture.bus, kind: .presence, atTicks: ticks)
}

/// Verdict-level signature: everything deterministic except the per-bus
/// minted sequence, which is intentionally excluded.
private func stableSignature(_ assessment: FusedAssessment) -> String {
    var signature = "reading=\(assessment.reading) confidence=\(assessment.confidence) groups=\(assessment.supportingGroups)"
    if let representative = assessment.representative {
        signature += " rep=\(representative.kind)|\(representative.source)|\(representative.reading)|\(representative.quality)|\(representative.confidence)|\(representative.coverage)|\(representative.independenceGroup.code)|\(representative.expiryTicks)"
    } else {
        signature += " rep=nil"
    }
    return signature
}

/// All admission orders of the proposals: fusion must converge on one
/// verdict-level result.
private func proposalPermutations(_ proposals: [EvidenceProposal]) -> [[EvidenceProposal]] {
    guard proposals.count > 1 else { return [proposals] }
    var result: [[EvidenceProposal]] = []
    for (index, proposal) in proposals.enumerated() {
        var rest = proposals
        rest.remove(at: index)
        for tail in proposalPermutations(rest) {
            result.append([proposal] + tail)
        }
    }
    return result
}

private func fuseOrdering(
    _ ordering: [EvidenceProposal],
    atTicks ticks: TimeInterval = 1010,
) throws -> FusedAssessment {
    var fixture = try fusionFixture()
    for proposal in ordering {
        #expect(fuseAdmit(fixture: &fixture, proposal: proposal) == .admitted)
    }
    return fuseReading(fixture: fixture, atTicks: ticks)
}

@Suite("Evidence fusion: determinism, contradiction, and correlation caps")
struct EvidenceFusionTests {
    @Test("Shuffled admission orders converge on one fused verdict")
    func shuffledInputsConverge() throws {
        let proposals = try [
            fuseProposal(confidence: .high, group: .fakeAlpha),
            fuseProposal(confidence: .medium, group: .fakeAlpha),
            fuseProposal(confidence: .medium, group: .fakeBeta),
            fuseProposal(confidence: .low, group: .fakeGamma),
        ]
        let baseline = try fuseOrdering(proposals)
        #expect(baseline.reading == .present)
        #expect(baseline.confidence == .high)
        #expect(baseline.supportingGroups == 3)
        let baselineSignature = stableSignature(baseline)
        for ordering in proposalPermutations(proposals) {
            #expect(try stableSignature(fuseOrdering(ordering)) == baselineSignature)
        }
    }

    @Test("Contradiction across independent groups yields Unknown with reason")
    func contradictionYieldsUnknown() throws {
        let proposals = try [
            fuseProposal(reading: .present, confidence: .high, group: .fakeAlpha),
            fuseProposal(reading: .absent, confidence: .high, group: .fakeBeta),
        ]
        let baseline = try fuseOrdering(proposals)
        #expect(baseline.reading == .unknown(.contradictory))
        // A contradiction pins confidence at the floor: never averaged lies.
        #expect(baseline.confidence == .low)
        #expect(baseline.representative == nil)
        let baselineSignature = stableSignature(baseline)
        for ordering in proposalPermutations(proposals) {
            #expect(try stableSignature(fuseOrdering(ordering)) == baselineSignature)
        }
    }

    @Test("One dissenter still contradicts; intra-group opposition does not")
    func dissenterScope() throws {
        var fixture = try fusionFixture()
        #expect(try fuseAdmit(fixture: &fixture, proposal: fuseProposal(reading: .present, group: .fakeAlpha)) ==
            .admitted)
        #expect(try fuseAdmit(fixture: &fixture, proposal: fuseProposal(reading: .present, group: .fakeBeta)) ==
            .admitted)
        #expect(try fuseAdmit(fixture: &fixture, proposal: fuseProposal(reading: .absent, group: .fakeGamma)) ==
            .admitted)
        #expect(fuseReading(fixture: fixture).reading == .unknown(.contradictory))

        // Opposing readings inside ONE group resolve to a single
        // representative: correlated signals vote once, never contradict.
        let intraGroup = try [
            fuseProposal(reading: .present, confidence: .high, group: .fakeAlpha),
            fuseProposal(reading: .absent, confidence: .low, group: .fakeAlpha),
        ]
        let baseline = try fuseOrdering(intraGroup)
        #expect(baseline.reading == .present)
        #expect(baseline.confidence == .high)
        #expect(baseline.supportingGroups == 1)
        let baselineSignature = stableSignature(baseline)
        for ordering in proposalPermutations(intraGroup) {
            #expect(try stableSignature(fuseOrdering(ordering)) == baselineSignature)
        }
    }

    @Test("Same-group signals never inflate past their max")
    func sameGroupNonInflation() throws {
        let single = try fuseOrdering([fuseProposal(confidence: .high, group: .fakeAlpha)])
        let pair = try fuseOrdering([
            fuseProposal(confidence: .high, group: .fakeAlpha),
            fuseProposal(confidence: .medium, group: .fakeAlpha),
        ])
        let triple = try fuseOrdering([
            fuseProposal(confidence: .high, group: .fakeAlpha),
            fuseProposal(confidence: .medium, group: .fakeAlpha),
            fuseProposal(confidence: .high, group: .fakeAlpha),
        ])
        // The second (and third) same-group signal adds nothing beyond the max.
        #expect(stableSignature(pair) == stableSignature(single))
        #expect(stableSignature(triple) == stableSignature(single))
        #expect(single.confidence == .high)
        #expect(single.supportingGroups == 1)
    }

    @Test("Missing, stale, denied, and degraded inputs read as Unknown, never negative")
    func unknownNeverNegative() throws {
        let empty = try fusionFixture()
        #expect(fuseReading(fixture: empty).reading == .unknown(.missing))

        var staleFixture = try fusionFixture()
        #expect(try fuseAdmit(fixture: &staleFixture, proposal: fuseProposal(observed: 1000, ttl: 10), atTicks: 1005) ==
            .admitted)
        #expect(fuseReading(fixture: staleFixture, atTicks: 1010).reading == .unknown(.stale))

        var degradedFixture = try fusionFixture()
        #expect(
            try fuseAdmit(fixture: &degradedFixture, proposal: fuseProposal(quality: .degraded, confidence: .high)) ==
                .admitted,
        )
        let degraded = fuseReading(fixture: degradedFixture)
        #expect(degraded.reading == .unknown(.degraded))
        #expect(degraded.confidence == .low)

        var deniedFixture = try fusionFixture()
        #expect(try fuseAdmit(fixture: &deniedFixture, proposal: fuseProposal(quality: .denied, confidence: .high)) ==
            .admitted)
        #expect(fuseReading(fixture: deniedFixture).reading == .unknown(.denied))

        // Denied outranks degraded in the closed Unknown precedence table.
        var mixedFixture = try fusionFixture()
        #expect(try fuseAdmit(fixture: &mixedFixture, proposal: fuseProposal(quality: .degraded, group: .fakeAlpha)) ==
            .admitted)
        #expect(try fuseAdmit(fixture: &mixedFixture, proposal: fuseProposal(quality: .denied, group: .fakeBeta)) ==
            .admitted)
        #expect(fuseReading(fixture: mixedFixture).reading == .unknown(.denied))

        // A denied signal is the absence of information: it neither votes
        // nor contradicts a qualified verdict.
        var qualifiedFixture = try fusionFixture()
        #expect(
            try fuseAdmit(fixture: &qualifiedFixture, proposal: fuseProposal(reading: .absent, group: .fakeAlpha)) ==
                .admitted,
        )
        #expect(try fuseAdmit(
            fixture: &qualifiedFixture,
            proposal: fuseProposal(reading: .present, quality: .denied, confidence: .high, group: .fakeBeta),
        ) == .admitted)
        #expect(fuseReading(fixture: qualifiedFixture).reading == .absent)
    }

    @Test("Denied outranks degraded inside one group")
    func deniedOutranksDegradedInGroup() throws {
        let degradedFirst = try [
            fuseProposal(quality: .degraded, group: .fakeAlpha),
            fuseProposal(quality: .denied, group: .fakeAlpha),
        ]
        let deniedFirst = try [
            fuseProposal(quality: .denied, group: .fakeAlpha),
            fuseProposal(quality: .degraded, group: .fakeAlpha),
        ]
        // Representative rank mirrors the Unknown precedence (F8): the
        // group counts as denied whichever order it arrived in.
        #expect(try fuseOrdering(degradedFirst).reading == .unknown(.denied))
        #expect(try stableSignature(fuseOrdering(deniedFirst)) == stableSignature(fuseOrdering(degradedFirst)))
    }

    @Test("Among agreeing independents the fresher representative is preferred")
    func freshnessWeightedPreference() throws {
        var fixture = try fusionFixture()
        let staler = try fuseProposal(confidence: .medium, group: .fakeAlpha, observed: 1000, ttl: 60)
        let fresher = try fuseProposal(confidence: .medium, group: .fakeBeta, observed: 1005, ttl: 60)
        #expect(fuseAdmit(fixture: &fixture, proposal: staler) == .admitted)
        #expect(fuseAdmit(fixture: &fixture, proposal: fresher) == .admitted)
        let fused = fuseReading(fixture: fixture)
        #expect(fused.reading == .present)
        #expect(fused.confidence == .medium)
        #expect(fused.supportingGroups == 2)
        let fresherAtom = fixture.bus.live(atTicks: 1010).first { $0.independenceGroup == .fakeBeta }
        #expect(fused.representative == fresherAtom)

        let swapped = try fuseOrdering([fresher, staler])
        #expect(stableSignature(swapped) == stableSignature(fused))

        // Confidence dominates: freshness only breaks ties among equals.
        var rankedFixture = try fusionFixture()
        let highStale = try fuseProposal(confidence: .high, group: .fakeAlpha, observed: 1000, ttl: 60)
        let mediumFresh = try fuseProposal(confidence: .medium, group: .fakeBeta, observed: 1005, ttl: 60)
        #expect(fuseAdmit(fixture: &rankedFixture, proposal: highStale) == .admitted)
        #expect(fuseAdmit(fixture: &rankedFixture, proposal: mediumFresh) == .admitted)
        let ranked = fuseReading(fixture: rankedFixture)
        #expect(ranked.confidence == .high)
        let highAtom = rankedFixture.bus.live(atTicks: 1010).first { $0.independenceGroup == .fakeAlpha }
        #expect(ranked.representative == highAtom)
    }

    @Test("Admitted atoms carry full provenance; revocation un-votes at fusion")
    func revocationUnvotesAtFusion() throws {
        var fixture = try fusionFixture()
        #expect(try fuseAdmit(fixture: &fixture, proposal: fuseProposal()) == .admitted)
        #expect(fuseReading(fixture: fixture).reading == .present)

        // Provenance is bus-stamped: lease identity, provider, revision,
        // epoch, device, and admission ticks.
        let stored = fixture.bus.live(atTicks: 1010)[0]
        #expect(stored.provenance.lease == fixture.presenceLease)
        #expect(stored.provenance.provider == .fakePresence)
        #expect(stored.provenance.originRevision == 0)
        #expect(stored.provenance.epoch == fuseEpochA)
        #expect(stored.provenance.presentingDeviceID == fuseDeviceA)
        #expect(stored.provenance.admittedTicks == 1010)

        // Post-admit revocation un-votes: storage is untouched (still 1
        // live by TTL), but fusion sees no votable evidence.
        fixture.bus.revoke(fixture.presenceLease)
        #expect(fixture.bus.live(atTicks: 1010).count == 1)
        #expect(fuseReading(fixture: fixture).reading == .unknown(.stale))
    }

    @Test("Lease expiry un-votes long-lived atoms at fusion")
    func leaseExpiryUnvotesAtFusion() throws {
        var fixture = try fusionFixture()
        #expect(try fuseAdmit(fixture: &fixture, proposal: fuseProposal(observed: 1000, ttl: 300)) == .admitted)
        #expect(fuseReading(fixture: fixture, atTicks: 1010).reading == .present)
        // The atom is TTL-live until tick 1300, but its lease expires at
        // 1060: provenance re-validation un-votes it past lease expiry.
        #expect(fuseReading(fixture: fixture, atTicks: 1070).reading == .unknown(.stale))
    }

    @Test("Spoof-split group casings fuse as one vote")
    func spoofSplitCountsOnce() throws {
        var fixture = try fusionFixture()
        #expect(try fuseAdmit(
            fixture: &fixture,
            proposal: fuseProposal(confidence: .high, group: EvidenceIndependenceGroup(code: "Frame-A")),
        ) == .admitted)
        #expect(try fuseAdmit(
            fixture: &fixture,
            proposal: fuseProposal(confidence: .high, group: EvidenceIndependenceGroup(code: " frame-a ")),
        ) == .admitted)
        let fused = fuseReading(fixture: fixture)
        #expect(fused.reading == .present)
        #expect(fused.confidence == .high)
        #expect(fused.supportingGroups == 1)
    }

    @Test("Assessment debug output is redacted to verdict and group count")
    func assessmentRedactionPinsExact() throws {
        var fixture = try fusionFixture()
        #expect(try fuseAdmit(fixture: &fixture, proposal: fuseProposal(group: .fakeAlpha)) == .admitted)
        #expect(try fuseAdmit(fixture: &fixture, proposal: fuseProposal(group: .fakeBeta)) == .admitted)
        #expect(fuseReading(fixture: fixture)
            .debugDescription == "FusedAssessment(reading: present, supportingGroups: 2)")

        var conflictFixture = try fusionFixture()
        #expect(
            try fuseAdmit(fixture: &conflictFixture, proposal: fuseProposal(reading: .present, group: .fakeAlpha)) ==
                .admitted,
        )
        #expect(try fuseAdmit(fixture: &conflictFixture, proposal: fuseProposal(reading: .absent, group: .fakeBeta)) ==
            .admitted)
        let conflictDescription = fuseReading(fixture: conflictFixture).debugDescription
        #expect(conflictDescription.contains("unknown("))
        #expect(conflictDescription.contains("contradictory"))
        #expect(conflictDescription.contains("supportingGroups: 2"))
        #expect(!conflictDescription.contains("confidence"))
        #expect(!conflictDescription.contains("representative"))
    }
}
