import Foundation

/// Ordered, closed machine field vocabulary that can be selected for a history export.
public enum HistoryExportField: String, Codable, CaseIterable, CodingKey, Sendable {
    case id
    case recordedAt
    case kind
    case source
    case opportunity
    case selectedDurationSeconds
}

/// File formats supported by the local history exporter.
public enum HistoryExportFormat: String, Codable, CaseIterable, Sendable {
    case csv
    case json
}

/// Validation failures for an immutable history-export request.
public enum HistoryExportRequestError: Error, Equatable, Sendable {
    case noSelectedFields
}

/// Immutable export intent shared by selection, retry, projection, and file writing.
public struct HistoryExportRequest: Equatable, Sendable {
    public let format: HistoryExportFormat
    public let fields: [HistoryExportField]

    /// Creates a request with fields normalized to the canonical schema order.
    public init(
        format: HistoryExportFormat,
        selectedFields: Set<HistoryExportField>,
    ) throws {
        guard !selectedFields.isEmpty else {
            throw HistoryExportRequestError.noSelectedFields
        }
        self.format = format
        fields = HistoryExportField.allCases.filter(selectedFields.contains)
    }
}

/// Stable privacy-minimized projection of one local opportunity event.
public struct HistoryExportRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let recordedAt: Date
    public let kind: String
    public let source: String
    public let opportunity: String?
    public let selectedDurationSeconds: TimeInterval?

    /// Creates an already projected record without adding inferred context.
    public init(
        id: UUID,
        recordedAt: Date,
        kind: String,
        source: String,
        opportunity: String?,
        selectedDurationSeconds: TimeInterval?,
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.kind = kind
        self.source = source
        self.opportunity = opportunity
        self.selectedDurationSeconds = selectedDurationSeconds
    }
}

/// Versioned, deterministic export projection containing only explicitly selected event fields.
public struct HistoryExport: Encodable, Equatable, Sendable {
    public static let currentFormatVersion = 2

    public let formatVersion: Int
    public let fields: [HistoryExportField]
    public let records: [HistoryExportRecord]

    /// Projects selected event fields in chronological order with stable UUID tie-breaking.
    public static func project(
        events: [OpportunityEvent],
        fields: [HistoryExportField],
    ) -> HistoryExport {
        let selectedFields = Set(fields)
        let canonicalFields = HistoryExportField.allCases.filter(selectedFields.contains)
        let records = events
            .sorted {
                if $0.recordedAt != $1.recordedAt {
                    return $0.recordedAt < $1.recordedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            .map {
                HistoryExportRecord(
                    id: $0.id,
                    recordedAt: $0.recordedAt,
                    kind: $0.kind.rawValue,
                    source: $0.source.rawValue,
                    opportunity: $0.opportunity?.rawValue,
                    selectedDurationSeconds: $0.selectedDurationSeconds,
                )
            }
        return HistoryExport(
            formatVersion: currentFormatVersion,
            fields: canonicalFields,
            records: records,
        )
    }

    private init(
        formatVersion: Int,
        fields: [HistoryExportField],
        records: [HistoryExportRecord],
    ) {
        self.formatVersion = formatVersion
        self.fields = fields
        self.records = records
    }

    /// Encodes schema metadata and only the selected closed-vocabulary record keys.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RootCodingKey.self)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(fields, forKey: .fields)
        var recordsContainer = container.nestedUnkeyedContainer(forKey: .records)
        for record in records {
            let recordEncoder = recordsContainer.superEncoder()
            var recordContainer = recordEncoder.container(keyedBy: HistoryExportField.self)
            for field in fields {
                try record.encode(field, into: &recordContainer)
            }
        }
    }
}

private enum RootCodingKey: String, CodingKey {
    case formatVersion
    case fields
    case records
}

private extension HistoryExportRecord {
    func encode(
        _ field: HistoryExportField,
        into container: inout KeyedEncodingContainer<HistoryExportField>,
    ) throws {
        switch field {
        case .id:
            try container.encode(id, forKey: field)
        case .recordedAt:
            try container.encode(recordedAt, forKey: field)
        case .kind:
            try container.encode(kind, forKey: field)
        case .source:
            try container.encode(source, forKey: field)
        case .opportunity:
            if let opportunity {
                try container.encode(opportunity, forKey: field)
            } else {
                try container.encodeNil(forKey: field)
            }
        case .selectedDurationSeconds:
            if let selectedDurationSeconds {
                try container.encode(selectedDurationSeconds, forKey: field)
            } else {
                try container.encodeNil(forKey: field)
            }
        }
    }
}
