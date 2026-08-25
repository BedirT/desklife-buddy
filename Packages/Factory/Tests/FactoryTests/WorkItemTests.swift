import Testing
@testable import FactoryCore

@Suite("Immutable WorkItem DAG")
struct WorkItemTests {
    @Test("A bounded graph produces a deterministic topological order")
    func validGraph() throws {
        let graph = try WorkItemGraph(
            issueNumber: 42,
            contractSHA256: TestValues.contract,
            items: [
                item(id: "contract"),
                item(id: "kernel", dependencies: ["contract"]),
                item(id: "proof", dependencies: ["kernel"]),
            ],
        )

        #expect(try graph.validatedTopologicalOrder().map(\.id) == ["contract", "kernel", "proof"])
    }

    @Test("Cycles, missing dependencies, and colliding writer paths are rejected")
    func invalidGraphs() throws {
        let cycle = try WorkItemGraph(
            issueNumber: 42,
            contractSHA256: TestValues.contract,
            items: [
                item(id: "a", dependencies: ["b"]),
                item(id: "b", dependencies: ["a"]),
            ],
        )
        #expect(throws: FactoryValidationError.self) {
            try cycle.validatedTopologicalOrder()
        }

        let missing = try WorkItemGraph(
            issueNumber: 42,
            contractSHA256: TestValues.contract,
            items: [item(id: "a", dependencies: ["missing"])],
        )
        #expect(throws: FactoryValidationError.self) {
            try missing.validatedTopologicalOrder()
        }

        let collision = try WorkItemGraph(
            issueNumber: 42,
            contractSHA256: TestValues.contract,
            items: [
                item(id: "a"),
                item(id: "b"),
            ],
        )
        #expect(throws: FactoryValidationError.self) {
            try collision.validateWriterPathOwnership(claimedItemIDs: ["a", "b"])
        }
    }

    @Test("Legacy skills cannot make a work item qualifying")
    func legacyExposure() throws {
        let work = try item(
            id: "a",
            skillExposures: [SkillExposure(skillID: "plan-feature", status: .legacy)],
        )

        #expect(!work.isQualifying)
    }

    private func item(
        id: String,
        dependencies: [String] = [],
        skillExposures: [SkillExposure] = [],
    ) throws -> WorkItem {
        try WorkItem(
            id: id,
            owner: "builder",
            dependencyIDs: dependencies,
            criterionIDs: ["criterion-1"],
            allowedPaths: [RepositoryPath(validating: "Packages/Factory")],
            allowedTools: ["swift"],
            contextEstimateBytes: 8192,
            risk: .high,
            initialState: .planned,
            expectedCheckpointCommit: TestValues.head,
            skillExposures: skillExposures,
        )
    }
}
