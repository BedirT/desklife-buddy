import Foundation
import SwiftData

@Model
final class StoredEstimatedActiveUseRun {
    var startedAt: Date
    var endedAt: Date

    init(startedAt: Date, endedAt: Date) {
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
