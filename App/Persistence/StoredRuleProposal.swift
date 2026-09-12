import Foundation
import SwiftData

/// Sanitized rule-proposal row (Epic 13 R1).
///
/// One row per proposal with a versioned payload blob decoded by the Domain
/// codec. Additive-only: this model is new, so no existing row changes.
/// The row identifier is the retained proposal identifier. A separate seam
/// beside the six ledgers — never a seventh ledger row.
@Model
final class StoredRuleProposal {
    @Attribute(.unique) var id: UUID
    var schemaVersion: Int
    var recordedAt: Date
    var payload: Data

    init(id: UUID, schemaVersion: Int, recordedAt: Date, payload: Data) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.recordedAt = recordedAt
        self.payload = payload
    }
}
