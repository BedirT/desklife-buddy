import Foundation

/// One sanitized correction row (story 5).
///
/// The audit that makes every automatic mutation replayable: the
/// corrected action identity, the correcting action when one exists, the
/// closed outcome (committed, duplicate replay, or a named rejection),
/// the reason, the causal generation, the global revision, and the
/// superseded decision identifiers. Corrections never re-apply effects;
/// they record what settled and what it superseded.
public struct LedgerCorrectionRecord: Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    public let recordedAt: Date
    public let correctedActionUUID: UUID
    public let correctedActionDeviceID: String
    public let correctedActionCounter: UInt64
    public let correctingActionUUID: UUID?
    public let correctingActionDeviceID: String?
    public let correctingActionCounter: UInt64?
    public let outcomeCode: String
    public let reasonCode: String
    public let generation: UInt64
    public let globalRevision: UInt64
    public let supersededDecisionUUIDs: [UUID]

    /// Closed outcomes this ledger admits: the committed and replay
    /// outcomes plus the named coordinator rejections.
    public static let outcomes = [
        "committed", "duplicateReplay",
        "rejectedStaleGeneration", "rejectedStaleRevision", "rejectedFencedEpoch",
        "rejectedScopeMismatch", "rejectedLeaseNotLive", "rejectedInvalidPayload",
    ]

    public init(
        id: UUID,
        recordedAt: Date,
        correctedActionUUID: UUID,
        correctedActionDeviceID: String,
        correctedActionCounter: UInt64,
        correctingActionUUID: UUID?,
        correctingActionDeviceID: String?,
        correctingActionCounter: UInt64?,
        outcomeCode: String,
        reasonCode: String,
        generation: UInt64,
        globalRevision: UInt64,
        supersededDecisionUUIDs: [UUID],
    ) throws {
        guard Self.outcomes.contains(outcomeCode) else {
            throw LedgerStoreError.invalidRecord("correction outcome \(outcomeCode)")
        }
        guard UUID(uuidString: correctedActionDeviceID) != nil else {
            throw LedgerStoreError.invalidRecord("correction device")
        }
        if let correctingActionDeviceID {
            guard UUID(uuidString: correctingActionDeviceID) != nil else {
                throw LedgerStoreError.invalidRecord("correction correcting device")
            }
        }
        guard (correctingActionUUID == nil) == (correctingActionDeviceID == nil),
              (correctingActionUUID == nil) == (correctingActionCounter == nil)
        else {
            throw LedgerStoreError.invalidRecord("correction correcting action")
        }
        guard !reasonCode.isEmpty else {
            throw LedgerStoreError.invalidRecord("correction reason")
        }
        self.id = id
        self.recordedAt = recordedAt
        self.correctedActionUUID = correctedActionUUID
        self.correctedActionDeviceID = correctedActionDeviceID
        self.correctedActionCounter = correctedActionCounter
        self.correctingActionUUID = correctingActionUUID
        self.correctingActionDeviceID = correctingActionDeviceID
        self.correctingActionCounter = correctingActionCounter
        self.outcomeCode = outcomeCode
        self.reasonCode = reasonCode
        self.generation = generation
        self.globalRevision = globalRevision
        self.supersededDecisionUUIDs = supersededDecisionUUIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case recordedAt
        case correctedActionUUID
        case correctedActionDeviceID
        case correctedActionCounter
        case correctingActionUUID
        case correctingActionDeviceID
        case correctingActionCounter
        case outcomeCode
        case reasonCode
        case generation
        case globalRevision
        case supersededDecisionUUIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            recordedAt: container.decode(Date.self, forKey: .recordedAt),
            correctedActionUUID: container.decode(UUID.self, forKey: .correctedActionUUID),
            correctedActionDeviceID: container.decode(String.self, forKey: .correctedActionDeviceID),
            correctedActionCounter: container.decode(UInt64.self, forKey: .correctedActionCounter),
            correctingActionUUID: container.decodeIfPresent(UUID.self, forKey: .correctingActionUUID),
            correctingActionDeviceID: container.decodeIfPresent(String.self, forKey: .correctingActionDeviceID),
            correctingActionCounter: container.decodeIfPresent(UInt64.self, forKey: .correctingActionCounter),
            outcomeCode: container.decode(String.self, forKey: .outcomeCode),
            reasonCode: container.decode(String.self, forKey: .reasonCode),
            generation: container.decode(UInt64.self, forKey: .generation),
            globalRevision: container.decode(UInt64.self, forKey: .globalRevision),
            supersededDecisionUUIDs: container.decode([UUID].self, forKey: .supersededDecisionUUIDs),
        )
    }

    /// Full export row; the exporter keeps selected keys only.
    public func exportRow() -> [String: String] {
        [
            "id": id.uuidString.lowercased(),
            "recordedAt": String(recordedAt.timeIntervalSince1970),
            "correctedAction": correctedActionUUID.uuidString.lowercased(),
            "correctedActionDevice": correctedActionDeviceID.lowercased(),
            "correctedActionCounter": String(correctedActionCounter),
            "correctingAction": correctingActionUUID?.uuidString.lowercased() ?? "",
            "correctingActionDevice": correctingActionDeviceID?.lowercased() ?? "",
            "correctingActionCounter": correctingActionCounter.map { String($0) } ?? "",
            "outcome": outcomeCode,
            "reason": reasonCode,
            "generation": String(generation),
            "globalRevision": String(globalRevision),
            "supersededDecisions": supersededDecisionUUIDs.map { $0.uuidString.lowercased() }.joined(separator: ";"),
        ]
    }
}

/// Versioned codec for correction rows. The envelope carries the row
/// schema version so a future version is refused by identity before its
/// row is decoded. Encoding is deterministic (sorted keys).
public enum LedgerCorrectionCodec {
    public static let schemaVersion = 1

    private struct Envelope: Codable {
        var schemaVersion: Int
        var row: LedgerCorrectionRecord
    }

    private struct EnvelopeVersion: Decodable {
        var schemaVersion: Int
    }

    public static func encode(_ record: LedgerCorrectionRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, row: record))
    }

    public static func decode(_ data: Data) throws -> LedgerCorrectionRecord {
        let probe: EnvelopeVersion
        do {
            probe = try JSONDecoder().decode(EnvelopeVersion.self, from: data)
        } catch {
            throw LedgerStoreError.invalidRecord("correction envelope")
        }
        guard probe.schemaVersion == schemaVersion else {
            throw LedgerStoreError.unknownSchemaVersion(
                ledger: LedgerKind.correction.code,
                version: probe.schemaVersion,
            )
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).row
        } catch let error as LedgerStoreError {
            throw error
        } catch {
            throw LedgerStoreError.invalidRecord("correction row")
        }
    }
}

/// Persistence seam for the append-only correction ledger.
public protocol LedgerCorrectionStore {
    func append(_ record: LedgerCorrectionRecord) async throws
    func loadRecords() async throws -> [LedgerCorrectionRecord]
    func deleteAllRecords() async throws
}

/// In-memory correction ledger for deterministic tests. Retention prunes
/// on every write and read; identical replays are idempotent; reused
/// identifiers with different facts are refused; regressed generations
/// and same-generation revision drops are refused before any mutation.
public final class InMemoryLedgerCorrectionStore: LedgerCorrectionStore {
    private var records: [UUID: LedgerCorrectionRecord] = [:]
    /// Insertion sequence for the recorded-at tiebreak in ordered().
    /// Fake-local memory only: never a row column, never exported.
    private var insertionOrder: [UUID] = []
    public var retention: HistoryRetentionPolicy
    public var now: () -> Date
    public var saveHook: (() throws -> Void)?

    public init(now: @escaping () -> Date = Date.init, retention: HistoryRetentionPolicy? = nil) {
        self.now = now
        self.retention = retention ?? LedgerRetention.policy(for: .correction)
    }

    public func append(_ record: LedgerCorrectionRecord) async throws {
        if let existing = records[record.id] {
            guard existing == record else {
                throw LedgerStoreError.conflictingRecord(id: record.id)
            }
            try saveHook?()
            return
        }
        try Self.checkFrontier(record, against: Array(records.values))
        guard retention != .keepNothing else { return }
        try saveHook?()
        records[record.id] = record
        insertionOrder.append(record.id)
        prune(asOf: now())
    }

    public func loadRecords() async throws -> [LedgerCorrectionRecord] {
        prune(asOf: now())
        return ordered()
    }

    public func deleteAllRecords() async throws {
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
        selected: LedgerExportSelection<LedgerCorrectionExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let columns = selected.fields.map(\.rawValue)
        let rows = ordered().map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        let table = LedgerExportTable(ledger: LedgerKind.correction.code, fields: columns, rows: rows)
        switch format {
        case .json: return try table.jsonData()
        case .csv: return try table.csvData()
        }
    }

    /// Refuses regressed generations and same-generation revision drops.
    /// Shared with the SwiftData store so both frontiers refuse alike.
    public static func checkFrontier(
        _ record: LedgerCorrectionRecord,
        against retained: [LedgerCorrectionRecord],
    ) throws {
        if let peak = retained.map(\.generation).max(), record.generation < peak {
            throw LedgerStoreError.illegalRollback
        }
        for existing in retained where existing.correctedActionUUID == record.correctedActionUUID
            && existing.generation == record.generation
            && existing.id != record.id
        {
            guard record.globalRevision >= existing.globalRevision else {
                throw LedgerStoreError.illegalRollback
            }
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

    private func ordered() -> [LedgerCorrectionRecord] {
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
