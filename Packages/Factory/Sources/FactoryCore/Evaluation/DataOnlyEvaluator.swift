import Foundation

/// Private data record stored only in the separately protected companion repository.
public struct PrivateEvaluationCase: Codable, Equatable, Sendable {
    public let caseID: String
    public let expectedOutputSHA256: SHA256Digest
    public let stratum: String

    public init(caseID: String, expectedOutputSHA256: SHA256Digest, stratum: String) {
        self.caseID = caseID
        self.expectedOutputSHA256 = expectedOutputSHA256
        self.stratum = stratum
    }
}

/// Exact private epoch bytes whose digest is frozen before a candidate exists.
public struct PrivateEvaluationEpochSnapshot: Codable, Equatable, Sendable {
    public let cases: [PrivateEvaluationCase]
    public let epochID: String
    public let partition: EvaluationPartition
    public let strataSHA256: SHA256Digest

    public init(
        cases: [PrivateEvaluationCase],
        epochID: String,
        partition: EvaluationPartition,
        strataSHA256: SHA256Digest,
    ) throws {
        let stableID = /^[a-z0-9][a-z0-9._:-]{0,127}$/
        guard epochID.wholeMatch(of: stableID) != nil,
              !cases.isEmpty,
              cases.count <= EvaluationExecutionBudget.maximumKernelCases,
              cases.map(\.caseID) == cases.map(\.caseID).sorted(),
              Set(cases.map(\.caseID)).count == cases.count,
              cases.allSatisfy({
                  $0.caseID.wholeMatch(of: stableID) != nil
                      && $0.stratum.wholeMatch(of: stableID) != nil
              })
        else {
            throw FactoryValidationError(
                code: "invalid_private_epoch",
                message: "Private epoch cases must be nonempty, canonical, and unique.",
            )
        }
        self.cases = cases
        self.epochID = epochID
        self.partition = partition
        self.strataSHA256 = strataSHA256
    }

    public init(from decoder: Decoder) throws {
        let value = try StoredSnapshot(from: decoder)
        try self.init(
            cases: value.cases,
            epochID: value.epochID,
            partition: value.partition,
            strataSHA256: value.strataSHA256,
        )
    }

    public func encode(to encoder: Encoder) throws {
        try StoredSnapshot(
            cases: cases,
            epochID: epochID,
            partition: partition,
            strataSHA256: strataSHA256,
        ).encode(to: encoder)
    }

    public var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }

    private struct StoredSnapshot: Codable {
        let cases: [PrivateEvaluationCase]
        let epochID: String
        let partition: EvaluationPartition
        let strataSHA256: SHA256Digest
    }
}

/// Candidate output reduced to a digest and private blocker codes before evaluation.
public struct CandidateCaseOutput: Codable, Equatable, Sendable {
    public let blockerCodes: [String]
    public let caseID: String
    public let outputSHA256: SHA256Digest

    public init(blockerCodes: [String], caseID: String, outputSHA256: SHA256Digest) {
        self.blockerCodes = blockerCodes
        self.caseID = caseID
        self.outputSHA256 = outputSHA256
    }
}

/// Whether the candidate runner produced a complete, budget-bounded result set.
public enum CandidateExecutionStatus: String, Codable, Sendable {
    case budgetExceeded = "budget-exceeded"
    case complete
    case insufficientEvidence = "insufficient-evidence"
}

/// Internal runner receipt binding every private output to the exact public request.
public struct CandidateExecutionReceipt: Codable, Equatable, Sendable {
    public let candidateSHA256: SHA256Digest
    public let clientID: String
    public let modelID: String
    public let outputs: [CandidateCaseOutput]
    public let requestSHA256: SHA256Digest
    public let status: CandidateExecutionStatus
    public let usage: EvaluationExecutionUsage

    public init(
        candidateSHA256: SHA256Digest,
        clientID: String,
        modelID: String,
        outputs: [CandidateCaseOutput],
        requestSHA256: SHA256Digest,
        status: CandidateExecutionStatus,
        usage: EvaluationExecutionUsage,
    ) {
        self.candidateSHA256 = candidateSHA256
        self.clientID = clientID
        self.modelID = modelID
        self.outputs = outputs
        self.requestSHA256 = requestSHA256
        self.status = status
        self.usage = usage
    }
}

/// Whole-candidate action returned through the bounded selection or sealed channel.
public enum EvaluationDecision: String, Codable, Sendable {
    case accept
    case inconclusive
    case reject
    case revise
}

/// The only revision detail allowed to cross the private evaluator boundary.
public enum EvaluationFailureClass: String, Codable, Sendable {
    case budget
    case correctness
    case insufficientEvidence = "insufficient-evidence"
    case integrity
    case none
    case privacy
    case scope
}

/// The complete revision channel: one action and one sanitized failure class.
public struct EvaluationAggregate: Codable, Equatable, Sendable {
    public let decision: EvaluationDecision
    public let failureClass: EvaluationFailureClass

    public init(decision: EvaluationDecision, failureClass: EvaluationFailureClass) throws {
        guard (decision == .accept) == (failureClass == .none) else {
            throw FactoryValidationError(
                code: "invalid_evaluation_aggregate",
                message: "Accepted evaluations have no failure; all other actions require one class.",
            )
        }
        self.decision = decision
        self.failureClass = failureClass
    }

    public init(from decoder: Decoder) throws {
        let value = try StoredAggregate(from: decoder)
        try self.init(decision: value.decision, failureClass: value.failureClass)
    }

    public func encode(to encoder: Encoder) throws {
        try StoredAggregate(decision: decision, failureClass: failureClass).encode(to: encoder)
    }

    public var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }

    private struct StoredAggregate: Codable {
        let decision: EvaluationDecision
        let failureClass: EvaluationFailureClass
    }
}

/// Internal evaluator result carrying a terminal query-chain receipt but no private metric.
public struct EvaluationResult: Codable, Equatable, Sendable {
    public let aggregate: EvaluationAggregate
    public let executionReceiptSHA256: SHA256Digest
    public let queryLedgerSHA256: SHA256Digest

    public init(
        aggregate: EvaluationAggregate,
        executionReceiptSHA256: SHA256Digest,
        queryLedgerSHA256: SHA256Digest,
    ) {
        self.aggregate = aggregate
        self.executionReceiptSHA256 = executionReceiptSHA256
        self.queryLedgerSHA256 = queryLedgerSHA256
    }
}

/// Deterministic evaluator that consumes a frozen private snapshot but emits no case result or score.
public enum DataOnlyEvaluator {
    /// Atomically consumes a query budget before any private case or model execution begins.
    package static func reserve(
        request: EvaluationRequest,
        policy: EvolutionAcceptancePolicy,
        ledger: EvaluationQueryLedger,
    ) throws -> SHA256Digest {
        try policy.validate(request)
        return try ledger.reserve(request)
    }

    /// Validates every public/content binding before a durable reservation is consumed.
    package static func validatePreflight(
        request: EvaluationRequest,
        candidatePayload: Data,
        policy: EvolutionAcceptancePolicy,
        budget: EvaluationExecutionBudget,
        epochSnapshot: PrivateEvaluationEpochSnapshot,
        executionReceipt: CandidateExecutionReceipt,
    ) throws {
        _ = try executionPreflight(
            request: request,
            candidatePayload: candidatePayload,
            policy: policy,
            budget: budget,
            epochSnapshot: epochSnapshot,
            executionReceipt: executionReceipt,
        )
    }

    public static func evaluate(
        request: EvaluationRequest,
        candidatePayload: Data,
        policy: EvolutionAcceptancePolicy,
        budget: EvaluationExecutionBudget,
        epochSnapshot: PrivateEvaluationEpochSnapshot,
        executionReceipt: CandidateExecutionReceipt,
        ledger: EvaluationQueryLedger,
    ) throws -> EvaluationResult {
        try evaluate(
            request: request,
            candidatePayload: candidatePayload,
            policy: policy,
            budget: budget,
            epochSnapshot: epochSnapshot,
            executionReceipt: executionReceipt,
            executionReceiptBindingSHA256: nil,
            ledger: ledger,
            outputEncoder: { try CanonicalJSON.encode($0) },
        )
    }

    package static func evaluateAuthorized(
        request: EvaluationRequest,
        candidatePayload: Data,
        policy: EvolutionAcceptancePolicy,
        budget: EvaluationExecutionBudget,
        epochSnapshot: PrivateEvaluationEpochSnapshot,
        executionReceipt: AuthorizedCandidateExecutionReceipt,
        ledger: EvaluationQueryLedger,
    ) throws -> EvaluationResult {
        try evaluate(
            request: request,
            candidatePayload: candidatePayload,
            policy: policy,
            budget: budget,
            epochSnapshot: epochSnapshot,
            executionReceipt: executionReceipt.receipt,
            executionReceiptBindingSHA256: CanonicalJSON.digest(executionReceipt),
            ledger: ledger,
            outputEncoder: { try CanonicalJSON.encode($0) },
        )
    }

    static func evaluate(
        request: EvaluationRequest,
        candidatePayload: Data,
        policy: EvolutionAcceptancePolicy,
        budget: EvaluationExecutionBudget,
        epochSnapshot: PrivateEvaluationEpochSnapshot,
        executionReceipt: CandidateExecutionReceipt,
        executionReceiptBindingSHA256: SHA256Digest? = nil,
        ledger: EvaluationQueryLedger,
        outputEncoder: ([CandidateCaseOutput]) throws -> Data,
    ) throws -> EvaluationResult {
        try ledger.requirePending(request)
        let aggregate: EvaluationAggregate
        let executionReceiptSHA256: SHA256Digest
        do {
            let preflightOutputBytes = try executionPreflight(
                request: request,
                candidatePayload: candidatePayload,
                policy: policy,
                budget: budget,
                epochSnapshot: epochSnapshot,
                executionReceipt: executionReceipt,
            )

            let overBudget = budget.isExceeded(by: executionReceipt.usage)
            switch executionReceipt.status {
            case .budgetExceeded:
                guard executionReceipt.outputs.isEmpty, overBudget else {
                    throw FactoryValidationError(
                        code: "invalid_execution_receipt",
                        message: "A budget stop must be output-free and prove an exhausted ceiling.",
                    )
                }
                aggregate = try EvaluationAggregate(decision: .inconclusive, failureClass: .budget)
            case .insufficientEvidence:
                guard executionReceipt.outputs.isEmpty, !overBudget else {
                    throw FactoryValidationError(
                        code: "invalid_execution_receipt",
                        message: "An inconclusive execution cannot include partial private outputs.",
                    )
                }
                aggregate = try EvaluationAggregate(decision: .inconclusive, failureClass: .insufficientEvidence)
            case .complete:
                let outputBytes = try outputEncoder(executionReceipt.outputs).count
                guard !overBudget,
                      outputBytes == preflightOutputBytes,
                      executionReceipt.usage.caseCount == executionReceipt.outputs.count,
                      executionReceipt.usage.modelCalls > 0,
                      executionReceipt.usage.outputBytes == outputBytes,
                      outputBytes <= budget.maximumOutputBytes,
                      executionReceipt.usage.wallTimeMilliseconds > 0
                else {
                    throw FactoryValidationError(
                        code: "invalid_execution_receipt",
                        message: "A complete execution must prove positive work within every ceiling.",
                    )
                }
                aggregate = try evaluateComplete(
                    request: request,
                    policy: policy,
                    budget: budget,
                    cases: epochSnapshot.cases,
                    outputs: executionReceipt.outputs,
                )
            }
            executionReceiptSHA256 = executionReceiptBindingSHA256 ?? CanonicalJSON.digest(executionReceipt)
        } catch {
            let failureCode = (error as? FactoryValidationError)?.code ?? "evaluation_failure"
            try ledger.abandon(request, failureCode: failureCode)
            throw error
        }
        let queryLedgerSHA256 = try ledger.complete(
            request,
            aggregate: aggregate,
            executionReceiptSHA256: executionReceiptSHA256,
        )
        return EvaluationResult(
            aggregate: aggregate,
            executionReceiptSHA256: executionReceiptSHA256,
            queryLedgerSHA256: queryLedgerSHA256,
        )
    }

    private static func executionPreflight(
        request: EvaluationRequest,
        candidatePayload: Data,
        policy: EvolutionAcceptancePolicy,
        budget: EvaluationExecutionBudget,
        epochSnapshot: PrivateEvaluationEpochSnapshot,
        executionReceipt: CandidateExecutionReceipt,
    ) throws -> Int {
        try policy.validate(request)
        guard request.budgetSHA256 == budget.digest,
              request.payloadRef.sizeBytes == candidatePayload.count,
              request.payloadRef.sha256 == SHA256Digest.hashing(candidatePayload),
              epochSnapshot.epochID == request.epoch,
              epochSnapshot.partition == request.partition,
              epochSnapshot.strataSHA256 == request.strataSHA256,
              epochSnapshot.digest == request.epochSHA256,
              executionReceipt.requestSHA256 == request.digest,
              executionReceipt.candidateSHA256 == request.candidateSHA256,
              executionReceipt.clientID == request.clientID,
              executionReceipt.modelID == request.modelID
        else {
            throw FactoryValidationError(
                code: "evaluation_content_mismatch",
                message: "Candidate, execution, budget, or private epoch identity changed.",
            )
        }
        return try validateCollectionPreflight(
            epochSnapshot: epochSnapshot,
            executionReceipt: executionReceipt,
            budget: budget,
        )
    }

    private static func validateCollectionPreflight(
        epochSnapshot: PrivateEvaluationEpochSnapshot,
        executionReceipt: CandidateExecutionReceipt,
        budget: EvaluationExecutionBudget,
    ) throws -> Int {
        let stableID = /^[a-z0-9][a-z0-9._:-]{0,127}$/
        let outputs = executionReceipt.outputs
        guard epochSnapshot.cases.count <= budget.maximumCases,
              outputs.count <= budget.maximumCases,
              executionReceipt.status == .complete || outputs.isEmpty,
              outputs.allSatisfy({ output in
                  output.caseID.wholeMatch(of: stableID) != nil
                      && output.blockerCodes.count <= 64
                      && output.blockerCodes == Array(Set(output.blockerCodes)).sorted()
                      && output.blockerCodes.allSatisfy { $0.wholeMatch(of: stableID) != nil }
              })
        else {
            throw FactoryValidationError(
                code: "invalid_execution_receipt",
                message: "Execution receipt collections exceed their fixed shape or count ceilings.",
            )
        }
        guard executionReceipt.status == .complete else { return 0 }
        var encodedBytes = 2
        for (index, output) in outputs.enumerated() {
            let itemBytes = try CanonicalJSON.encode(output).count
            let separatorBytes = index == 0 ? 0 : 1
            let (withItem, itemOverflow) = encodedBytes.addingReportingOverflow(itemBytes)
            let (withSeparator, separatorOverflow) = withItem.addingReportingOverflow(separatorBytes)
            guard !itemOverflow,
                  !separatorOverflow,
                  withSeparator <= budget.maximumOutputBytes
            else {
                throw FactoryValidationError(
                    code: "invalid_execution_receipt",
                    message: "Execution receipt output bytes exceed their fixed ceiling.",
                )
            }
            encodedBytes = withSeparator
        }
        return encodedBytes
    }

    private static func evaluateComplete(
        request: EvaluationRequest,
        policy: EvolutionAcceptancePolicy,
        budget: EvaluationExecutionBudget,
        cases: [PrivateEvaluationCase],
        outputs: [CandidateCaseOutput],
    ) throws -> EvaluationAggregate {
        let stableID = /^[a-z0-9][a-z0-9._:-]{0,127}$/
        guard cases.count <= budget.maximumCases,
              cases.count == outputs.count,
              outputs.map(\.caseID) == outputs.map(\.caseID).sorted(),
              Set(outputs.map(\.caseID)).count == outputs.count,
              Set(cases.map(\.caseID)) == Set(outputs.map(\.caseID)),
              outputs.allSatisfy({ output in
                  output.blockerCodes == Array(Set(output.blockerCodes)).sorted()
                      && output.blockerCodes.allSatisfy { $0.wholeMatch(of: stableID) != nil }
              })
        else {
            throw FactoryValidationError(
                code: "invalid_private_evaluation",
                message: "Private output membership or execution budget is invalid.",
            )
        }

        var outputsByID: [String: CandidateCaseOutput] = [:]
        for output in outputs {
            guard outputsByID.updateValue(output, forKey: output.caseID) == nil else {
                throw FactoryValidationError(
                    code: "invalid_private_evaluation",
                    message: "Private output membership or execution budget is invalid.",
                )
            }
        }
        let passed = cases.count(where: { testCase in
            outputsByID[testCase.caseID]?.outputSHA256 == testCase.expectedOutputSHA256
        })
        let passRate = Double(passed) / Double(cases.count)
        let hasBlocker = outputs.contains(where: { !$0.blockerCodes.isEmpty })
        if passRate >= policy.minimumPassRate, !hasBlocker {
            return try EvaluationAggregate(decision: .accept, failureClass: .none)
        }
        return try EvaluationAggregate(
            decision: request.partition == .selection ? .revise : .reject,
            failureClass: .correctness,
        )
    }
}
