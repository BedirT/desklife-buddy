import Foundation

/// One sanitized policy-decision row (story 5).
///
/// The audit behind one automatic behavior change: the action identity
/// (uuid, device, counter), the hold decision it opens or closes, the
/// closed command kind, the effect class (quiet/shift/restart/resume — never
/// a payload), the coordinator-lease window, the opaque assessment
/// digest that justified it, and the evaluated ticks. Carries no reading,
/// confidence, provider, or group content.
public struct LedgerPolicyDecisionRecord: Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    public let recordedAt: Date
    public let actionUUID: UUID
    public let actionDeviceID: String
    public let actionCounter: UInt64
    public let holdDecisionUUID: UUID?
    public let kindCode: String
    public let effectCode: String
    public let leaseGrantedTicks: TimeInterval
    public let leaseExpiryTicks: TimeInterval
    public let assessmentDigest: String
    public let evaluatedTicks: TimeInterval

    /// Closed command kinds this ledger admits: the hold/release family
    /// plus the qualified strong-motion restart.
    public static let kinds = [
        "holdBegin", "holdRelease", "holdCorrectionRelease", "sensorStrongMovementRestart",
    ]
    /// Closed effect classes this ledger admits.
    public static let effects = ["quiet", "shift", "restart", "resume"]

    public init(
        id: UUID,
        recordedAt: Date,
        actionUUID: UUID,
        actionDeviceID: String,
        actionCounter: UInt64,
        holdDecisionUUID: UUID?,
        kindCode: String,
        effectCode: String,
        leaseGrantedTicks: TimeInterval,
        leaseExpiryTicks: TimeInterval,
        assessmentDigest: String,
        evaluatedTicks: TimeInterval,
    ) throws {
        guard Self.kinds.contains(kindCode) else {
            throw LedgerStoreError.invalidRecord("policy-decision kind \(kindCode)")
        }
        guard Self.effects.contains(effectCode) else {
            throw LedgerStoreError.invalidRecord("policy-decision effect \(effectCode)")
        }
        guard UUID(uuidString: actionDeviceID) != nil else {
            throw LedgerStoreError.invalidRecord("policy-decision device")
        }
        guard leaseExpiryTicks > leaseGrantedTicks else {
            throw LedgerStoreError.invalidRecord("policy-decision lease")
        }
        guard !assessmentDigest.isEmpty else {
            throw LedgerStoreError.invalidRecord("policy-decision digest")
        }
        self.id = id
        self.recordedAt = recordedAt
        self.actionUUID = actionUUID
        self.actionDeviceID = actionDeviceID
        self.actionCounter = actionCounter
        self.holdDecisionUUID = holdDecisionUUID
        self.kindCode = kindCode
        self.effectCode = effectCode
        self.leaseGrantedTicks = leaseGrantedTicks
        self.leaseExpiryTicks = leaseExpiryTicks
        self.assessmentDigest = assessmentDigest
        self.evaluatedTicks = evaluatedTicks
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case recordedAt
        case actionUUID
        case actionDeviceID
        case actionCounter
        case holdDecisionUUID
        case kindCode
        case effectCode
        case leaseGrantedTicks
        case leaseExpiryTicks
        case assessmentDigest
        case evaluatedTicks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            recordedAt: container.decode(Date.self, forKey: .recordedAt),
            actionUUID: container.decode(UUID.self, forKey: .actionUUID),
            actionDeviceID: container.decode(String.self, forKey: .actionDeviceID),
            actionCounter: container.decode(UInt64.self, forKey: .actionCounter),
            holdDecisionUUID: container.decodeIfPresent(UUID.self, forKey: .holdDecisionUUID),
            kindCode: container.decode(String.self, forKey: .kindCode),
            effectCode: container.decode(String.self, forKey: .effectCode),
            leaseGrantedTicks: container.decode(TimeInterval.self, forKey: .leaseGrantedTicks),
            leaseExpiryTicks: container.decode(TimeInterval.self, forKey: .leaseExpiryTicks),
            assessmentDigest: container.decode(String.self, forKey: .assessmentDigest),
            evaluatedTicks: container.decode(TimeInterval.self, forKey: .evaluatedTicks),
        )
    }

    /// Full export row; the exporter keeps selected keys only.
    public func exportRow() -> [String: String] {
        [
            "id": id.uuidString.lowercased(),
            "recordedAt": String(recordedAt.timeIntervalSince1970),
            "action": actionUUID.uuidString.lowercased(),
            "actionDevice": actionDeviceID.lowercased(),
            "actionCounter": String(actionCounter),
            "holdDecision": holdDecisionUUID?.uuidString.lowercased() ?? "",
            "kind": kindCode,
            "effect": effectCode,
            "leaseGrantedTicks": String(leaseGrantedTicks),
            "leaseExpiryTicks": String(leaseExpiryTicks),
            "assessmentDigest": assessmentDigest,
            "evaluatedTicks": String(evaluatedTicks),
        ]
    }
}

/// Versioned codec for policy-decision rows. The envelope carries the row
/// schema version so a future version is refused by identity before its
/// row is decoded. Encoding is deterministic (sorted keys).
public enum LedgerPolicyDecisionCodec {
    public static let schemaVersion = 1

    private struct Envelope: Codable {
        var schemaVersion: Int
        var row: LedgerPolicyDecisionRecord
    }

    private struct EnvelopeVersion: Decodable {
        var schemaVersion: Int
    }

    public static func encode(_ record: LedgerPolicyDecisionRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, row: record))
    }

    public static func decode(_ data: Data) throws -> LedgerPolicyDecisionRecord {
        let probe: EnvelopeVersion
        do {
            probe = try JSONDecoder().decode(EnvelopeVersion.self, from: data)
        } catch {
            throw LedgerStoreError.invalidRecord("policy-decision envelope")
        }
        guard probe.schemaVersion == schemaVersion else {
            throw LedgerStoreError.unknownSchemaVersion(
                ledger: LedgerKind.policyDecision.code,
                version: probe.schemaVersion,
            )
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).row
        } catch let error as LedgerStoreError {
            throw error
        } catch {
            throw LedgerStoreError.invalidRecord("policy-decision row")
        }
    }
}

/// Persistence seam for the append-only policy-decision ledger.
public protocol LedgerPolicyDecisionStore {
    func append(_ record: LedgerPolicyDecisionRecord) async throws
    func loadRecords() async throws -> [LedgerPolicyDecisionRecord]
    func deleteAllRecords() async throws
}

/// In-memory policy-decision ledger for deterministic tests. Retention
/// prunes on every write and read; identical replays are idempotent;
/// reused identifiers with different facts are refused.
public final class InMemoryLedgerPolicyDecisionStore: LedgerPolicyDecisionStore {
    private var records: [UUID: LedgerPolicyDecisionRecord] = [:]
    /// Insertion sequence for the recorded-at tiebreak in ordered().
    /// Fake-local memory only: never a row column, never exported.
    private var insertionOrder: [UUID] = []
    public var retention: HistoryRetentionPolicy
    public var now: () -> Date
    public var saveHook: (() throws -> Void)?

    public init(now: @escaping () -> Date = Date.init, retention: HistoryRetentionPolicy? = nil) {
        self.now = now
        self.retention = retention ?? LedgerRetention.policy(for: .policyDecision)
    }

    public func append(_ record: LedgerPolicyDecisionRecord) async throws {
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

    public func loadRecords() async throws -> [LedgerPolicyDecisionRecord] {
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
        selected: LedgerExportSelection<LedgerPolicyDecisionExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let columns = selected.fields.map(\.rawValue)
        let rows = ordered().map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        let table = LedgerExportTable(ledger: LedgerKind.policyDecision.code, fields: columns, rows: rows)
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

    private func ordered() -> [LedgerPolicyDecisionRecord] {
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
