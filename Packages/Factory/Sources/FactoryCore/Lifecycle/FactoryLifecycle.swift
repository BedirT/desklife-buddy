import Foundation

/// Durable phases whose transitions are controlled by compare-and-swap.
public enum FactoryPhase: String, Codable, CaseIterable, Sendable {
    case new = "NEW"
    case intakeRequired = "INTAKE_REQUIRED"
    case planning = "PLANNING"
    case contractNegotiation = "CONTRACT_NEGOTIATION"
    case readyToBuild = "READY_TO_BUILD"
    case building = "BUILDING"
    case verifying = "VERIFYING"
    case witnessing = "WITNESSING"
    case reviewing = "REVIEWING"
    case prChecks = "PR_CHECKS"
    case readyForOwner = "READY_FOR_OWNER"
    case merged = "MERGED"
    case retrospective = "RETROSPECTIVE"
    case complete = "COMPLETE"
    case repairing = "REPAIRING"
    case recovering = "RECOVERING"
    case blockedOwner = "BLOCKED_OWNER"
    case pausedOperator = "PAUSED_OPERATOR"
    case abortedOperator = "ABORTED_OPERATOR"
    case quarantined = "QUARANTINED"
}

/// Evidence predicates that make a lifecycle edge legal.
public enum TransitionPredicate: String, Codable, CaseIterable, Hashable, Sendable {
    case issueAndOutcomeExist = "issue_and_outcome_exist"
    case intakeRecorded = "intake_recorded"
    case productContextComplete = "product_context_complete"
    case contractAcceptedByBuilderAndSkeptic = "contract_accepted_by_builder_and_skeptic"
    case authoritativeBuildBoundaryReady = "authoritative_build_boundary_ready"
    case boundedSliceCommitted = "bounded_slice_committed"
    case deterministicEvidenceFresh = "deterministic_evidence_fresh"
    case independentWitnessComplete = "independent_witness_complete"
    case independentReviewClear = "independent_review_clear"
    case latestSHAHandoffComplete = "latest_sha_handoff_complete"
    case ownerMerged = "owner_merged"
    case mergeReconciled = "merge_reconciled"
    case retrospectiveRecordedAndLeasesReleased = "retrospective_recorded_and_leases_released"
    case reproducibleFailureAndBudgetRemain = "reproducible_failure_and_budget_remain"
    case repairContractRecordedAndLeaseAvailable = "repair_contract_recorded_and_lease_available"
    case liveStateDiverged = "live_state_diverged"
    case stateReconciled = "state_reconciled"
    case ownerEscalationRecorded = "owner_escalation_recorded"
    case ownerAnswerRecordedAndCASFresh = "owner_answer_recorded_and_cas_fresh"
    case operatorPauseRecorded = "operator_pause_recorded"
    case operatorResumeReconciled = "operator_resume_reconciled"
    case operatorAbortComplete = "operator_abort_complete"
    case partialEvidenceAndLeasesReleased = "partial_evidence_and_leases_released"
    case circuitBreakerFired = "circuit_breaker_fired"
}

/// Durable lifecycle state addressable without conversation history.
public struct FactoryState: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case contractDigest = "contractSHA256"
        case evidenceInvalidatedAtGeneration
        case generation
        case head = "headSHA"
        case issueNumber
        case phase
        case pullRequestNumber
        case resumePhase
        case runID
        case schemaVersion
    }

    public let schemaVersion: Int
    public let runID: String
    public fileprivate(set) var phase: FactoryPhase
    public fileprivate(set) var resumePhase: FactoryPhase?
    public let issueNumber: Int
    public fileprivate(set) var pullRequestNumber: Int?
    public fileprivate(set) var contractDigest: SHA256Digest
    public fileprivate(set) var head: GitObjectID
    public fileprivate(set) var generation: Int
    public fileprivate(set) var evidenceInvalidatedAtGeneration: Int?

    public init(
        runID: String,
        phase: FactoryPhase,
        resumePhase: FactoryPhase?,
        issueNumber: Int,
        pullRequestNumber: Int?,
        contractDigest: SHA256Digest,
        head: GitObjectID,
        generation: Int,
        evidenceInvalidatedAtGeneration: Int? = nil,
        schemaVersion: Int = FactoryCore.schemaVersion,
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.phase = phase
        self.resumePhase = resumePhase
        self.issueNumber = issueNumber
        self.pullRequestNumber = pullRequestNumber
        self.contractDigest = contractDigest
        self.head = head
        self.generation = generation
        self.evidenceInvalidatedAtGeneration = evidenceInvalidatedAtGeneration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            runID: container.decode(String.self, forKey: .runID),
            phase: container.decode(FactoryPhase.self, forKey: .phase),
            resumePhase: container.decode(RequiredNullable<FactoryPhase>.self, forKey: .resumePhase).wrappedValue,
            issueNumber: container.decode(Int.self, forKey: .issueNumber),
            pullRequestNumber: container
                .decode(RequiredNullable<Int>.self, forKey: .pullRequestNumber).wrappedValue,
            contractDigest: container.decode(SHA256Digest.self, forKey: .contractDigest),
            head: container.decode(GitObjectID.self, forKey: .head),
            generation: container.decode(Int.self, forKey: .generation),
            evidenceInvalidatedAtGeneration: container
                .decode(RequiredNullable<Int>.self, forKey: .evidenceInvalidatedAtGeneration).wrappedValue,
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
        )
        try validateStructure()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contractDigest, forKey: .contractDigest)
        try container.encode(
            RequiredNullable(wrappedValue: evidenceInvalidatedAtGeneration),
            forKey: .evidenceInvalidatedAtGeneration,
        )
        try container.encode(generation, forKey: .generation)
        try container.encode(head, forKey: .head)
        try container.encode(issueNumber, forKey: .issueNumber)
        try container.encode(phase, forKey: .phase)
        try container.encode(RequiredNullable(wrappedValue: pullRequestNumber), forKey: .pullRequestNumber)
        try container.encode(RequiredNullable(wrappedValue: resumePhase), forKey: .resumePhase)
        try container.encode(runID, forKey: .runID)
        try container.encode(schemaVersion, forKey: .schemaVersion)
    }

    func validateStructure() throws {
        let suspended: [FactoryPhase] = [.recovering, .blockedOwner, .pausedOperator]
        let hasValidResumePhase: Bool = if suspended.contains(phase) {
            resumePhase.map {
                !suspended.contains($0) && ![.complete, .quarantined].contains($0)
            } ?? false
        } else {
            resumePhase == nil
        }
        let hasValidEvidenceGeneration = evidenceInvalidatedAtGeneration.map { evidenceGeneration in
            evidenceGeneration > 0 && evidenceGeneration <= generation
        } ?? true
        let pullRequestRequiredPhases: Set<FactoryPhase> = [
            .building, .verifying, .witnessing, .reviewing, .prChecks,
            .readyForOwner, .merged, .repairing,
        ]
        let pullRequestForbiddenPhases: Set<FactoryPhase> = [
            .new, .intakeRequired, .planning, .contractNegotiation, .readyToBuild,
        ]
        let effectivePhase = suspended.contains(phase) ? resumePhase : phase
        let hasValidPullRequestBinding = effectivePhase.map { effective in
            if pullRequestRequiredPhases.contains(effective) {
                return pullRequestNumber != nil
            }
            if pullRequestForbiddenPhases.contains(effective) {
                return pullRequestNumber == nil
            }
            return true
        } ?? false
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(runID),
              issueNumber > 0,
              pullRequestNumber.map({ $0 > 0 }) ?? true,
              generation >= 0,
              hasValidResumePhase,
              hasValidEvidenceGeneration,
              hasValidPullRequestBinding
        else {
            throw FactoryValidationError(
                code: "invalid_lifecycle_state",
                message: "Durable lifecycle state is malformed or cannot be resumed exactly.",
            )
        }
    }
}

/// Exact expected state supplied with every lifecycle mutation request.
public struct StateCAS: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case contractDigest = "contractSHA256"
        case evidenceInvalidatedAtGeneration
        case generation
        case head = "headSHA"
        case issueNumber
        case phase
        case pullRequestNumber
        case resumePhase
        case runID
        case schemaVersion
    }

    public let schemaVersion: Int
    public let runID: String
    public let phase: FactoryPhase
    public let issueNumber: Int
    public let pullRequestNumber: Int?
    public let contractDigest: SHA256Digest
    public let head: GitObjectID
    public let resumePhase: FactoryPhase?
    public let evidenceInvalidatedAtGeneration: Int?
    public var generation: Int

    public init(expected state: FactoryState) {
        schemaVersion = state.schemaVersion
        runID = state.runID
        phase = state.phase
        issueNumber = state.issueNumber
        pullRequestNumber = state.pullRequestNumber
        contractDigest = state.contractDigest
        head = state.head
        resumePhase = state.resumePhase
        evidenceInvalidatedAtGeneration = state.evidenceInvalidatedAtGeneration
        generation = state.generation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        runID = try container.decode(String.self, forKey: .runID)
        phase = try container.decode(FactoryPhase.self, forKey: .phase)
        issueNumber = try container.decode(Int.self, forKey: .issueNumber)
        pullRequestNumber = try container
            .decode(RequiredNullable<Int>.self, forKey: .pullRequestNumber).wrappedValue
        contractDigest = try container.decode(SHA256Digest.self, forKey: .contractDigest)
        head = try container.decode(GitObjectID.self, forKey: .head)
        resumePhase = try container
            .decode(RequiredNullable<FactoryPhase>.self, forKey: .resumePhase).wrappedValue
        evidenceInvalidatedAtGeneration = try container
            .decode(RequiredNullable<Int>.self, forKey: .evidenceInvalidatedAtGeneration).wrappedValue
        generation = try container.decode(Int.self, forKey: .generation)
        let hasValidEvidenceGeneration = evidenceInvalidatedAtGeneration.map {
            $0 > 0 && $0 <= generation
        } ?? true
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(runID),
              issueNumber > 0,
              pullRequestNumber.map({ $0 > 0 }) ?? true,
              generation >= 0,
              hasValidEvidenceGeneration
        else {
            throw FactoryValidationError(code: "invalid_state_cas", message: "Lifecycle CAS metadata is invalid.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contractDigest, forKey: .contractDigest)
        try container.encode(
            RequiredNullable(wrappedValue: evidenceInvalidatedAtGeneration),
            forKey: .evidenceInvalidatedAtGeneration,
        )
        try container.encode(generation, forKey: .generation)
        try container.encode(head, forKey: .head)
        try container.encode(issueNumber, forKey: .issueNumber)
        try container.encode(phase, forKey: .phase)
        try container.encode(RequiredNullable(wrappedValue: pullRequestNumber), forKey: .pullRequestNumber)
        try container.encode(RequiredNullable(wrappedValue: resumePhase), forKey: .resumePhase)
        try container.encode(runID, forKey: .runID)
        try container.encode(schemaVersion, forKey: .schemaVersion)
    }

    /// Whether no authoritative lifecycle input changed after the request was built.
    public func matches(_ state: FactoryState) -> Bool {
        schemaVersion == state.schemaVersion
            && runID == state.runID
            && phase == state.phase
            && issueNumber == state.issueNumber
            && pullRequestNumber == state.pullRequestNumber
            && contractDigest == state.contractDigest
            && head == state.head
            && resumePhase == state.resumePhase
            && evidenceInvalidatedAtGeneration == state.evidenceInvalidatedAtGeneration
            && generation == state.generation
    }
}

/// Proposed lifecycle edge with its complete deterministic proof set.
public struct TransitionRequest: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case cas
        case nextContractDigest = "nextContractSHA256"
        case nextHead = "nextHeadSHA"
        case nextPullRequestNumber
        case predicates
        case schemaVersion
        case target
    }

    public let schemaVersion: Int
    public let cas: StateCAS
    public let target: FactoryPhase
    public let predicates: [TransitionPredicate]
    public let nextContractDigest: SHA256Digest
    public let nextHead: GitObjectID
    public let nextPullRequestNumber: Int?

    public init(
        cas: StateCAS,
        target: FactoryPhase,
        predicates: [TransitionPredicate],
        nextContractDigest: SHA256Digest,
        nextHead: GitObjectID,
        nextPullRequestNumber: Int?,
        schemaVersion: Int = FactoryCore.schemaVersion,
    ) {
        self.schemaVersion = schemaVersion
        self.cas = cas
        self.target = target
        self.predicates = predicates
        self.nextContractDigest = nextContractDigest
        self.nextHead = nextHead
        self.nextPullRequestNumber = nextPullRequestNumber
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            cas: container.decode(StateCAS.self, forKey: .cas),
            target: container.decode(FactoryPhase.self, forKey: .target),
            predicates: container.decode([TransitionPredicate].self, forKey: .predicates),
            nextContractDigest: container.decode(SHA256Digest.self, forKey: .nextContractDigest),
            nextHead: container.decode(GitObjectID.self, forKey: .nextHead),
            nextPullRequestNumber: container
                .decode(RequiredNullable<Int>.self, forKey: .nextPullRequestNumber).wrappedValue,
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
        )
        guard schemaVersion == FactoryCore.schemaVersion,
              predicates == Array(Set(predicates)).sorted(by: { $0.rawValue < $1.rawValue })
        else {
            throw FactoryValidationError(
                code: "noncanonical_transition_predicates",
                message: "Transition predicates must be sorted and unique.",
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cas, forKey: .cas)
        try container.encode(nextContractDigest, forKey: .nextContractDigest)
        try container.encode(nextHead, forKey: .nextHead)
        try container.encode(
            RequiredNullable(wrappedValue: nextPullRequestNumber),
            forKey: .nextPullRequestNumber,
        )
        try container.encode(predicates, forKey: .predicates)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(target, forKey: .target)
    }
}

/// Pure lifecycle reducer that refuses stale state and unproven transitions.
public enum FactoryStateMachine {
    public static func apply(_ request: TransitionRequest, to state: FactoryState) throws -> FactoryState {
        try state.validateStructure()
        guard request.schemaVersion == FactoryCore.schemaVersion else {
            throw FactoryValidationError(code: "invalid_transition", message: "Transition schema version is invalid.")
        }
        guard request.cas.matches(state) else {
            throw FactoryValidationError(code: "stale_state_cas", message: "Lifecycle state changed before transition.")
        }
        guard state.phase != .quarantined else {
            throw FactoryValidationError(code: "quarantine_is_terminal", message: "Quarantine has no automatic exit.")
        }
        guard state.phase != request.target else {
            throw FactoryValidationError(code: "invalid_transition", message: "A transition must change phase.")
        }

        try validatePredicates(request, state: state)
        try validatePullRequestBinding(request, state: state)

        let changedHead = request.nextHead != state.head
        let changedContract = request.nextContractDigest != state.contractDigest
        let commitBearingEdges: Set<LifecycleEdge> = [
            LifecycleEdge(from: .intakeRequired, to: .planning),
            LifecycleEdge(from: .planning, to: .contractNegotiation),
            LifecycleEdge(from: .contractNegotiation, to: .readyToBuild),
            LifecycleEdge(from: .readyToBuild, to: .building),
            LifecycleEdge(from: .building, to: .verifying),
        ]
        let edge = LifecycleEdge(from: state.phase, to: request.target)
        let isRecoveredCheckpoint = state.phase == .recovering
            && state.resumePhase == .building
            && request.target == .verifying
        guard !changedHead || commitBearingEdges.contains(edge) || isRecoveredCheckpoint else {
            throw FactoryValidationError(
                code: "invalid_lifecycle_head_change",
                message: "This lifecycle edge must preserve the exact candidate commit.",
            )
        }
        if edge == LifecycleEdge(from: .building, to: .verifying) || isRecoveredCheckpoint {
            guard changedHead else {
                throw FactoryValidationError(
                    code: "missing_lifecycle_commit",
                    message: "A committed build checkpoint must advance the candidate commit.",
                )
            }
        }
        let mayReviseContract = edge == LifecycleEdge(from: .contractNegotiation, to: .readyToBuild)
            || edge == LifecycleEdge(from: .building, to: .verifying)
            || isRecoveredCheckpoint
        guard !changedContract || mayReviseContract else {
            throw FactoryValidationError(
                code: "invalid_lifecycle_contract_change",
                message: "This lifecycle edge must preserve the accepted contract.",
            )
        }
        if changedContract, !changedHead {
            throw FactoryValidationError(
                code: "uncommitted_contract_revision",
                message: "An accepted contract revision must be represented by a new candidate commit.",
            )
        }
        if changedContract,
           !request.predicates.contains(.contractAcceptedByBuilderAndSkeptic)
        {
            throw FactoryValidationError(
                code: "unaccepted_contract_revision",
                message: "A revised implementation contract requires independent acceptance.",
            )
        }

        let (nextGeneration, overflow) = state.generation.addingReportingOverflow(1)
        guard !overflow else {
            throw FactoryValidationError(
                code: "lifecycle_generation_overflow",
                message: "Lifecycle generation is exhausted.",
            )
        }
        var result = state
        result.generation = nextGeneration
        result.pullRequestNumber = request.nextPullRequestNumber
        result.contractDigest = request.nextContractDigest
        if changedHead {
            result.head = request.nextHead
        }
        if changedHead || changedContract {
            result.evidenceInvalidatedAtGeneration = result.generation
        }
        if [.recovering, .blockedOwner, .pausedOperator].contains(request.target) {
            result.resumePhase = state.phase
        } else if [.recovering, .blockedOwner, .pausedOperator].contains(state.phase) {
            result.resumePhase = nil
        }
        result.phase = request.target
        try result.validateStructure()
        return result
    }

    private static func validatePredicates(_ request: TransitionRequest, state: FactoryState) throws {
        let canonicalPredicates = Array(Set(request.predicates)).sorted { $0.rawValue < $1.rawValue }
        guard request.predicates == canonicalPredicates else {
            throw FactoryValidationError(
                code: "noncanonical_transition_predicates",
                message: "Transition predicates must be sorted and unique.",
            )
        }
        let required = try requiredPredicates(from: state, to: request.target)
        guard required.isSubset(of: Set(request.predicates)) else {
            throw FactoryValidationError(
                code: "missing_transition_predicate",
                message: "The lifecycle edge is missing required deterministic proof.",
            )
        }
    }

    private static func validatePullRequestBinding(_ request: TransitionRequest, state: FactoryState) throws {
        let isBinding = state.phase == .readyToBuild && request.target == .building
        if isBinding {
            guard state.pullRequestNumber == nil,
                  request.nextPullRequestNumber.map({ $0 > 0 }) == true
            else {
                throw FactoryValidationError(
                    code: "invalid_pull_request_binding",
                    message: "The draft pull request must be bound once at the authoritative build boundary.",
                )
            }
        } else {
            guard request.nextPullRequestNumber == state.pullRequestNumber else {
                throw FactoryValidationError(
                    code: "invalid_pull_request_binding",
                    message: "A lifecycle transition cannot rebind or clear the pull request.",
                )
            }
        }
    }

    private static func requiredPredicates(
        from state: FactoryState,
        to target: FactoryPhase,
    ) throws -> Set<TransitionPredicate> {
        let happyPath: [FactoryPhase: (FactoryPhase, TransitionPredicate)] = [
            .new: (.intakeRequired, .issueAndOutcomeExist),
            .intakeRequired: (.planning, .intakeRecorded),
            .planning: (.contractNegotiation, .productContextComplete),
            .contractNegotiation: (.readyToBuild, .contractAcceptedByBuilderAndSkeptic),
            .readyToBuild: (.building, .authoritativeBuildBoundaryReady),
            .building: (.verifying, .boundedSliceCommitted),
            .verifying: (.witnessing, .deterministicEvidenceFresh),
            .witnessing: (.reviewing, .independentWitnessComplete),
            .reviewing: (.prChecks, .independentReviewClear),
            .prChecks: (.readyForOwner, .latestSHAHandoffComplete),
            .readyForOwner: (.merged, .ownerMerged),
            .merged: (.retrospective, .mergeReconciled),
            .retrospective: (.complete, .retrospectiveRecordedAndLeasesReleased),
            .repairing: (.building, .repairContractRecordedAndLeaseAvailable),
            .abortedOperator: (.retrospective, .partialEvidenceAndLeasesReleased),
        ]
        if let edge = happyPath[state.phase], edge.0 == target {
            return [edge.1]
        }
        if [.verifying, .witnessing, .reviewing, .prChecks].contains(state.phase), target == .repairing {
            return [.reproducibleFailureAndBudgetRemain]
        }
        if target == .recovering, isNonterminal(state.phase) {
            return [.liveStateDiverged]
        }
        if state.phase == .recovering, target == state.resumePhase {
            return [.stateReconciled]
        }
        if state.phase == .recovering, state.resumePhase == .building, target == .verifying {
            return [.boundedSliceCommitted, .stateReconciled]
        }
        if target == .blockedOwner, isNonterminal(state.phase) {
            return [.ownerEscalationRecorded]
        }
        if state.phase == .blockedOwner, target == state.resumePhase {
            return [.ownerAnswerRecordedAndCASFresh]
        }
        if target == .pausedOperator, isNonterminal(state.phase) {
            return [.operatorPauseRecorded]
        }
        if state.phase == .pausedOperator, target == state.resumePhase {
            return [.operatorResumeReconciled]
        }
        if target == .abortedOperator, isNonterminal(state.phase) {
            return [.operatorAbortComplete]
        }
        if target == .quarantined, isNonterminal(state.phase) {
            return [.circuitBreakerFired]
        }
        throw FactoryValidationError(
            code: "invalid_transition",
            message: "The requested lifecycle edge is not declared.",
        )
    }

    private static func isNonterminal(_ phase: FactoryPhase) -> Bool {
        ![.complete, .quarantined].contains(phase)
    }

    private struct LifecycleEdge: Hashable {
        let from: FactoryPhase
        let to: FactoryPhase
    }
}
