import Foundation

/// Restart-safe fence/dedup snapshot for the coordinator (Story 2.5).
///
/// This is the exact crash-replay authority the contract requires to
/// survive restore: the generation (the causal clock; not elapsed time),
/// global and opportunity revisions, bound projection epochs, fenced epochs,
/// committed ActionIDs with their auditable receipts (authorship device +
/// gap-free counter ride along, never regenerated), and merged sessions. It
/// carries no clocks, no wall-time anchors, and no Class 0 candidate
/// buffers.
public struct CoordinatorFenceState: Equatable, Sendable {
    public var generation: CoordinatorGeneration
    public var globalRevision: UInt64
    public var opportunityRevisions: [OpportunityID: UInt64]
    public var projectionEpochs: [OpportunityID: ProjectionEpochID]
    public var fencedEpochs: Set<ProjectionEpochID>
    public var committedActions: [ActionID: OpportunityActionReceipt]
    public var mergedSessions: [OpportunityID: OpportunityActionReducer.OpportunityMergedSession]

    public init(
        generation: CoordinatorGeneration = CoordinatorGeneration(0),
        globalRevision: UInt64 = 0,
        opportunityRevisions: [OpportunityID: UInt64] = [:],
        projectionEpochs: [OpportunityID: ProjectionEpochID] = [:],
        fencedEpochs: Set<ProjectionEpochID> = [],
        committedActions: [ActionID: OpportunityActionReceipt] = [:],
        mergedSessions: [OpportunityID: OpportunityActionReducer.OpportunityMergedSession] = [:],
    ) {
        self.generation = generation
        self.globalRevision = globalRevision
        self.opportunityRevisions = opportunityRevisions
        self.projectionEpochs = projectionEpochs
        self.fencedEpochs = fencedEpochs
        self.committedActions = committedActions
        self.mergedSessions = mergedSessions
    }
}

extension CoordinatorFenceState: Codable {
    private enum CodingKeys: String, CodingKey {
        case generation
        case globalRevision
        case opportunityRevisions
        case projectionEpochs
        case fencedEpochs
        case committedActions
        case mergedSessions
    }

    private struct OpportunityRevisionRecord: Codable {
        var opportunity: OpportunityID
        var revision: UInt64
    }

    private struct ProjectionEpochRecord: Codable {
        var opportunity: OpportunityID
        var epoch: ProjectionEpochID
    }

    private struct CommittedActionRecord: Codable {
        var action: ActionID
        var receipt: OpportunityActionReceipt
    }

    private struct MergedSessionRecord: Codable {
        var opportunity: OpportunityID
        var session: OpportunityActionReducer.OpportunityMergedSession
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generation = try container.decode(CoordinatorGeneration.self, forKey: .generation)
        globalRevision = try container.decode(UInt64.self, forKey: .globalRevision)
        let revisions = try container.decode([OpportunityRevisionRecord].self, forKey: .opportunityRevisions)
        opportunityRevisions = try Self.uniquelyKeyed(
            revisions,
            key: \.opportunity,
            value: \.revision,
            forKey: .opportunityRevisions,
            codingPath: container.codingPath,
        )
        let epochs = try container.decode([ProjectionEpochRecord].self, forKey: .projectionEpochs)
        projectionEpochs = try Self.uniquelyKeyed(
            epochs,
            key: \.opportunity,
            value: \.epoch,
            forKey: .projectionEpochs,
            codingPath: container.codingPath,
        )
        fencedEpochs = try Set(container.decode([ProjectionEpochID].self, forKey: .fencedEpochs))
        let actions = try container.decode([CommittedActionRecord].self, forKey: .committedActions)
        committedActions = try Self.uniquelyKeyed(
            actions,
            key: \.action,
            value: \.receipt,
            forKey: .committedActions,
            codingPath: container.codingPath,
        )
        let sessions = try container.decode([MergedSessionRecord].self, forKey: .mergedSessions)
        mergedSessions = try Self.uniquelyKeyed(
            sessions,
            key: \.opportunity,
            value: \.session,
            forKey: .mergedSessions,
            codingPath: container.codingPath,
        )
    }

    /// Builds a keyed map from decoded records, failing closed on duplicates.
    /// A tampered payload carrying two records for one key throws
    /// `DecodingError.dataCorrupted` (surfaced as invalidCoordinatorFenceState
    /// at the store boundary) instead of trapping in
    /// `Dictionary(uniqueKeysWithValues:)` on the launch path.
    private static func uniquelyKeyed<Record, Key: Hashable, Value>(
        _ records: [Record],
        key keyPath: KeyPath<Record, Key>,
        value valuePath: KeyPath<Record, Value>,
        forKey codingKey: CodingKeys,
        codingPath: [CodingKey],
    ) throws -> [Key: Value] {
        var map: [Key: Value] = [:]
        map.reserveCapacity(records.count)
        for record in records {
            let key = record[keyPath: keyPath]
            guard map[key] == nil else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath + [codingKey],
                    debugDescription: "Duplicate coordinator fence record for one key.",
                ))
            }
            map[key] = record[keyPath: valuePath]
        }
        return map
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(generation, forKey: .generation)
        try container.encode(globalRevision, forKey: .globalRevision)
        try container.encode(
            opportunityRevisions
                .sorted { $0.key.uuid.uuidString < $1.key.uuid.uuidString }
                .map { OpportunityRevisionRecord(opportunity: $0.key, revision: $0.value) },
            forKey: .opportunityRevisions,
        )
        try container.encode(
            projectionEpochs
                .sorted { $0.key.uuid.uuidString < $1.key.uuid.uuidString }
                .map { ProjectionEpochRecord(opportunity: $0.key, epoch: $0.value) },
            forKey: .projectionEpochs,
        )
        try container.encode(
            fencedEpochs.sorted { $0.uuid.uuidString < $1.uuid.uuidString },
            forKey: .fencedEpochs,
        )
        try container.encode(
            committedActions
                .sorted {
                    if $0.key.deviceID.uuid.uuidString != $1.key.deviceID.uuid.uuidString {
                        return $0.key.deviceID.uuid.uuidString < $1.key.deviceID.uuid.uuidString
                    }
                    if $0.key.counter != $1.key.counter { return $0.key.counter < $1.key.counter }
                    return $0.key.uuid.uuidString < $1.key.uuid.uuidString
                }
                .map { CommittedActionRecord(action: $0.key, receipt: $0.value) },
            forKey: .committedActions,
        )
        try container.encode(
            mergedSessions
                .sorted { $0.key.uuid.uuidString < $1.key.uuid.uuidString }
                .map { MergedSessionRecord(opportunity: $0.key, session: $0.value) },
            forKey: .mergedSessions,
        )
    }
}
