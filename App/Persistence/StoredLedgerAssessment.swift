import Foundation
import SwiftData

/// Sanitized assessment row (story 5).
///
/// One row per record with a versioned payload blob decoded by the Domain
/// codec. Additive-only: this model is new, so no existing row changes.
/// Identifiers derive from retained seeds — rows never invent identity.
@Model
final class StoredLedgerAssessment {
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
