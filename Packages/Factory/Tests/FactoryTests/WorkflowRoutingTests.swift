import Foundation
import Testing
@testable import FactoryCore

@Suite("Deterministic workflow routing")
struct WorkflowRoutingTests {
    @Test("Checked-in route policy is the exact executable ruler")
    func checkedInPolicy() throws {
        let root = repositoryRoot()
        let raw = try Data(contentsOf: root.appending(path: ".factory/routes.json"))
        let object = try JSONSerialization.jsonObject(with: raw)
        let canonical = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes],
        )
        let decoded = try CanonicalJSON.decode(WorkflowRoutePolicy.self, from: canonical)
        let expected = try WorkflowRoutePolicy.factoryV1()
        #expect(decoded == expected)
        try decoded.validate()
    }

    @Test("Every route preserves the independent acceptance and verification spine")
    func commonSpine() throws {
        let policy = try WorkflowRoutePolicy.factoryV1()
        let route = try WorkflowRouteCompiler.compile(
            WorkflowRouteRequest(
                dimensions: [.logic],
                requestedRisk: .low,
                changedPaths: [RepositoryPath(validating: "Packages/Domain/Sources/Rule.swift")],
                designSourceIDs: [],
            ),
            policy: policy,
        )

        #expect(route.effectiveRisk == .low)
        #expect(route.steps.map(\.role) == [
            .contractAuthor,
            .contractSkeptic,
            .acceptanceAuthor,
            .builder,
            .deterministicVerifier,
            .codeAuditor,
            .repairer,
            .prShepherd,
        ])
        #expect(route.steps.filter { $0.mutationMode == .scratchWrite }.map(\.role) == [.builder, .repairer])
        #expect(try route.validatedExecutionOrder().map(\.id) == route.steps.map(\.id))
    }

    @Test("External design, UI, and motion compose without weakening either lane")
    func composedVisualRoute() throws {
        let route = try WorkflowRouteCompiler.compile(
            WorkflowRouteRequest(
                dimensions: [.externalDesign, .motion, .ui],
                requestedRisk: .low,
                changedPaths: [RepositoryPath(validating: "Packages/Features/Sources/HeroView.swift")],
                designSourceIDs: ["hero-reference"],
            ),
            policy: WorkflowRoutePolicy.factoryV1(),
        )

        #expect(route.effectiveRisk == .medium)
        #expect(route.steps.map(\.role).contains(.designIngestor))
        #expect(route.steps.map(\.role).contains(.designTranslator))
        #expect(route.steps.map(\.role).contains(.productWitness))
        #expect(route.steps.map(\.role).contains(.motionWitness))
        #expect(route.requiredEvidenceIDs.contains("design-source-provenance"))
        #expect(route.requiredEvidenceIDs.contains("source-implementation-comparison"))
        #expect(route.requiredEvidenceIDs.contains("video-motion-decomposition"))
        #expect(route.requiredEvidenceIDs.contains("reduced-motion-proof"))
    }

    @Test("Path-implied dimensions and risk cannot be downgraded")
    func pathAndRiskFloor() throws {
        let policy = try WorkflowRoutePolicy.factoryV1()

        #expect(throws: FactoryValidationError.self) {
            try WorkflowRouteCompiler.compile(
                WorkflowRouteRequest(
                    dimensions: [.logic],
                    requestedRisk: .low,
                    changedPaths: [RepositoryPath(validating: ".factory/routes.json")],
                    designSourceIDs: [],
                ),
                policy: policy,
            )
        }
        #expect(throws: FactoryValidationError.self) {
            try WorkflowRouteCompiler.compile(
                WorkflowRouteRequest(
                    dimensions: [.externalDesign, .ui],
                    requestedRisk: .medium,
                    changedPaths: [RepositoryPath(validating: "Packages/Features/Sources/View.swift")],
                    designSourceIDs: [],
                ),
                policy: policy,
            )
        }
    }

    @Test("Route policy rejects a missing acceptance oracle and concurrent writers")
    func policyDenials() throws {
        let valid = try WorkflowRoutePolicy.factoryV1()
        let missingOracle = WorkflowRoutePolicy(
            policyID: valid.policyID,
            commonRoleOrder: valid.commonRoleOrder.filter { $0 != .acceptanceAuthor },
            dimensionRules: valid.dimensionRules,
            roleDefinitions: valid.roleDefinitions,
        )
        #expect(throws: FactoryValidationError.self) { try missingOracle.validate() }

        var definitions = valid.roleDefinitions
        let authorIndex = try #require(definitions.firstIndex { $0.role == .contractAuthor })
        definitions[authorIndex] = WorkflowRoleDefinition(
            role: .contractAuthor,
            mutationMode: .scratchWrite,
            defaultModelLane: definitions[authorIndex].defaultModelLane,
        )
        let multipleWriters = WorkflowRoutePolicy(
            policyID: valid.policyID,
            commonRoleOrder: valid.commonRoleOrder,
            dimensionRules: valid.dimensionRules,
            roleDefinitions: definitions,
        )
        #expect(throws: FactoryValidationError.self) { try multipleWriters.validate() }
    }

    private func repositoryRoot() -> URL {
        var cursor = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while cursor.path != "/" {
            if FileManager.default.fileExists(atPath: cursor.appending(path: ".factory/routes.json").path) {
                return cursor
            }
            cursor.deleteLastPathComponent()
        }
        preconditionFailure("Repository root not found from test file path")
    }
}
