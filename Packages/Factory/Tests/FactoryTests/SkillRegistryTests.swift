import Foundation
import Testing
@testable import FactoryCore

@Suite("Skill registry and deterministic routing")
struct SkillRegistryTests {
    @Test("Checked-in legacy portfolio passes the executable registry validator")
    func checkedInRegistry() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while root.path != "/",
              !FileManager.default.fileExists(atPath: root.appending(path: ".factory/skills/registry.json").path)
        {
            root.deleteLastPathComponent()
        }
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root.appending(path: ".factory/skills/registry.json")),
        )
        let bytes = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes],
        )
        let registry = try CanonicalJSON.decode(SkillRegistry.self, from: bytes)

        try registry.validate()
        #expect(registry.skills.count == 15)
    }

    @Test("Every curated skill has an explicit inert migration disposition")
    func checkedInMigration() throws {
        let root = repositoryRoot()
        let registry = try canonicalFile(
            SkillRegistry.self,
            at: root.appending(path: ".factory/skills/registry.json"),
        )
        let migration = try canonicalFile(
            SkillMigrationPortfolio.self,
            at: root.appending(path: ".factory/skills/migration.json"),
        )

        try migration.validate(registry: registry)
        #expect(migration.entries.count == 15)
        #expect(migration.entries.filter { $0.disposition == .introduce }.map(\.skillID) == [
            "design-ingest",
            "factory-run",
            "grill-me",
        ])
        #expect(migration.unclassifiedSkillIDs.isEmpty)
        #expect(migration.status == .inertPendingActivation)
    }

    @Test("Active capability ownership is unique and routes in dependency order")
    func activeRouting() throws {
        let intake = try manifest(id: "grill-me", capability: "intake.owner-dialogue")
        let planning = try manifest(
            id: "plan-feature",
            capability: "planning.feature-contract",
            dependencies: ["grill-me"],
        )
        let registry = SkillRegistry(
            portfolioStatus: "legacy-migration-required",
            skills: [intake, planning],
        )

        try registry.validate()
        let selected = try SkillRouter.select(
            request: SkillRouteRequest(
                role: "foreman",
                phase: "planning",
                risk: .medium,
                capabilityIDs: ["planning.feature-contract"],
            ),
            registry: registry,
        )
        #expect(selected.map(\.id) == ["grill-me", "plan-feature"])
    }

    @Test("Duplicate owners and incomplete trigger proof fail closed")
    func ownershipAndTriggerDenials() throws {
        let ambiguous = try SkillRegistry(
            portfolioStatus: "legacy-migration-required",
            skills: [
                manifest(id: "first", capability: "review.code"),
                manifest(id: "second", capability: "review.code"),
            ],
        )
        #expect(throws: FactoryValidationError.self) { try ambiguous.validate() }

        let incomplete = try SkillRegistry(
            portfolioStatus: "legacy-migration-required",
            skills: [
                manifest(
                    id: "incomplete",
                    capability: "review.security",
                    positiveFixtures: ["one", "two"],
                ),
            ],
        )
        #expect(throws: FactoryValidationError.self) { try incomplete.validate() }
    }

    @Test("Legacy skills stay inventoried but cannot enter qualifying routes")
    func legacyIsInert() throws {
        let legacy = try manifest(id: "legacy-review", capability: "review.legacy", status: .legacy)
        let registry = SkillRegistry(
            portfolioStatus: "legacy-migration-required",
            skills: [legacy],
        )

        try registry.validate()
        #expect(throws: FactoryValidationError.self) {
            try SkillRouter.select(
                request: SkillRouteRequest(
                    role: "reviewer",
                    phase: "reviewing",
                    risk: .low,
                    capabilityIDs: ["review.legacy"],
                ),
                registry: registry,
            )
        }
    }

    @Test("Declared context totals must equal their progressive-disclosure parts")
    func contextBudgetDenial() throws {
        let overBudget = try manifest(
            id: "large",
            capability: "planning.large",
            contextBudget: SkillContextBudget(
                bodyBytes: 16000,
                metadataBytes: 2000,
                referenceBytes: 20000,
                resourceBytes: 40000,
                totalBytes: 64000,
            ),
        )
        let registry = SkillRegistry(
            portfolioStatus: "legacy-migration-required",
            skills: [overBudget],
        )
        #expect(throws: FactoryValidationError.self) { try registry.validate() }
    }

    @Test("Rollback predecessors are content-addressed skill versions")
    func rollbackPredecessorIdentity() throws {
        let registry = try SkillRegistry(
            portfolioStatus: "legacy-migration-required",
            skills: [manifest(id: "rollback", capability: "review.rollback")],
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: CanonicalJSON.encode(registry)) as? [String: Any],
        )
        var skills = try #require(object["skills"] as? [[String: Any]])
        skills[0]["rollback_predecessor"] = "not-a-content-digest"
        object["skills"] = skills
        let bytes = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes],
        )

        #expect(throws: (any Error).self) {
            let decoded = try CanonicalJSON.decode(SkillRegistry.self, from: bytes)
            try decoded.validate()
        }
    }

    private func manifest(
        id: String,
        capability: String,
        dependencies: [String] = [],
        status: SkillLifecycleStatus = .active,
        positiveFixtures: [String]? = nil,
        contextBudget: SkillContextBudget = SkillContextBudget(
            bodyBytes: 2000,
            metadataBytes: 500,
            referenceBytes: 1000,
            resourceBytes: 0,
            totalBytes: 3500,
        ),
    ) throws -> SkillManifest {
        let qualificationStatus: ClientQualificationStatus = status == .active ? .passed : .unqualified
        return try SkillManifest(
            allowedTools: ["read"],
            clientQualification: FactoryClient.allCases.map {
                ClientQualification(
                    clientID: $0,
                    clientVersion: status == .active ? "fixture" : nil,
                    modelID: status == .active ? "fixture" : nil,
                    status: qualificationStatus,
                )
            },
            conflictsWith: [],
            contextBudget: contextBudget,
            declaredCostCeiling: SkillCostCeiling(maxContextTokens: 2000, maxToolCalls: 20),
            dependencySkillIDs: dependencies,
            expectedInputs: ["accepted-contract"],
            expectedOutputs: ["structured-result"],
            handoffSkillIDs: [],
            id: id,
            nonCapabilities: ["privileged-side-effects"],
            owner: "factory",
            prerequisites: [],
            primaryCapabilityID: capability,
            progressiveDisclosurePaths: [],
            provenance: SkillProvenance(
                introduction: .introducedInCurrentChange,
                kind: .repositoryAuthored,
                license: "repository-owned",
                repositoryPath: RepositoryPath(validating: ".agents/skills/\(id)"),
                sourceCommit: TestValues.head,
                upstreamPin: nil,
            ),
            publicEvalTags: ["factory-smoke"],
            qualificationPath: RepositoryPath(validating: ".factory/skills/qualification/\(id).json"),
            qualificationSHA256: TestValues.evidence,
            resources: [],
            riskTiers: [.high, .low, .medium],
            rollbackPredecessor: nil,
            sealedPartitionID: "instruction-v1",
            sourcePath: RepositoryPath(validating: ".agents/skills/\(id)/SKILL.md"),
            sourceSHA256: SHA256Digest.hashing(Data("# \(id)".utf8)),
            status: status,
            supersedes: [],
            supportedPhases: ["planning", "reviewing"],
            supportedRoles: ["foreman", "reviewer"],
            triggerFixtureIDs: SkillTriggerFixtureIDs(
                negative: ["\(id)-negative-1", "\(id)-negative-2", "\(id)-negative-3"],
                positive: positiveFixtures ?? ["\(id)-positive-1", "\(id)-positive-2", "\(id)-positive-3"],
            ),
            verificationCommand: "scripts/check-factory-contract.sh",
            version: 1,
        )
    }

    private func repositoryRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while root.path != "/",
              !FileManager.default.fileExists(atPath: root.appending(path: ".factory/skills/registry.json").path)
        {
            root.deleteLastPathComponent()
        }
        return root
    }

    private func canonicalFile<T: Codable>(_ type: T.Type, at url: URL) throws -> T {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let bytes = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes],
        )
        return try CanonicalJSON.decode(type, from: bytes)
    }
}
