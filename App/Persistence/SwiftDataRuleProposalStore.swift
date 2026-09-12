import Domain
import Foundation
import SwiftData

/// SwiftData owner for rule proposals (Epic 13 R1).
///
/// A separate additive-only seam beside the six ledgers: rows carry a
/// versioned payload blob decoded by the Domain codec. Unknown versions
/// throw before any mutation, duplicate identifiers replay idempotently,
/// reused identifiers with different facts are refused, regressed status
/// ticks on update are refused, and retention prunes on every write and
/// read. `.keepNothing` retains nothing. Export and delete use the ledger
/// export vocabulary.
final class SwiftDataRuleProposalStore {
    let container: ModelContainer
    let context: ModelContext
    let now: () -> Date
    let saveContext: () throws -> Void

    /// Retention override for tests. Defaults to the proposal policy.
    var retentionOverride: HistoryRetentionPolicy?

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

    func retention() -> HistoryRetentionPolicy {
        retentionOverride ?? RuleProposalRetention.defaultPolicy
    }

    func append(_ record: RuleProposal) async throws {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredRuleProposal>())
            if let existing = rows.first(where: { $0.id == record.id }) {
                try Self.checkRowVersion(existing.schemaVersion)
                let decoded = try RuleProposalCodec.decode(existing.payload)
                guard decoded == record else {
                    throw LedgerStoreError.conflictingRecord(id: record.id)
                }
                try saveContext()
                return
            }
            guard retention() != .keepNothing else { return }
            try context.insert(StoredRuleProposal(
                id: record.id,
                schemaVersion: RuleProposalCodec.schemaVersion,
                recordedAt: record.recordedAt,
                payload: RuleProposalCodec.encode(record),
            ))
            try prune(asOf: now())
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadProposals() async throws -> [RuleProposal] {
        do {
            let rows = try context
                .fetch(FetchDescriptor<StoredRuleProposal>(sortBy: [SortDescriptor(\.recordedAt)]))
            var decoded: [RuleProposal] = []
            for row in rows {
                try Self.checkRowVersion(row.schemaVersion)
                decoded.append(try RuleProposalCodec.decode(row.payload))
            }
            try pruneLoaded(rows: rows)
            try saveContext()
            let policy = retention()
            let moment = now()
            return Self.ordered(decoded.filter { Self.isLive(recordedAt: $0.recordedAt, asOf: moment, policy: policy) })
        } catch {
            context.rollback()
            throw error
        }
    }

    func update(_ record: RuleProposal) async throws {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredRuleProposal>())
            guard let existing = rows.first(where: { $0.id == record.id }) else {
                // Update on an unknown identifier inserts, through the same
                // retention and idempotency path as append.
                try await appendWithoutRollback(record)
                return
            }
            try Self.checkRowVersion(existing.schemaVersion)
            let current = try RuleProposalCodec.decode(existing.payload)
            guard record.statusUpdatedTicks >= current.statusUpdatedTicks else {
                throw LedgerStoreError.illegalRollback
            }
            guard retention() != .keepNothing else {
                context.delete(existing)
                try saveContext()
                return
            }
            existing.recordedAt = record.recordedAt
            existing.payload = try RuleProposalCodec.encode(record)
            try prune(asOf: now())
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteAllProposals() async throws {
        do {
            for row in try context.fetch(FetchDescriptor<StoredRuleProposal>()) {
                context.delete(row)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func purge(asOf date: Date) async -> Int {
        do {
            let removed = try purgeRows(asOf: date)
            try saveContext()
            return removed
        } catch {
            context.rollback()
            return 0
        }
    }

    func export(
        selected: LedgerExportSelection<RuleProposalExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let records = try await loadProposals()
        let columns = selected.fields.map(\.rawValue)
        let rows = records.map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        let table = LedgerExportTable(ledger: RuleProposalRetention.seamCode, fields: columns, rows: rows)
        switch format {
        case .json: return try table.jsonData()
        case .csv: return try table.csvData()
        }
    }

    // MARK: - Private

    private func appendWithoutRollback(_ record: RuleProposal) async throws {
        let rows = try context.fetch(FetchDescriptor<StoredRuleProposal>())
        if rows.contains(where: { $0.id == record.id }) {
            return
        }
        guard retention() != .keepNothing else { return }
        try context.insert(StoredRuleProposal(
            id: record.id,
            schemaVersion: RuleProposalCodec.schemaVersion,
            recordedAt: record.recordedAt,
            payload: RuleProposalCodec.encode(record),
        ))
        try prune(asOf: now())
        try saveContext()
    }

    private static func checkRowVersion(_ version: Int) throws {
        guard version == RuleProposalCodec.schemaVersion else {
            throw LedgerStoreError.unknownSchemaVersion(
                ledger: RuleProposalRetention.seamCode,
                version: version,
            )
        }
    }

    private static func isLive(recordedAt: Date, asOf date: Date, policy: HistoryRetentionPolicy) -> Bool {
        guard policy != .keepNothing else { return false }
        return recordedAt >= date.addingTimeInterval(-policy.retentionDurationSeconds)
    }

    private static func ordered(_ records: [RuleProposal]) -> [RuleProposal] {
        // Recorded-at order; the load fetch already sorts by recordedAt with
        // row order for ties, so same-moment appends read back stably.
        records.enumerated().sorted {
            if $0.element.recordedAt != $1.element.recordedAt {
                return $0.element.recordedAt < $1.element.recordedAt
            }
            return $0.offset < $1.offset
        }.map(\.element)
    }

    private func prune(asOf date: Date) throws {
        try pruneLoaded(rows: context.fetch(FetchDescriptor<StoredRuleProposal>()), asOf: date)
    }

    private func pruneLoaded(rows: [StoredRuleProposal], asOf date: Date? = nil) throws {
        let moment = date ?? now()
        let policy = retention()
        if policy == .keepNothing {
            for row in rows {
                context.delete(row)
            }
            return
        }
        let cutoff = moment.addingTimeInterval(-policy.retentionDurationSeconds)
        for row in rows where row.recordedAt < cutoff {
            context.delete(row)
        }
    }

    private func purgeRows(asOf date: Date) throws -> Int {
        let rows = try context.fetch(FetchDescriptor<StoredRuleProposal>())
        let policy = retention()
        let doomed: [StoredRuleProposal]
        if policy == .keepNothing {
            doomed = rows
        } else {
            let cutoff = date.addingTimeInterval(-policy.retentionDurationSeconds)
            doomed = rows.filter { $0.recordedAt < cutoff }
        }
        for row in doomed {
            context.delete(row)
        }
        return doomed.count
    }
}
