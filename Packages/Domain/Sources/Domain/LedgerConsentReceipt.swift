import Foundation

/// One sanitized consent-receipt row (story 5).
///
/// The audit behind one grant, revocation, or expiry: the provider code,
/// the placeholder capability scope plus its revision, the granted and
/// expiry ticks, the epoch code, the device, the closed status, and the
/// revoked ticks when revoked. Scopes name placeholder capabilities only
/// — story 6 owns the permission surface; this ledger only records what
/// was decided, at which revision, and when it lapsed.
public struct LedgerConsentReceiptRecord: Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    public let recordedAt: Date
    public let providerCode: String
    public let scopeCode: String
    public let scopeRevision: UInt64
    public let grantedTicks: TimeInterval
    public let expiryTicks: TimeInterval
    public let epochCode: String
    public let deviceID: String
    public let statusCode: String
    public let revokedTicks: TimeInterval?

    /// Closed placeholder capability scopes this ledger admits.
    public static let scopes = [
        "sensing-presence", "sensing-motion", "sensing-ambient",
        "effect-hold", "effect-restart",
    ]
    /// Closed receipt statuses this ledger admits.
    public static let statuses = ["granted", "revoked", "expired"]

    public init(
        id: UUID,
        recordedAt: Date,
        providerCode: String,
        scopeCode: String,
        scopeRevision: UInt64,
        grantedTicks: TimeInterval,
        expiryTicks: TimeInterval,
        epochCode: String,
        deviceID: String,
        statusCode: String,
        revokedTicks: TimeInterval?,
    ) throws {
        guard Self.scopes.contains(scopeCode) else {
            throw LedgerStoreError.invalidRecord("consent scope \(scopeCode)")
        }
        guard Self.statuses.contains(statusCode) else {
            throw LedgerStoreError.invalidRecord("consent status \(statusCode)")
        }
        guard !providerCode.isEmpty else {
            throw LedgerStoreError.invalidRecord("consent provider")
        }
        guard expiryTicks > grantedTicks else {
            throw LedgerStoreError.invalidRecord("consent expiry")
        }
        guard !epochCode.isEmpty else {
            throw LedgerStoreError.invalidRecord("consent epoch")
        }
        guard UUID(uuidString: deviceID) != nil else {
            throw LedgerStoreError.invalidRecord("consent device")
        }
        if statusCode == "granted" {
            guard revokedTicks == nil else {
                throw LedgerStoreError.invalidRecord("consent granted revocation")
            }
        } else {
            guard revokedTicks != nil else {
                throw LedgerStoreError.invalidRecord("consent terminal revocation")
            }
        }
        self.id = id
        self.recordedAt = recordedAt
        self.providerCode = providerCode
        self.scopeCode = scopeCode
        self.scopeRevision = scopeRevision
        self.grantedTicks = grantedTicks
        self.expiryTicks = expiryTicks
        self.epochCode = epochCode
        self.deviceID = deviceID
        self.statusCode = statusCode
        self.revokedTicks = revokedTicks
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case recordedAt
        case providerCode
        case scopeCode
        case scopeRevision
        case grantedTicks
        case expiryTicks
        case epochCode
        case deviceID
        case statusCode
        case revokedTicks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            recordedAt: container.decode(Date.self, forKey: .recordedAt),
            providerCode: container.decode(String.self, forKey: .providerCode),
            scopeCode: container.decode(String.self, forKey: .scopeCode),
            scopeRevision: container.decode(UInt64.self, forKey: .scopeRevision),
            grantedTicks: container.decode(TimeInterval.self, forKey: .grantedTicks),
            expiryTicks: container.decode(TimeInterval.self, forKey: .expiryTicks),
            epochCode: container.decode(String.self, forKey: .epochCode),
            deviceID: container.decode(String.self, forKey: .deviceID),
            statusCode: container.decode(String.self, forKey: .statusCode),
            revokedTicks: container.decodeIfPresent(TimeInterval.self, forKey: .revokedTicks),
        )
    }

    /// Full export row; the exporter keeps selected keys only.
    public func exportRow() -> [String: String] {
        [
            "id": id.uuidString.lowercased(),
            "recordedAt": String(recordedAt.timeIntervalSince1970),
            "provider": providerCode,
            "scope": scopeCode,
            "scopeRevision": String(scopeRevision),
            "grantedTicks": String(grantedTicks),
            "expiryTicks": String(expiryTicks),
            "epoch": epochCode.lowercased(),
            "device": deviceID.lowercased(),
            "status": statusCode,
            "revokedTicks": revokedTicks.map { String($0) } ?? "",
        ]
    }
}

/// Versioned codec for consent-receipt rows. The envelope carries the row
/// schema version so a future version is refused by identity before its
/// row is decoded. Encoding is deterministic (sorted keys).
public enum LedgerConsentReceiptCodec {
    public static let schemaVersion = 1

    private struct Envelope: Codable {
        var schemaVersion: Int
        var row: LedgerConsentReceiptRecord
    }

    private struct EnvelopeVersion: Decodable {
        var schemaVersion: Int
    }

    public static func encode(_ record: LedgerConsentReceiptRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, row: record))
    }

    public static func decode(_ data: Data) throws -> LedgerConsentReceiptRecord {
        let probe: EnvelopeVersion
        do {
            probe = try JSONDecoder().decode(EnvelopeVersion.self, from: data)
        } catch {
            throw LedgerStoreError.invalidRecord("consent-receipt envelope")
        }
        guard probe.schemaVersion == schemaVersion else {
            throw LedgerStoreError.unknownSchemaVersion(ledger: LedgerKind.consentReceipt.code, version: probe.schemaVersion)
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).row
        } catch let error as LedgerStoreError {
            throw error
        } catch {
            throw LedgerStoreError.invalidRecord("consent-receipt row")
        }
    }
}

/// Persistence seam for the append-only consent-receipt ledger.
public protocol LedgerConsentReceiptStore {
    func append(_ record: LedgerConsentReceiptRecord) async throws
    func loadRecords() async throws -> [LedgerConsentReceiptRecord]
    func deleteAllRecords() async throws
}

/// In-memory consent-receipt ledger for deterministic tests. Retention
/// prunes on every write and read; identical replays are idempotent;
/// reused identifiers with different facts are refused; regressed scope
/// revisions for a retained provider and scope are refused before any
/// mutation.
public final class InMemoryLedgerConsentReceiptStore: LedgerConsentReceiptStore {
    private var records: [UUID: LedgerConsentReceiptRecord] = [:]
    public var retention: HistoryRetentionPolicy
    public var now: () -> Date
    public var saveHook: (() throws -> Void)?

    public init(now: @escaping () -> Date = Date.init, retention: HistoryRetentionPolicy? = nil) {
        self.now = now
        self.retention = retention ?? LedgerRetention.policy(for: .consentReceipt)
    }

    public func append(_ record: LedgerConsentReceiptRecord) async throws {
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
        prune(asOf: now())
    }

    public func loadRecords() async throws -> [LedgerConsentReceiptRecord] {
        prune(asOf: now())
        return ordered()
    }

    public func deleteAllRecords() async throws {
        try saveHook?()
        records.removeAll()
    }

    @discardableResult
    public func purge(asOf date: Date) async -> Int {
        let removed = expired(asOf: date)
        for id in removed {
            records.removeValue(forKey: id)
        }
        return removed.count
    }

    public func export(
        selected: LedgerExportSelection<LedgerConsentReceiptExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let columns = selected.fields.map(\.rawValue)
        let rows = ordered().map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        let table = LedgerExportTable(ledger: LedgerKind.consentReceipt.code, fields: columns, rows: rows)
        switch format {
        case .json: return try table.jsonData()
        case .csv: return try table.csvData()
        }
    }

    /// Refuses regressed scope revisions for a retained provider + scope.
    /// Shared with the SwiftData store so both frontiers refuse alike.
    public static func checkFrontier(
        _ record: LedgerConsentReceiptRecord,
        against retained: [LedgerConsentReceiptRecord],
    ) throws {
        let peak = retained
            .filter { $0.providerCode == record.providerCode && $0.scopeCode == record.scopeCode }
            .map(\.scopeRevision).max()
        if let peak, record.scopeRevision < peak {
            throw LedgerStoreError.illegalRollback
        }
    }

    private func prune(asOf date: Date) {
        for id in expired(asOf: date) {
            records.removeValue(forKey: id)
        }
    }

    private func expired(asOf date: Date) -> [UUID] {
        guard retention != .keepNothing else {
            return Array(records.keys)
        }
        let cutoff = date.addingTimeInterval(-retention.retentionDurationSeconds)
        return records.values.filter { $0.recordedAt < cutoff }.map(\.id)
    }

    private func ordered() -> [LedgerConsentReceiptRecord] {
        records.values.sorted {
            if $0.recordedAt != $1.recordedAt {
                return $0.recordedAt < $1.recordedAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
