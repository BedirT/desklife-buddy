import Foundation
import Testing
@testable import FactoryCore

@Suite("Transparent context compiler")
struct ContextCompilerTests {
    @Test("Compilation is ordered, content-addressed, and excludes unselected skill bodies")
    func deterministicPacket() throws {
        let request = try ContextCompilationRequest(
            invocationID: "invoke-builder-1",
            issueNumber: 42,
            role: .builder,
            headSHA: TestValues.head,
            contractSHA256: TestValues.contract,
            cleanWorktree: true,
            planPath: RepositoryPath(validating: "docs/plans/feature.md"),
            orderedPaths: [
                RepositoryPath(validating: ".factory/prompts/builder.md"),
                RepositoryPath(validating: "docs/plans/feature.md"),
                RepositoryPath(validating: ".agents/skills/design-system/SKILL.md"),
            ],
            orderedPromptPaths: [RepositoryPath(validating: ".factory/prompts/builder.md")],
            sources: [
                ContextSource(path: RepositoryPath(validating: "docs/plans/feature.md"), text: "Accepted plan"),
                ContextSource(
                    path: RepositoryPath(validating: ".agents/skills/design-system/SKILL.md"),
                    text: "Design tokens only",
                ),
                ContextSource(
                    path: RepositoryPath(validating: ".factory/prompts/builder.md"),
                    text: "Build the slice",
                ),
            ],
            excludedContext: [
                ContextExclusion(pathOrClass: "raw-design-video", reason: "Private source remains local"),
            ],
            selectedSkills: ["design-system"],
            client: .codex,
            clientVersion: "0.144.3",
            minimumVersion: "0.144.3",
            permissionMode: .scratchWrite,
            networkPolicy: .brokeredProviderOnly,
            outputSchema: RepositoryPath(validating: ".factory/schemas/report.schema.json"),
            toolAllowlist: ["read", "shell"],
            timeoutSeconds: 900,
            maximumBytes: 8192,
        )
        let first = try FactoryContextCompiler.compile(request)
        let second = try FactoryContextCompiler.compile(request)
        #expect(first == second)
        #expect(first.includedFiles.map(\.path) == request.orderedPaths)
        #expect(first.launch.selectedSkillIDs == ["design-system"])
        #expect(first.launch.environmentKeys.isEmpty)
        #expect(first.totalBytes == request.sources.reduce(0) { $0 + $1.text.utf8.count })
        #expect(first.launch.promptSHA256 == SHA256Digest.hashing(Data("Build the slice".utf8)))
    }

    @Test("Dirty trees, budget overflow, and unselected skill projection fail closed")
    func denial() throws {
        let base = try requestWithSkill(path: ".agents/skills/design-system/SKILL.md", selected: ["design-system"])
        let dirty = ContextCompilationRequest(copying: base, cleanWorktree: false)
        #expect(throws: FactoryValidationError.self) { try FactoryContextCompiler.compile(dirty) }

        let overBudget = ContextCompilationRequest(copying: base, maximumBytes: 1)
        #expect(throws: FactoryValidationError.self) { try FactoryContextCompiler.compile(overBudget) }

        let leaked = try requestWithSkill(path: ".agents/skills/grill-me/SKILL.md", selected: ["design-system"])
        #expect(throws: FactoryValidationError.self) { try FactoryContextCompiler.compile(leaked) }
    }

    private func requestWithSkill(path: String, selected: [String]) throws -> ContextCompilationRequest {
        let prompt = try RepositoryPath(validating: ".factory/prompts/builder.md")
        let plan = try RepositoryPath(validating: "docs/plans/feature.md")
        let skill = try RepositoryPath(validating: path)
        return try ContextCompilationRequest(
            invocationID: "invoke-builder-1",
            issueNumber: 42,
            role: .builder,
            headSHA: TestValues.head,
            contractSHA256: TestValues.contract,
            cleanWorktree: true,
            planPath: RepositoryPath(validating: "docs/plans/feature.md"),
            orderedPaths: [prompt, plan, skill],
            orderedPromptPaths: [prompt],
            sources: [
                ContextSource(path: prompt, text: "Build"),
                ContextSource(path: plan, text: "Plan"),
                ContextSource(path: skill, text: "Skill"),
            ],
            excludedContext: [],
            selectedSkills: selected,
            client: .codex,
            clientVersion: "0.144.3",
            minimumVersion: "0.144.3",
            permissionMode: .scratchWrite,
            networkPolicy: .brokeredProviderOnly,
            outputSchema: RepositoryPath(validating: ".factory/schemas/report.schema.json"),
            toolAllowlist: ["read"],
            timeoutSeconds: 900,
            maximumBytes: 8192,
        )
    }
}
