import enum CryptoKit.Curve25519
import Foundation
import Testing
@testable import FactoryCore

struct EvaluatorProcessHarness {
    let fixture: EvaluationFixture
    let request: EvaluationRequest
    let root: URL
    let signingKey: Curve25519.Signing.PrivateKey
    let sealedExecutor: Curve25519.Signing.PrivateKey
    let selectionExecutor: Curve25519.Signing.PrivateKey
    let signingKeyURL: URL
    let runtimeBinding: EvaluatorRuntimeBinding

    private var evaluateArguments: [String] {
        [
            "query",
            "evaluate",
            "sealed",
            root.path,
            signingKeyURL.path,
            "/fixture/execution.json",
        ]
    }

    init() throws {
        let fixture = try EvaluationFixture()
        let root = try fixture.makeLedgerRoot(prefix: "evaluator-process")
        let signingKey = Curve25519.Signing.PrivateKey()
        let otherSigningKey = Curve25519.Signing.PrivateKey()
        let sealedExecutor = Curve25519.Signing.PrivateKey()
        let selectionExecutor = Curve25519.Signing.PrivateKey()
        let signingKeyURL = root.appending(path: "attestation.key")
        try signingKey.rawRepresentation.write(to: signingKeyURL, options: .withoutOverwriting)
        #expect(Darwin.chmod(signingKeyURL.path, 0o600) == 0)

        self.fixture = fixture
        request = try fixture.request(partition: .sealed, queryOrdinal: 1, frozen: true)
        self.root = root
        self.signingKey = signingKey
        self.sealedExecutor = sealedExecutor
        self.selectionExecutor = selectionExecutor
        self.signingKeyURL = signingKeyURL
        runtimeBinding = try EvaluatorRuntimeBinding(
            anchor: EvaluatorRuntimeAnchor(
                evaluatorSHA256: fixture.policy.evaluatorSHA256,
                policySHA256: fixture.policy.digest,
                sealedExecutionPublicKey: sealedExecutor.publicKey.rawRepresentation,
                sealedSigningPublicKeySHA256: SHA256Digest.hashing(signingKey.publicKey.rawRepresentation),
                sealedUserID: Int(getuid()),
                selectionExecutionPublicKey: selectionExecutor.publicKey.rawRepresentation,
                selectionSigningPublicKeySHA256: SHA256Digest.hashing(
                    otherSigningKey.publicKey.rawRepresentation,
                ),
                selectionUserID: Int(getuid()) + 1,
                trustedRootSHA: fixture.policy.trustedRootSHA,
            ),
            partition: .sealed,
        )
    }

    func initializeLedger() throws {
        let result = try run(
            arguments: ["query", "initialize", "sealed", root.path, "/fixture/initialize.json"],
            standardInput: CanonicalJSON.encode(fixture.policy),
            at: "2026-07-11T00:00:00Z",
        )
        #expect(result.exitCode == 0)
    }

    func reserveAndRetry() throws -> EvaluationExecutionAuthorization {
        let arguments = [
            "query",
            "reserve",
            "sealed",
            root.path,
            signingKeyURL.path,
            "/fixture/reservation.json",
        ]
        let input = try CanonicalJSON.encode(EvaluationReservationCommand(
            policy: fixture.policy,
            request: request,
        ))
        let reserved = try run(arguments: arguments, standardInput: input, at: "2026-07-11T00:00:10Z")
        #expect(reserved.exitCode == 0)
        let retry = try run(arguments: arguments, standardInput: input, at: "2026-07-11T00:00:40Z")
        #expect(retry.exitCode == 0)
        #expect(retry.standardOutput == reserved.standardOutput)
        return try CanonicalJSON.decode(EvaluationExecutionAuthorization.self, from: reserved.standardOutput)
    }

    func proveAuthorizationReplayDenial(_ authorization: EvaluationExecutionAuthorization) throws {
        let replayRoot = try fixture.makeLedgerRoot(prefix: "executor-authorization-replay")
        let replay = try EvaluationAuthorizationReplayLedger.initialize(
            at: replayRoot,
            partition: .sealed,
            epochSHA256: request.epochSHA256,
        )
        let head = try replay.consume(
            authorization,
            request: request,
            reservationSHA256: authorization.reservationSHA256,
            now: "2026-07-11T00:00:20Z",
            evaluatorPublicKey: signingKey.publicKey,
        )
        #expect(head != TestValues.zero)
        #expect(throws: FactoryValidationError.self) {
            try EvaluationAuthorizationReplayLedger(
                opening: replayRoot,
                partition: .sealed,
                epochSHA256: request.epochSHA256,
            ).consume(
                authorization,
                request: request,
                reservationSHA256: authorization.reservationSHA256,
                now: "2026-07-11T00:00:20Z",
                evaluatorPublicKey: signingKey.publicKey,
            )
        }
    }

    func executionInput(
        for authorization: EvaluationExecutionAuthorization,
    ) throws -> (authorized: AuthorizedCandidateExecutionReceipt, input: Data) {
        let outputs = fixture.sealedSnapshot.cases.map {
            CandidateCaseOutput(blockerCodes: [], caseID: $0.caseID, outputSHA256: $0.expectedOutputSHA256)
        }
        let receipt = try CandidateExecutionReceipt(
            candidateSHA256: request.candidateSHA256,
            clientID: request.clientID,
            modelID: request.modelID,
            outputs: outputs,
            requestSHA256: request.digest,
            status: .complete,
            usage: fixture.usage(
                caseCount: outputs.count,
                outputBytes: CanonicalJSON.encode(outputs).count,
            ),
        )
        let authorized = try AuthorizedCandidateExecutionReceipt(
            authorizationSHA256: authorization.digest,
            completedAt: "2026-07-11T00:00:30Z",
            receipt: receipt,
            startedAt: "2026-07-11T00:00:20Z",
        )
        let input = try evaluationInput(
            authorization: authorization,
            receipt: authorized,
            signature: sealedExecutor.signature(for: CanonicalJSON.encode(authorized)),
        )
        return (authorized, input)
    }

    func proveExecutionSignatureDenials(
        authorization: EvaluationExecutionAuthorization,
        authorizedReceipt: AuthorizedCandidateExecutionReceipt,
    ) throws {
        let receiptOnlySignature = try sealedExecutor.signature(
            for: CanonicalJSON.encode(authorizedReceipt.receipt),
        )
        let preauthorization = try run(
            arguments: evaluateArguments,
            standardInput: evaluationInput(
                authorization: authorization,
                receipt: authorizedReceipt,
                signature: receiptOnlySignature,
            ),
            at: "2026-07-11T00:00:20Z",
        )
        try expectSignatureDenial(preauthorization)

        let forged = try run(
            arguments: evaluateArguments,
            standardInput: evaluationInput(
                authorization: authorization,
                receipt: authorizedReceipt,
                signature: selectionExecutor.signature(for: CanonicalJSON.encode(authorizedReceipt)),
            ),
            at: "2026-07-11T00:00:30Z",
        )
        try expectSignatureDenial(forged)
    }

    func evaluateRecoverAndRenew(
        input: Data,
    ) throws -> (first: AggregateAttestation, renewed: AggregateAttestation) {
        let evaluation = try run(
            arguments: evaluateArguments,
            standardInput: input,
            at: "2026-07-11T00:20:00Z",
        )
        #expect(evaluation.exitCode == 0)
        let first = try CanonicalJSON.decode(AggregateAttestation.self, from: evaluation.standardOutput)
        let restarted = try run(
            arguments: evaluateArguments,
            standardInput: input,
            at: "2026-07-11T00:21:00Z",
        )
        #expect(restarted.exitCode == 0)
        #expect(restarted.standardOutput == evaluation.standardOutput)

        let renewal = try run(
            arguments: evaluateArguments,
            standardInput: input,
            at: "2026-07-11T00:26:00Z",
        )
        #expect(renewal.exitCode == 0)
        #expect(renewal.standardOutput != evaluation.standardOutput)
        let renewed = try CanonicalJSON.decode(AggregateAttestation.self, from: renewal.standardOutput)
        #expect(renewed.requestSHA256 == first.requestSHA256)
        #expect(renewed.queryLedgerSHA256 == first.queryLedgerSHA256)
        #expect(renewed.issuedAt == "2026-07-11T00:26:00Z")
        return (first, renewed)
    }

    func proveSemanticAttestationReplayDenial(
        first: AggregateAttestation,
        renewed: AggregateAttestation,
    ) throws {
        let replayLedger = try EvaluationAttestationReplayLedger.initialize(
            at: fixture.makeLedgerRoot(prefix: "process-attestation-replay"),
            partition: .sealed,
            epochSHA256: request.epochSHA256,
        )
        let keyDigest = SHA256Digest.hashing(signingKey.publicKey.rawRepresentation)
        let keyID = "evaluator-\(keyDigest.rawValue.prefix(32))"
        #expect(try EvaluationAttestationSigner.verify(
            first,
            request: request,
            policy: fixture.policy,
            expectedQueryLedgerSHA256: first.queryLedgerSHA256,
            expectedSigningKeyID: keyID,
            now: first.issuedAt,
            replayLedger: replayLedger,
            publicKey: signingKey.publicKey,
        ))
        #expect(throws: FactoryValidationError.self) {
            try EvaluationAttestationSigner.verify(
                renewed,
                request: request,
                policy: fixture.policy,
                expectedQueryLedgerSHA256: renewed.queryLedgerSHA256,
                expectedSigningKeyID: keyID,
                now: renewed.issuedAt,
                replayLedger: replayLedger,
                publicKey: signingKey.publicKey,
            )
        }
    }

    private func evaluationInput(
        authorization: EvaluationExecutionAuthorization,
        receipt: AuthorizedCandidateExecutionReceipt,
        signature: Data,
    ) throws -> Data {
        try CanonicalJSON.encode(EvaluationExecutionCommand(
            authorization: authorization,
            budget: fixture.budget,
            candidatePayload: fixture.defaultPayload,
            epochSnapshot: fixture.sealedSnapshot,
            executionReceipt: receipt,
            executionReceiptSignature: signature,
            policy: fixture.policy,
            request: request,
        ))
    }

    private func run(
        arguments: [String],
        standardInput: Data,
        at instant: String,
    ) throws -> FactoryCommandResult {
        try FactoryEvaluatorCommand.run(
            arguments: arguments,
            standardInput: standardInput,
            now: #require(ISO8601DateFormatter().date(from: instant)),
            runtimeBinding: runtimeBinding,
        )
    }

    private func expectSignatureDenial(_ result: FactoryCommandResult) throws {
        #expect(result.exitCode == 1)
        let envelope = try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: result.standardError)
        #expect(envelope.reasonCode == "invalid_execution_receipt_signature")
    }
}
