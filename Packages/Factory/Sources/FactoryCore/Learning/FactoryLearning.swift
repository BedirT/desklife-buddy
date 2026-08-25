import Foundation

public enum SkillOptAdapterStatus: String, Codable, Sendable {
    case buildCandidateMockOnly = "build-candidate-mock-only"
}

/// Pinned upstream SkillOpt integration policy. Provider calls and adoption unlock only after activation.
public struct SkillOptAdapterPolicy: Codable, Equatable, Sendable {
    public let allowProviderBackends: Bool
    public let automaticAdoption: Bool
    public let maximumEdits: Int
    public let package: String
    public let packageVersion: String
    public let status: SkillOptAdapterStatus
    public let upstreamCommit: GitObjectID
    public let upstreamRepository: String
    public let uvVersion: String

    public init(
        allowProviderBackends: Bool,
        automaticAdoption: Bool,
        maximumEdits: Int,
        package: String,
        packageVersion: String,
        status: SkillOptAdapterStatus,
        upstreamCommit: GitObjectID,
        upstreamRepository: String,
        uvVersion: String,
    ) {
        self.allowProviderBackends = allowProviderBackends
        self.automaticAdoption = automaticAdoption
        self.maximumEdits = maximumEdits
        self.package = package
        self.packageVersion = packageVersion
        self.status = status
        self.upstreamCommit = upstreamCommit
        self.upstreamRepository = upstreamRepository
        self.uvVersion = uvVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            allowProviderBackends: container.decode(Bool.self, forKey: .allowProviderBackends),
            automaticAdoption: container.decode(Bool.self, forKey: .automaticAdoption),
            maximumEdits: container.decode(Int.self, forKey: .maximumEdits),
            package: container.decode(String.self, forKey: .package),
            packageVersion: container.decode(String.self, forKey: .packageVersion),
            status: container.decode(SkillOptAdapterStatus.self, forKey: .status),
            upstreamCommit: container.decode(GitObjectID.self, forKey: .upstreamCommit),
            upstreamRepository: container.decode(String.self, forKey: .upstreamRepository),
            uvVersion: container.decode(String.self, forKey: .uvVersion),
        )
        try validate()
    }

    public static func factoryV1() throws -> SkillOptAdapterPolicy {
        try SkillOptAdapterPolicy(
            allowProviderBackends: false,
            automaticAdoption: false,
            maximumEdits: 4,
            package: "skillopt",
            packageVersion: "0.2.0",
            status: .buildCandidateMockOnly,
            upstreamCommit: GitObjectID(validating: "e4ea6a6771e797ef820cdd8bfea64c57e0481065"),
            upstreamRepository: "https://github.com/microsoft/SkillOpt",
            uvVersion: "0.7.13",
        )
    }

    public func validate() throws {
        guard !allowProviderBackends,
              !automaticAdoption,
              maximumEdits == 4,
              package == "skillopt",
              packageVersion == "0.2.0",
              status == .buildCandidateMockOnly,
              upstreamCommit.rawValue == "e4ea6a6771e797ef820cdd8bfea64c57e0481065",
              upstreamRepository == "https://github.com/microsoft/SkillOpt",
              uvVersion == "0.7.13"
        else {
            throw FactoryValidationError(
                code: "invalid-skillopt-policy",
                message: "The build-candidate SkillOpt adapter is exact-version, mock-only, bounded, and never auto-adopting.",
            )
        }
    }
}

public enum FactoryEpisodeOutcome: String, Codable, CaseIterable, Hashable, Sendable {
    case abortedOperator = "aborted-operator"
    case blockedOwner = "blocked-owner"
    case failure
    case success
}

/// Immutable outcome and exact component exposure for one completed or stopped run.
public struct FactoryEpisode: Codable, Equatable, Sendable {
    public let episodeID: String
    public let runID: String
    public let headSHA: GitObjectID
    public let contractSHA256: SHA256Digest
    public let routeID: String
    public let outcome: FactoryEpisodeOutcome
    public let componentExposureIDs: [String]
    public let skillExposureIDs: [String]
    public let incidentIDs: [String]

    public init(
        episodeID: String,
        runID: String,
        headSHA: GitObjectID,
        contractSHA256: SHA256Digest,
        routeID: String,
        outcome: FactoryEpisodeOutcome,
        componentExposureIDs: [String],
        skillExposureIDs: [String],
        incidentIDs: [String],
    ) {
        self.episodeID = episodeID
        self.runID = runID
        self.headSHA = headSHA
        self.contractSHA256 = contractSHA256
        self.routeID = routeID
        self.outcome = outcome
        self.componentExposureIDs = componentExposureIDs
        self.skillExposureIDs = skillExposureIDs
        self.incidentIDs = incidentIDs
    }

    public func validate() throws {
        let lists = [componentExposureIDs, skillExposureIDs, incidentIDs]
        guard FactoryTextRules.isStableID(episodeID),
              FactoryTextRules.isStableID(runID),
              FactoryTextRules.isStableID(routeID),
              !componentExposureIDs.isEmpty,
              lists.allSatisfy({ list in
                  list == list.sorted() && Set(list).count == list.count && list.allSatisfy(FactoryTextRules.isStableID)
              }),
              outcome != .failure || !incidentIDs.isEmpty
        else {
            throw FactoryValidationError(
                code: "invalid-factory-episode",
                message: "Episodes must preserve canonical outcome, exposure, incident, and immutable SHA bindings.",
            )
        }
    }
}

public struct FactoryEpisodeLedger: Codable, Equatable, Sendable {
    public let episodes: [FactoryEpisode]
    public let digest: SHA256Digest

    public init(episodes: [FactoryEpisode], digest: SHA256Digest) {
        self.episodes = episodes
        self.digest = digest
    }

    public static func harvest(_ input: some Sequence<FactoryEpisode>) throws -> FactoryEpisodeLedger {
        var byID: [String: FactoryEpisode] = [:]
        for episode in input {
            try episode.validate()
            if let existing = byID[episode.episodeID], existing != episode {
                throw FactoryValidationError(
                    code: "conflicting-factory-episode",
                    message: "An episode identity cannot be reused with different immutable content.",
                )
            }
            byID[episode.episodeID] = episode
        }
        let episodes = byID.values.sorted { $0.episodeID < $1.episodeID }
        guard !episodes.isEmpty else {
            throw FactoryValidationError(
                code: "empty-episode-ledger",
                message: "Learning requires at least one episode.",
            )
        }
        return FactoryEpisodeLedger(episodes: episodes, digest: CanonicalJSON.digest(episodes))
    }
}

public enum SkillAtomicEditOperation: String, Codable, CaseIterable, Hashable, Sendable {
    case add
    case delete
    case replace
}

/// One bounded semantic edit proposed by the reflection pass.
public struct SkillAtomicEdit: Codable, Equatable, Hashable, Sendable {
    public let operation: SkillAtomicEditOperation
    public let target: String
    public let replacement: String

    public init(operation: SkillAtomicEditOperation, target: String, replacement: String) {
        self.operation = operation
        self.target = target
        self.replacement = replacement
    }
}

public struct SkillOptimizationSample: Codable, Equatable, Sendable {
    public let sampleID: String
    public let episodeID: String
    public let targetComponentID: String
    public let outcome: FactoryEpisodeOutcome
    @RequiredNullable public var failureFingerprint: String?
    public let proposedEdits: [SkillAtomicEdit]

    public init(
        sampleID: String,
        episodeID: String,
        targetComponentID: String,
        outcome: FactoryEpisodeOutcome,
        failureFingerprint: String?,
        proposedEdits: [SkillAtomicEdit],
    ) {
        self.sampleID = sampleID
        self.episodeID = episodeID
        self.targetComponentID = targetComponentID
        self.outcome = outcome
        self.failureFingerprint = failureFingerprint
        self.proposedEdits = proposedEdits
    }
}

public enum FrozenSkillCandidateStatus: String, Codable, CaseIterable, Sendable {
    case frozenForEvaluation = "frozen-for-evaluation"
}

/// One-component SkillOpt-style candidate. Evaluation and promotion remain separate transactions.
public struct FrozenSkillCandidate: Codable, Equatable, Sendable {
    public let candidateID: String
    public let targetComponentID: String
    public let baselineSHA256: SHA256Digest
    public let priorRegressionID: String
    public let edits: [SkillAtomicEdit]
    public let status: FrozenSkillCandidateStatus
    public let maximumRevisionRounds: Int
    public let allowedPaths: [RepositoryPath]

    public init(
        candidateID: String,
        targetComponentID: String,
        baselineSHA256: SHA256Digest,
        priorRegressionID: String,
        edits: [SkillAtomicEdit],
        status: FrozenSkillCandidateStatus,
        maximumRevisionRounds: Int,
        allowedPaths: [RepositoryPath],
    ) {
        self.candidateID = candidateID
        self.targetComponentID = targetComponentID
        self.baselineSHA256 = baselineSHA256
        self.priorRegressionID = priorRegressionID
        self.edits = edits
        self.status = status
        self.maximumRevisionRounds = maximumRevisionRounds
        self.allowedPaths = allowedPaths
    }

    public func validate() throws {
        guard FactoryTextRules.isStableID(candidateID),
              FactoryTextRules.isStableID(targetComponentID),
              FactoryTextRules.isStableID(priorRegressionID),
              (1 ... 4).contains(edits.count),
              Set(edits).count == edits.count,
              status == .frozenForEvaluation,
              maximumRevisionRounds == 1,
              allowedPaths.count == 1,
              allowedPaths.allSatisfy({ !$0.isControlPlane })
        else {
            throw FactoryValidationError(
                code: "invalid-frozen-skill-candidate",
                message: "A frozen skill candidate is single-component, bounded, and cannot modify its evaluator or ruler.",
            )
        }
    }
}

/// Canonical CLI request for a single bounded reflection candidate.
public struct SkillFreezeRequest: Codable, Equatable, Sendable {
    public let candidateID: String
    public let targetComponentID: String
    public let baselineSHA256: SHA256Digest
    @RequiredNullable public var priorRegressionID: String?
    public let samples: [SkillOptimizationSample]

    public init(
        candidateID: String,
        targetComponentID: String,
        baselineSHA256: SHA256Digest,
        priorRegressionID: String?,
        samples: [SkillOptimizationSample],
    ) {
        self.candidateID = candidateID
        self.targetComponentID = targetComponentID
        self.baselineSHA256 = baselineSHA256
        self.priorRegressionID = priorRegressionID
        self.samples = samples
    }
}

public enum BoundedSkillOptimizer {
    public static func freeze(
        candidateID: String,
        targetComponentID: String,
        baselineSHA256: SHA256Digest,
        priorRegressionID: String?,
        samples: [SkillOptimizationSample],
    ) throws -> FrozenSkillCandidate {
        let relevant = samples.filter { $0.targetComponentID == targetComponentID }
        let hasSuccess = relevant.contains { $0.outcome == .success }
        let failures = relevant.filter { $0.outcome == .failure && $0.failureFingerprint?.isEmpty == false }
        guard FactoryTextRules.isStableID(candidateID),
              FactoryTextRules.isStableID(targetComponentID),
              let priorRegressionID,
              FactoryTextRules.isStableID(priorRegressionID),
              hasSuccess,
              !failures.isEmpty,
              relevant
              .allSatisfy({ FactoryTextRules.isStableID($0.sampleID) && FactoryTextRules.isStableID($0.episodeID) })
        else {
            throw FactoryValidationError(
                code: "unqualified-skill-reflection",
                message: "Skill reflection requires success contrast, attributed failure, and an earlier frozen regression.",
            )
        }

        let edits = Array(Set(failures.flatMap(\.proposedEdits)))
            .sorted {
                ($0.operation.rawValue, $0.target, $0.replacement)
                    < ($1.operation.rawValue, $1.target, $1.replacement)
            }
            .prefix(4)
        guard !edits.isEmpty,
              edits.allSatisfy({
                  FactoryTextRules.isBoundedText($0.target, maximumScalars: 512)
                      && ($0.operation == .delete || FactoryTextRules.isBoundedText(
                          $0.replacement,
                          maximumScalars: 2000,
                      ))
              })
        else {
            throw FactoryValidationError(
                code: "empty-skill-candidate",
                message: "A frozen candidate must contain one to four bounded atomic edits.",
            )
        }

        let stagingPath = try RepositoryPath(validating: "artifacts/factory-learning/\(candidateID).json")
        let candidate = FrozenSkillCandidate(
            candidateID: candidateID,
            targetComponentID: targetComponentID,
            baselineSHA256: baselineSHA256,
            priorRegressionID: priorRegressionID,
            edits: Array(edits),
            status: .frozenForEvaluation,
            maximumRevisionRounds: 1,
            allowedPaths: [stagingPath],
        )
        try candidate.validate()
        return candidate
    }
}
