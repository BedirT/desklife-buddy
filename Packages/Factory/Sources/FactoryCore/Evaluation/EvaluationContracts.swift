import Foundation

/// Private evaluation partitions whose ancestry and query ledgers never mix.
public enum EvaluationPartition: String, Codable, Sendable {
    case sealed
    case selection
}

/// Candidate byte classes accepted by the frozen Evolution ruler.
public enum EvaluationCandidateKind: String, Codable, Hashable, Sendable {
    case declarativeRouting = "declarative-routing"
    case instruction
}

/// Public component class carried by an evaluation request.
public enum EvaluationComponentKind: String, Codable, Sendable {
    case contextRoute = "context-route"
    case prompt
    case rubric
    case skillInstruction = "skill-instruction"

    var policyKind: EvaluationCandidateKind {
        switch self {
        case .contextRoute: .declarativeRouting
        case .prompt, .rubric, .skillInstruction: .instruction
        }
    }
}

/// Stable schema identity represented as a canonical array element, never a dictionary.
public struct SchemaDigest: Codable, Equatable, Hashable, Sendable {
    public let schemaID: String
    public let sha256: SHA256Digest

    public init(schemaID: String, sha256: SHA256Digest) {
        self.schemaID = schemaID
        self.sha256 = sha256
    }
}

/// Frozen private epoch identity referenced without exposing any case.
public struct EvaluationEpoch: Codable, Equatable, Sendable {
    public let epochID: String
    public let partition: EvaluationPartition
    public let sha256: SHA256Digest

    public init(epochID: String, partition: EvaluationPartition, sha256: SHA256Digest) {
        self.epochID = epochID
        self.partition = partition
        self.sha256 = sha256
    }
}

/// One Evolution component's immutable scope, schema, and evidence ruler.
public struct EvolutionComponentAcceptance: Codable, Equatable, Sendable {
    public let allowedCandidateKinds: [EvaluationCandidateKind]
    public let allowedClientIDs: [String]
    public let allowedModelIDs: [String]
    public let allowedPaths: [RepositoryPath]
    public let baseComponentSHA256: SHA256Digest
    public let budgetSHA256: SHA256Digest
    public let componentID: String
    public let maximumCandidateBytes: Int
    public let maximumChangedPaths: Int
    public let requiredEvidence: [EvaluationEvidenceRequirement]
    public let requiredSchemaDigests: [SchemaDigest]
    public let strataSHA256: SHA256Digest

    public init(
        allowedCandidateKinds: [EvaluationCandidateKind],
        allowedClientIDs: [String],
        allowedModelIDs: [String],
        allowedPaths: [RepositoryPath],
        baseComponentSHA256: SHA256Digest,
        budgetSHA256: SHA256Digest,
        componentID: String,
        maximumCandidateBytes: Int,
        maximumChangedPaths: Int,
        requiredEvidence: [EvaluationEvidenceRequirement],
        requiredSchemaDigests: [SchemaDigest],
        strataSHA256: SHA256Digest,
    ) {
        self.allowedCandidateKinds = allowedCandidateKinds
        self.allowedClientIDs = allowedClientIDs
        self.allowedModelIDs = allowedModelIDs
        self.allowedPaths = allowedPaths
        self.baseComponentSHA256 = baseComponentSHA256
        self.budgetSHA256 = budgetSHA256
        self.componentID = componentID
        self.maximumCandidateBytes = maximumCandidateBytes
        self.maximumChangedPaths = maximumChangedPaths
        self.requiredEvidence = requiredEvidence
        self.requiredSchemaDigests = requiredSchemaDigests
        self.strataSHA256 = strataSHA256
    }
}

/// Owner-merged trusted root ruler that Evolution may narrow but never replace.
public struct EvolutionAcceptancePolicy: Codable, Equatable, Sendable {
    public let components: [EvolutionComponentAcceptance]
    public let evaluatorSHA256: SHA256Digest
    public let maximumSelectionQueries: Int
    public let minimumPassRate: Double
    public let schemaVersion: Int
    public let sealedEpoch: EvaluationEpoch
    public let selectionEpoch: EvaluationEpoch
    public let trustedRootSHA: GitObjectID

    public init(
        components: [EvolutionComponentAcceptance],
        evaluatorSHA256: SHA256Digest,
        maximumSelectionQueries: Int,
        minimumPassRate: Double,
        schemaVersion: Int = FactoryCore.schemaVersion,
        sealedEpoch: EvaluationEpoch,
        selectionEpoch: EvaluationEpoch,
        trustedRootSHA: GitObjectID,
    ) throws {
        self.components = components
        self.evaluatorSHA256 = evaluatorSHA256
        self.maximumSelectionQueries = maximumSelectionQueries
        self.minimumPassRate = minimumPassRate
        self.schemaVersion = schemaVersion
        self.sealedEpoch = sealedEpoch
        self.selectionEpoch = selectionEpoch
        self.trustedRootSHA = trustedRootSHA
        try validateStructure()
    }

    public init(from decoder: Decoder) throws {
        let value = try StoredPolicy(from: decoder)
        try self.init(
            components: value.components,
            evaluatorSHA256: value.evaluatorSHA256,
            maximumSelectionQueries: value.maximumSelectionQueries,
            minimumPassRate: value.minimumPassRate,
            schemaVersion: value.schemaVersion,
            sealedEpoch: value.sealedEpoch,
            selectionEpoch: value.selectionEpoch,
            trustedRootSHA: value.trustedRootSHA,
        )
    }

    public func encode(to encoder: Encoder) throws {
        try StoredPolicy(
            components: components,
            evaluatorSHA256: evaluatorSHA256,
            maximumSelectionQueries: maximumSelectionQueries,
            minimumPassRate: minimumPassRate,
            schemaVersion: schemaVersion,
            sealedEpoch: sealedEpoch,
            selectionEpoch: selectionEpoch,
            trustedRootSHA: trustedRootSHA,
        ).encode(to: encoder)
    }

    /// Canonical identity used to prove the evaluator did not trust PR-head policy.
    public var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }

    /// Validates one content-addressed candidate request against the trusted acceptance ceiling.
    public func validate(_ request: EvaluationRequest) throws {
        try request.validateStructure()
        guard request.schemaVersion == schemaVersion,
              request.trustedBaseSHA == trustedRootSHA,
              request.policySHA256 == digest,
              request.evaluatorSHA256 == evaluatorSHA256,
              request.candidateSHA256 == request.payloadRef.sha256,
              request.payloadRef.sizeBytes > 0,
              request.queryOrdinal > 0
        else {
            throw FactoryValidationError(
                code: "evaluation_request_mismatch",
                message: "The request is stale, malformed, or bound to another ruler.",
            )
        }

        guard let component = components.first(where: { $0.componentID == request.candidateComponentID }),
              component.allowedCandidateKinds.contains(request.componentKind.policyKind),
              component.allowedClientIDs.contains(request.clientID),
              component.allowedModelIDs.contains(request.modelID),
              request.baseComponentSHA256 == component.baseComponentSHA256,
              request.budgetSHA256 == component.budgetSHA256,
              request.strataSHA256 == component.strataSHA256,
              request.payloadRef.sizeBytes <= component.maximumCandidateBytes,
              !request.changedPaths.isEmpty,
              request.changedPaths.count <= component.maximumChangedPaths,
              request.changedPaths == request.changedPaths.sorted(),
              Set(request.changedPaths.map(\.collisionKey)).count == request.changedPaths.count,
              request.changedPaths.allSatisfy({ path in
                  component.allowedPaths.contains(where: { path.isWithin($0) })
              }),
              request.schemaDigests == component.requiredSchemaDigests,
              request.evidence.map({ EvaluationEvidenceRequirement(kind: $0.kind, sha256: $0.sha256) }) == component
              .requiredEvidence,
              request.evidence.allSatisfy({ $0.provenAtHeadSHA == request.candidateHeadSHA })
        else {
            throw FactoryValidationError(
                code: "evaluation_scope_mismatch",
                message: "Candidate scope, schema, or evidence exceeds trusted root acceptance.",
            )
        }

        let expectedEpoch = request.partition == .selection ? selectionEpoch : sealedEpoch
        guard request.epoch == expectedEpoch.epochID,
              request.epochSHA256 == expectedEpoch.sha256
        else {
            throw FactoryValidationError(
                code: "evaluation_epoch_mismatch",
                message: "The request targets another partition or epoch.",
            )
        }
        switch request.partition {
        case .selection:
            guard request.queryOrdinal <= maximumSelectionQueries else {
                throw FactoryValidationError(
                    code: "selection_query_budget",
                    message: "Selection revision budget is exhausted.",
                )
            }
        case .sealed:
            guard request.queryOrdinal == 1, request.frozen else {
                throw FactoryValidationError(
                    code: "sealed_candidate_not_frozen",
                    message: "Sealed evaluation is one query after freeze.",
                )
            }
        }
    }

    private func validateStructure() throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              selectionEpoch.partition == .selection,
              sealedEpoch.partition == .sealed,
              FactoryTextRules.isStableID(selectionEpoch.epochID),
              FactoryTextRules.isStableID(sealedEpoch.epochID),
              selectionEpoch.epochID != sealedEpoch.epochID,
              selectionEpoch.sha256 != sealedEpoch.sha256,
              maximumSelectionQueries > 0,
              minimumPassRate > 0,
              minimumPassRate <= 1,
              !components.isEmpty,
              components.map(\.componentID) == components.map(\.componentID).sorted(),
              Set(components.map(\.componentID)).count == components.count,
              components.allSatisfy({ component in
                  FactoryTextRules.isStableID(component.componentID)
                      && !component.allowedCandidateKinds.isEmpty
                      && component.allowedCandidateKinds == Array(Set(component.allowedCandidateKinds))
                      .sorted(by: { $0.rawValue < $1.rawValue })
                      && !component.allowedClientIDs.isEmpty
                      && component.allowedClientIDs == Array(Set(component.allowedClientIDs)).sorted()
                      && component.allowedClientIDs.allSatisfy {
                          FactoryTextRules.isBoundedText($0, maximumScalars: 128)
                      }
                      && !component.allowedModelIDs.isEmpty
                      && component.allowedModelIDs == Array(Set(component.allowedModelIDs)).sorted()
                      && component.allowedModelIDs.allSatisfy {
                          FactoryTextRules.isBoundedText($0, maximumScalars: 256)
                      }
                      && !component.allowedPaths.isEmpty
                      && component.allowedPaths == component.allowedPaths.sorted()
                      && Set(component.allowedPaths.map(\.collisionKey)).count == component.allowedPaths.count
                      && component.maximumCandidateBytes > 0
                      && component.maximumChangedPaths > 0
                      && !component.requiredEvidence.isEmpty
                      && component.requiredEvidence.map(\.kind) == component.requiredEvidence.map(\.kind).sorted()
                      && Set(component.requiredEvidence.map(\.kind)).count == component.requiredEvidence.count
                      && component.requiredEvidence.allSatisfy { FactoryTextRules.isStableID($0.kind) }
                      && !component.requiredSchemaDigests.isEmpty
                      && component.requiredSchemaDigests.map(\.schemaID) == component.requiredSchemaDigests
                      .map(\.schemaID).sorted()
                      && Set(component.requiredSchemaDigests.map(\.schemaID)).count == component.requiredSchemaDigests
                      .count
                      && component.requiredSchemaDigests.allSatisfy {
                          FactoryTextRules.isStableID($0.schemaID)
                      }
              })
        else {
            throw FactoryValidationError(
                code: "invalid_evolution_policy",
                message: "Evolution acceptance must be complete, unique, canonical, and bounded.",
            )
        }
    }

    private struct StoredPolicy: Codable {
        let components: [EvolutionComponentAcceptance]
        let evaluatorSHA256: SHA256Digest
        let maximumSelectionQueries: Int
        let minimumPassRate: Double
        let schemaVersion: Int
        let sealedEpoch: EvaluationEpoch
        let selectionEpoch: EvaluationEpoch
        let trustedRootSHA: GitObjectID
    }
}

/// Trusted evidence identity required by a component ruler.
public struct EvaluationEvidenceRequirement: Codable, Equatable, Sendable {
    public let kind: String
    public let sha256: SHA256Digest

    public init(kind: String, sha256: SHA256Digest) {
        self.kind = kind
        self.sha256 = sha256
    }
}

/// SHA-bound evidence input used by the aggregate evaluator.
public struct EvaluationEvidenceReference: Codable, Equatable, Sendable {
    public let kind: String
    public let provenAtHeadSHA: GitObjectID
    public let sha256: SHA256Digest

    public init(kind: String, provenAtHeadSHA: GitObjectID, sha256: SHA256Digest) {
        self.kind = kind
        self.provenAtHeadSHA = provenAtHeadSHA
        self.sha256 = sha256
    }
}

/// Media classes that a data-only evaluator may load from a content-addressed store.
public enum EvaluationPayloadMediaType: String, Codable, Sendable {
    case json = "application/json"
    case markdown = "text/markdown"
    case text = "text/plain"
}

/// Candidate content identity carried in place of candidate bytes.
public struct EvaluationPayloadReference: Codable, Equatable, Sendable {
    public let mediaType: EvaluationPayloadMediaType
    public let sha256: SHA256Digest
    public let sizeBytes: Int

    public init(mediaType: EvaluationPayloadMediaType, sha256: SHA256Digest, sizeBytes: Int) {
        self.mediaType = mediaType
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}

/// Inert candidate bindings dispatched to the trusted evaluator.
public struct EvaluationRequest: Codable, Equatable, Sendable {
    public let baseComponentSHA256: SHA256Digest
    public let budgetSHA256: SHA256Digest
    public let candidateComponentID: String
    public let candidateHeadSHA: GitObjectID
    public let candidateSHA256: SHA256Digest
    public let changedPaths: [RepositoryPath]
    public let clientID: String
    public let componentKind: EvaluationComponentKind
    public let epoch: String
    public let epochSHA256: SHA256Digest
    public let evaluatorSHA256: SHA256Digest
    public let evidence: [EvaluationEvidenceReference]
    public let frozen: Bool
    public let modelID: String
    public let nonce: String
    public let partition: EvaluationPartition
    public let payloadRef: EvaluationPayloadReference
    public let policySHA256: SHA256Digest
    public let queryOrdinal: Int
    public let requestID: String
    public let schemaDigests: [SchemaDigest]
    public let schemaVersion: Int
    public let strataSHA256: SHA256Digest
    public let trustedBaseSHA: GitObjectID

    public init(
        baseComponentSHA256: SHA256Digest,
        budgetSHA256: SHA256Digest,
        candidateComponentID: String,
        candidateHeadSHA: GitObjectID,
        candidateSHA256: SHA256Digest,
        changedPaths: [RepositoryPath],
        clientID: String,
        componentKind: EvaluationComponentKind,
        epoch: String,
        epochSHA256: SHA256Digest,
        evaluatorSHA256: SHA256Digest,
        evidence: [EvaluationEvidenceReference],
        frozen: Bool,
        modelID: String,
        nonce: String,
        partition: EvaluationPartition,
        payloadRef: EvaluationPayloadReference,
        policySHA256: SHA256Digest,
        queryOrdinal: Int,
        requestID: String,
        schemaDigests: [SchemaDigest],
        schemaVersion: Int = FactoryCore.schemaVersion,
        strataSHA256: SHA256Digest,
        trustedBaseSHA: GitObjectID,
    ) {
        self.baseComponentSHA256 = baseComponentSHA256
        self.budgetSHA256 = budgetSHA256
        self.candidateComponentID = candidateComponentID
        self.candidateHeadSHA = candidateHeadSHA
        self.candidateSHA256 = candidateSHA256
        self.changedPaths = changedPaths
        self.clientID = clientID
        self.componentKind = componentKind
        self.epoch = epoch
        self.epochSHA256 = epochSHA256
        self.evaluatorSHA256 = evaluatorSHA256
        self.evidence = evidence
        self.frozen = frozen
        self.modelID = modelID
        self.nonce = nonce
        self.partition = partition
        self.payloadRef = payloadRef
        self.policySHA256 = policySHA256
        self.queryOrdinal = queryOrdinal
        self.requestID = requestID
        self.schemaDigests = schemaDigests
        self.schemaVersion = schemaVersion
        self.strataSHA256 = strataSHA256
        self.trustedBaseSHA = trustedBaseSHA
    }

    /// Canonical request identity included in the signed aggregate.
    public var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }

    func validateStructure() throws {
        let nonceScalars = nonce.unicodeScalars
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(requestID),
              FactoryTextRules.isStableID(candidateComponentID),
              FactoryTextRules.isStableID(epoch),
              FactoryTextRules.isBoundedText(clientID, maximumScalars: 128),
              FactoryTextRules.isBoundedText(modelID, maximumScalars: 256),
              (32 ... 256).contains(nonceScalars.count),
              nonceScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }),
              payloadRef.sizeBytes > 0,
              queryOrdinal > 0,
              !changedPaths.isEmpty,
              changedPaths == changedPaths.sorted(),
              Set(changedPaths.map(\.collisionKey)).count == changedPaths.count,
              !evidence.isEmpty,
              evidence.map(\.kind) == evidence.map(\.kind).sorted(),
              Set(evidence.map(\.kind)).count == evidence.count,
              evidence.allSatisfy({ FactoryTextRules.isStableID($0.kind) }),
              !schemaDigests.isEmpty,
              schemaDigests.map(\.schemaID) == schemaDigests.map(\.schemaID).sorted(),
              Set(schemaDigests.map(\.schemaID)).count == schemaDigests.count,
              schemaDigests.allSatisfy({ FactoryTextRules.isStableID($0.schemaID) })
        else {
            throw FactoryValidationError(
                code: "invalid_evaluation_request",
                message: "Evaluation request identifiers, collections, or budgets are malformed.",
            )
        }
    }
}

/// Aggregate resource use observed by the credential-separated private executor.
public struct EvaluationExecutionUsage: Codable, Equatable, Sendable {
    public let caseCount: Int
    @RequiredNullable public var costMicrousd: Int?
    public let inputTokens: Int
    public let modelCalls: Int
    public let outputBytes: Int
    public let outputTokens: Int
    public let wallTimeMilliseconds: Int

    public init(
        caseCount: Int,
        costMicrousd: Int?,
        inputTokens: Int,
        modelCalls: Int,
        outputBytes: Int,
        outputTokens: Int,
        wallTimeMilliseconds: Int,
    ) throws {
        guard caseCount >= 0,
              costMicrousd.map({ $0 >= 0 }) ?? true,
              inputTokens >= 0,
              modelCalls >= 0,
              outputBytes >= 0,
              outputTokens >= 0,
              wallTimeMilliseconds >= 0
        else {
            throw FactoryValidationError(
                code: "invalid_evaluation_usage",
                message: "Evaluation usage counters cannot be negative.",
            )
        }
        self.caseCount = caseCount
        self.costMicrousd = costMicrousd
        self.inputTokens = inputTokens
        self.modelCalls = modelCalls
        self.outputBytes = outputBytes
        self.outputTokens = outputTokens
        self.wallTimeMilliseconds = wallTimeMilliseconds
    }

    public init(from decoder: Decoder) throws {
        let value = try StoredUsage(from: decoder)
        try self.init(
            caseCount: value.caseCount,
            costMicrousd: value.costMicrousd,
            inputTokens: value.inputTokens,
            modelCalls: value.modelCalls,
            outputBytes: value.outputBytes,
            outputTokens: value.outputTokens,
            wallTimeMilliseconds: value.wallTimeMilliseconds,
        )
    }

    public func encode(to encoder: Encoder) throws {
        try StoredUsage(self).encode(to: encoder)
    }

    private struct StoredUsage: Codable {
        let caseCount: Int
        @RequiredNullable var costMicrousd: Int?
        let inputTokens: Int
        let modelCalls: Int
        let outputBytes: Int
        let outputTokens: Int
        let wallTimeMilliseconds: Int

        init(_ usage: EvaluationExecutionUsage) {
            caseCount = usage.caseCount
            costMicrousd = usage.costMicrousd
            inputTokens = usage.inputTokens
            modelCalls = usage.modelCalls
            outputBytes = usage.outputBytes
            outputTokens = usage.outputTokens
            wallTimeMilliseconds = usage.wallTimeMilliseconds
        }
    }
}

/// Trusted private execution ceiling referenced from a public request only by digest.
public struct EvaluationExecutionBudget: Codable, Equatable, Sendable {
    package static let maximumKernelCases = 100_000
    package static let maximumKernelOutputBytes = 16 * 1024 * 1024
    private static let maximumAuthorizedWallTimeMilliseconds = 10 * 60 * 1000

    public enum CostTracking: String, Codable, Sendable {
        case tracked
        case unavailable
    }

    public let costTracking: CostTracking
    public let maximumCases: Int
    @RequiredNullable public var maximumCostMicrousd: Int?
    public let maximumInputTokens: Int
    public let maximumModelCalls: Int
    public let maximumOutputBytes: Int
    public let maximumOutputTokens: Int
    public let maximumWallTimeMilliseconds: Int

    public init(
        costTracking: CostTracking,
        maximumCases: Int,
        maximumCostMicrousd: Int?,
        maximumInputTokens: Int,
        maximumModelCalls: Int,
        maximumOutputBytes: Int,
        maximumOutputTokens: Int,
        maximumWallTimeMilliseconds: Int,
    ) throws {
        guard (1 ... Self.maximumKernelCases).contains(maximumCases),
              maximumInputTokens > 0,
              maximumModelCalls > 0,
              (1 ... Self.maximumKernelOutputBytes).contains(maximumOutputBytes),
              maximumOutputTokens > 0,
              (1 ... Self.maximumAuthorizedWallTimeMilliseconds).contains(maximumWallTimeMilliseconds),
              (costTracking == .tracked) == (maximumCostMicrousd != nil),
              maximumCostMicrousd.map({ $0 > 0 }) ?? true
        else {
            throw FactoryValidationError(
                code: "invalid_evaluation_budget",
                message: "Evaluation execution budgets must be finite, positive, and explicit about cost tracking.",
            )
        }
        self.costTracking = costTracking
        self.maximumCases = maximumCases
        self.maximumCostMicrousd = maximumCostMicrousd
        self.maximumInputTokens = maximumInputTokens
        self.maximumModelCalls = maximumModelCalls
        self.maximumOutputBytes = maximumOutputBytes
        self.maximumOutputTokens = maximumOutputTokens
        self.maximumWallTimeMilliseconds = maximumWallTimeMilliseconds
    }

    public init(from decoder: Decoder) throws {
        let value = try StoredBudget(from: decoder)
        try self.init(
            costTracking: value.costTracking,
            maximumCases: value.maximumCases,
            maximumCostMicrousd: value.maximumCostMicrousd,
            maximumInputTokens: value.maximumInputTokens,
            maximumModelCalls: value.maximumModelCalls,
            maximumOutputBytes: value.maximumOutputBytes,
            maximumOutputTokens: value.maximumOutputTokens,
            maximumWallTimeMilliseconds: value.maximumWallTimeMilliseconds,
        )
    }

    public func encode(to encoder: Encoder) throws {
        try StoredBudget(self).encode(to: encoder)
    }

    public var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }

    func isExceeded(by usage: EvaluationExecutionUsage) -> Bool {
        usage.caseCount > maximumCases
            || usage.outputBytes > maximumOutputBytes
            || usage.inputTokens > maximumInputTokens
            || usage.modelCalls > maximumModelCalls
            || usage.outputTokens > maximumOutputTokens
            || usage.wallTimeMilliseconds > maximumWallTimeMilliseconds
            || costViolation(usage.costMicrousd)
    }

    private func costViolation(_ costMicrousd: Int?) -> Bool {
        switch costTracking {
        case .tracked:
            guard let maximumCostMicrousd, let costMicrousd else { return true }
            return costMicrousd > maximumCostMicrousd
        case .unavailable:
            return costMicrousd != nil
        }
    }

    private struct StoredBudget: Codable {
        let costTracking: CostTracking
        let maximumCases: Int
        @RequiredNullable var maximumCostMicrousd: Int?
        let maximumInputTokens: Int
        let maximumModelCalls: Int
        let maximumOutputBytes: Int
        let maximumOutputTokens: Int
        let maximumWallTimeMilliseconds: Int

        init(_ budget: EvaluationExecutionBudget) {
            costTracking = budget.costTracking
            maximumCases = budget.maximumCases
            maximumCostMicrousd = budget.maximumCostMicrousd
            maximumInputTokens = budget.maximumInputTokens
            maximumModelCalls = budget.maximumModelCalls
            maximumOutputBytes = budget.maximumOutputBytes
            maximumOutputTokens = budget.maximumOutputTokens
            maximumWallTimeMilliseconds = budget.maximumWallTimeMilliseconds
        }
    }
}
