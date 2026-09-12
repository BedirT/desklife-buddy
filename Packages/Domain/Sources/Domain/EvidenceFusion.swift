import Foundation

/// One fused verdict (Story 3.3).
///
/// Binary like the proposals, plus explicit Unknown: missing, stale,
/// denied, and degraded inputs read as Unknown with a reason — never as a
/// negative verdict, never averaged, never inflated.
public enum FusedReading: Equatable, Hashable, Sendable {
    case present
    case absent
    case unknown(EvidenceFailureReason)
}

/// The deterministic fusion result for one evidence kind (Story 3.3).
///
/// Pure non-`Codable` value: Class 0, derived in memory from bus contents,
/// never persisted. `supportingGroups` counts the qualified independent
/// groups behind the verdict; `representative` is the winning atom when
/// the verdict is binary and `nil` for every Unknown.
public struct FusedAssessment: Equatable, Hashable, Sendable {
    public let reading: FusedReading
    public let confidence: EvidenceConfidence
    public let supportingGroups: Int
    public let representative: EvidenceAtom?

    public init(
        reading: FusedReading,
        confidence: EvidenceConfidence,
        supportingGroups: Int,
        representative: EvidenceAtom?
    ) {
        self.reading = reading
        self.confidence = confidence
        self.supportingGroups = supportingGroups
        self.representative = representative
    }
}

extension FusedAssessment: CustomDebugStringConvertible {
    /// Redacted (F6): verdict and group count only. Confidence and the
    /// representative stay out of debug output with the reading payload.
    public var debugDescription: String {
        "FusedAssessment(reading: \(reading), supportingGroups: \(supportingGroups))"
    }
}

/// Deterministic evidence fusion (Story 3.3, F2/F5/F8).
///
/// Fusion accepts a bus, never caller-built atoms (F2): candidates are the
/// bus's live atoms whose stamped provenance still validates against the
/// bus-held authority at the fusion ticks, so post-admit revocation,
/// expiry, revision advance, or epoch fencing un-votes immediately.
///
/// Determinism rule: for each `(kind, independence group)` at most one
/// live provenanced representative fuses, chosen by the total order of
/// quality class ascending (full, then denied, then degraded — mirroring
/// the denied-over-degraded Unknown precedence, F8), confidence rank
/// descending, coverage rank descending, expiry tick descending, then
/// bus-minted sequence ascending (F5: no caller UUIDs, no randomness).
/// Inputs are canonically sorted before combining, so arrival order and
/// the number of atoms inside one group never change the verdict —
/// though per-bus sequences differ, so cross-bus equality is verdict-level
/// (reading, confidence, groups, representative content), never ID-level.
/// Opposing qualified independent groups produce explicit
/// `.unknown(.contradictory)`; confidence caps at the best representative
/// (a second same-group signal adds nothing); confidence dominates and
/// freshness breaks ties among equals.
public enum EvidenceFusion: Sendable {
    /// Fuses one kind from the bus at the presented monotonic ticks.
    public static func fuse(
        _ bus: EvidenceBus,
        kind: EvidenceKind,
        atTicks ticks: TimeInterval
    ) -> FusedAssessment {
        var authorityCopy = bus.authority
        let votable = bus.live(atTicks: ticks).filter {
            $0.kind == kind && isProvenanceLive($0.provenance, authority: &authorityCopy, atTicks: ticks)
        }
        guard !votable.isEmpty else {
            return FusedAssessment(
                reading: bus.containsEvidence(of: kind) ? .unknown(.stale) : .unknown(.missing),
                confidence: .low,
                supportingGroups: 0,
                representative: nil
            )
        }
        // Canonical sort before combine: one representative per
        // independence group, arrival order irrelevant.
        let ordered = votable.sorted(by: precedesRepresentative)
        var seenGroups = Set<EvidenceIndependenceGroup>()
        var representatives: [EvidenceAtom] = []
        for atom in ordered where seenGroups.insert(atom.independenceGroup).inserted {
            representatives.append(atom)
        }
        let qualified = representatives.filter { $0.quality.isQualified }
        guard !qualified.isEmpty else {
            // Closed Unknown precedence: denied outranks degraded, and
            // representative rank already prefers denied (F8), so this is
            // a backstop, never a surprise.
            if representatives.contains(where: { $0.quality == .denied }) {
                return FusedAssessment(
                    reading: .unknown(.denied),
                    confidence: .low,
                    supportingGroups: 0,
                    representative: nil
                )
            }
            return FusedAssessment(
                reading: .unknown(.degraded),
                confidence: .low,
                supportingGroups: 0,
                representative: nil
            )
        }
        let readings = Set(qualified.map(\.reading))
        guard readings.count == 1, let verdict = readings.first else {
            // Contradiction: explicit Unknown at floored confidence. The
            // count stays auditable; no average, no winner, no inflation.
            return FusedAssessment(
                reading: .unknown(.contradictory),
                confidence: .low,
                supportingGroups: qualified.count,
                representative: nil
            )
        }
        // `qualified` preserves canonical order, so the first element is
        // the total-order winner: its confidence caps the fusion.
        let winner = qualified[0]
        return FusedAssessment(
            reading: verdict == .present ? .present : .absent,
            confidence: winner.confidence,
            supportingGroups: qualified.count,
            representative: winner
        )
    }

    /// Provenance liveness at fusion ticks: the stamped lease must still
    /// validate against the bus-held frontier. Revoked, expired, outgrown,
    /// or fenced leases un-vote their atoms.
    private static func isProvenanceLive(
        _ provenance: EvidenceProvenance,
        authority: inout SensingLeaseAuthority,
        atTicks ticks: TimeInterval
    ) -> Bool {
        authority.validate(
            provenance.lease,
            for: provenance.provider,
            originRevision: provenance.originRevision,
            epoch: provenance.epoch,
            presentingDeviceID: provenance.presentingDeviceID,
            atTicks: ticks
        ) == nil
    }

    /// Total representative order: quality class ascending (full, denied,
    /// degraded), then confidence, coverage, and expiry descending, then
    /// bus-minted sequence ascending. Sequences are unique per bus, so the
    /// order is total.
    private static func precedesRepresentative(_ lhs: EvidenceAtom, _ rhs: EvidenceAtom) -> Bool {
        if lhs.quality.fusionRank != rhs.quality.fusionRank {
            return lhs.quality.fusionRank < rhs.quality.fusionRank
        }
        if lhs.confidence.rank != rhs.confidence.rank {
            return lhs.confidence.rank > rhs.confidence.rank
        }
        if lhs.coverage.rank != rhs.coverage.rank {
            return lhs.coverage.rank > rhs.coverage.rank
        }
        if lhs.expiryTicks != rhs.expiryTicks {
            return lhs.expiryTicks > rhs.expiryTicks
        }
        return lhs.id.sequence < rhs.id.sequence
    }
}
