import SwiftData

@Model
final class StoredProtocolState {
    @Attribute(.unique) var key: String
    var schemaVersion: Int
    var profileID: String
    var visualAccumulatedActiveUseSeconds: Double
    var movementAccumulatedActiveUseSeconds: Double

    init(
        key: String,
        schemaVersion: Int,
        profileID: String,
        visualAccumulatedActiveUseSeconds: Double,
        movementAccumulatedActiveUseSeconds: Double,
    ) {
        self.key = key
        self.schemaVersion = schemaVersion
        self.profileID = profileID
        self.visualAccumulatedActiveUseSeconds = visualAccumulatedActiveUseSeconds
        self.movementAccumulatedActiveUseSeconds = movementAccumulatedActiveUseSeconds
    }

    func update(
        profileID: String,
        visualAccumulatedActiveUseSeconds: Double,
        movementAccumulatedActiveUseSeconds: Double,
    ) {
        self.profileID = profileID
        self.visualAccumulatedActiveUseSeconds = visualAccumulatedActiveUseSeconds
        self.movementAccumulatedActiveUseSeconds = movementAccumulatedActiveUseSeconds
    }
}
