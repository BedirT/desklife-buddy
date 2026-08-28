import Foundation
import SwiftData

@Model
final class StoredOnboardingCompletion {
    @Attribute(.unique) var key: String
    var schemaVersion: Int
    var outcome: String
    var completedAt: Date

    init(key: String, schemaVersion: Int, outcome: String, completedAt: Date) {
        self.key = key
        self.schemaVersion = schemaVersion
        self.outcome = outcome
        self.completedAt = completedAt
    }
}
