import Foundation

/// Agent clients that share one repository-owned skill portfolio.
public enum FactoryClient: String, Codable, CaseIterable, Comparable, Sendable {
    case claude
    case codex
    case pi

    public static func < (lhs: FactoryClient, rhs: FactoryClient) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Cross-client qualification status recorded without provider credentials.
public enum ClientQualificationStatus: String, Codable, Sendable {
    case failed
    case passed
    case pending
    case unqualified
}

/// Exact client/model identity and result for one frozen qualification report.
public struct ClientQualification: Codable, Equatable, Sendable {
    public let clientID: FactoryClient
    @RequiredNullable public var clientVersion: String?
    @RequiredNullable public var modelID: String?
    public let status: ClientQualificationStatus

    public init(
        clientID: FactoryClient,
        clientVersion: String?,
        modelID: String?,
        status: ClientQualificationStatus,
    ) {
        self.clientID = clientID
        self.clientVersion = clientVersion
        self.modelID = modelID
        self.status = status
    }
}

/// Origin and reuse terms for one repository-managed skill.
public struct SkillProvenance: Codable, Equatable, Sendable {
    public enum Introduction: String, Codable, Sendable {
        case inheritedAtBase = "inherited-at-base"
        case introducedInCurrentChange = "introduced-in-current-change"
    }

    public enum Kind: String, Codable, Sendable {
        case repositoryAuthored = "repository-authored"
        case repositoryInherited = "repository-inherited"
    }

    public let introduction: Introduction
    public let kind: Kind
    public let license: String
    public let repositoryPath: RepositoryPath
    @RequiredNullable public var sourceCommit: GitObjectID?
    @RequiredNullable public var upstreamPin: String?

    public init(
        introduction: Introduction,
        kind: Kind,
        license: String,
        repositoryPath: RepositoryPath,
        sourceCommit: GitObjectID?,
        upstreamPin: String?,
    ) {
        self.introduction = introduction
        self.kind = kind
        self.license = license
        self.repositoryPath = repositoryPath
        self.sourceCommit = sourceCommit
        self.upstreamPin = upstreamPin
    }
}

/// Content-addressed file resource beneath a skill's single source directory.
public struct SkillResourceManifest: Codable, Equatable, Sendable {
    public let path: RepositoryPath
    public let sha256: SHA256Digest
    public let sizeBytes: Int

    public init(path: RepositoryPath, sha256: SHA256Digest, sizeBytes: Int) {
        self.path = path
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}

/// Progressive-disclosure byte ceiling declared before a client launch.
public struct SkillContextBudget: Codable, Equatable, Sendable {
    public let bodyBytes: Int
    public let metadataBytes: Int
    public let referenceBytes: Int
    public let resourceBytes: Int
    public let totalBytes: Int

    public init(
        bodyBytes: Int,
        metadataBytes: Int,
        referenceBytes: Int,
        resourceBytes: Int,
        totalBytes: Int,
    ) {
        self.bodyBytes = bodyBytes
        self.metadataBytes = metadataBytes
        self.referenceBytes = referenceBytes
        self.resourceBytes = resourceBytes
        self.totalBytes = totalBytes
    }
}

/// Maximum context and tool use attributable to one skill exposure.
public struct SkillCostCeiling: Codable, Equatable, Sendable {
    public let maxContextTokens: Int
    public let maxToolCalls: Int

    public init(maxContextTokens: Int, maxToolCalls: Int) {
        self.maxContextTokens = maxContextTokens
        self.maxToolCalls = maxToolCalls
    }
}

/// Minimum positive and confusable-negative trigger corpus for one skill.
public struct SkillTriggerFixtureIDs: Codable, Equatable, Sendable {
    public let negative: [String]
    public let positive: [String]

    public init(negative: [String], positive: [String]) {
        self.negative = negative
        self.positive = positive
    }
}

/// Risk vocabulary specific to skill routing and control-plane work.
public enum SkillRiskTier: String, Codable, CaseIterable, Sendable {
    case controlPlane = "control-plane"
    case high
    case low
    case medium
}

/// Canonical ownership, provenance, routing, budget, and qualification record for one skill.
public struct SkillManifest: Codable, Equatable, Sendable {
    public let allowedTools: [String]
    public let clientQualification: [ClientQualification]
    public let conflictsWith: [String]
    public let contextBudget: SkillContextBudget
    public let declaredCostCeiling: SkillCostCeiling
    public let dependencySkillIDs: [String]
    public let expectedInputs: [String]
    public let expectedOutputs: [String]
    public let handoffSkillIDs: [String]
    public let id: String
    public let nonCapabilities: [String]
    public let owner: String
    public let prerequisites: [String]
    public let primaryCapabilityID: String
    public let progressiveDisclosurePaths: [RepositoryPath]
    public let provenance: SkillProvenance
    public let publicEvalTags: [String]
    public let qualificationPath: RepositoryPath
    public let qualificationSHA256: SHA256Digest
    public let resources: [SkillResourceManifest]
    public let riskTiers: [SkillRiskTier]
    @RequiredNullable public var rollbackPredecessor: SHA256Digest?
    public let sealedPartitionID: String
    public let sourcePath: RepositoryPath
    public let sourceSHA256: SHA256Digest
    public let status: SkillLifecycleStatus
    public let supersedes: [String]
    public let supportedPhases: [String]
    public let supportedRoles: [String]
    public let triggerFixtureIDs: SkillTriggerFixtureIDs
    public let verificationCommand: String
    public let version: Int

    public init(
        allowedTools: [String],
        clientQualification: [ClientQualification],
        conflictsWith: [String],
        contextBudget: SkillContextBudget,
        declaredCostCeiling: SkillCostCeiling,
        dependencySkillIDs: [String],
        expectedInputs: [String],
        expectedOutputs: [String],
        handoffSkillIDs: [String],
        id: String,
        nonCapabilities: [String],
        owner: String,
        prerequisites: [String],
        primaryCapabilityID: String,
        progressiveDisclosurePaths: [RepositoryPath],
        provenance: SkillProvenance,
        publicEvalTags: [String],
        qualificationPath: RepositoryPath,
        qualificationSHA256: SHA256Digest,
        resources: [SkillResourceManifest],
        riskTiers: [SkillRiskTier],
        rollbackPredecessor: SHA256Digest?,
        sealedPartitionID: String,
        sourcePath: RepositoryPath,
        sourceSHA256: SHA256Digest,
        status: SkillLifecycleStatus,
        supersedes: [String],
        supportedPhases: [String],
        supportedRoles: [String],
        triggerFixtureIDs: SkillTriggerFixtureIDs,
        verificationCommand: String,
        version: Int,
    ) {
        self.allowedTools = allowedTools
        self.clientQualification = clientQualification
        self.conflictsWith = conflictsWith
        self.contextBudget = contextBudget
        self.declaredCostCeiling = declaredCostCeiling
        self.dependencySkillIDs = dependencySkillIDs
        self.expectedInputs = expectedInputs
        self.expectedOutputs = expectedOutputs
        self.handoffSkillIDs = handoffSkillIDs
        self.id = id
        self.nonCapabilities = nonCapabilities
        self.owner = owner
        self.prerequisites = prerequisites
        self.primaryCapabilityID = primaryCapabilityID
        self.progressiveDisclosurePaths = progressiveDisclosurePaths
        self.provenance = provenance
        self.publicEvalTags = publicEvalTags
        self.qualificationPath = qualificationPath
        self.qualificationSHA256 = qualificationSHA256
        self.resources = resources
        self.riskTiers = riskTiers
        self.rollbackPredecessor = rollbackPredecessor
        self.sealedPartitionID = sealedPartitionID
        self.sourcePath = sourcePath
        self.sourceSHA256 = sourceSHA256
        self.status = status
        self.supersedes = supersedes
        self.supportedPhases = supportedPhases
        self.supportedRoles = supportedRoles
        self.triggerFixtureIDs = triggerFixtureIDs
        self.verificationCommand = verificationCommand
        self.version = version
    }
}

/// Complete managed-skill inventory; legacy content is visible but nonqualifying.
public struct SkillRegistry: Codable, Equatable, Sendable {
    private static let maximumSkills = 256
    private static let maximumListEntries = 256
    private static let maximumContextBytes = 16 * 1024 * 1024
    private static let maximumContextTokens = 1_000_000
    private static let maximumToolCalls = 100_000

    public let portfolioStatus: String
    public let schemaVersion: Int
    public let skills: [SkillManifest]

    public init(
        portfolioStatus: String,
        schemaVersion: Int = FactoryCore.schemaVersion,
        skills: [SkillManifest],
    ) {
        self.portfolioStatus = portfolioStatus
        self.schemaVersion = schemaVersion
        self.skills = skills
    }

    /// Rejects ambiguous ownership, discoverable provisional content, stale references, and unbounded context.
    public func validate() throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              portfolioStatus == "legacy-migration-required",
              !skills.isEmpty,
              skills.count <= Self.maximumSkills,
              skills.map(\.id) == skills.map(\.id).sorted()
        else {
            throw FactoryValidationError(
                code: "invalid_skill_registry",
                message: "The skill registry status, ordering, or version is invalid.",
            )
        }
        let ids = skills.map(\.id)
        guard Set(ids).count == ids.count,
              Set(ids.map { $0.lowercased() }).count == ids.count
        else {
            throw FactoryValidationError(
                code: "duplicate_skill_id",
                message: "Skill IDs must be unique on macOS filesystems.",
            )
        }
        let byID = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0) })
        var capabilities: Set<String> = []
        for skill in skills {
            try validate(skill, registry: byID)
            guard capabilities.insert(skill.primaryCapabilityID).inserted else {
                throw FactoryValidationError(
                    code: "ambiguous_skill_capability",
                    message: "Every capability has one primary owner.",
                )
            }
        }
        try validateActiveDependencies(byID: byID)
    }

    private func validate(_ skill: SkillManifest, registry: [String: SkillManifest]) throws {
        let stableID = /^[a-z0-9][a-z0-9.-]{0,127}$/
        let sourceRoot = try RepositoryPath(validating: ".agents/skills/\(skill.id)")
        let probationRoot = try RepositoryPath(validating: ".factory/skills/probation/\(skill.id)")
        let expectedQualification = ".factory/skills/qualification/\(skill.id).json"
        let lists = [
            skill.allowedTools,
            skill.conflictsWith,
            skill.dependencySkillIDs,
            skill.expectedInputs,
            skill.expectedOutputs,
            skill.handoffSkillIDs,
            skill.nonCapabilities,
            skill.prerequisites,
            skill.publicEvalTags,
            skill.supersedes,
            skill.supportedPhases,
            skill.supportedRoles,
            skill.triggerFixtureIDs.negative,
            skill.triggerFixtureIDs.positive,
        ]
        let context = skill.contextBudget
        let computedContextBytes = try validatedContextBytes(context)
        let computedResourceBytes = try validatedResourceBytes(skill.resources)
        let riskTierIDs = skill.riskTiers.map(\.rawValue)
        let sourceMatchesStatus = isSourcePathAllowed(
            for: skill,
            sourceRoot: sourceRoot,
            probationRoot: probationRoot,
        )
        guard skill.id.wholeMatch(of: stableID) != nil,
              skill.primaryCapabilityID.wholeMatch(of: stableID) != nil,
              skill.version > 0,
              sourceMatchesStatus,
              skill.qualificationPath.rawValue == expectedQualification,
              !skill.owner.isEmpty,
              !skill.provenance.license.isEmpty,
              !skill.allowedTools.isEmpty,
              !skill.expectedInputs.isEmpty,
              !skill.expectedOutputs.isEmpty,
              !skill.nonCapabilities.isEmpty,
              !skill.riskTiers.isEmpty,
              !skill.supportedPhases.isEmpty,
              !skill.supportedRoles.isEmpty,
              !skill.sealedPartitionID.isEmpty,
              !skill.verificationCommand.isEmpty,
              skill.triggerFixtureIDs.negative.count >= 3,
              skill.triggerFixtureIDs.positive.count >= 3,
              lists.allSatisfy({ list in
                  list.count <= Self.maximumListEntries
                      && list == Array(Set(list)).sorted()
                      && list.allSatisfy { FactoryTextRules.isBoundedText($0, maximumScalars: 256) }
              }),
              skill.dependencySkillIDs.allSatisfy({ registry[$0] != nil && $0 != skill.id }),
              skill.handoffSkillIDs.allSatisfy({ registry[$0] != nil && $0 != skill.id }),
              skill.conflictsWith.allSatisfy({ registry[$0] != nil && $0 != skill.id }),
              context.bodyBytes > 0,
              context.metadataBytes > 0,
              context.totalBytes == computedContextBytes,
              context.totalBytes <= Self.maximumContextBytes,
              skill.declaredCostCeiling.maxContextTokens > 0,
              skill.declaredCostCeiling.maxContextTokens <= Self.maximumContextTokens,
              skill.declaredCostCeiling.maxToolCalls >= 0,
              skill.declaredCostCeiling.maxToolCalls <= Self.maximumToolCalls,
              skill.clientQualification.map(\.clientID) == FactoryClient.allCases.sorted(),
              skill.clientQualification.allSatisfy({ qualification in
                  (qualification.clientVersion.map {
                      FactoryTextRules.isBoundedText($0, maximumScalars: 256)
                  } ?? true)
                      && (qualification.modelID.map {
                          FactoryTextRules.isBoundedText($0, maximumScalars: 256)
                      } ?? true)
              }),
              riskTierIDs == Array(Set(riskTierIDs)).sorted(),
              skill.progressiveDisclosurePaths.count <= Self.maximumListEntries,
              skill.progressiveDisclosurePaths == skill.progressiveDisclosurePaths.sorted(),
              Set(skill.progressiveDisclosurePaths.map(\.collisionKey)).count == skill.progressiveDisclosurePaths.count,
              skill.progressiveDisclosurePaths.allSatisfy({ $0.isWithin(sourceRoot) || $0.isWithin(probationRoot) }),
              skill.resources.map(\.path) == skill.resources.map(\.path).sorted(),
              skill.resources.count <= Self.maximumListEntries,
              Set(skill.resources.map(\.path.collisionKey)).count == skill.resources.count,
              computedResourceBytes <= context.resourceBytes,
              skill.resources.allSatisfy({ resource in
                  resource.path.isWithin(sourceRoot) || resource.path.isWithin(probationRoot)
              })
        else {
            throw FactoryValidationError(
                code: "invalid_skill_manifest",
                message: "A skill manifest is incomplete, ambiguous, or over budget.",
            )
        }
        if skill.status == .active {
            guard skill.clientQualification.allSatisfy({
                $0.status == .passed && $0.clientVersion != nil && $0.modelID != nil
            }) else {
                throw FactoryValidationError(
                    code: "incomplete_skill_qualification",
                    message: "Active skills require frozen Codex, Claude, and Pi evidence.",
                )
            }
        }
    }

    private func isSourcePathAllowed(
        for skill: SkillManifest,
        sourceRoot: RepositoryPath,
        probationRoot: RepositoryPath,
    ) -> Bool {
        switch skill.status {
        case .legacy, .active:
            skill.sourcePath.rawValue == "\(sourceRoot.rawValue)/SKILL.md"
        case .candidate, .probation:
            skill.sourcePath.rawValue == "\(probationRoot.rawValue)/SKILL.md"
        case .deprecated, .quarantined:
            skill.sourcePath.isWithin(sourceRoot) || skill.sourcePath.isWithin(probationRoot)
        }
    }

    private func validatedContextBytes(_ context: SkillContextBudget) throws -> Int {
        var total = 0
        for bytes in [context.bodyBytes, context.metadataBytes, context.referenceBytes, context.resourceBytes] {
            let (next, overflow) = total.addingReportingOverflow(bytes)
            guard bytes >= 0, !overflow else {
                throw FactoryValidationError(
                    code: "invalid_skill_manifest",
                    message: "A skill context budget overflowed its fixed ceiling.",
                )
            }
            total = next
        }
        return total
    }

    private func validatedResourceBytes(_ resources: [SkillResourceManifest]) throws -> Int {
        var total = 0
        for resource in resources {
            let (next, overflow) = total.addingReportingOverflow(resource.sizeBytes)
            guard resource.sizeBytes >= 0, !overflow else {
                throw FactoryValidationError(
                    code: "invalid_skill_manifest",
                    message: "A skill resource budget overflowed its fixed ceiling.",
                )
            }
            total = next
        }
        return total
    }

    private func validateActiveDependencies(byID: [String: SkillManifest]) throws {
        let active = Set(skills.filter { $0.status == .active }.map(\.id))
        guard active.allSatisfy({ id in
            guard let skill = byID[id] else { return false }
            return skill.dependencySkillIDs.allSatisfy(active.contains)
                && skill.handoffSkillIDs.allSatisfy(active.contains)
        }) else {
            throw FactoryValidationError(
                code: "inactive_skill_dependency",
                message: "Active routes may compose only active skills.",
            )
        }
        var visiting: Set<String> = []
        var visited: Set<String> = []
        func visit(_ id: String) throws {
            if visited.contains(id) { return }
            guard visiting.insert(id).inserted else {
                throw FactoryValidationError(
                    code: "skill_dependency_cycle",
                    message: "Skill dependencies must be acyclic.",
                )
            }
            for dependency in byID[id]?.dependencySkillIDs.sorted() ?? [] {
                try visit(dependency)
            }
            visiting.remove(id)
            visited.insert(id)
        }
        for id in active.sorted() {
            try visit(id)
        }
    }
}

/// Deterministic inputs used to choose the minimum active skill set.
public struct SkillRouteRequest: Codable, Equatable, Sendable {
    public let role: String
    public let phase: String
    public let risk: SkillRiskTier
    public let capabilityIDs: [String]

    public init(role: String, phase: String, risk: SkillRiskTier, capabilityIDs: [String]) {
        self.role = role
        self.phase = phase
        self.risk = risk
        self.capabilityIDs = capabilityIDs
    }
}

/// Pure capability router that never exposes legacy or provisional content.
public enum SkillRouter {
    public static func select(request: SkillRouteRequest, registry: SkillRegistry) throws -> [SkillManifest] {
        try registry.validate()
        guard !request.role.isEmpty,
              !request.phase.isEmpty,
              !request.capabilityIDs.isEmpty,
              Set(request.capabilityIDs).count == request.capabilityIDs.count
        else {
            throw FactoryValidationError(
                code: "invalid_skill_route",
                message: "A route needs a role, phase, and unique capabilities.",
            )
        }
        let byID = Dictionary(uniqueKeysWithValues: registry.skills.map { ($0.id, $0) })
        let byCapability = Dictionary(uniqueKeysWithValues: registry.skills.map { ($0.primaryCapabilityID, $0.id) })
        var selected: Set<String> = []
        var ordered: [SkillManifest] = []

        func append(_ id: String) throws {
            guard let skill = byID[id], skill.status == .active else {
                throw FactoryValidationError(
                    code: "skill_not_active",
                    message: "Only active skills may enter a qualifying route.",
                )
            }
            if selected.contains(id) { return }
            for dependency in skill.dependencySkillIDs.sorted() {
                try append(dependency)
            }
            selected.insert(id)
            ordered.append(skill)
        }

        for capability in request.capabilityIDs.sorted() {
            guard let id = byCapability[capability],
                  let skill = byID[id],
                  skill.status == .active,
                  skill.supportedRoles.contains(request.role),
                  skill.supportedPhases.contains(request.phase),
                  skill.riskTiers.contains(request.risk)
            else {
                throw FactoryValidationError(
                    code: "missing_skill_capability",
                    message: "No active skill qualifies for the requested route.",
                )
            }
            try append(id)
        }
        for skill in ordered {
            guard skill.conflictsWith.allSatisfy({ !selected.contains($0) }) else {
                throw FactoryValidationError(
                    code: "conflicting_skill_route",
                    message: "The route selects conflicting skills.",
                )
            }
        }
        return ordered
    }
}
