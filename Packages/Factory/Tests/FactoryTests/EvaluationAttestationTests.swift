import enum CryptoKit.Curve25519
import Foundation
import Testing
@testable import FactoryCore

@Suite("Evaluation policy and attestations")
struct EvaluationAttestationTests {
    @Test("Untrusted ruler, bad scope, unaccepted kinds, and stale evidence are denied")
    func policyDenials() throws {
        let fixture = try EvaluationFixture()
        let wrongBase = try fixture.request(
            partition: .selection,
            queryOrdinal: 1,
            frozen: false,
            trustedBaseSHA: TestValues.nextHead,
        )
        let wrongPath = try fixture.request(
            partition: .selection,
            queryOrdinal: 1,
            frozen: false,
            changedPaths: [RepositoryPath(validating: ".factory/policy.json")],
        )
        let unacceptedKind = try fixture.request(
            partition: .selection,
            queryOrdinal: 1,
            frozen: false,
            componentKind: .contextRoute,
        )
        let staleEvidence = try fixture.request(
            partition: .selection,
            queryOrdinal: 1,
            frozen: false,
            evidenceHeadSHA: TestValues.head,
        )
        let headRuler = try fixture.request(
            partition: .selection,
            queryOrdinal: 1,
            frozen: false,
            policySHA256: TestValues.context,
        )

        for request in [wrongBase, wrongPath, unacceptedKind, staleEvidence, headRuler] {
            #expect(throws: FactoryValidationError.self) {
                try fixture.policy.validate(request)
            }
        }
    }

    @Test("Attestation signature binds every request, ledger, lifetime, and aggregate field")
    func attestationBinding() throws {
        let fixture = try EvaluationFixture()
        let request = try fixture.request(partition: .sealed, queryOrdinal: 1, frozen: true)
        let result = try fixture.evaluate(
            request: request,
            outputs: privateCases().map {
                CandidateCaseOutput(blockerCodes: [], caseID: $0.caseID, outputSHA256: $0.expectedOutputSHA256)
            },
        )
        let privateKey = Curve25519.Signing.PrivateKey()
        let attestation = try EvaluationAttestationSigner.sign(
            request: request,
            policy: fixture.policy,
            result: result,
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T00:05:00Z",
            signingKeyID: "trusted-root-evaluator-key",
            privateKey: privateKey,
        )
        let replayRoot = try fixture.makeLedgerRoot(prefix: "attestation-replay")
        let replayLedger = try EvaluationAttestationReplayLedger.initialize(
            at: replayRoot,
            partition: request.partition,
            epochSHA256: request.epochSHA256,
        )

        #expect(try EvaluationAttestationSigner.verify(
            attestation,
            request: request,
            policy: fixture.policy,
            expectedQueryLedgerSHA256: result.queryLedgerSHA256,
            expectedSigningKeyID: "trusted-root-evaluator-key",
            now: "2026-07-11T00:01:00Z",
            replayLedger: replayLedger,
            publicKey: privateKey.publicKey,
        ))
        #expect(throws: FactoryValidationError.self) {
            try EvaluationAttestationSigner.verify(
                attestation,
                request: request,
                policy: fixture.policy,
                expectedQueryLedgerSHA256: result.queryLedgerSHA256,
                expectedSigningKeyID: "trusted-root-evaluator-key",
                now: "2026-07-11T00:01:00Z",
                replayLedger: replayLedger,
                publicKey: privateKey.publicKey,
            )
        }
        #expect(throws: FactoryValidationError.self) {
            try EvaluationAttestationSigner.verify(
                attestation,
                request: request,
                policy: fixture.policy,
                expectedQueryLedgerSHA256: result.queryLedgerSHA256,
                expectedSigningKeyID: "trusted-root-evaluator-key",
                now: "2026-07-11T00:01:00Z",
                replayLedger: EvaluationAttestationReplayLedger(
                    opening: replayRoot,
                    partition: request.partition,
                    epochSHA256: request.epochSHA256,
                ),
                publicKey: privateKey.publicKey,
            )
        }
        #expect(try !EvaluationAttestationSigner.verify(
            attestation,
            request: request,
            policy: fixture.policy,
            expectedQueryLedgerSHA256: result.queryLedgerSHA256,
            expectedSigningKeyID: "trusted-root-evaluator-key",
            now: "2026-07-11T00:05:00Z",
            replayLedger: fixture.replayLedger(for: request),
            publicKey: privateKey.publicKey,
        ))

        let rawObject = try JSONSerialization.jsonObject(with: CanonicalJSON.encode(attestation))
        var object = try #require(rawObject as? [String: Any])
        object["query_ledger_sha256"] = TestValues.context.rawValue
        let tamperedBytes = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes],
        )
        let tampered = try CanonicalJSON.decode(AggregateAttestation.self, from: tamperedBytes)
        #expect(try !EvaluationAttestationSigner.verify(
            tampered,
            request: request,
            policy: fixture.policy,
            expectedQueryLedgerSHA256: result.queryLedgerSHA256,
            expectedSigningKeyID: "trusted-root-evaluator-key",
            now: "2026-07-11T00:01:00Z",
            replayLedger: fixture.replayLedger(for: request),
            publicKey: privateKey.publicKey,
        ))

        let json = try String(decoding: CanonicalJSON.encode(attestation), as: UTF8.self)
        for forbidden in ["aggregate_metrics", "blocker_codes", "case_count", "passed_count", "score"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test("Replay identity rejects a separately signed attestation for the same private query")
    func attestationSemanticReplay() throws {
        let fixture = try EvaluationFixture()
        let request = try fixture.request(partition: .sealed, queryOrdinal: 1, frozen: true)
        let result = try fixture.evaluate(
            request: request,
            outputs: privateCases().map {
                CandidateCaseOutput(blockerCodes: [], caseID: $0.caseID, outputSHA256: $0.expectedOutputSHA256)
            },
        )
        let privateKey = Curve25519.Signing.PrivateKey()
        let first = try EvaluationAttestationSigner.sign(
            request: request,
            policy: fixture.policy,
            result: result,
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T00:05:00Z",
            signingKeyID: "trusted-root-evaluator-key",
            privateKey: privateKey,
        )
        let resigned = try EvaluationAttestationSigner.sign(
            request: request,
            policy: fixture.policy,
            result: result,
            issuedAt: "2026-07-11T00:01:00Z",
            expiresAt: "2026-07-11T00:06:00Z",
            signingKeyID: "trusted-root-evaluator-key",
            privateKey: privateKey,
        )
        let replayLedger = try EvaluationAttestationReplayLedger.initialize(
            at: fixture.makeLedgerRoot(prefix: "attestation-semantic-replay"),
            partition: request.partition,
            epochSHA256: request.epochSHA256,
        )

        #expect(try EvaluationAttestationSigner.verify(
            first,
            request: request,
            policy: fixture.policy,
            expectedQueryLedgerSHA256: result.queryLedgerSHA256,
            expectedSigningKeyID: "trusted-root-evaluator-key",
            now: "2026-07-11T00:01:00Z",
            replayLedger: replayLedger,
            publicKey: privateKey.publicKey,
        ))
        #expect(throws: FactoryValidationError.self) {
            try EvaluationAttestationSigner.verify(
                resigned,
                request: request,
                policy: fixture.policy,
                expectedQueryLedgerSHA256: result.queryLedgerSHA256,
                expectedSigningKeyID: "trusted-root-evaluator-key",
                now: "2026-07-11T00:02:00Z",
                replayLedger: replayLedger,
                publicKey: privateKey.publicKey,
            )
        }
    }

    @Test("Private companion scaffold contains data policy but no corpus or code")
    func privateScaffold() throws {
        let root = TestValues.temporaryDirectory
            .appending(path: "factory-eval-scaffold-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try EvaluationFixture()
        let schemas = [SchemaDigest(schemaID: "private-evaluation-case", sha256: TestValues.contract)]

        let expectedManifest = try PrivateEvaluationRootManifest(
            acceptanceSHA256: fixture.policy.digest,
            casesPresent: false,
            epochZeroFrozen: false,
            evaluatorCodePresent: false,
            schemaDigests: schemas,
            trustedRootSHA: TestValues.head,
        )
        let manifest = try PrivateEvaluationScaffold.generate(
            at: root,
            manifest: expectedManifest,
        )

        let files = try FileManager.default.subpathsOfDirectory(atPath: root.path).sorted()
        #expect(files == [".factory", ".factory/evaluation-root.json", ".gitignore", "README.md"])
        #expect(!manifest.casesPresent)
        #expect(!manifest.evaluatorCodePresent)
        #expect(!manifest.epochZeroFrozen)
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: ".github/workflows").path))
        let manifestBytes = try Data(contentsOf: root.appending(path: ".factory/evaluation-root.json"))
        #expect(try CanonicalJSON.decode(PrivateEvaluationRootManifest.self, from: manifestBytes) == manifest)

        #expect(throws: FactoryValidationError.self) {
            _ = try PrivateEvaluationRootManifest(
                acceptanceSHA256: fixture.policy.digest,
                casesPresent: false,
                epochZeroFrozen: false,
                evaluatorCodePresent: false,
                schemaDigests: [],
                trustedRootSHA: TestValues.head,
            )
        }
    }
}
