import Domain
import Foundation
import SwiftData

typealias SwiftDataSettingsStore = SwiftDataProtocolStore

protocol ProtocolRuntimeSettingsStore {
    func resolve(_ preferences: AppPreferences) throws -> ResolvedAppPreferences
    @discardableResult
    func commitPreferences(
        _ preferences: ResolvedAppPreferences,
        state: ProtocolState,
    ) async throws -> Int
    func deleteHistory() async throws
    func resetAll(state: ProtocolState) async throws -> ResolvedAppPreferences
}

extension SwiftDataProtocolStore: AppPreferencesStore, ProtocolRuntimeSettingsStore {
    func loadPreferences() async throws -> AppPreferences? {
        try await loadResolvedPreferences().preferences
    }

    func loadResolvedPreferences() async throws -> ResolvedAppPreferences {
        do {
            try removeLegacyHarnessItems()
            if let stored = try fetchStoredPreferences() {
                let resolved = try resolvedPreferences(from: stored)
                try pruneStoredHistory(
                    policy: resolved.preferences.historyRetention,
                    asOf: now(),
                )
                try saveContext()
                return resolved
            }
            let migrated = try legacyResolvedPreferences()
            try upsertPreferences(migrated)
            try pruneStoredHistory(
                policy: migrated.preferences.historyRetention,
                asOf: now(),
            )
            try saveContext()
            return migrated
        } catch {
            context.rollback()
            throw error
        }
    }

    func savePreferences(_ preferences: AppPreferences) async throws {
        _ = try await saveResolvedPreferences(preferences)
    }

    @discardableResult
    func saveResolvedPreferences(
        _ preferences: AppPreferences,
    ) async throws -> ResolvedAppPreferences {
        guard try fetchStoredState() == nil else {
            throw SettingsPersistenceError.runtimeStateRequiresAtomicCommit
        }
        let resolved = try resolve(preferences)
        do {
            try upsertPreferences(resolved)
            try pruneStoredHistory(
                policy: resolved.preferences.historyRetention,
                asOf: now(),
            )
            try saveContext()
            return resolved
        } catch {
            context.rollback()
            throw error
        }
    }

    func deletePreferences() async throws {
        do {
            guard try fetchStoredState() == nil else {
                throw SettingsPersistenceError.runtimeStateRequiresAtomicCommit
            }
            guard let stored = try fetchStoredPreferences() else { return }
            context.delete(stored)
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func resolve(_ preferences: AppPreferences) throws -> ResolvedAppPreferences {
        if let stored = try fetchStoredPreferences() {
            let retained = try resolvedPreferences(from: stored)
            if retained.preferences.schedule.profile == preferences.schedule.profile {
                return ResolvedAppPreferences(
                    preferences: preferences,
                    configuration: preferences.protocolConfiguration(
                        applyingTo: retained.configuration,
                    ),
                )
            }
        }
        return try SettingsPreferenceResolver.resolve(preferences)
    }

    @discardableResult
    func commitPreferences(
        _ preferences: ResolvedAppPreferences,
        state: ProtocolState,
    ) async throws -> Int {
        guard preferences.profileID == state.profileID else {
            throw SettingsPersistenceError.profileStateMismatch
        }
        do {
            try upsertPreferences(preferences)
            try upsert(state)
            let retainedHistoryCount = try pruneStoredHistory(
                policy: preferences.preferences.historyRetention,
                asOf: now(),
            )
            try saveContext()
            return retainedHistoryCount
        } catch {
            context.rollback()
            throw error
        }
    }

    func pruneHistory() async throws {
        do {
            let preferences = try await loadResolvedPreferences().preferences
            try pruneStoredHistory(policy: preferences.historyRetention, asOf: now())
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteHistory() async throws {
        do {
            for event in try context.fetch(FetchDescriptor<StoredOpportunityEvent>()) {
                context.delete(event)
            }
            for run in try context.fetch(FetchDescriptor<StoredEstimatedActiveUseRun>()) {
                context.delete(run)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func retainedHistoryCount() async throws -> Int {
        try await loadEvents().count
    }

    func resetAll(state: ProtocolState) async throws -> ResolvedAppPreferences {
        let defaults = try SettingsPreferenceResolver.resolve(.defaults)
        guard state.profileID == defaults.profileID else {
            throw SettingsPersistenceError.profileStateMismatch
        }
        do {
            for event in try context.fetch(FetchDescriptor<StoredOpportunityEvent>()) {
                context.delete(event)
            }
            for run in try context.fetch(FetchDescriptor<StoredEstimatedActiveUseRun>()) {
                context.delete(run)
            }
            for item in try context.fetch(FetchDescriptor<StoredItem>()) {
                context.delete(item)
            }
            if let storedState = try fetchStoredState() {
                context.delete(storedState)
            }
            if let storedPreferences = try fetchStoredPreferences() {
                context.delete(storedPreferences)
            }
            try upsertPreferences(defaults)
            try upsert(state)
            try saveContext()
            return defaults
        } catch {
            context.rollback()
            throw error
        }
    }

    func exportHistory(request: HistoryExportRequest) async throws -> Data {
        let events = try await loadEvents()
        let projection = HistoryExport.project(events: events, fields: request.fields)
        switch request.format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            var data = try encoder.encode(projection)
            data.append(0x0A)
            return data
        case .csv:
            return Data(csv(projection).utf8)
        }
    }
}

private extension SwiftDataProtocolStore {
    static var settingsSchemaVersion: Int { 1 }
    static var settingsKey: String { "current" }

    func removeLegacyHarnessItems() throws {
        for item in try context.fetch(FetchDescriptor<StoredItem>()) {
            context.delete(item)
        }
    }

    func fetchStoredPreferences() throws -> StoredAppPreferences? {
        let key = Self.settingsKey
        let descriptor = FetchDescriptor<StoredAppPreferences>(
            predicate: #Predicate { $0.key == key },
        )
        return try context.fetch(descriptor).first
    }

    func fetchStoredState() throws -> StoredProtocolState? {
        let key = "current"
        let descriptor = FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        )
        return try context.fetch(descriptor).first
    }

    func resolvedPreferences(from stored: StoredAppPreferences) throws -> ResolvedAppPreferences {
        guard stored.schemaVersion == Self.settingsSchemaVersion else {
            throw SettingsPersistenceError.unsupportedSchemaVersion(stored.schemaVersion)
        }
        return try ResolvedAppPreferences(
            preferences: SettingsPayloadCodec.decodePreferences(stored.preferencesPayload),
            configuration: SettingsPayloadCodec.decodeConfiguration(stored.configurationPayload),
        )
    }

    func legacyResolvedPreferences() throws -> ResolvedAppPreferences {
        let profileID = try fetchStoredState()
            .flatMap { ProtocolProfileID(rawValue: $0.profileID) }
            .flatMap { ProtocolProfileID.builtInCases.contains($0) ? $0 : nil }
            ?? .balanced
        let profile: ScheduleProfile = switch profileID {
        case .gentle: .gentle
        case .balanced: .balanced
        case .frequentMovement: .frequentMovement
        case .researchInformedHighFrequency: .researchInformedHighFrequency
        case .custom: .balanced
        }
        let preferences = AppPreferences(schedule: SchedulePreferences(profile: profile))
        return try resolve(preferences)
    }

    func upsertPreferences(_ resolved: ResolvedAppPreferences) throws {
        let preferencesPayload = try SettingsPayloadCodec.encode(resolved.preferences)
        let configurationPayload = try SettingsPayloadCodec.encode(resolved.configuration)
        if let stored = try fetchStoredPreferences() {
            stored.update(
                preferencesPayload: preferencesPayload,
                configurationPayload: configurationPayload,
            )
        } else {
            context.insert(StoredAppPreferences(
                key: Self.settingsKey,
                schemaVersion: Self.settingsSchemaVersion,
                preferencesPayload: preferencesPayload,
                configurationPayload: configurationPayload,
            ))
        }
    }

    func csv(_ export: HistoryExport) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let header = export.fields.map(\.rawValue).joined(separator: ",")
        let rows = export.records.map { record in
            export.fields.map { field in
                switch field {
                case .id:
                    record.id.uuidString.lowercased()
                case .recordedAt:
                    formatter.string(from: record.recordedAt)
                case .kind:
                    record.kind
                case .source:
                    record.source
                case .opportunity:
                    record.opportunity ?? ""
                case .selectedDurationSeconds:
                    record.selectedDurationSeconds.map(stableNumber) ?? ""
                }
            }.joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    func stableNumber(_ value: TimeInterval) -> String {
        if let exactInteger = Int(exactly: value) {
            return String(exactInteger)
        }
        return String(value)
    }
}
