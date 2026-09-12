import Foundation

/// File formats supported by the ledger exporter.
public enum LedgerExportFormat: String, CaseIterable, Sendable {
    case csv
    case json
}

/// Closed per-ledger observation export vocabulary in canonical order.
public enum LedgerObservationExportField: String, Equatable, Hashable, CaseIterable, Codable, CodingKey, Sendable {
    case id
    case recordedAt
    case provider
    case kind
    case source
    case quality
    case confidence
    case coverage
    case group
    case admittedTicks
    case expiryTicks
    case leaseGrantedTicks
    case leaseExpiryTicks
    case presentingDevice
}

/// Closed per-ledger assessment export vocabulary in canonical order.
public enum LedgerAssessmentExportField: String, Equatable, Hashable, CaseIterable, Codable, CodingKey, Sendable {
    case id
    case recordedAt
    case reading
    case confidence
    case supportingGroups
    case representativeKind
    case representativeSource
    case representativeReading
    case representativeQuality
    case representativeConfidence
    case representativeCoverage
    case representativeGroup
    case representativeExpiryTicks
    case evaluatedTicks
    case assessmentDigest
}

/// Closed per-ledger policy-decision export vocabulary in canonical order.
public enum LedgerPolicyDecisionExportField: String, Equatable, Hashable, CaseIterable, Codable, CodingKey, Sendable {
    case id
    case recordedAt
    case action
    case actionDevice
    case actionCounter
    case holdDecision
    case kind
    case effect
    case leaseGrantedTicks
    case leaseExpiryTicks
    case assessmentDigest
    case evaluatedTicks
}

/// Closed per-ledger correction export vocabulary in canonical order.
public enum LedgerCorrectionExportField: String, Equatable, Hashable, CaseIterable, Codable, CodingKey, Sendable {
    case id
    case recordedAt
    case correctedAction
    case correctedActionDevice
    case correctedActionCounter
    case correctingAction
    case correctingActionDevice
    case correctingActionCounter
    case outcome
    case reason
    case generation
    case globalRevision
    case supersededDecisions
}

/// Closed per-ledger consent-receipt export vocabulary in canonical order.
public enum LedgerConsentReceiptExportField: String, Equatable, Hashable, CaseIterable, Codable, CodingKey, Sendable {
    case id
    case recordedAt
    case provider
    case scope
    case scopeRevision
    case grantedTicks
    case expiryTicks
    case epoch
    case device
    case status
    case revokedTicks
}

/// Closed per-ledger companion-action export vocabulary in canonical order.
public enum LedgerCompanionActionExportField: String, Equatable, Hashable, CaseIterable, Codable, CodingKey, Sendable {
    case id
    case recordedAt
    case action
    case actionDevice
    case actionCounter
    case kind
    case scope
    case originRevision
    case segment
    case causalParents
    case leaseGrantedTicks
    case leaseExpiryTicks
    case outcome
    case reason
}

/// An immutable field selection normalized to the canonical vocabulary
/// order. Unknown spellings are unrepresentable: callers name enum cases.
public struct LedgerExportSelection<Field>: Equatable, Sendable
    where Field: RawRepresentable & CaseIterable & Equatable & Sendable, Field.RawValue == String
{
    /// Selected fields in canonical vocabulary order.
    public let fields: [Field]

    /// Creates a selection with fields normalized to canonical order.
    public init(selected: some Sequence<Field>) throws {
        let wanted = Set(selected.map(\.rawValue))
        guard !wanted.isEmpty else {
            throw LedgerStoreError.exportNoFields
        }
        fields = Field.allCases.filter { wanted.contains($0.rawValue) }
    }
}

/// A versioned, deterministic export projection holding selected keys only.
public struct LedgerExportTable: Equatable, Sendable {
    /// Export document version.
    public static let formatVersion = 1

    public let ledger: String
    public let fields: [String]
    public let rows: [[String: String]]

    public init(ledger: String, fields: [String], rows: [[String: String]]) {
        self.ledger = ledger
        self.fields = fields
        self.rows = rows
    }

    private struct Document: Encodable {
        var formatVersion: Int
        var ledger: String
        var fields: [String]
        var records: [[String: String]]
    }

    /// Encodes the projection as deterministic JSON (sorted keys only).
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Document(
            formatVersion: Self.formatVersion,
            ledger: ledger,
            fields: fields,
            records: rows,
        ))
    }

    /// Encodes the projection as CSV with a canonical header row.
    public func csvData() throws -> Data {
        var lines = [fields.map(Self.csvCell).joined(separator: ",")]
        for row in rows {
            lines.append(fields.map { Self.csvCell(row[$0] ?? "") }.joined(separator: ","))
        }
        lines.append("")
        guard let data = lines.joined(separator: "\n").data(using: .utf8) else {
            throw LedgerStoreError.invalidRecord(ledger)
        }
        return data
    }

    private static func csvCell(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
