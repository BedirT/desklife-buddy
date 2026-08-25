import Foundation

/// Risk tier selecting mandatory review roles and execution ceilings.
public enum RiskTier: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
    case controlPlane = "control-plane"
}

/// Immutable work-item execution state persisted outside the committed DAG.
public enum WorkItemState: String, Codable, CaseIterable, Sendable {
    case planned
    case ready
    case claimed
    case completed
    case failed
    case quarantined
}

/// Lifecycle status controlling whether a skill can contribute qualifying evidence.
public enum SkillLifecycleStatus: String, Codable, CaseIterable, Sendable {
    case legacy
    case candidate
    case probation
    case active
    case deprecated
    case quarantined
}

/// Exact skill identity and status exposed to one bounded work item.
public struct SkillExposure: Codable, Equatable, Sendable {
    public let skillID: String
    public let status: SkillLifecycleStatus

    public init(skillID: String, status: SkillLifecycleStatus) {
        self.skillID = skillID
        self.status = status
    }
}

/// One context-sized unit in the immutable execution DAG.
public struct WorkItem: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case owner
        case dependencyIDs
        case criterionIDs
        case allowedPaths
        case allowedTools
        case contextEstimateBytes
        case risk
        case initialState
        case expectedCheckpointCommit
        case skillExposures
    }

    public let id: String
    public let owner: String
    public let dependencyIDs: [String]
    public let criterionIDs: [String]
    public let allowedPaths: [RepositoryPath]
    public let allowedTools: [String]
    public let contextEstimateBytes: Int
    public let risk: RiskTier
    public let initialState: WorkItemState
    public let expectedCheckpointCommit: GitObjectID?
    public let skillExposures: [SkillExposure]

    public init(
        id: String,
        owner: String,
        dependencyIDs: [String],
        criterionIDs: [String],
        allowedPaths: [RepositoryPath],
        allowedTools: [String],
        contextEstimateBytes: Int,
        risk: RiskTier,
        initialState: WorkItemState,
        expectedCheckpointCommit: GitObjectID?,
        skillExposures: [SkillExposure],
    ) {
        self.id = id
        self.owner = owner
        self.dependencyIDs = dependencyIDs
        self.criterionIDs = criterionIDs
        self.allowedPaths = allowedPaths
        self.allowedTools = allowedTools
        self.contextEstimateBytes = contextEstimateBytes
        self.risk = risk
        self.initialState = initialState
        self.expectedCheckpointCommit = expectedCheckpointCommit
        self.skillExposures = skillExposures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        owner = try container.decode(String.self, forKey: .owner)
        dependencyIDs = try container.decode([String].self, forKey: .dependencyIDs)
        criterionIDs = try container.decode([String].self, forKey: .criterionIDs)
        allowedPaths = try container.decode([RepositoryPath].self, forKey: .allowedPaths)
        allowedTools = try container.decode([String].self, forKey: .allowedTools)
        contextEstimateBytes = try container.decode(Int.self, forKey: .contextEstimateBytes)
        risk = try container.decode(RiskTier.self, forKey: .risk)
        initialState = try container.decode(WorkItemState.self, forKey: .initialState)
        expectedCheckpointCommit = try container.decodeIfPresent(GitObjectID.self, forKey: .expectedCheckpointCommit)
        skillExposures = try container.decode([SkillExposure].self, forKey: .skillExposures)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(owner, forKey: .owner)
        try container.encode(dependencyIDs, forKey: .dependencyIDs)
        try container.encode(criterionIDs, forKey: .criterionIDs)
        try container.encode(allowedPaths, forKey: .allowedPaths)
        try container.encode(allowedTools, forKey: .allowedTools)
        try container.encode(contextEstimateBytes, forKey: .contextEstimateBytes)
        try container.encode(risk, forKey: .risk)
        try container.encode(initialState, forKey: .initialState)
        try container.encode(expectedCheckpointCommit, forKey: .expectedCheckpointCommit)
        try container.encode(skillExposures, forKey: .skillExposures)
    }

    /// Whether this item is free of bootstrap-only or provisional skill exposure.
    public var isQualifying: Bool {
        skillExposures.allSatisfy { $0.status == .active }
    }
}

/// Committed dependency graph beneath one accepted issue contract.
public struct WorkItemGraph: Codable, Equatable, Sendable {
    private static let maximumItems = 4096
    private static let maximumListEntries = 256
    private static let maximumContextEstimateBytes = 16 * 1024 * 1024

    public let schemaVersion: Int
    public let issueNumber: Int
    public let contractSHA256: SHA256Digest
    public let items: [WorkItem]

    public init(
        schemaVersion: Int = FactoryCore.schemaVersion,
        issueNumber: Int,
        contractSHA256: SHA256Digest,
        items: [WorkItem],
    ) {
        self.schemaVersion = schemaVersion
        self.issueNumber = issueNumber
        self.contractSHA256 = contractSHA256
        self.items = items
    }

    /// Validates graph structure and returns a stable dependency-first order.
    public func validatedTopologicalOrder() throws -> [WorkItem] {
        guard schemaVersion == FactoryCore.schemaVersion,
              issueNumber > 0,
              !items.isEmpty,
              items.count <= Self.maximumItems,
              items.map(\.id) == items.map(\.id).sorted()
        else {
            throw FactoryValidationError(code: "invalid_work_graph", message: "A work graph needs an issue and items.")
        }
        let ids = items.map(\.id)
        guard Set(ids).count == ids.count,
              Set(ids.map { $0.lowercased() }).count == ids.count
        else {
            throw FactoryValidationError(code: "duplicate_work_item", message: "Work-item IDs must be unique.")
        }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for item in items {
            try validate(item)
            guard item.dependencyIDs.allSatisfy({ byID[$0] != nil && $0 != item.id }) else {
                throw FactoryValidationError(
                    code: "missing_work_dependency",
                    message: "Every dependency must name another item.",
                )
            }
        }

        var indegree = Dictionary(uniqueKeysWithValues: ids.map { ($0, 0) })
        var dependents: [String: [String]] = [:]
        for item in items {
            indegree[item.id] = item.dependencyIDs.count
            for dependency in item.dependencyIDs {
                dependents[dependency, default: []].append(item.id)
            }
        }
        var ready = indegree.filter { $0.value == 0 }.map(\.key).sorted()
        var ordered: [WorkItem] = []
        while let id = ready.first {
            ready.removeFirst()
            guard let item = byID[id] else {
                throw FactoryValidationError(
                    code: "missing_work_item",
                    message: "The work graph changed during validation.",
                )
            }
            ordered.append(item)
            for dependent in dependents[id, default: []].sorted() {
                indegree[dependent, default: 0] -= 1
                if indegree[dependent] == 0 {
                    ready.append(dependent)
                    ready.sort()
                }
            }
        }
        guard ordered.count == items.count else {
            throw FactoryValidationError(code: "work_graph_cycle", message: "Work-item dependencies must be acyclic.")
        }
        return ordered
    }

    /// Rejects simultaneous writers whose declared path ownership overlaps.
    public func validateWriterPathOwnership(claimedItemIDs: Set<String>) throws {
        let writers = items.filter { claimedItemIDs.contains($0.id) }
        guard writers.count == claimedItemIDs.count else {
            throw FactoryValidationError(
                code: "unknown_writer_claim",
                message: "Every writer claim must name a committed work item.",
            )
        }
        for leftIndex in writers.indices {
            for rightIndex in writers.indices where rightIndex > leftIndex {
                for left in writers[leftIndex].allowedPaths {
                    for right in writers[rightIndex].allowedPaths {
                        if left.collisionKey == right.collisionKey || left.isWithin(right) || right.isWithin(left) {
                            throw FactoryValidationError(
                                code: "writer_path_collision",
                                message: "Claimed work items may not own overlapping paths.",
                            )
                        }
                    }
                }
            }
        }
    }

    private func validate(_ item: WorkItem) throws {
        let idPattern = /^[a-z0-9][a-z0-9._-]{0,127}$/
        guard item.id.wholeMatch(of: idPattern) != nil,
              FactoryTextRules.isStableID(item.owner),
              !item.criterionIDs.isEmpty,
              !item.allowedPaths.isEmpty,
              item.dependencyIDs.count <= Self.maximumListEntries,
              item.criterionIDs.count <= Self.maximumListEntries,
              item.allowedPaths.count <= Self.maximumListEntries,
              !item.allowedTools.isEmpty,
              item.allowedTools.count <= Self.maximumListEntries,
              item.skillExposures.count <= Self.maximumListEntries,
              item.contextEstimateBytes > 0,
              item.contextEstimateBytes <= Self.maximumContextEstimateBytes,
              item.initialState == .planned,
              item.dependencyIDs == Array(Set(item.dependencyIDs)).sorted(),
              item.dependencyIDs.allSatisfy(FactoryTextRules.isStableID),
              item.criterionIDs == Array(Set(item.criterionIDs)).sorted(),
              item.criterionIDs.allSatisfy(FactoryTextRules.isStableID),
              item.allowedPaths == item.allowedPaths.sorted(),
              Set(item.allowedPaths.map(\.collisionKey)).count == item.allowedPaths.count,
              item.allowedTools == Array(Set(item.allowedTools)).sorted(),
              item.allowedTools.allSatisfy({ FactoryTextRules.isBoundedText($0, maximumScalars: 128) }),
              item.skillExposures.map(\.skillID) == item.skillExposures.map(\.skillID).sorted(),
              Set(item.skillExposures.map(\.skillID)).count == item.skillExposures.count,
              item.skillExposures.allSatisfy({ FactoryTextRules.isStableID($0.skillID) })
        else {
            throw FactoryValidationError(
                code: "invalid_work_item",
                message: "A work item must be bounded, unique, and owned.",
            )
        }
    }
}
