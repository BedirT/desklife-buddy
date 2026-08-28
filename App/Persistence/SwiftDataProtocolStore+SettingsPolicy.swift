import Domain
import Foundation
import SwiftData

extension SwiftDataProtocolStore {
    func storedRetentionPolicy() throws -> HistoryRetentionPolicy {
        let key = "current"
        let descriptor = FetchDescriptor<StoredAppPreferences>(
            predicate: #Predicate { $0.key == key },
        )
        guard let stored = try context.fetch(descriptor).first else { return .thirtyDays }
        guard stored.schemaVersion == 1 else {
            throw SettingsPersistenceError.unsupportedSchemaVersion(stored.schemaVersion)
        }
        return try SettingsPayloadCodec.decodePreferences(
            stored.preferencesPayload,
        ).historyRetention
    }

    func pruneStoredHistoryIfConfigured() throws {
        _ = try pruneStoredHistory(policy: storedRetentionPolicy(), asOf: now())
    }

    @discardableResult
    func pruneStoredHistory(
        policy: HistoryRetentionPolicy,
        asOf date: Date,
    ) throws -> Int {
        let events = try context.fetch(FetchDescriptor<StoredOpportunityEvent>())
        let activeUseRuns = try context.fetch(FetchDescriptor<StoredEstimatedActiveUseRun>())
        let cutoff = date.addingTimeInterval(-policy.retentionDurationSeconds)
        var retainedCount = 0
        for event in events {
            if policy == .keepNothing || event.recordedAt < cutoff {
                context.delete(event)
            } else {
                retainedCount += 1
            }
        }
        for run in activeUseRuns {
            if policy == .keepNothing || run.endedAt <= cutoff {
                context.delete(run)
            } else if run.startedAt < cutoff {
                run.startedAt = cutoff
            }
        }
        return retainedCount
    }

    func isSupportedPersistedProfile(_ profileID: ProtocolProfileID) throws -> Bool {
        guard profileID == .custom else {
            return ProtocolProfileID.builtInCases.contains(profileID)
        }
        let key = "current"
        let descriptor = FetchDescriptor<StoredAppPreferences>(
            predicate: #Predicate { $0.key == key },
        )
        guard let stored = try context.fetch(descriptor).first,
              stored.schemaVersion == 1,
              let preferences = try? SettingsPayloadCodec.decodePreferences(
                  stored.preferencesPayload,
              )
        else {
            return false
        }
        return preferences.schedule.profile.protocolProfileID == .custom
    }

    func validateStateProfileMatchesPreferences(_ profileID: ProtocolProfileID) throws {
        let key = "current"
        let descriptor = FetchDescriptor<StoredAppPreferences>(
            predicate: #Predicate { $0.key == key },
        )
        guard let stored = try context.fetch(descriptor).first else { return }
        guard stored.schemaVersion == 1 else {
            throw SettingsPersistenceError.unsupportedSchemaVersion(stored.schemaVersion)
        }
        let preferences = try SettingsPayloadCodec.decodePreferences(stored.preferencesPayload)
        guard preferences.schedule.profile.protocolProfileID == profileID else {
            throw SettingsPersistenceError.profileStateMismatch
        }
    }
}
