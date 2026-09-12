import Foundation

/// One sanitized companion-action row (story 5).
///
/// The audit behind one companion-routed action: the action identity
/// (uuid, device, counter), the closed companion kind, the closed scope,
/// the origin revision, the optional segment, the causal parents, the
/// lease window, and the settlement receipt (outcome + reason). Titles,
/// content identifiers, and payload content never enter the row — the
/// ledger records that an action settled, never what it carried.
public struct LedgerCompanionActionRecord: Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    public let recordedAt: Date
    public let actionDeviceID: String
    public let actionCounter: UInt64
    public let kindCode: String
    public let scopeCode: String
    public let originRevision: UInt64
    public let segmentUUID: UUID?
    public let causalParents: [UUID]
    public let leaseGrantedTicks: TimeInterval
    public let leaseExpiryTicks: TimeInterval
    public let outcomeCode: String
    public let reasonCode: String

    /// Closed companion kinds this ledger admits.
    public static let kinds = ["takeWithMe", "handoff", "mirror"]
    /// Closed scopes this ledger admits.
    public static let scopes = ["globalSystem", "visual", "movement"]
    /// Closed settlement outcomes this ledger admits.
    public static let outcomes = [
        "committed", "duplicateReplay",
        "rejectedStaleGeneration", "rejectedStaleRevision", "rejectedFencedEpoch",
        "rejectedScopeMismatch", "rejectedLeaseNotLive", "rejectedInvalidPayload",
    ]

    public init(
        id: UUID,
        recordedAt: Date,
        actionDeviceID: String,
        actionCounter: UInt64,
        kindCode: String,
        scopeCode: String,
        originRevision: UInt64,
        segmentUUID: UUID?,
        causalParents: [UUID],
        leaseGrantedTicks: TimeInterval,
        leaseExpiryTicks: TimeInterval,
        outcomeCode: String,
        reasonCode: String,
    ) throws {
        guard Self.kinds.contains(kindCode) else {
            throw LedgerStoreError.invalidRecord("companion kind \(kindCode)")
        }
        guard Self.scopes.contains(scopeCode) else {
            throw LedgerStoreError.invalidRecord("companion scope \(scopeCode)")
        }
        guard Self.outcomes.contains(outcomeCode) else {
            throw LedgerStoreError.invalidRecord("companion outcome \(outcomeCode)")
        }
        guard UUID(uuidString: actionDeviceID) != nil else {
            throw LedgerStoreError.invalidRecord("companion device")
        }
        guard leaseExpiryTicks > leaseGrantedTicks else {
            throw LedgerStoreError.invalidRecord("companion lease")
        }
        guard !reasonCode.isEmpty else {
            throw LedgerStoreError.invalidRecord("companion reason")
        }
        self.id = id
        self.recordedAt = recordedAt
        self.actionDeviceID = actionDeviceID
        self.actionCounter = actionCounter
        self.kindCode = kindCode
        self.scopeCode = scopeCode
        self.originRevision = originRevision
        self.segmentUUID = segmentUUID
        self.causalParents = causalParents
        self.leaseGrantedTicks = leaseGrantedTicks
        self.leaseExpiryTicks = leaseExpiryTicks
        self.outcomeCode = outcomeCode
        self.reasonCode = reasonCode
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case recordedAt
        case actionDeviceID
        case actionCounter
        case kindCode
        case scopeCode
        case originRevision
        case segmentUUID
        case causalParents
        case leaseGrantedTicks
        case leaseExpiryTicks
        case outcomeCode
        case reasonCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            recordedAt: container.decode(Date.self, forKey: .recordedAt),
            actionDeviceID: container.decode(String.self, forKey: .actionDeviceID),
            actionCounter: container.decode(UInt64.self, forKey: .actionCounter),
            kindCode: container.decode(String.self, forKey: .kindCode),
            scopeCode: container.decode(String.self, forKey: .scopeCode),
            originRevision: container.decode(UInt64.self, forKey: .originRevision),
            segmentUUID: container.decodeIfPresent(UUID.self, forKey: .segmentUUID),
            causalParents: container.decode([UUID].self, forKey: .causalParents),
            leaseGrantedTicks: container.decode(TimeInterval.self, forKey: .leaseGrantedTicks),
            leaseExpiryTicks: container.decode(TimeInterval.self, forKey: .leaseExpiryTicks),
            outcomeCode: container.decode(String.self, forKey: .outcomeCode),
            reasonCode: container.decode(String.self, forKey: .reasonCode),
        )
    }

    /// Full export row; the exporter keeps selected keys only.
    public func exportRow() -> [String: String] {
        [
            "id": id.uuidString.lowercased(),
            "recordedAt": String(recordedAt.timeIntervalSince1970),
            "action": id.uuidString.lowercased(),
            "actionDevice": actionDeviceID.lowercased(),
            "actionCounter": String(actionCounter),
            "kind": kindCode,
            "scope": scopeCode,
            "originRevision": String(originRevision),
            "segment": segmentUUID?.uuidString.lowercased() ?? "",
            "causalParents": causalParents.map { $0.uuidString.lowercased() }.joined(separator: ";"),
            "leaseGrantedTicks": String(leaseGrantedTicks),
            "leaseExpiryTicks": String(leaseExpiryTicks),
            "outcome": outcomeCode,
            "reason": reasonCode,
        ]
    }
}

/// Versioned codec for companion-action rows. The envelope carries the row
/// schema version so a future version is refused by identity before its
/// row is decoded. Encoding is deterministic (sorted keys).
public enum LedgerCompanionActionCodec {
    public static let schemaVersion = 1

    private struct Envelope: Codable {
        var schemaVersion: Int
        var row: LedgerCompanionActionRecord
    }

    private struct EnvelopeVersion: Decodable {
        var schemaVersion: Int
    }

    public static func encode(_ record: LedgerCompanionActionRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, row: record))
    }

    public static func decode(_ data: Data) throws -> LedgerCompanionActionRecord {
        let probe: EnvelopeVersion
        do {
            probe = try JSONDecoder().decode(EnvelopeVersion.self, from: data)
        } catch {
            throw LedgerStoreError.invalidRecord("companion-action envelope")
        }
        guard probe.schemaVersion == schemaVersion else {
            throw LedgerStoreError.unknownSchemaVersion(
                ledger: LedgerKind.companionAction.code,
                version: probe.schemaVersion,
            )
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).row
        } catch let error as LedgerStoreError {
            throw error
        } catch {
            throw LedgerStoreError.invalidRecord("companion-action row")
        }
    }
}

/// Persistence seam for the append-only companion-action ledger.
public protocol LedgerCompanionActionStore {
    func append(_ record: LedgerCompanionActionRecord) async throws
    func loadRecords() async throws -> [LedgerCompanionActionRecord]
    func deleteAllRecords() async throws
}

/// In-memory companion-action ledger for deterministic tests. Retention
/// prunes on every write and read; identical replays are idempotent;
/// reused identifiers with different facts are refused.
public final class InMemoryLedgerCompanionActionStore: LedgerCompanionActionStore {
    private var records: [UUID: LedgerCompanionActionRecord] = [:]
    /// Insertion sequence for the recorded-at tiebreak in ordered().
    /// Fake-local memory only: never a row column, never exported.
    private var insertionOrder: [UUID] = []
    public var retention: HistoryRetentionPolicy
    public var now: () -> Date
    public var saveHook: (() throws -> Void)?

    public init(now: @escaping () -> Date = Date.init, retention: HistoryRetentionPolicy? = nil) {
        self.now = now
        self.retention = retention ?? LedgerRetention.policy(for: .companionAction)
    }

    public func append(_ record: LedgerCompanionActionRecord) async throws {
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

    public func loadRecords() async throws -> [LedgerCompanionActionRecord] {
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
        selected: LedgerExportSelection<LedgerCompanionActionExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let columns = selected.fields.map(\.rawValue)
        let rows = ordered().map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        let table = LedgerExportTable(ledger: LedgerKind.companionAction.code, fields: columns, rows: rows)
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

    private func ordered() -> [LedgerCompanionActionRecord] {
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

/// Deterministic factory for the six in-memory ledgers.
public enum InMemoryLedgerStores {
    public static func observation(
        now: @escaping () -> Date = Date.init,
        retention: HistoryRetentionPolicy? = nil,
    ) -> InMemoryLedgerObservationStore {
        InMemoryLedgerObservationStore(now: now, retention: retention)
    }

    public static func assessment(
        now: @escaping () -> Date = Date.init,
        retention: HistoryRetentionPolicy? = nil,
    ) -> InMemoryLedgerAssessmentStore {
        InMemoryLedgerAssessmentStore(now: now, retention: retention)
    }

    public static func policyDecision(
        now: @escaping () -> Date = Date.init,
        retention: HistoryRetentionPolicy? = nil,
    ) -> InMemoryLedgerPolicyDecisionStore {
        InMemoryLedgerPolicyDecisionStore(now: now, retention: retention)
    }

    public static func correction(
        now: @escaping () -> Date = Date.init,
        retention: HistoryRetentionPolicy? = nil,
    ) -> InMemoryLedgerCorrectionStore {
        InMemoryLedgerCorrectionStore(now: now, retention: retention)
    }

    public static func consentReceipt(
        now: @escaping () -> Date = Date.init,
        retention: HistoryRetentionPolicy? = nil,
    ) -> InMemoryLedgerConsentReceiptStore {
        InMemoryLedgerConsentReceiptStore(now: now, retention: retention)
    }

    public static func companionAction(
        now: @escaping () -> Date = Date.init,
        retention: HistoryRetentionPolicy? = nil,
    ) -> InMemoryLedgerCompanionActionStore {
        InMemoryLedgerCompanionActionStore(now: now, retention: retention)
    }
}
