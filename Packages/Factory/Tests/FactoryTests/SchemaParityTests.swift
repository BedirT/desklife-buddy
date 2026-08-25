import Foundation
import Testing
@testable import FactoryCore

@Suite("Checked-in schema fixture parity")
struct SchemaParityTests {
    @Test("Factory and skill fixtures decode through their public Codable models")
    func factoryAndSkillModels() throws {
        try assertParity(WorkItemGraph.self, record: "WorkItemGraph", fixture: "factory-fixtures.json")
        try assertParity(
            FactoryState.self,
            record: "FactoryState",
            fixture: "factory-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            StateCAS.self,
            record: "StateCAS",
            fixture: "factory-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            TransitionRequest.self,
            record: "TransitionRequest",
            fixture: "factory-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            ClientLaunchManifest.self,
            record: "ClientLaunchManifest",
            fixture: "factory-fixtures.json",
        )
        try assertParity(ContextPacket.self, record: "ContextPacket", fixture: "factory-fixtures.json")
        try assertParity(SkillRegistry.self, record: "SkillRegistry", fixture: "skills-fixtures.json")
        try assertParity(
            SkillMigrationPortfolio.self,
            record: "SkillMigrationPortfolio",
            fixture: "skills-fixtures.json",
            rejectInvalid: true,
        )
    }

    @Test("Route and design fixtures decode through their semantic models")
    func routeAndDesignModels() throws {
        try assertParity(
            WorkflowRoutePolicy.self,
            record: "WorkflowRoutePolicy",
            fixture: "routing-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            WorkflowRouteRequest.self,
            record: "WorkflowRouteRequest",
            fixture: "routing-fixtures.json",
        )
        try assertParity(
            CompiledWorkflowRoute.self,
            record: "CompiledWorkflowRoute",
            fixture: "routing-fixtures.json",
        )
        try assertParity(
            DesignSourceManifest.self,
            record: "DesignSourceManifest",
            fixture: "design-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            DesignTranslationContract.self,
            record: "DesignTranslationContract",
            fixture: "design-fixtures.json",
        )
        try assertParity(
            DesignTranslationValidationInput.self,
            record: "DesignTranslationValidationInput",
            fixture: "design-fixtures.json",
            rejectInvalid: true,
        )
    }

    @Test("Execution, report, and learning fixtures decode through their semantic models")
    func factoryV1Models() throws {
        try assertParity(
            FactoryClientProfile.self,
            record: "FactoryClientProfile",
            fixture: "execution-fixtures.json",
        )
        try assertParity(
            FactoryRoleInvocation.self,
            record: "FactoryRoleInvocation",
            fixture: "execution-fixtures.json",
        )
        try assertParity(
            FactoryClientLaunchPlan.self,
            record: "FactoryClientLaunchPlan",
            fixture: "execution-fixtures.json",
        )
        try assertParity(
            FactoryControllerPlanningInput.self,
            record: "FactoryControllerPlanningInput",
            fixture: "execution-fixtures.json",
        )
        try assertParity(
            FactoryControllerPlan.self,
            record: "FactoryControllerPlan",
            fixture: "execution-fixtures.json",
        )
        try assertParity(
            FactoryFinding.self,
            record: "FactoryFinding",
            fixture: "execution-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            FactoryNormalizedClientResult.self,
            record: "FactoryNormalizedClientResult",
            fixture: "execution-fixtures.json",
        )
        try assertParity(
            FactoryRepairOutcome.self,
            record: "FactoryRepairOutcome",
            fixture: "execution-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(FactoryReport.self, record: "FactoryReport", fixture: "report-fixtures.json")
        try assertParity(FactoryEpisode.self, record: "FactoryEpisode", fixture: "learning-fixtures.json")
        try assertParity(
            SkillOptAdapterPolicy.self,
            record: "SkillOptAdapterPolicy",
            fixture: "learning-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            FrozenSkillCandidate.self,
            record: "FrozenSkillCandidate",
            fixture: "learning-fixtures.json",
        )
    }

    @Test("Product learning fixtures decode through owner-gated semantic models")
    func productModels() throws {
        try assertParity(
            ProductAdapterPolicy.self,
            record: "ProductAdapterPolicy",
            fixture: "product-fixtures.json",
        )
        try assertParity(
            ProductTrace.self,
            record: "ProductTrace",
            fixture: "product-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            ProductCorrection.self,
            record: "Correction",
            fixture: "product-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            ExpertDisposition.self,
            record: "ExpertDisposition",
            fixture: "product-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            ProductFinding.self,
            record: "ProductFinding",
            fixture: "product-fixtures.json",
        )
        try assertParity(
            ProductEvalTarget.self,
            record: "EvalTarget",
            fixture: "product-fixtures.json",
        )
    }

    @Test("Work-item risk tiers match the public schema")
    func workItemRiskTierParity() throws {
        let schemaURL = repositoryRoot().appending(path: ".factory/schemas/factory.schema.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL))
        let document = try #require(object as? [String: Any])
        let definitions = try #require(document["$defs"] as? [String: Any])
        let riskTier = try #require(definitions["RiskTierId"] as? [String: Any])
        let schemaValues = try #require(riskTier["enum"] as? [String])

        #expect(RiskTier.allCases.map(\.rawValue).sorted() == schemaValues.sorted())
    }

    @Test("Kernel fixtures decode through the exact broker, isolation, and patch models")
    func kernelModels() throws {
        try assertParity(
            BrokerActivationReceipt.self,
            record: "BrokerActivationReceipt",
            fixture: "kernel-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            BrokerTrustAnchor.self,
            record: "BrokerTrustAnchor",
            fixture: "kernel-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(BrokerRequest.self, record: "BrokerRequest", fixture: "kernel-fixtures.json")
        try assertParity(
            BrokerResponse.self,
            record: "BrokerResponse",
            fixture: "kernel-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            ScratchProjectionInventory.self,
            record: "ScratchProjectionInventory",
            fixture: "kernel-fixtures.json",
        )
        try assertParity(RunnerIsolation.self, record: "RunnerIsolation", fixture: "kernel-fixtures.json")
        try assertParity(PatchEnvelope.self, record: "PatchEnvelope", fixture: "kernel-fixtures.json")
        try assertParity(BrokerAuditEntry.self, record: "AuditEntry", fixture: "kernel-fixtures.json")
    }

    @Test("Evaluator fixtures decode through the frozen trusted root models")
    func evaluatorModels() throws {
        try assertParity(
            EvolutionAcceptancePolicy.self,
            record: "EvolutionAcceptancePolicy",
            fixture: "evaluator-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            PrivateEvaluationRootManifest.self,
            record: "PrivateEvaluationRootManifest",
            fixture: "evaluator-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            EvaluationRequest.self,
            record: "EvaluationRequest",
            fixture: "evaluator-fixtures.json",
            rejectInvalid: true,
        )
        try assertParity(
            AggregateAttestation.self,
            record: "AggregateAttestation",
            fixture: "evaluator-fixtures.json",
            rejectInvalid: true,
        )
    }

    private func assertParity(
        _ type: (some Codable & Equatable).Type,
        record: String,
        fixture: String,
        rejectInvalid: Bool = false,
    ) throws {
        let root = repositoryRoot()
        let url = root
            .appending(path: ".factory/evals/public/schemas", directoryHint: .isDirectory)
            .appending(path: fixture)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        guard let payload = object as? [String: Any],
              let fixtures = payload["fixtures"] as? [[String: Any]],
              let entry = fixtures.first(where: { $0["record_name"] as? String == record })
        else {
            Issue.record("Missing valid fixture for \(record)")
            return
        }
        let valid: Any
        if let embedded = entry["valid"] {
            valid = embedded
        } else if let reference = entry["valid_ref"] as? String {
            valid = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appending(path: reference)))
        } else {
            Issue.record("Missing valid fixture payload for \(record)")
            return
        }
        let bytes = try JSONSerialization.data(withJSONObject: valid, options: [.sortedKeys, .withoutEscapingSlashes])
        do {
            let decoded = try CanonicalJSON.decode(type, from: bytes)
            #expect(try CanonicalJSON.encode(decoded) == bytes)
        } catch let error as FactoryValidationError where error.code == "noncanonical_json" {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .custom { path in
                FactoryJSONKey(snakeCase: path.last?.stringValue ?? "")
            }
            let decoded = try decoder.decode(type, from: bytes)
            let reencoded = try CanonicalJSON.encode(decoded)
            Issue
                .record(
                    "\(record) Codable mismatch: expected \(String(decoding: bytes, as: UTF8.self)); encoded \(String(decoding: reencoded, as: UTF8.self))",
                )
        } catch {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .custom { path in
                FactoryJSONKey(snakeCase: path.last?.stringValue ?? "")
            }
            do {
                _ = try decoder.decode(type, from: bytes)
                Issue.record("\(record) strict decode failed: \(error)")
            } catch {
                Issue.record("\(record) decode failed: \(error)")
            }
        }

        guard rejectInvalid else { return }
        guard let invalid = entry["invalid"] else {
            Issue.record("Missing invalid fixture payload for \(record)")
            return
        }
        let invalidBytes = try JSONSerialization.data(
            withJSONObject: invalid,
            options: [.sortedKeys, .withoutEscapingSlashes],
        )
        #expect(throws: FactoryValidationError.self) {
            let decoded = try CanonicalJSON.decode(type, from: invalidBytes)
            if let source = decoded as? DesignSourceManifest {
                try source.validate()
            }
        }
    }

    private func repositoryRoot() -> URL {
        var cursor = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while cursor.path != "/" {
            if FileManager.default.fileExists(atPath: cursor.appending(path: ".factory/schemas/catalog.json").path) {
                return cursor
            }
            cursor.deleteLastPathComponent()
        }
        preconditionFailure("Repository root not found from test file path")
    }
}
