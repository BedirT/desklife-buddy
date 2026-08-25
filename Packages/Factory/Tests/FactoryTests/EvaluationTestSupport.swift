import enum CryptoKit.Curve25519
import Foundation
import Testing
@testable import FactoryCore

func privateCases() -> [PrivateEvaluationCase] {
    [
        PrivateEvaluationCase(
            caseID: "case-a",
            expectedOutputSHA256: SHA256Digest.hashing(Data("expected-a".utf8)),
            stratum: "trigger-positive",
        ),
        PrivateEvaluationCase(
            caseID: "case-b",
            expectedOutputSHA256: SHA256Digest.hashing(Data("expected-b".utf8)),
            stratum: "trigger-negative",
        ),
    ]
}

func mutatedCanonicalJSON(
    _ value: some Encodable,
    mutation: (inout [String: Any]) throws -> Void,
) throws -> Data {
    let raw = try JSONSerialization.jsonObject(with: CanonicalJSON.encode(value))
    var object = try #require(raw as? [String: Any])
    try mutation(&object)
    return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes],
    )
}

func addEvaluationACL(_ rule: String, to url: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/chmod")
    process.arguments = ["+a", rule, url.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw FactoryValidationError(
            code: "test_fixture_acl",
            message: "Could not install the evaluation ACL denial fixture.",
        )
    }
}

struct EvaluationFixture {
    let budget: EvaluationExecutionBudget
    let policy: EvolutionAcceptancePolicy
    let strataSHA256 = SHA256Digest.hashing(Data("private-strata".utf8))
    let defaultPayload = Data("candidate instructions".utf8)
    let sealedSnapshot: PrivateEvaluationEpochSnapshot
    let selectionSnapshot: PrivateEvaluationEpochSnapshot
    private let durableRoots = EvaluationDurableRoots()

    init(
        allowedClientIDs: [String] = ["codex"],
        allowedModelIDs: [String] = ["fixture-model"],
    ) throws {
        budget = try EvaluationExecutionBudget(
            costTracking: .tracked,
            maximumCases: 10,
            maximumCostMicrousd: 10000,
            maximumInputTokens: 10000,
            maximumModelCalls: 3,
            maximumOutputBytes: 65536,
            maximumOutputTokens: 10000,
            maximumWallTimeMilliseconds: 60000,
        )
        let cases = Self.cases
        sealedSnapshot = try PrivateEvaluationEpochSnapshot(
            cases: cases,
            epochID: "sealed-epoch-0",
            partition: .sealed,
            strataSHA256: strataSHA256,
        )
        selectionSnapshot = try PrivateEvaluationEpochSnapshot(
            cases: cases,
            epochID: "selection-epoch-0",
            partition: .selection,
            strataSHA256: strataSHA256,
        )
        policy = try EvolutionAcceptancePolicy(
            components: [
                EvolutionComponentAcceptance(
                    allowedCandidateKinds: [.instruction],
                    allowedClientIDs: allowedClientIDs,
                    allowedModelIDs: allowedModelIDs,
                    allowedPaths: [RepositoryPath(validating: ".factory/skills/probation/factory-run")],
                    baseComponentSHA256: TestValues.context,
                    budgetSHA256: budget.digest,
                    componentID: "factory-run-skill",
                    maximumCandidateBytes: 65536,
                    maximumChangedPaths: 4,
                    requiredEvidence: [EvaluationEvidenceRequirement(
                        kind: "public-evaluation",
                        sha256: TestValues.evidence,
                    )],
                    requiredSchemaDigests: [SchemaDigest(schemaID: "skill-candidate", sha256: TestValues.contract)],
                    strataSHA256: strataSHA256,
                ),
            ],
            evaluatorSHA256: SHA256Digest.hashing(Data("evaluator".utf8)),
            maximumSelectionQueries: 3,
            minimumPassRate: 1,
            sealedEpoch: EvaluationEpoch(
                epochID: "sealed-epoch-0",
                partition: .sealed,
                sha256: sealedSnapshot.digest,
            ),
            selectionEpoch: EvaluationEpoch(
                epochID: "selection-epoch-0",
                partition: .selection,
                sha256: selectionSnapshot.digest,
            ),
            trustedRootSHA: TestValues.head,
        )
    }

    func request(
        partition: EvaluationPartition,
        queryOrdinal: Int,
        frozen: Bool,
        payload: Data? = nil,
        requestID: String = "evaluation-request-1",
        nonce: String = "evaluation-nonce-012345678901234",
        trustedBaseSHA: GitObjectID = TestValues.head,
        changedPaths: [RepositoryPath]? = nil,
        componentKind: EvaluationComponentKind = .skillInstruction,
        evidenceHeadSHA: GitObjectID = TestValues.nextHead,
        policySHA256: SHA256Digest? = nil,
        clientID: String = "codex",
        modelID: String = "fixture-model",
    ) throws -> EvaluationRequest {
        let payload = payload ?? defaultPayload
        let epoch = partition == .sealed ? policy.sealedEpoch : policy.selectionEpoch
        return try EvaluationRequest(
            baseComponentSHA256: TestValues.context,
            budgetSHA256: budget.digest,
            candidateComponentID: "factory-run-skill",
            candidateHeadSHA: TestValues.nextHead,
            candidateSHA256: SHA256Digest.hashing(payload),
            changedPaths: changedPaths ??
                [RepositoryPath(validating: ".factory/skills/probation/factory-run/SKILL.md")],
            clientID: clientID,
            componentKind: componentKind,
            epoch: epoch.epochID,
            epochSHA256: epoch.sha256,
            evaluatorSHA256: policy.evaluatorSHA256,
            evidence: [
                EvaluationEvidenceReference(
                    kind: "public-evaluation",
                    provenAtHeadSHA: evidenceHeadSHA,
                    sha256: TestValues.evidence,
                ),
            ],
            frozen: frozen,
            modelID: modelID,
            nonce: nonce,
            partition: partition,
            payloadRef: EvaluationPayloadReference(
                mediaType: .markdown,
                sha256: SHA256Digest.hashing(payload),
                sizeBytes: payload.count,
            ),
            policySHA256: policySHA256 ?? policy.digest,
            queryOrdinal: queryOrdinal,
            requestID: requestID,
            schemaDigests: [SchemaDigest(schemaID: "skill-candidate", sha256: TestValues.contract)],
            strataSHA256: strataSHA256,
            trustedBaseSHA: trustedBaseSHA,
        )
    }

    func evaluate(
        request: EvaluationRequest,
        payload: Data? = nil,
        outputs: [CandidateCaseOutput],
        status: CandidateExecutionStatus = .complete,
        ledger: EvaluationQueryLedger? = nil,
        usage: EvaluationExecutionUsage? = nil,
    ) throws -> EvaluationResult {
        let ledger = ledger ?? self.ledger(for: request.partition)
        _ = try DataOnlyEvaluator.reserve(request: request, policy: policy, ledger: ledger)
        let snapshot = request.partition == .sealed ? sealedSnapshot : selectionSnapshot
        let receipt = try CandidateExecutionReceipt(
            candidateSHA256: request.candidateSHA256,
            clientID: request.clientID,
            modelID: request.modelID,
            outputs: outputs,
            requestSHA256: request.digest,
            status: status,
            usage: usage ?? self.usage(
                caseCount: outputs.count,
                outputBytes: CanonicalJSON.encode(outputs).count,
            ),
        )
        let result = try DataOnlyEvaluator.evaluate(
            request: request,
            candidatePayload: payload ?? defaultPayload,
            policy: policy,
            budget: budget,
            epochSnapshot: snapshot,
            executionReceipt: receipt,
            ledger: ledger,
        )
        let privateKey = Curve25519.Signing.PrivateKey()
        let attestation = try EvaluationAttestationSigner.sign(
            request: request,
            policy: policy,
            result: result,
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T00:05:00Z",
            signingKeyID: "fixture-evaluator-key",
            privateKey: privateKey,
        )
        try ledger.attach(attestation, to: request)
        return result
    }

    func ledger(for partition: EvaluationPartition) -> EvaluationQueryLedger {
        do {
            return try EvaluationQueryLedger.initialize(
                at: makeLedgerRoot(prefix: "query-\(partition.rawValue)"),
                partition: partition,
                policy: policy,
            )
        } catch {
            preconditionFailure("Could not create a durable evaluation query fixture: \(error)")
        }
    }

    func replayLedger(for request: EvaluationRequest) -> EvaluationAttestationReplayLedger {
        do {
            return try EvaluationAttestationReplayLedger.initialize(
                at: makeLedgerRoot(prefix: "replay-\(request.partition.rawValue)"),
                partition: request.partition,
                epochSHA256: request.epochSHA256,
            )
        } catch {
            preconditionFailure("Could not create a durable attestation fixture: \(error)")
        }
    }

    func makeLedgerRoot(prefix: String) throws -> URL {
        try durableRoots.make(prefix: prefix)
    }

    func usage(
        caseCount: Int = 2,
        costMicrousd: Int? = 1000,
        inputTokens: Int = 1000,
        modelCalls: Int = 1,
        outputBytes: Int = 1000,
        outputTokens: Int = 500,
        wallTimeMilliseconds: Int = 1000,
    ) throws -> EvaluationExecutionUsage {
        try EvaluationExecutionUsage(
            caseCount: caseCount,
            costMicrousd: costMicrousd,
            inputTokens: inputTokens,
            modelCalls: modelCalls,
            outputBytes: outputBytes,
            outputTokens: outputTokens,
            wallTimeMilliseconds: wallTimeMilliseconds,
        )
    }

    private static let cases = [
        PrivateEvaluationCase(
            caseID: "case-a",
            expectedOutputSHA256: SHA256Digest.hashing(Data("expected-a".utf8)),
            stratum: "trigger-positive",
        ),
        PrivateEvaluationCase(
            caseID: "case-b",
            expectedOutputSHA256: SHA256Digest.hashing(Data("expected-b".utf8)),
            stratum: "trigger-negative",
        ),
    ]
}

private final class EvaluationDurableRoots {
    private var roots: [URL] = []

    deinit {
        for root in roots {
            try? FileManager.default.removeItem(at: root)
        }
    }

    func make(prefix: String) throws -> URL {
        let root = TestValues.temporaryDirectory
            .appending(path: "factory-\(prefix)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        guard Darwin.chmod(root.path, 0o700) == 0 else {
            throw FactoryValidationError(
                code: "test_fixture_permissions",
                message: "Could not protect the durable evaluation test root.",
            )
        }
        roots.append(root)
        return root
    }
}
