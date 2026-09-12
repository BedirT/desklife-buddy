import Foundation

/// One sanitized assessment row (story 5).
///
/// A verdict over one window: the binary-or-unknown reading code, the
/// capped confidence code, the independent-group count, the winning
/// representative's sanitized content (closed kind/source/reading/
/// quality/confidence/coverage codes, group code, expiry ticks), the
/// evaluated ticks, and the opaque digest. The digest audits the verdict
/// without revealing the underlying content; atom identifiers and bus
/// sequences never enter the row.
public struct LedgerAssessmentRecord: Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    public let recordedAt: Date
    public let readingCode: String
    public let confidenceCode: String
    public let supportingGroups: Int
    public let representativeKindCode: String
    public let representativeSourceCode: String
    public let representativeReadingCode: String
    public let representativeQualityCode: String
    public let representativeConfidenceCode: String
    public let representativeCoverageCode: String
    public let representativeGroupCode: String
    public let representativeExpiryTicks: TimeInterval
    public let evaluatedTicks: TimeInterval
    public let assessmentDigest: String

    /// Closed code sets admitted to this ledger.
    public static let readings = [
        "present", "absent",
        "unknown-missing", "unknown-stale", "unknown-denied",
        "unknown-degraded", "unknown-contradictory",
    ]
    public static let confidences = ["low", "medium", "high"]
    public static let kinds = ["presence", "motion", "ambient"]
    public static let sources = ["fakePresence", "fakeMotion", "fakeAmbient"]
    public static let qualities = ["full", "degraded", "denied"]
    public static let coverages = ["partial", "full"]

    public init(
        id: UUID,
        recordedAt: Date,
        readingCode: String,
        confidenceCode: String,
        supportingGroups: Int,
        representativeKindCode: String,
        representativeSourceCode: String,
        representativeReadingCode: String,
        representativeQualityCode: String,
        representativeConfidenceCode: String,
        representativeCoverageCode: String,
        representativeGroupCode: String,
        representativeExpiryTicks: TimeInterval,
        evaluatedTicks: TimeInterval,
        assessmentDigest: String,
    ) throws {
        guard Self.readings.contains(readingCode) else {
            throw LedgerStoreError.invalidRecord("assessment reading \(readingCode)")
        }
        guard Self.confidences.contains(confidenceCode) else {
            throw LedgerStoreError.invalidRecord("assessment confidence \(confidenceCode)")
        }
        guard supportingGroups >= 0 else {
            throw LedgerStoreError.invalidRecord("assessment groups")
        }
        guard Self.kinds.contains(representativeKindCode) else {
            throw LedgerStoreError.invalidRecord("assessment representative kind")
        }
        guard Self.sources.contains(representativeSourceCode) else {
            throw LedgerStoreError.invalidRecord("assessment representative source")
        }
        guard ["present", "absent"].contains(representativeReadingCode) else {
            throw LedgerStoreError.invalidRecord("assessment representative reading")
        }
        guard Self.qualities.contains(representativeQualityCode) else {
            throw LedgerStoreError.invalidRecord("assessment representative quality")
        }
        guard Self.confidences.contains(representativeConfidenceCode) else {
            throw LedgerStoreError.invalidRecord("assessment representative confidence")
        }
        guard Self.coverages.contains(representativeCoverageCode) else {
            throw LedgerStoreError.invalidRecord("assessment representative coverage")
        }
        guard !representativeGroupCode.isEmpty else {
            throw LedgerStoreError.invalidRecord("assessment representative group")
        }
        guard !assessmentDigest.isEmpty else {
            throw LedgerStoreError.invalidRecord("assessment digest")
        }
        self.id = id
        self.recordedAt = recordedAt
        self.readingCode = readingCode
        self.confidenceCode = confidenceCode
        self.supportingGroups = supportingGroups
        self.representativeKindCode = representativeKindCode
        self.representativeSourceCode = representativeSourceCode
        self.representativeReadingCode = representativeReadingCode
        self.representativeQualityCode = representativeQualityCode
        self.representativeConfidenceCode = representativeConfidenceCode
        self.representativeCoverageCode = representativeCoverageCode
        self.representativeGroupCode = representativeGroupCode
        self.representativeExpiryTicks = representativeExpiryTicks
        self.evaluatedTicks = evaluatedTicks
        self.assessmentDigest = assessmentDigest
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case recordedAt
        case readingCode
        case confidenceCode
        case supportingGroups
        case representativeKindCode
        case representativeSourceCode
        case representativeReadingCode
        case representativeQualityCode
        case representativeConfidenceCode
        case representativeCoverageCode
        case representativeGroupCode
        case representativeExpiryTicks
        case evaluatedTicks
        case assessmentDigest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            recordedAt: container.decode(Date.self, forKey: .recordedAt),
            readingCode: container.decode(String.self, forKey: .readingCode),
            confidenceCode: container.decode(String.self, forKey: .confidenceCode),
            supportingGroups: container.decode(Int.self, forKey: .supportingGroups),
            representativeKindCode: container.decode(String.self, forKey: .representativeKindCode),
            representativeSourceCode: container.decode(String.self, forKey: .representativeSourceCode),
            representativeReadingCode: container.decode(String.self, forKey: .representativeReadingCode),
            representativeQualityCode: container.decode(String.self, forKey: .representativeQualityCode),
            representativeConfidenceCode: container.decode(String.self, forKey: .representativeConfidenceCode),
            representativeCoverageCode: container.decode(String.self, forKey: .representativeCoverageCode),
            representativeGroupCode: container.decode(String.self, forKey: .representativeGroupCode),
            representativeExpiryTicks: container.decode(TimeInterval.self, forKey: .representativeExpiryTicks),
            evaluatedTicks: container.decode(TimeInterval.self, forKey: .evaluatedTicks),
            assessmentDigest: container.decode(String.self, forKey: .assessmentDigest),
        )
    }

    /// Full export row; the exporter keeps selected keys only.
    public func exportRow() -> [String: String] {
        [
            "id": id.uuidString.lowercased(),
            "recordedAt": String(recordedAt.timeIntervalSince1970),
            "reading": readingCode,
            "confidence": confidenceCode,
            "supportingGroups": String(supportingGroups),
            "representativeKind": representativeKindCode,
            "representativeSource": representativeSourceCode,
            "representativeReading": representativeReadingCode,
            "representativeQuality": representativeQualityCode,
            "representativeConfidence": representativeConfidenceCode,
            "representativeCoverage": representativeCoverageCode,
            "representativeGroup": representativeGroupCode,
            "representativeExpiryTicks": String(representativeExpiryTicks),
            "evaluatedTicks": String(evaluatedTicks),
            "assessmentDigest": assessmentDigest,
        ]
    }
}

/// Versioned codec for assessment rows. The envelope carries the row
/// schema version so a future version is refused by identity before its
/// row is decoded. Encoding is deterministic (sorted keys).
public enum LedgerAssessmentCodec {
    public static let schemaVersion = 1

    private struct Envelope: Codable {
        var schemaVersion: Int
        var row: LedgerAssessmentRecord
    }

    private struct EnvelopeVersion: Decodable {
        var schemaVersion: Int
    }

    public static func encode(_ record: LedgerAssessmentRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, row: record))
    }

    public static func decode(_ data: Data) throws -> LedgerAssessmentRecord {
        let probe: EnvelopeVersion
        do {
            probe = try JSONDecoder().decode(EnvelopeVersion.self, from: data)
        } catch {
            throw LedgerStoreError.invalidRecord("assessment envelope")
        }
        guard probe.schemaVersion == schemaVersion else {
            throw LedgerStoreError.unknownSchemaVersion(
                ledger: LedgerKind.assessment.code,
                version: probe.schemaVersion,
            )
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).row
        } catch let error as LedgerStoreError {
            throw error
        } catch {
            throw LedgerStoreError.invalidRecord("assessment row")
        }
    }
}

/// Persistence seam for the append-only assessment ledger.
public protocol LedgerAssessmentStore {
    func append(_ record: LedgerAssessmentRecord) async throws
    func loadRecords() async throws -> [LedgerAssessmentRecord]
    func deleteAllRecords() async throws
}

/// In-memory assessment ledger for deterministic tests. Retention prunes
/// on every write and read; identical replays are idempotent; reused
/// identifiers with different facts are refused.
public final class InMemoryLedgerAssessmentStore: LedgerAssessmentStore {
    private var records: [UUID: LedgerAssessmentRecord] = [:]
    /// Insertion sequence for the recorded-at tiebreak in ordered().
    /// Fake-local memory only: never a row column, never exported.
    private var insertionOrder: [UUID] = []
    public var retention: HistoryRetentionPolicy
    public var now: () -> Date
    public var saveHook: (() throws -> Void)?

    public init(now: @escaping () -> Date = Date.init, retention: HistoryRetentionPolicy? = nil) {
        self.now = now
        self.retention = retention ?? LedgerRetention.policy(for: .assessment)
    }

    public func append(_ record: LedgerAssessmentRecord) async throws {
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

    public func loadRecords() async throws -> [LedgerAssessmentRecord] {
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
        selected: LedgerExportSelection<LedgerAssessmentExportField>,
        format: LedgerExportFormat,
    ) async throws -> Data {
        let columns = selected.fields.map(\.rawValue)
        let rows = ordered().map { record in
            let row = record.exportRow()
            return Dictionary(uniqueKeysWithValues: columns.map { ($0, row[$0] ?? "") })
        }
        let table = LedgerExportTable(ledger: LedgerKind.assessment.code, fields: columns, rows: rows)
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

    private func ordered() -> [LedgerAssessmentRecord] {
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
