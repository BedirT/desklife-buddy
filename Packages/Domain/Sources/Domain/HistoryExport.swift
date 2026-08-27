import Foundation

/// Ordered machine field vocabulary available for localized pre-export disclosure.
public enum HistoryExportField: String, Codable, CaseIterable, Sendable {
    case id
    case recordedAt
    case kind
    case source
    case opportunity
    case selectedDurationSeconds
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

/// Versioned, deterministic export input that contains only retained event fields.
public struct HistoryExport: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public let formatVersion: Int
    public let records: [HistoryExportRecord]

    /// Projects events in chronological order with stable UUID tie-breaking.
    public static func project(events: [OpportunityEvent]) -> HistoryExport {
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
        return HistoryExport(formatVersion: currentFormatVersion, records: records)
    }

    private init(formatVersion: Int, records: [HistoryExportRecord]) {
        self.formatVersion = formatVersion
        self.records = records
    }
}
