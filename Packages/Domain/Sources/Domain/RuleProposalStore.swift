import Foundation

/// Closed rule-proposal export vocabulary in canonical order.
///
/// Field names reuse the ledger export shape (`LedgerExportTable`); the row
/// carries codes and counts only — no readings, providers, or groups.
public enum RuleProposalExportField: String, Equatable, Hashable, CaseIterable, Codable, CodingKey, Sendable {
    case id
    case recordedAt
    case ruleKey
    case kind
    case effect
    case status
    case evidence
    case requiredEvidence
    case statusTicks
}

/// Bounded retention for rule proposals.
///
/// Proposals justify automatic behavior changes, so they keep the audit
/// ninety-day window like policy decisions and corrections. `.keepNothing`
/// clears proposals alongside every other retained row.
public enum RuleProposalRetention {
    public static let defaultPolicy: HistoryRetentionPolicy = .ninetyDays
    /// Ledger code naming this seam in schema-version errors and exports.
    /// A plain code, not a seventh `LedgerKind`: the proposal store sits
    /// beside the six ledgers.
    public static let seamCode = "ruleProposal"
}

/// Versioned codec for rule-proposal rows. The envelope carries the row
/// schema version so a future version is refused by identity before its
/// row is decoded. Encoding is deterministic (sorted keys).
public enum RuleProposalCodec {
    public static let schemaVersion = 1

    private struct Envelope: Codable {
        var schemaVersion: Int
        var row: RuleProposal
    }

    private struct EnvelopeVersion: Decodable {
        var schemaVersion: Int
    }

    public static func encode(_ record: RuleProposal) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, row: record))
    }

    public static func decode(_ data: Data) throws -> RuleProposal {
        let probe: EnvelopeVersion
        do {
            probe = try JSONDecoder().decode(EnvelopeVersion.self, from: data)
        } catch {
            throw LedgerStoreError.invalidRecord("rule-proposal envelope")
        }
        guard probe.schemaVersion == schemaVersion else {
            throw LedgerStoreError.unknownSchemaVersion(
                ledger: RuleProposalRetention.seamCode,
                version: probe.schemaVersion,
            )
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).row
        } catch let error as LedgerStoreError {
            throw error
        } catch {
            throw LedgerStoreError.invalidRecord("rule-proposal row")
        }
    }
}

/// Persistence seam for rule proposals, beside the six ledgers.
///
/// Updates carry owner status transitions (Add/Not-now/Never, undo, reset);
/// regressed status ticks are refused before any mutation.
public protocol RuleProposalStore {
    func append(_ record: RuleProposal) async throws
    func loadProposals() async throws -> [RuleProposal]
    func update(_ record: RuleProposal) async throws
    func deleteAllProposals() async throws
}

/// In-memory rule-proposal store for deterministic tests. Retention prunes
/// on every write and read; identical replays are idempotent; reused
/// identifiers with different facts are refused; regressed status ticks on
/// update are refused before any mutation.
public final class InMemoryRuleProposalStore: RuleProposalStore {
    private var records: [UUID: RuleProposal] = [:]
    /// Insertion sequence for the recorded-at tiebreak in ordered().
    /// Fake-local memory only: never a row column, never exported.
    private var insertionOrder: [UUID] = []
    public var retention: HistoryRetentionPolicy
    public var now: () -> Date
    public var saveHook: (() throws -> Void)?

    public init(now: @escaping () -> Date = Date.init, retention: HistoryRetentionPolicy? = nil) {
        self.now = now
        self.retention = retention ?? RuleProposalRetention.defaultPolicy
    }

    public func append(_ record: RuleProposal) async throws {
        if let existing = records[record.id] {
            guard existing == record else {
                throw LedgerStoreError.conflictingRecord(id: record.id)
            }
            try saveHook?()
            return
        }
        guard retention != .keepNothing else { return }
        try saveHook?()
        records[record.id] = record
        insertionOrder.append(record.id)
        prune(asOf: now())
    }

    public func loadProposals() async throws -> [RuleProposal] {
        prune(asOf: now())
        return ordered()
    }

    public func update(_ record: RuleProposal) async throws {
        if let existing = records[record.id] {
            guard record.statusUpdatedTicks >= existing.statusUpdatedTicks else {
                throw LedgerStoreError.illegalRollback
            }
            guard retention != .keepNothing else {
                records.removeValue(forKey: record.id)
                insertionOrder.removeAll { $0 == record.id }
                return
            }
            try saveHook?()
            records[record.id] = record
            prune(asOf: now())
            return
        }
        try await append(record)
    }

    public func deleteAllProposals() async throws {
        try saveHook?()
        records.removeAll()
        insertionOrder.removeAll()
    }

    @discardableResult
    public func purge(asOf date: Date) async -> Int {
        let removed = Set(expired(asOf: date))
        for id in removed {
            records.removeValue(forKey: id)
        }
        insertionOrder.removeAll { removed.contains($0) }
        return removed.count
    }

    public func export(
        selected: LedgerExportSelection<RuleProposalExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let columns = selected.fields.map(\.rawValue)
        let rows = ordered().map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        let table = LedgerExportTable(ledger: RuleProposalRetention.seamCode, fields: columns, rows: rows)
        switch format {
        case .json: return try table.jsonData()
        case .csv: return try table.csvData()
        }
    }

    private func prune(asOf date: Date) {
        let removed = Set(expired(asOf: date))
        for id in removed {
            records.removeValue(forKey: id)
        }
        insertionOrder.removeAll { removed.contains($0) }
    }

    private func expired(asOf date: Date) -> [UUID] {
        guard retention != .keepNothing else {
            return Array(records.keys)
        }
        let cutoff = date.addingTimeInterval(-retention.retentionDurationSeconds)
        return records.values.filter { $0.recordedAt < cutoff }.map(\.id)
    }

    private func ordered() -> [RuleProposal] {
        // Recorded-at order; same-timestamp rows read back in insertion
        // order, never identifier order, so same-moment appends are stable.
        let insertionIndex = Dictionary(uniqueKeysWithValues: insertionOrder.enumerated().map { ($1, $0) })
        return records.values.sorted {
            if $0.recordedAt != $1.recordedAt {
                return $0.recordedAt < $1.recordedAt
            }
            return (insertionIndex[$0.id] ?? Int.max) < (insertionIndex[$1.id] ?? Int.max)
        }
    }
}
