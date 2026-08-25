import enum CryptoKit.Curve25519
import Foundation
import Testing
@testable import FactoryCore

@Suite("Evaluation execution contracts")
struct EvaluationExecutionContractTests {
    @Test("Private output shape rejects before aggregate serialization")
    func collectionPreflight() throws {
        let fixture = try EvaluationFixture()
        let request = try fixture.request(partition: .selection, queryOrdinal: 1, frozen: false)
        let snapshot = fixture.selectionSnapshot
        let ledger = fixture.ledger(for: .selection)
        let oneOutput = [CandidateCaseOutput(
            blockerCodes: [],
            caseID: "case-a",
            outputSHA256: snapshot.cases[0].expectedOutputSHA256,
        )]
        let partialReceipt = try CandidateExecutionReceipt(
            candidateSHA256: request.candidateSHA256,
            clientID: request.clientID,
            modelID: request.modelID,
            outputs: oneOutput,
            requestSHA256: request.digest,
            status: .budgetExceeded,
            usage: fixture.usage(caseCount: 11),
        )
        _ = try DataOnlyEvaluator.reserve(request: request, policy: fixture.policy, ledger: ledger)
        var outputEncoderCalled = false
        #expect(throws: FactoryValidationError.self) {
            try DataOnlyEvaluator.evaluate(
                request: request,
                candidatePayload: fixture.defaultPayload,
                policy: fixture.policy,
                budget: fixture.budget,
                epochSnapshot: snapshot,
                executionReceipt: partialReceipt,
                ledger: ledger,
                outputEncoder: { outputs in
                    outputEncoderCalled = true
                    return try CanonicalJSON.encode(outputs)
                },
            )
        }
        #expect(!outputEncoderCalled)

        let tooManyOutputs = (0 ... fixture.budget.maximumCases).map { _ in
            CandidateCaseOutput(
                blockerCodes: [],
                caseID: "case-(index)",
                outputSHA256: TestValues.evidence,
            )
        }
        let oversizedReceipt = try CandidateExecutionReceipt(
            candidateSHA256: request.candidateSHA256,
            clientID: request.clientID,
            modelID: request.modelID,
            outputs: tooManyOutputs,
            requestSHA256: request.digest,
            status: .complete,
            usage: fixture.usage(caseCount: tooManyOutputs.count),
        )
        #expect(throws: FactoryValidationError.self) {
            try DataOnlyEvaluator.evaluate(
                request: request,
                candidatePayload: fixture.defaultPayload,
                policy: fixture.policy,
                budget: fixture.budget,
                epochSnapshot: snapshot,
                executionReceipt: oversizedReceipt,
                ledger: ledger,
                outputEncoder: { outputs in
                    outputEncoderCalled = true
                    return try CanonicalJSON.encode(outputs)
                },
            )
        }
        #expect(!outputEncoderCalled)

        let excessiveBlockers = try CandidateExecutionReceipt(
            candidateSHA256: request.candidateSHA256,
            clientID: request.clientID,
            modelID: request.modelID,
            outputs: [CandidateCaseOutput(
                blockerCodes: (0 ... 64).map { "blocker-\($0)" },
                caseID: "case-a",
                outputSHA256: TestValues.evidence,
            )],
            requestSHA256: request.digest,
            status: .complete,
            usage: fixture.usage(caseCount: 1),
        )
        #expect(throws: FactoryValidationError.self) {
            try DataOnlyEvaluator.evaluate(
                request: request,
                candidatePayload: fixture.defaultPayload,
                policy: fixture.policy,
                budget: fixture.budget,
                epochSnapshot: snapshot,
                executionReceipt: excessiveBlockers,
                ledger: ledger,
                outputEncoder: { outputs in
                    outputEncoderCalled = true
                    return try CanonicalJSON.encode(outputs)
                },
            )
        }
        #expect(!outputEncoderCalled)
    }

    @Test("Every private execution ceiling is finite and exhaustion is inconclusive")
    func executionBudgets() throws {
        let fixture = try EvaluationFixture()
        let request = try fixture.request(partition: .selection, queryOrdinal: 1, frozen: false)
        let exceededUsage = try [
            fixture.usage(caseCount: 11),
            fixture.usage(costMicrousd: 10001),
            fixture.usage(inputTokens: 10001),
            fixture.usage(modelCalls: 4),
            fixture.usage(outputBytes: 65537),
            fixture.usage(outputTokens: 10001),
            fixture.usage(wallTimeMilliseconds: 60001),
            fixture.usage(costMicrousd: nil),
        ]

        for (index, usage) in exceededUsage.enumerated() {
            let result = try fixture.evaluate(
                request: fixture.request(
                    partition: .selection,
                    queryOrdinal: 1,
                    frozen: false,
                    requestID: "budget-request-\(index)",
                    nonce: "evaluation-budget-nonce-0000000\(index)",
                ),
                outputs: [],
                status: .budgetExceeded,
                usage: usage,
            )
            #expect(result.aggregate.decision == .inconclusive)
            #expect(result.aggregate.failureClass == .budget)
        }

        let completeOutputs = fixture.selectionSnapshot.cases.map {
            CandidateCaseOutput(blockerCodes: [], caseID: $0.caseID, outputSHA256: $0.expectedOutputSHA256)
        }
        #expect(throws: FactoryValidationError.self) {
            try fixture.evaluate(
                request: request,
                outputs: completeOutputs,
                usage: fixture.usage(inputTokens: 10001),
            )
        }
        #expect(throws: FactoryValidationError.self) {
            _ = try EvaluationExecutionBudget(
                costTracking: .tracked,
                maximumCases: 10,
                maximumCostMicrousd: 10000,
                maximumInputTokens: 10000,
                maximumModelCalls: 3,
                maximumOutputBytes: 65536,
                maximumOutputTokens: 10000,
                maximumWallTimeMilliseconds: 600_001,
            )
        }
    }

    @Test("Canonical usage decoding rejects negative counters directly and in receipts")
    func negativeUsageDecode() throws {
        let fixture = try EvaluationFixture()
        let usage = try fixture.usage()
        for key in [
            "case_count", "cost_microusd", "input_tokens", "model_calls",
            "output_bytes", "output_tokens", "wall_time_milliseconds",
        ] {
            let invalid = try mutatedCanonicalJSON(usage) { object in
                object[key] = -1
            }
            #expect(throws: FactoryValidationError.self) {
                try CanonicalJSON.decode(EvaluationExecutionUsage.self, from: invalid)
            }
        }

        let request = try fixture.request(partition: .selection, queryOrdinal: 1, frozen: false)
        let receipt = try CandidateExecutionReceipt(
            candidateSHA256: request.candidateSHA256,
            clientID: request.clientID,
            modelID: request.modelID,
            outputs: [],
            requestSHA256: request.digest,
            status: .insufficientEvidence,
            usage: fixture.usage(caseCount: 0, outputBytes: 2),
        )
        let invalidReceipt = try mutatedCanonicalJSON(receipt) { object in
            var storedUsage = try #require(object["usage"] as? [String: Any])
            storedUsage["input_tokens"] = -1
            object["usage"] = storedUsage
        }
        #expect(throws: FactoryValidationError.self) {
            try CanonicalJSON.decode(CandidateExecutionReceipt.self, from: invalidReceipt)
        }
    }

    @Test("Canonical budget decoding rejects zero ceilings and inconsistent cost policy")
    func invalidBudgetDecode() throws {
        let budget = try EvaluationFixture().budget
        for key in [
            "maximum_cases", "maximum_cost_microusd", "maximum_input_tokens", "maximum_model_calls",
            "maximum_output_bytes", "maximum_output_tokens", "maximum_wall_time_milliseconds",
        ] {
            let invalid = try mutatedCanonicalJSON(budget) { object in
                object[key] = 0
            }
            #expect(throws: FactoryValidationError.self) {
                try CanonicalJSON.decode(EvaluationExecutionBudget.self, from: invalid)
            }
        }
        let inconsistentCostPolicy = try mutatedCanonicalJSON(budget) { object in
            object["cost_tracking"] = "unavailable"
        }
        #expect(throws: FactoryValidationError.self) {
            try CanonicalJSON.decode(EvaluationExecutionBudget.self, from: inconsistentCostPolicy)
        }
        for (key, value) in [
            ("maximum_cases", EvaluationExecutionBudget.maximumKernelCases + 1),
            ("maximum_output_bytes", EvaluationExecutionBudget.maximumKernelOutputBytes + 1),
        ] {
            let overKernelCeiling = try mutatedCanonicalJSON(budget) { object in
                object[key] = value
            }
            #expect(throws: FactoryValidationError.self) {
                try CanonicalJSON.decode(EvaluationExecutionBudget.self, from: overKernelCeiling)
            }
        }
    }

    @Test("Canonical snapshots and nested aggregates re-enter semantic validation")
    func snapshotAndAggregateDecode() throws {
        let snapshot = try EvaluationFixture().selectionSnapshot
        let duplicateCases = try mutatedCanonicalJSON(snapshot) { object in
            let cases = try #require(object["cases"] as? [[String: Any]])
            object["cases"] = [cases[0], cases[0]]
        }
        #expect(throws: FactoryValidationError.self) {
            try CanonicalJSON.decode(PrivateEvaluationEpochSnapshot.self, from: duplicateCases)
        }
        let noncanonicalCases = try mutatedCanonicalJSON(snapshot) { object in
            let cases = try #require(object["cases"] as? [[String: Any]])
            object["cases"] = Array(cases.reversed())
        }
        #expect(throws: FactoryValidationError.self) {
            try CanonicalJSON.decode(PrivateEvaluationEpochSnapshot.self, from: noncanonicalCases)
        }

        let aggregate = try EvaluationAggregate(decision: .accept, failureClass: .none)
        let invalidResult = try mutatedCanonicalJSON(
            EvaluationResult(
                aggregate: aggregate,
                executionReceiptSHA256: TestValues.evidence,
                queryLedgerSHA256: TestValues.context,
            ),
        ) { object in
            var storedAggregate = try #require(object["aggregate"] as? [String: Any])
            storedAggregate["failure_class"] = "correctness"
            object["aggregate"] = storedAggregate
        }
        #expect(throws: FactoryValidationError.self) {
            try CanonicalJSON.decode(EvaluationResult.self, from: invalidResult)
        }
    }
}
