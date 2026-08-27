import Foundation
import SwiftData

@Model
final class StoredAppPreferences {
    @Attribute(.unique) var key: String
    var schemaVersion: Int
    var preferencesPayload: Data
    var configurationPayload: Data

    init(
        key: String,
        schemaVersion: Int,
        preferencesPayload: Data,
        configurationPayload: Data,
    ) {
        self.key = key
        self.schemaVersion = schemaVersion
        self.preferencesPayload = preferencesPayload
        self.configurationPayload = configurationPayload
    }

    func update(preferencesPayload: Data, configurationPayload: Data) {
        self.preferencesPayload = preferencesPayload
        self.configurationPayload = configurationPayload
    }
}
