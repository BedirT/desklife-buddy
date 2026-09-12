import Foundation

/// One sanitized observation row (story 5).
///
/// A window fact admitted under a live provider lease: closed provider,
/// kind, source, quality, confidence, and coverage codes plus the
/// independence-group code, the admitted and expiry ticks, the lease
/// window, and the presenting device. The record carries no payload
/// content, no bus sequence, and no atom identity — the admission ticks
/// are the only ordering the ledger keeps.
public struct LedgerObservationRecord: Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    public let recordedAt: Date
    public let providerCode: String
    public let kindCode: String
    public let sourceCode: String
    public let qualityCode: String
    public let confidenceCode: String
    public let coverageCode: String
    public let groupCode: String
    public let admittedTicks: TimeInterval
    public let expiryTicks: TimeInterval
    public let leaseGrantedTicks: TimeInterval
    public let leaseExpiryTicks: TimeInterval
    public let presentingDeviceID: String

    /// Closed code sets admitted to this ledger.
    public static let providers = ["fake-presence", "fake-motion", "fake-ambient"]
    public static let kinds = ["presence", "motion", "ambient"]
    public static let sources = ["fakePresence", "fakeMotion", "fakeAmbient"]
    public static let qualities = ["full", "degraded", "denied"]
    public static let confidences = ["low", "medium", "high"]
    public static let coverages = ["partial", "full"]

    public init(
        id: UUID,
        recordedAt: Date,
        providerCode: String,
        kindCode: String,
        sourceCode: String,
        qualityCode: String,
        confidenceCode: String,
        coverageCode: String,
        groupCode: String,
        admittedTicks: TimeInterval,
        expiryTicks: TimeInterval,
        leaseGrantedTicks: TimeInterval,
        leaseExpiryTicks: TimeInterval,
        presentingDeviceID: String,
    ) throws {
        guard Self.providers.contains(providerCode) else {
            throw LedgerStoreError.invalidRecord("observation provider \(providerCode)")
        }
        guard Self.kinds.contains(kindCode) else {
            throw LedgerStoreError.invalidRecord("observation kind \(kindCode)")
        }
        guard Self.sources.contains(sourceCode) else {
            throw LedgerStoreError.invalidRecord("observation source \(sourceCode)")
        }
        guard Self.qualities.contains(qualityCode) else {
            throw LedgerStoreError.invalidRecord("observation quality \(qualityCode)")
        }
        guard Self.confidences.contains(confidenceCode) else {
            throw LedgerStoreError.invalidRecord("observation confidence \(confidenceCode)")
        }
        guard Self.coverages.contains(coverageCode) else {
            throw LedgerStoreError.invalidRecord("observation coverage \(coverageCode)")
        }
        guard !groupCode.isEmpty else {
            throw LedgerStoreError.invalidRecord("observation group")
        }
        guard expiryTicks > admittedTicks else {
            throw LedgerStoreError.invalidRecord("observation expiry")
        }
        guard leaseExpiryTicks > leaseGrantedTicks else {
            throw LedgerStoreError.invalidRecord("observation lease")
        }
        guard UUID(uuidString: presentingDeviceID) != nil else {
            throw LedgerStoreError.invalidRecord("observation device")
        }
        self.id = id
        self.recordedAt = recordedAt
        self.providerCode = providerCode
        self.kindCode = kindCode
        self.sourceCode = sourceCode
        self.qualityCode = qualityCode
        self.confidenceCode = confidenceCode
        self.coverageCode = coverageCode
        self.groupCode = groupCode
        self.admittedTicks = admittedTicks
        self.expiryTicks = expiryTicks
        self.leaseGrantedTicks = leaseGrantedTicks
        self.leaseExpiryTicks = leaseExpiryTicks
        self.presentingDeviceID = presentingDeviceID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case recordedAt
        case providerCode
        case kindCode
        case sourceCode
        case qualityCode
        case confidenceCode
        case coverageCode
        case groupCode
        case admittedTicks
        case expiryTicks
        case leaseGrantedTicks
        case leaseExpiryTicks
        case presentingDeviceID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            recordedAt: container.decode(Date.self, forKey: .recordedAt),
            providerCode: container.decode(String.self, forKey: .providerCode),
            kindCode: container.decode(String.self, forKey: .kindCode),
            sourceCode: container.decode(String.self, forKey: .sourceCode),
            qualityCode: container.decode(String.self, forKey: .qualityCode),
            confidenceCode: container.decode(String.self, forKey: .confidenceCode),
            coverageCode: container.decode(String.self, forKey: .coverageCode),
            groupCode: container.decode(String.self, forKey: .groupCode),
            admittedTicks: container.decode(TimeInterval.self, forKey: .admittedTicks),
            expiryTicks: container.decode(TimeInterval.self, forKey: .expiryTicks),
            leaseGrantedTicks: container.decode(TimeInterval.self, forKey: .leaseGrantedTicks),
            leaseExpiryTicks: container.decode(TimeInterval.self, forKey: .leaseExpiryTicks),
            presentingDeviceID: container.decode(String.self, forKey: .presentingDeviceID),
        )
    }

    /// Full export row; the exporter keeps selected keys only.
    public func exportRow() -> [String: String] {
        [
            "id": id.uuidString.lowercased(),
            "recordedAt": String(recordedAt.timeIntervalSince1970),
            "provider": providerCode,
            "kind": kindCode,
            "source": sourceCode,
            "quality": qualityCode,
            "confidence": confidenceCode,
            "coverage": coverageCode,
            "group": groupCode,
            "admittedTicks": String(admittedTicks),
            "expiryTicks": String(expiryTicks),
            "leaseGrantedTicks": String(leaseGrantedTicks),
            "leaseExpiryTicks": String(leaseExpiryTicks),
            "presentingDevice": presentingDeviceID.lowercased(),
        ]
    }
}

/// Versioned codec for observation rows. The envelope carries the row
/// schema version so a future version is refused by identity before its
/// row is decoded. Encoding is deterministic (sorted keys).
public enum LedgerObservationCodec {
    public static let schemaVersion = 1

    private struct Envelope: Codable {
        var schemaVersion: Int
        var row: LedgerObservationRecord
    }

    private struct EnvelopeVersion: Decodable {
        var schemaVersion: Int
    }

    public static func encode(_ record: LedgerObservationRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, row: record))
    }

    public static func decode(_ data: Data) throws -> LedgerObservationRecord {
        let probe: EnvelopeVersion
        do {
            probe = try JSONDecoder().decode(EnvelopeVersion.self, from: data)
        } catch {
            throw LedgerStoreError.invalidRecord("observation envelope")
        }
        guard probe.schemaVersion == schemaVersion else {
            throw LedgerStoreError.unknownSchemaVersion(
                ledger: LedgerKind.observation.code,
                version: probe.schemaVersion,
            )
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).row
        } catch let error as LedgerStoreError {
            throw error
        } catch {
            throw LedgerStoreError.invalidRecord("observation row")
        }
    }
}

/// Persistence seam for the append-only observation ledger.
public protocol LedgerObservationStore {
    func append(_ record: LedgerObservationRecord) async throws
    func loadRecords() async throws -> [LedgerObservationRecord]
    func deleteAllRecords() async throws
}

/// In-memory observation ledger for deterministic tests. Retention prunes
/// on every write and read; identical replays are idempotent; reused
/// identifiers with different facts are refused.
public final class InMemoryLedgerObservationStore: LedgerObservationStore {
    private var records: [UUID: LedgerObservationRecord] = [:]
    /// Insertion sequence for the recorded-at tiebreak in ordered().
    /// Fake-local memory only: never a row column, never exported.
    private var insertionOrder: [UUID] = []
    public var retention: HistoryRetentionPolicy
    public var now: () -> Date
    public var saveHook: (() throws -> Void)?

    public init(now: @escaping () -> Date = Date.init, retention: HistoryRetentionPolicy? = nil) {
        self.now = now
        self.retention = retention ?? LedgerRetention.policy(for: .observation)
    }

    public func append(_ record: LedgerObservationRecord) async throws {
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

    public func loadRecords() async throws -> [LedgerObservationRecord] {
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
        selected: LedgerExportSelection<LedgerObservationExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let columns = selected.fields.map(\.rawValue)
        let rows = ordered().map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        let table = LedgerExportTable(ledger: LedgerKind.observation.code, fields: columns, rows: rows)
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

    private func ordered() -> [LedgerObservationRecord] {
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
