import enum CryptoKit.Curve25519
import Foundation
import Testing
@testable import FactoryCore

@Suite("Evaluator runtime and restart")
struct EvaluatorRuntimeTests {
    @Test("Evaluator runtime anchor independently binds policy and partition")
    func evaluatorRuntimeBindingDenials() throws {
        let fixture = try EvaluationFixture()
        let root = try fixture.makeLedgerRoot(prefix: "evaluator-runtime-binding")
        let policyBytes = try CanonicalJSON.encode(fixture.policy)
        let sealedExecutor = Curve25519.Signing.PrivateKey()
        let selectionExecutor = Curve25519.Signing.PrivateKey()
        let mismatchedPolicy = try EvaluatorRuntimeBinding(
            anchor: EvaluatorRuntimeAnchor(
                evaluatorSHA256: fixture.policy.evaluatorSHA256,
                policySHA256: TestValues.zero,
                sealedExecutionPublicKey: sealedExecutor.publicKey.rawRepresentation,
                sealedSigningPublicKeySHA256: TestValues.context,
                sealedUserID: Int(getuid()),
                selectionExecutionPublicKey: selectionExecutor.publicKey.rawRepresentation,
                selectionSigningPublicKeySHA256: TestValues.evidence,
                selectionUserID: Int(getuid()) + 1,
                trustedRootSHA: fixture.policy.trustedRootSHA,
            ),
            partition: .sealed,
        )
        let policyResult = FactoryEvaluatorCommand.run(
            arguments: ["query", "initialize", "sealed", root.path, "/fixture/initialize.json"],
            standardInput: policyBytes,
            now: Date(timeIntervalSince1970: 0),
            runtimeBinding: mismatchedPolicy,
        )
        #expect(policyResult.exitCode == 1)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: policyResult.standardError)
            .reasonCode == "evaluator_runtime_mismatch")

        let wrongPartition = try EvaluatorRuntimeBinding(
            anchor: EvaluatorRuntimeAnchor(
                evaluatorSHA256: fixture.policy.evaluatorSHA256,
                policySHA256: fixture.policy.digest,
                sealedExecutionPublicKey: sealedExecutor.publicKey.rawRepresentation,
                sealedSigningPublicKeySHA256: TestValues.context,
                sealedUserID: Int(getuid()),
                selectionExecutionPublicKey: selectionExecutor.publicKey.rawRepresentation,
                selectionSigningPublicKeySHA256: TestValues.evidence,
                selectionUserID: Int(getuid()) + 1,
                trustedRootSHA: fixture.policy.trustedRootSHA,
            ),
            partition: .selection,
        )
        let partitionResult = FactoryEvaluatorCommand.run(
            arguments: ["query", "initialize", "sealed", root.path, "/fixture/initialize.json"],
            standardInput: policyBytes,
            now: Date(timeIntervalSince1970: 0),
            runtimeBinding: wrongPartition,
        )
        #expect(partitionResult.exitCode == 1)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: partitionResult.standardError)
            .reasonCode == "evaluator_runtime_mismatch")
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: "evaluation-query.json").path))
    }

    @Test("Evaluator command recovers the exact signed result after reconstruction")
    func evaluatorProcessRestart() throws {
        let harness = try EvaluatorProcessHarness()
        try harness.initializeLedger()
        let authorization = try harness.reserveAndRetry()
        try harness.proveAuthorizationReplayDenial(authorization)
        let execution = try harness.executionInput(for: authorization)
        try harness.proveExecutionSignatureDenials(
            authorization: authorization,
            authorizedReceipt: execution.authorized,
        )
        let attestations = try harness.evaluateRecoverAndRenew(input: execution.input)
        try harness.proveSemanticAttestationReplayDenial(
            first: attestations.first,
            renewed: attestations.renewed,
        )
    }
}
