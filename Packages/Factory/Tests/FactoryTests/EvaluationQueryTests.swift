import enum CryptoKit.Curve25519
import Foundation
import Testing
@testable import FactoryCore

@Suite("Evaluation query ledger")
struct EvaluationQueryTests {
    @Test("Selection returns only an action and sanitized failure class")
    func selectionAggregate() throws {
        let fixture = try EvaluationFixture()
        let request = try fixture.request(partition: .selection, queryOrdinal: 1, frozen: false)
        let cases = privateCases()
        let outputs = [
            CandidateCaseOutput(blockerCodes: [], caseID: "case-a", outputSHA256: cases[0].expectedOutputSHA256),
            CandidateCaseOutput(
                blockerCodes: ["criterion-miss"],
                caseID: "case-b",
                outputSHA256: SHA256Digest.hashing(Data("wrong".utf8)),
            ),
        ]

        let result = try fixture.evaluate(request: request, outputs: outputs)

        #expect(result.aggregate.decision == .revise)
        #expect(result.aggregate.failureClass == .correctness)
        let json = try String(decoding: CanonicalJSON.encode(result), as: UTF8.self)
        for forbidden in [
            "case-a",
            "case-b",
            "case_count",
            "passed_count",
            "score",
            "metric",
            "criterion-miss",
            "wrong",
        ] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test("Sealed is one-shot, frozen, aggregate-only, and non-revisable")
    func sealedOneShot() throws {
        let fixture = try EvaluationFixture()
        let cases = privateCases()
        let outputs = cases.map {
            CandidateCaseOutput(blockerCodes: [], caseID: $0.caseID, outputSHA256: $0.expectedOutputSHA256)
        }
        let ledger = fixture.ledger(for: .sealed)
        let request = try fixture.request(partition: .sealed, queryOrdinal: 1, frozen: true)

        let accepted = try fixture.evaluate(request: request, outputs: outputs, ledger: ledger)
        #expect(accepted.aggregate.decision == .accept)
        #expect(accepted.aggregate.failureClass == .none)
        #expect(throws: FactoryValidationError.self) {
            try fixture.evaluate(request: request, outputs: outputs, ledger: ledger)
        }

        var rejectedOutputs = outputs
        rejectedOutputs[0] = CandidateCaseOutput(
            blockerCodes: [],
            caseID: "case-a",
            outputSHA256: SHA256Digest.hashing(Data("miss".utf8)),
        )
        let nextPayload = Data("candidate instructions version two".utf8)
        let next = try fixture.request(
            partition: .sealed,
            queryOrdinal: 1,
            frozen: true,
            payload: nextPayload,
            requestID: "evaluation-request-2",
            nonce: "evaluation-nonce-sealed-00000002",
        )
        #expect(throws: FactoryValidationError.self) {
            try fixture.evaluate(
                request: next,
                payload: nextPayload,
                outputs: rejectedOutputs,
                ledger: ledger,
            )
        }
    }

    @Test("Evaluation query budgets survive a process restart")
    func queryBudgetSurvivesRestart() throws {
        let fixture = try EvaluationFixture()
        let outputs = fixture.sealedSnapshot.cases.map {
            CandidateCaseOutput(blockerCodes: [], caseID: $0.caseID, outputSHA256: $0.expectedOutputSHA256)
        }
        let request = try fixture.request(partition: .sealed, queryOrdinal: 1, frozen: true)
        let root = try fixture.makeLedgerRoot(prefix: "query-restart")
        let ledger = try EvaluationQueryLedger.initialize(at: root, partition: .sealed, policy: fixture.policy)

        _ = try fixture.evaluate(request: request, outputs: outputs, ledger: ledger)

        #expect(throws: FactoryValidationError.self) {
            let reopened = try EvaluationQueryLedger(opening: root, partition: .sealed, policy: fixture.policy)
            _ = try fixture.evaluate(request: request, outputs: outputs, ledger: reopened)
        }
    }

    @Test("Evaluation ledger roots and files reject extended ACL authority")
    func evaluationLedgerACLDenials() throws {
        let fixture = try EvaluationFixture()

        let rootACL = try fixture.makeLedgerRoot(prefix: "query-root-acl")
        _ = try EvaluationQueryLedger.initialize(at: rootACL, partition: .sealed, policy: fixture.policy)
        try addEvaluationACL("everyone allow add_file,delete_child", to: rootACL)
        #expect(throws: FactoryValidationError.self) {
            _ = try EvaluationQueryLedger(opening: rootACL, partition: .sealed, policy: fixture.policy)
        }

        let stateACL = try fixture.makeLedgerRoot(prefix: "query-state-acl")
        _ = try EvaluationQueryLedger.initialize(at: stateACL, partition: .sealed, policy: fixture.policy)
        try addEvaluationACL("everyone allow write", to: stateACL.appending(path: "evaluation-query.json"))
        #expect(throws: FactoryValidationError.self) {
            _ = try EvaluationQueryLedger(opening: stateACL, partition: .sealed, policy: fixture.policy)
        }

        let lockACL = try fixture.makeLedgerRoot(prefix: "query-lock-acl")
        _ = try EvaluationQueryLedger.initialize(at: lockACL, partition: .sealed, policy: fixture.policy)
        try addEvaluationACL("everyone allow write", to: lockACL.appending(path: ".evaluation-query.lock"))
        #expect(throws: FactoryValidationError.self) {
            _ = try EvaluationQueryLedger(opening: lockACL, partition: .sealed, policy: fixture.policy)
        }

        let temporaryACL = try fixture.makeLedgerRoot(prefix: "query-temporary-acl")
        let temporaryLedger = try EvaluationQueryLedger.initialize(
            at: temporaryACL,
            partition: .sealed,
            policy: fixture.policy,
        )
        let temporary = temporaryACL.appending(path: ".evaluation-query.json.tmp")
        try Data("temporary".utf8).write(to: temporary, options: .withoutOverwriting)
        #expect(Darwin.chmod(temporary.path, 0o600) == 0)
        try addEvaluationACL("everyone allow write", to: temporary)
        let request = try fixture.request(partition: .sealed, queryOrdinal: 1, frozen: true)
        #expect(throws: FactoryValidationError.self) {
            _ = try DataOnlyEvaluator.reserve(
                request: request,
                policy: fixture.policy,
                ledger: temporaryLedger,
            )
        }
    }

    @Test("Selection continues from durable ordinal while an incomplete reservation fails closed")
    func selectionRestartAndIncompleteReservation() throws {
        let fixture = try EvaluationFixture()
        let outputs = privateCases().map {
            CandidateCaseOutput(blockerCodes: [], caseID: $0.caseID, outputSHA256: $0.expectedOutputSHA256)
        }
        let root = try fixture.makeLedgerRoot(prefix: "selection-restart")
        let firstLedger = try EvaluationQueryLedger.initialize(
            at: root,
            partition: .selection,
            policy: fixture.policy,
        )
        let first = try fixture.request(partition: .selection, queryOrdinal: 1, frozen: false)
        _ = try fixture.evaluate(request: first, outputs: outputs, ledger: firstLedger)

        let reopened = try EvaluationQueryLedger(opening: root, partition: .selection, policy: fixture.policy)
        let nextPayload = Data("candidate instructions version two".utf8)
        let reset = try fixture.request(
            partition: .selection,
            queryOrdinal: 1,
            frozen: false,
            payload: nextPayload,
            requestID: "evaluation-request-reset",
            nonce: "evaluation-nonce-reset-0123456789",
        )
        #expect(throws: FactoryValidationError.self) {
            _ = try fixture.evaluate(request: reset, payload: nextPayload, outputs: outputs, ledger: reopened)
        }
        let second = try fixture.request(
            partition: .selection,
            queryOrdinal: 2,
            frozen: false,
            payload: nextPayload,
            requestID: "evaluation-request-second",
            nonce: "evaluation-nonce-second-012345678",
        )
        _ = try fixture.evaluate(request: second, payload: nextPayload, outputs: outputs, ledger: reopened)

        let crashRoot = try fixture.makeLedgerRoot(prefix: "selection-incomplete")
        let crashLedger = try EvaluationQueryLedger.initialize(
            at: crashRoot,
            partition: .selection,
            policy: fixture.policy,
        )
        let pending = try fixture.request(
            partition: .selection,
            queryOrdinal: 1,
            frozen: false,
            requestID: "evaluation-request-pending",
            nonce: "evaluation-nonce-pending-01234567",
        )
        _ = try DataOnlyEvaluator.reserve(request: pending, policy: fixture.policy, ledger: crashLedger)
        let afterCrash = try EvaluationQueryLedger(
            opening: crashRoot,
            partition: .selection,
            policy: fixture.policy,
        )
        #expect(throws: FactoryValidationError.self) {
            _ = try DataOnlyEvaluator.reserve(request: pending, policy: fixture.policy, ledger: afterCrash)
        }
        let bypass = try fixture.request(
            partition: .selection,
            queryOrdinal: 2,
            frozen: false,
            payload: Data("candidate instructions after crash".utf8),
            requestID: "evaluation-request-bypass",
            nonce: "evaluation-nonce-bypass-012345678",
        )
        #expect(throws: FactoryValidationError.self) {
            _ = try DataOnlyEvaluator.reserve(
                request: bypass,
                policy: fixture.policy,
                ledger: afterCrash,
            )
        }
    }

    @Test("Two reopened ledgers cannot reserve the same nonce or ordinal")
    func durableReservationContention() throws {
        let fixture = try EvaluationFixture()
        let root = try fixture.makeLedgerRoot(prefix: "query-contention")
        let first = try EvaluationQueryLedger.initialize(at: root, partition: .selection, policy: fixture.policy)
        let second = try EvaluationQueryLedger(opening: root, partition: .selection, policy: fixture.policy)
        let request = try fixture.request(partition: .selection, queryOrdinal: 1, frozen: false)

        _ = try DataOnlyEvaluator.reserve(request: request, policy: fixture.policy, ledger: first)
        #expect(throws: FactoryValidationError.self) {
            _ = try DataOnlyEvaluator.reserve(request: request, policy: fixture.policy, ledger: second)
        }
    }

    @Test("Selection revisions cannot reset their query budget by changing bytes")
    func selectionRevisionOrdering() throws {
        let fixture = try EvaluationFixture()
        let outputs = privateCases().map {
            CandidateCaseOutput(blockerCodes: [], caseID: $0.caseID, outputSHA256: $0.expectedOutputSHA256)
        }
        let ledger = fixture.ledger(for: .selection)
        let first = try fixture.request(partition: .selection, queryOrdinal: 1, frozen: false)
        _ = try fixture.evaluate(request: first, outputs: outputs, ledger: ledger)

        let nextPayload = Data("candidate instructions version two".utf8)
        let reset = try fixture.request(
            partition: .selection,
            queryOrdinal: 1,
            frozen: false,
            payload: nextPayload,
            requestID: "evaluation-request-2",
            nonce: "evaluation-nonce-select-00000002",
        )
        #expect(throws: FactoryValidationError.self) {
            try fixture.evaluate(
                request: reset,
                payload: nextPayload,
                outputs: outputs,
                ledger: ledger,
            )
        }

        let second = try fixture.request(
            partition: .selection,
            queryOrdinal: 2,
            frozen: false,
            payload: nextPayload,
            requestID: "evaluation-request-3",
            nonce: "evaluation-nonce-select-00000003",
        )
        _ = try fixture.evaluate(
            request: second,
            payload: nextPayload,
            outputs: outputs,
            ledger: ledger,
        )
    }

    @Test("Query budgets cannot reset across allowed client or model identities")
    func queryIdentityCannotReset() throws {
        let fixture = try EvaluationFixture(
            allowedClientIDs: ["claude", "codex"],
            allowedModelIDs: ["fixture-model", "other-model"],
        )
        let outputs = privateCases().map {
            CandidateCaseOutput(blockerCodes: [], caseID: $0.caseID, outputSHA256: $0.expectedOutputSHA256)
        }

        let sealedLedger = fixture.ledger(for: .sealed)
        let sealed = try fixture.request(partition: .sealed, queryOrdinal: 1, frozen: true)
        _ = try fixture.evaluate(request: sealed, outputs: outputs, ledger: sealedLedger)
        let switchedSealed = try fixture.request(
            partition: .sealed,
            queryOrdinal: 1,
            frozen: true,
            requestID: "evaluation-request-2",
            nonce: "evaluation-nonce-sealed-00000002",
            clientID: "claude",
            modelID: "other-model",
        )
        #expect(throws: FactoryValidationError.self) {
            try fixture.evaluate(request: switchedSealed, outputs: outputs, ledger: sealedLedger)
        }

        let selectionLedger = fixture.ledger(for: .selection)
        let selection = try fixture.request(partition: .selection, queryOrdinal: 1, frozen: false)
        _ = try fixture.evaluate(request: selection, outputs: outputs, ledger: selectionLedger)
        let resetSelection = try fixture.request(
            partition: .selection,
            queryOrdinal: 1,
            frozen: false,
            requestID: "evaluation-request-3",
            nonce: "evaluation-nonce-select-00000003",
            clientID: "claude",
            modelID: "other-model",
        )
        #expect(throws: FactoryValidationError.self) {
            try fixture.evaluate(request: resetSelection, outputs: outputs, ledger: selectionLedger)
        }
    }

    @Test("Insufficient evidence is signed as inconclusive and ledgers cannot cross partitions")
    func inconclusiveAndPartitionedLedger() throws {
        let fixture = try EvaluationFixture()
        let selection = try fixture.request(partition: .selection, queryOrdinal: 1, frozen: false)
        let result = try fixture.evaluate(
            request: selection,
            outputs: [],
            status: .insufficientEvidence,
        )
        #expect(result.aggregate.decision == .inconclusive)
        #expect(result.aggregate.failureClass == .insufficientEvidence)

        let sealed = try fixture.request(partition: .sealed, queryOrdinal: 1, frozen: true)
        #expect(throws: FactoryValidationError.self) {
            try fixture.evaluate(
                request: sealed,
                outputs: [],
                status: .insufficientEvidence,
                ledger: fixture.ledger(for: .selection),
            )
        }
    }
}
