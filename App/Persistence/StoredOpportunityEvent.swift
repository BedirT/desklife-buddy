import Foundation
import SwiftData

@Model
final class StoredOpportunityEvent {
    @Attribute(.unique) var id: UUID
    var schemaVersion: Int
    var appendSequence: Int64
    var kind: String
    var recordedAt: Date
    var source: String
    var opportunity: String?
    var selectedDurationSeconds: Double?

    init(
        id: UUID,
        schemaVersion: Int,
        appendSequence: Int64,
        kind: String,
        recordedAt: Date,
        source: String,
        opportunity: String?,
        selectedDurationSeconds: Double?,
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.appendSequence = appendSequence
        self.kind = kind
        self.recordedAt = recordedAt
        self.source = source
        self.opportunity = opportunity
        self.selectedDurationSeconds = selectedDurationSeconds
    }
}
