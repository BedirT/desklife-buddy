import Domain
import Foundation
import SwiftData

/// SwiftData owner for the six versioned ledgers (story 5).
///
/// Each ledger is a separate additive-only row type holding sanitized rows
/// only (window facts, digests, receipts, lease windows, effect classes).
/// Rows carry a versioned payload blob decoded by the Domain codec:
/// unknown versions throw before any mutation, duplicate identifiers
/// replay idempotently, reused identifiers with different facts are
/// refused, and retention prunes on every write and read. Production
/// wiring arrives in stories 6-7; until then tests construct this store
/// directly.
final class SwiftDataLedgerStore {
    let container: ModelContainer
    let context: ModelContext
    let now: () -> Date
    let saveContext: () throws -> Void

    /// Per-ledger retention overrides for tests. Defaults come from the
    /// Domain retention table.
    var retentionOverrides: [LedgerKind: HistoryRetentionPolicy] = [:]

    convenience init(
        inMemory: Bool = false,
        now: @escaping () -> Date = Date.init,
        save: ((ModelContext) throws -> Void)? = nil,
    ) throws {
        try self.init(
            container: AppModelContainer.make(inMemory: inMemory),
            now: now,
            save: save,
        )
    }

    init(
        container: ModelContainer,
        now: @escaping () -> Date = Date.init,
        save: ((ModelContext) throws -> Void)? = nil,
    ) throws {
        self.container = container
        self.now = now
        let context = ModelContext(container)
        self.context = context
        saveContext = {
            if let save {
                try save(context)
            } else {
                try context.save()
            }
        }
    }

    func retention(for ledger: LedgerKind) -> HistoryRetentionPolicy {
        retentionOverrides[ledger] ?? LedgerRetention.policy(for: ledger)
    }

    // MARK: - Observation

    func appendObservation(_ record: LedgerObservationRecord) async throws {
        do {
            guard retention(for: .observation) != .keepNothing else { return }
            let rows = try context.fetch(FetchDescriptor<StoredLedgerObservation>())
            if let existing = rows.first(where: { $0.id == record.id }) {
                try Self.checkRowVersion(existing.schemaVersion, ledger: .observation)
                let decoded = try LedgerObservationCodec.decode(existing.payload)
                guard decoded == record else {
                    throw LedgerStoreError.conflictingRecord(id: record.id)
                }
                try saveContext()
                return
            }
            context.insert(StoredLedgerObservation(
                id: record.id,
                schemaVersion: LedgerObservationCodec.schemaVersion,
                recordedAt: record.recordedAt,
                payload: try LedgerObservationCodec.encode(record),
            ))
            try pruneObservations(asOf: now(), policy: retention(for: .observation))
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadObservations() async throws -> [LedgerObservationRecord] {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredLedgerObservation>())
            var records: [(StoredLedgerObservation, LedgerObservationRecord)] = []
            for row in rows {
                try Self.checkRowVersion(row.schemaVersion, ledger: .observation)
                records.append((row, try LedgerObservationCodec.decode(row.payload)))
            }
            try pruneLoaded(records.map(\.0), policy: retention(for: .observation), asOf: now(), recordedAt: \.recordedAt)
            try saveContext()
            return Self.ordered(records.compactMap { row, record in
                Self.isLive(recordedAt: record.recordedAt, policy: retention(for: .observation), asOf: now()) ? record : nil
            }, by: { ($0.recordedAt, $0.id.uuidString) })
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteObservations() async throws {
        do {
            for row in try context.fetch(FetchDescriptor<StoredLedgerObservation>()) {
                context.delete(row)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func purgeObservations(asOf date: Date) async -> Int {
        do {
            let removed = try purgeRows(
                FetchDescriptor<StoredLedgerObservation>(),
                policy: retention(for: .observation),
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

    func exportObservations(
        selected: LedgerExportSelection<LedgerObservationExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let records = try await loadObservations()
        let columns = selected.fields.map(\.rawValue)
        let rows = records.map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        return try Self.exportData(ledger: .observation, columns: columns, rows: rows, format: format)
    }

    // MARK: - Assessment

    func appendAssessment(_ record: LedgerAssessmentRecord) async throws {
        do {
            guard retention(for: .assessment) != .keepNothing else { return }
            let rows = try context.fetch(FetchDescriptor<StoredLedgerAssessment>())
            if let existing = rows.first(where: { $0.id == record.id }) {
                try Self.checkRowVersion(existing.schemaVersion, ledger: .assessment)
                let decoded = try LedgerAssessmentCodec.decode(existing.payload)
                guard decoded == record else {
                    throw LedgerStoreError.conflictingRecord(id: record.id)
                }
                try saveContext()
                return
            }
            context.insert(StoredLedgerAssessment(
                id: record.id,
                schemaVersion: LedgerAssessmentCodec.schemaVersion,
                recordedAt: record.recordedAt,
                payload: try LedgerAssessmentCodec.encode(record),
            ))
            try pruneAssessments(asOf: now(), policy: retention(for: .assessment))
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadAssessments() async throws -> [LedgerAssessmentRecord] {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredLedgerAssessment>())
            var records: [(StoredLedgerAssessment, LedgerAssessmentRecord)] = []
            for row in rows {
                try Self.checkRowVersion(row.schemaVersion, ledger: .assessment)
                records.append((row, try LedgerAssessmentCodec.decode(row.payload)))
            }
            try pruneLoaded(records.map(\.0), policy: retention(for: .assessment), asOf: now(), recordedAt: \.recordedAt)
            try saveContext()
            let policy = retention(for: .assessment)
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

    func deleteAssessments() async throws {
        do {
            for row in try context.fetch(FetchDescriptor<StoredLedgerAssessment>()) {
                context.delete(row)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func purgeAssessments(asOf date: Date) async -> Int {
        do {
            let removed = try purgeRows(
                FetchDescriptor<StoredLedgerAssessment>(),
                policy: retention(for: .assessment),
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

    func exportAssessments(
        selected: LedgerExportSelection<LedgerAssessmentExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let records = try await loadAssessments()
        let columns = selected.fields.map(\.rawValue)
        let rows = records.map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        return try Self.exportData(ledger: .assessment, columns: columns, rows: rows, format: format)
    }

    // MARK: - Policy decision

    func appendPolicyDecision(_ record: LedgerPolicyDecisionRecord) async throws {
        do {
            guard retention(for: .policyDecision) != .keepNothing else { return }
            let rows = try context.fetch(FetchDescriptor<StoredLedgerPolicyDecision>())
            if let existing = rows.first(where: { $0.id == record.id }) {
                try Self.checkRowVersion(existing.schemaVersion, ledger: .policyDecision)
                let decoded = try LedgerPolicyDecisionCodec.decode(existing.payload)
                guard decoded == record else {
                    throw LedgerStoreError.conflictingRecord(id: record.id)
                }
                try saveContext()
                return
            }
            context.insert(StoredLedgerPolicyDecision(
                id: record.id,
                schemaVersion: LedgerPolicyDecisionCodec.schemaVersion,
                recordedAt: record.recordedAt,
                payload: try LedgerPolicyDecisionCodec.encode(record),
            ))
            try prunePolicyDecisions(asOf: now(), policy: retention(for: .policyDecision))
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadPolicyDecisions() async throws -> [LedgerPolicyDecisionRecord] {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredLedgerPolicyDecision>())
            var records: [(StoredLedgerPolicyDecision, LedgerPolicyDecisionRecord)] = []
            for row in rows {
                try Self.checkRowVersion(row.schemaVersion, ledger: .policyDecision)
                records.append((row, try LedgerPolicyDecisionCodec.decode(row.payload)))
            }
            try pruneLoaded(records.map(\.0), policy: retention(for: .policyDecision), asOf: now(), recordedAt: \.recordedAt)
            try saveContext()
            let policy = retention(for: .policyDecision)
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

    func deletePolicyDecisions() async throws {
        do {
            for row in try context.fetch(FetchDescriptor<StoredLedgerPolicyDecision>()) {
                context.delete(row)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func purgePolicyDecisions(asOf date: Date) async -> Int {
        do {
            let removed = try purgeRows(
                FetchDescriptor<StoredLedgerPolicyDecision>(),
                policy: retention(for: .policyDecision),
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

    func exportPolicyDecisions(
        selected: LedgerExportSelection<LedgerPolicyDecisionExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let records = try await loadPolicyDecisions()
        let columns = selected.fields.map(\.rawValue)
        let rows = records.map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        return try Self.exportData(ledger: .policyDecision, columns: columns, rows: rows, format: format)
    }
}
