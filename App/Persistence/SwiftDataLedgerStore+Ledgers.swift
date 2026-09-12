import Domain
import Foundation
import SwiftData

/// Ledger store continuation (story 5): correction, consent-receipt, and
/// companion-action ledgers plus the whole-ledger delete and the shared
/// version/retention/export helpers used by every ledger.
extension SwiftDataLedgerStore {
    // MARK: - Correction

    func appendCorrection(_ record: LedgerCorrectionRecord) async throws {
        do {
            guard retention(for: .correction) != .keepNothing else { return }
            let rows = try context.fetch(FetchDescriptor<StoredLedgerCorrection>())
            if let existing = rows.first(where: { $0.id == record.id }) {
                try Self.checkRowVersion(existing.schemaVersion, ledger: .correction)
                let decoded = try LedgerCorrectionCodec.decode(existing.payload)
                guard decoded == record else {
                    throw LedgerStoreError.conflictingRecord(id: record.id)
                }
                try saveContext()
                return
            }
            var retained: [LedgerCorrectionRecord] = []
            for row in rows {
                try Self.checkRowVersion(row.schemaVersion, ledger: .correction)
                retained.append(try LedgerCorrectionCodec.decode(row.payload))
            }
            try InMemoryLedgerCorrectionStore.checkFrontier(record, against: retained)
            context.insert(StoredLedgerCorrection(
                id: record.id,
                schemaVersion: LedgerCorrectionCodec.schemaVersion,
                recordedAt: record.recordedAt,
                payload: try LedgerCorrectionCodec.encode(record),
            ))
            try pruneCorrections(asOf: now(), policy: retention(for: .correction))
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadCorrections() async throws -> [LedgerCorrectionRecord] {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredLedgerCorrection>())
            var records: [(StoredLedgerCorrection, LedgerCorrectionRecord)] = []
            for row in rows {
                try Self.checkRowVersion(row.schemaVersion, ledger: .correction)
                records.append((row, try LedgerCorrectionCodec.decode(row.payload)))
            }
            try pruneLoaded(records.map(\.0), policy: retention(for: .correction), asOf: now(), recordedAt: \.recordedAt)
            try saveContext()
            let policy = retention(for: .correction)
            let moment = now()
            return Self.ordered(
                records.map(\.1).filter { Self.isLive(recordedAt: $0.recordedAt, policy: policy, asOf: moment) },
                by: { ($0.recordedAt, $0.id.uuidString) },
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteCorrections() async throws {
        do {
            for row in try context.fetch(FetchDescriptor<StoredLedgerCorrection>()) {
                context.delete(row)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func purgeCorrections(asOf date: Date) async -> Int {
        do {
            let removed = try purgeRows(
                FetchDescriptor<StoredLedgerCorrection>(),
                policy: retention(for: .correction),
                asOf: date,
                recordedAt: \.recordedAt,
            )
            try saveContext()
            return removed
        } catch {
            context.rollback()
            return 0
        }
    }

    func exportCorrections(
        selected: LedgerExportSelection<LedgerCorrectionExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let records = try await loadCorrections()
        let columns = selected.fields.map(\.rawValue)
        let rows = records.map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        return try Self.exportData(ledger: .correction, columns: columns, rows: rows, format: format)
    }

    // MARK: - Consent receipt

    func appendConsentReceipt(_ record: LedgerConsentReceiptRecord) async throws {
        do {
            guard retention(for: .consentReceipt) != .keepNothing else { return }
            let rows = try context.fetch(FetchDescriptor<StoredLedgerConsentReceipt>())
            if let existing = rows.first(where: { $0.id == record.id }) {
                try Self.checkRowVersion(existing.schemaVersion, ledger: .consentReceipt)
                let decoded = try LedgerConsentReceiptCodec.decode(existing.payload)
                guard decoded == record else {
                    throw LedgerStoreError.conflictingRecord(id: record.id)
                }
                try saveContext()
                return
            }
            var retained: [LedgerConsentReceiptRecord] = []
            for row in rows {
                try Self.checkRowVersion(row.schemaVersion, ledger: .consentReceipt)
                retained.append(try LedgerConsentReceiptCodec.decode(row.payload))
            }
            try InMemoryLedgerConsentReceiptStore.checkFrontier(record, against: retained)
            context.insert(StoredLedgerConsentReceipt(
                id: record.id,
                schemaVersion: LedgerConsentReceiptCodec.schemaVersion,
                recordedAt: record.recordedAt,
                payload: try LedgerConsentReceiptCodec.encode(record),
            ))
            try pruneConsentReceipts(asOf: now(), policy: retention(for: .consentReceipt))
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadConsentReceipts() async throws -> [LedgerConsentReceiptRecord] {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredLedgerConsentReceipt>())
            var records: [(StoredLedgerConsentReceipt, LedgerConsentReceiptRecord)] = []
            for row in rows {
                try Self.checkRowVersion(row.schemaVersion, ledger: .consentReceipt)
                records.append((row, try LedgerConsentReceiptCodec.decode(row.payload)))
            }
            try pruneLoaded(records.map(\.0), policy: retention(for: .consentReceipt), asOf: now(), recordedAt: \.recordedAt)
            try saveContext()
            let policy = retention(for: .consentReceipt)
            let moment = now()
            return Self.ordered(
                records.map(\.1).filter { Self.isLive(recordedAt: $0.recordedAt, policy: policy, asOf: moment) },
                by: { ($0.recordedAt, $0.id.uuidString) },
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteConsentReceipts() async throws {
        do {
            for row in try context.fetch(FetchDescriptor<StoredLedgerConsentReceipt>()) {
                context.delete(row)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func purgeConsentReceipts(asOf date: Date) async -> Int {
        do {
            let removed = try purgeRows(
                FetchDescriptor<StoredLedgerConsentReceipt>(),
                policy: retention(for: .consentReceipt),
                asOf: date,
                recordedAt: \.recordedAt,
            )
            try saveContext()
            return removed
        } catch {
            context.rollback()
            return 0
        }
    }

    func exportConsentReceipts(
        selected: LedgerExportSelection<LedgerConsentReceiptExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let records = try await loadConsentReceipts()
        let columns = selected.fields.map(\.rawValue)
        let rows = records.map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        return try Self.exportData(ledger: .consentReceipt, columns: columns, rows: rows, format: format)
    }

    // MARK: - Companion action

    func appendCompanionAction(_ record: LedgerCompanionActionRecord) async throws {
        do {
            guard retention(for: .companionAction) != .keepNothing else { return }
            let rows = try context.fetch(FetchDescriptor<StoredLedgerCompanionAction>())
            if let existing = rows.first(where: { $0.id == record.id }) {
                try Self.checkRowVersion(existing.schemaVersion, ledger: .companionAction)
                let decoded = try LedgerCompanionActionCodec.decode(existing.payload)
                guard decoded == record else {
                    throw LedgerStoreError.conflictingRecord(id: record.id)
                }
                try saveContext()
                return
            }
            context.insert(StoredLedgerCompanionAction(
                id: record.id,
                schemaVersion: LedgerCompanionActionCodec.schemaVersion,
                recordedAt: record.recordedAt,
                payload: try LedgerCompanionActionCodec.encode(record),
            ))
            try pruneCompanionActions(asOf: now(), policy: retention(for: .companionAction))
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadCompanionActions() async throws -> [LedgerCompanionActionRecord] {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredLedgerCompanionAction>())
            var records: [(StoredLedgerCompanionAction, LedgerCompanionActionRecord)] = []
            for row in rows {
                try Self.checkRowVersion(row.schemaVersion, ledger: .companionAction)
                records.append((row, try LedgerCompanionActionCodec.decode(row.payload)))
            }
            try pruneLoaded(records.map(\.0), policy: retention(for: .companionAction), asOf: now(), recordedAt: \.recordedAt)
            try saveContext()
            let policy = retention(for: .companionAction)
            let moment = now()
            return Self.ordered(
                records.map(\.1).filter { Self.isLive(recordedAt: $0.recordedAt, policy: policy, asOf: moment) },
                by: { ($0.recordedAt, $0.id.uuidString) },
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteCompanionActions() async throws {
        do {
            for row in try context.fetch(FetchDescriptor<StoredLedgerCompanionAction>()) {
                context.delete(row)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func purgeCompanionActions(asOf date: Date) async -> Int {
        do {
            let removed = try purgeRows(
                FetchDescriptor<StoredLedgerCompanionAction>(),
                policy: retention(for: .companionAction),
                asOf: date,
                recordedAt: \.recordedAt,
            )
            try saveContext()
            return removed
        } catch {
            context.rollback()
            return 0
        }
    }

    func exportCompanionActions(
        selected: LedgerExportSelection<LedgerCompanionActionExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let records = try await loadCompanionActions()
        let columns = selected.fields.map(\.rawValue)
        let rows = records.map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        return try Self.exportData(ledger: .companionAction, columns: columns, rows: rows, format: format)
    }

    // MARK: - Whole-ledger delete

    /// Deletes every ledger row. A failed save rolls back, preserving rows.
    func deleteAllLedgers() async throws {
        do {
            for row in try context.fetch(FetchDescriptor<StoredLedgerObservation>()) {
                context.delete(row)
            }
            for row in try context.fetch(FetchDescriptor<StoredLedgerAssessment>()) {
                context.delete(row)
            }
            for row in try context.fetch(FetchDescriptor<StoredLedgerPolicyDecision>()) {
                context.delete(row)
            }
            for row in try context.fetch(FetchDescriptor<StoredLedgerCorrection>()) {
                context.delete(row)
            }
            for row in try context.fetch(FetchDescriptor<StoredLedgerConsentReceipt>()) {
                context.delete(row)
            }
            for row in try context.fetch(FetchDescriptor<StoredLedgerCompanionAction>()) {
                context.delete(row)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - Shared helpers

    static func checkRowVersion(_ version: Int, ledger: LedgerKind) throws {
        guard version == 1 else {
            throw LedgerStoreError.unknownSchemaVersion(ledger: ledger.code, version: version)
        }
    }

    static func isLive(recordedAt: Date, policy: HistoryRetentionPolicy, asOf date: Date) -> Bool {
        guard policy != .keepNothing else { return false }
        return recordedAt >= date.addingTimeInterval(-policy.retentionDurationSeconds)
    }

    static func ordered<Record>(_ records: [Record], by key: (Record) -> (Date, String)) -> [Record] {
        records.sorted {
            let lhs = key($0)
            let rhs = key($1)
            if lhs.0 != rhs.0 {
                return lhs.0 < rhs.0
            }
            return lhs.1 < rhs.1
        }
    }

    static func exportData(
        ledger: LedgerKind,
        columns: [String],
        rows: [[String: String]],
        format: LedgerExportFormat,
    ) throws -> Data {
        let table = LedgerExportTable(ledger: ledger.code, fields: columns, rows: rows)
        switch format {
        case .json: return try table.jsonData()
        case .csv: return try table.csvData()
        }
    }

    func pruneLoaded<Row: PersistentModel>(
        _ rows: [Row],
        policy: HistoryRetentionPolicy,
        asOf date: Date,
        recordedAt: KeyPath<Row, Date>,
    ) throws {
        if policy == .keepNothing {
            for row in rows {
                context.delete(row)
            }
            return
        }
        let cutoff = date.addingTimeInterval(-policy.retentionDurationSeconds)
        for row in rows where row[keyPath: recordedAt] < cutoff {
            context.delete(row)
        }
    }

    func purgeRows<Row: PersistentModel>(
        _ descriptor: FetchDescriptor<Row>,
        policy: HistoryRetentionPolicy,
        asOf date: Date,
        recordedAt: KeyPath<Row, Date>,
    ) throws -> Int {
        let rows = try context.fetch(descriptor)
        let doomed: [Row]
        if policy == .keepNothing {
            doomed = rows
        } else {
            let cutoff = date.addingTimeInterval(-policy.retentionDurationSeconds)
            doomed = rows.filter { $0[keyPath: recordedAt] < cutoff }
        }
        for row in doomed {
            context.delete(row)
        }
        return doomed.count
    }

    func pruneObservations(asOf date: Date, policy: HistoryRetentionPolicy) throws {
        try pruneLoaded(
            context.fetch(FetchDescriptor<StoredLedgerObservation>()),
            policy: policy,
            asOf: date,
            recordedAt: \.recordedAt,
        )
    }

    func pruneAssessments(asOf date: Date, policy: HistoryRetentionPolicy) throws {
        try pruneLoaded(
            context.fetch(FetchDescriptor<StoredLedgerAssessment>()),
            policy: policy,
            asOf: date,
            recordedAt: \.recordedAt,
        )
    }

    func prunePolicyDecisions(asOf date: Date, policy: HistoryRetentionPolicy) throws {
        try pruneLoaded(
            context.fetch(FetchDescriptor<StoredLedgerPolicyDecision>()),
            policy: policy,
            asOf: date,
            recordedAt: \.recordedAt,
        )
    }

    func pruneCorrections(asOf date: Date, policy: HistoryRetentionPolicy) throws {
        try pruneLoaded(
            context.fetch(FetchDescriptor<StoredLedgerCorrection>()),
            policy: policy,
            asOf: date,
            recordedAt: \.recordedAt,
        )
    }

    func pruneConsentReceipts(asOf date: Date, policy: HistoryRetentionPolicy) throws {
        try pruneLoaded(
            context.fetch(FetchDescriptor<StoredLedgerConsentReceipt>()),
            policy: policy,
            asOf: date,
            recordedAt: \.recordedAt,
        )
    }

    func pruneCompanionActions(asOf date: Date, policy: HistoryRetentionPolicy) throws {
        try pruneLoaded(
            context.fetch(FetchDescriptor<StoredLedgerCompanionAction>()),
            policy: policy,
            asOf: date,
            recordedAt: \.recordedAt,
        )
    }
}
