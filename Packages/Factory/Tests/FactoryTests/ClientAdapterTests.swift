import Foundation
import Testing
@testable import FactoryCore

@Suite("Codex, Claude Code, and Pi adapters")
struct ClientAdapterTests {
    @Test("All clients compile the same visible invocation binding through thin transports")
    func sharedInvocation() throws {
        let profiles = try FactoryClientProfile.factoryV1()
        #expect(profiles.map(\.client) == [.claude, .codex, .pi])

        let invocation = try FactoryRoleInvocation(
            invocationID: "invoke-builder-1",
            runID: "run-42",
            role: .builder,
            mutationMode: .scratchWrite,
            promptSHA256: TestValues.contract,
            contextSHA256: TestValues.evidence,
            selectedSkills: [
                SelectedSkillBinding(skillID: "design-system", version: 1, sourceSHA256: TestValues.evidence),
            ],
            outputSchema: FactoryOutputSchemaBinding(
                repositoryPath: RepositoryPath(validating: ".factory/schemas/kernel.schema.json"),
                sha256: SHA256Digest.hashing(Data("{\"type\":\"object\"}".utf8)),
            ),
            workingDirectory: RepositoryPath(validating: "scratch/run-42"),
            timeoutSeconds: 900,
            sessionAction: .new,
            sessionID: nil,
        )

        let plans = try profiles.map {
            try FactoryClientAdapterCompiler.compile(
                invocation,
                profile: $0,
                outputSchemaJSON: $0.client == .claude ? "{\"type\":\"object\"}" : nil,
            )
        }
        #expect(Set(plans.map(\.invocationSHA256)).count == 1)
        #expect(plans.allSatisfy { $0.promptSHA256 == invocation.promptSHA256 })
        #expect(plans.allSatisfy { $0.contextSHA256 == invocation.contextSHA256 })
        #expect(plans.allSatisfy { $0.selectedSkills == invocation.selectedSkills })
        #expect(plans.allSatisfy { $0.environmentKeys.isEmpty == true })
        #expect(plans.allSatisfy { !$0.arguments.contains("danger-full-access") })
        #expect(plans.first(where: { $0.client == .codex })?.arguments.contains("--json") == true)
        #expect(plans.first(where: { $0.client == .claude })?.arguments.contains("stream-json") == true)
        #expect(plans.first(where: { $0.client == .pi })?.arguments.contains("json") == true)
        #expect(plans.first(where: { $0.client == .codex })?.schemaDelivery == .filePath)
        #expect(plans.first(where: { $0.client == .claude })?.schemaDelivery == .inlineJSON)
        #expect(plans.first(where: { $0.client == .pi })?.schemaDelivery == .downstreamValidation)
        #expect(plans.first(where: { $0.client == .claude })?.arguments.contains("{\"type\":\"object\"}") == true)
    }

    @Test("Profiles bind observed compatibility behavior and reject authority inflation")
    func compatibilityAndAuthority() throws {
        let profiles = try FactoryClientProfile.factoryV1()
        #expect(profiles.allSatisfy { $0.supportsResume == true })
        #expect(profiles.filter(\.supportsFork).map(\.client) == [.claude, .pi])
        #expect(profiles.allSatisfy { $0.supportsCancellation == true })
        #expect(profiles.map(\.schemaDelivery) == [.inlineJSON, .filePath, .downstreamValidation])

        var codex = try #require(profiles.first(where: { $0.client == .codex }))
        codex = FactoryClientProfile(
            profileID: codex.profileID,
            client: codex.client,
            executable: codex.executable,
            minimumVersion: codex.minimumVersion,
            eventFormat: codex.eventFormat,
            baseArguments: codex.baseArguments + ["--dangerously-bypass-approvals-and-sandbox"],
            readOnlyTools: codex.readOnlyTools,
            writerTools: codex.writerTools,
            systemPromptMode: codex.systemPromptMode,
            supportsResume: codex.supportsResume,
            supportsFork: codex.supportsFork,
            supportsCancellation: codex.supportsCancellation,
            schemaDelivery: codex.schemaDelivery,
        )
        #expect(throws: FactoryValidationError.self) { try codex.validate() }
    }

    @Test("Resume and fork stay session-explicit, truthful, and authority preserving")
    func explicitSessions() throws {
        let profiles = try FactoryClientProfile.factoryV1()
        let pi = try #require(profiles.first(where: { $0.client == .pi }))
        let base = try FactoryRoleInvocation(
            invocationID: "invoke-review-1",
            runID: "run-42",
            role: .codeAuditor,
            mutationMode: .readOnly,
            promptSHA256: TestValues.contract,
            contextSHA256: TestValues.evidence,
            selectedSkills: [],
            outputSchema: FactoryOutputSchemaBinding(
                repositoryPath: RepositoryPath(validating: ".factory/schemas/factory.schema.json"),
                sha256: TestValues.contract,
            ),
            workingDirectory: RepositoryPath(validating: "scratch/run-42"),
            timeoutSeconds: 600,
            sessionAction: .resume,
            sessionID: "session-42",
        )
        let plan = try FactoryClientAdapterCompiler.compile(base, profile: pi)
        #expect(plan.arguments.contains("--session"))
        #expect(plan.arguments.contains("session-42"))
        #expect(plan.mutationMode == .readOnly)
        #expect(plan.toolAllowlist.allSatisfy { $0 != "write" && $0 != "edit" && $0 != "bash" })

        let fork = FactoryRoleInvocation(
            invocationID: base.invocationID,
            runID: base.runID,
            role: base.role,
            mutationMode: base.mutationMode,
            promptSHA256: base.promptSHA256,
            contextSHA256: base.contextSHA256,
            selectedSkills: base.selectedSkills,
            outputSchema: base.outputSchema,
            workingDirectory: base.workingDirectory,
            timeoutSeconds: base.timeoutSeconds,
            sessionAction: .fork,
            sessionID: "session-42",
        )
        #expect(try FactoryClientAdapterCompiler.compile(fork, profile: pi).arguments.contains("--fork"))
        let codex = try #require(profiles.first(where: { $0.client == .codex }))
        #expect(throws: FactoryValidationError.self) {
            try FactoryClientAdapterCompiler.compile(fork, profile: codex)
        }
    }

    @Test("Claude inline schema must match the invocation's content binding")
    func schemaBinding() throws {
        let profile = try #require(FactoryClientProfile.factoryV1().first(where: { $0.client == .claude }))
        let schema = "{\"additionalProperties\":false,\"type\":\"object\"}"
        let invocation = try FactoryRoleInvocation(
            invocationID: "invoke-builder-schema",
            runID: "run-42",
            role: .builder,
            mutationMode: .scratchWrite,
            promptSHA256: TestValues.contract,
            contextSHA256: TestValues.evidence,
            selectedSkills: [],
            outputSchema: FactoryOutputSchemaBinding(
                repositoryPath: RepositoryPath(validating: ".factory/schemas/kernel.schema.json"),
                sha256: SHA256Digest.hashing(Data(schema.utf8)),
            ),
            workingDirectory: RepositoryPath(validating: "scratch/run-42"),
            timeoutSeconds: 600,
            sessionAction: .new,
            sessionID: nil,
        )
        #expect(throws: FactoryValidationError.self) {
            try FactoryClientAdapterCompiler.compile(invocation, profile: profile, outputSchemaJSON: "{}")
        }
        let plan = try FactoryClientAdapterCompiler.compile(
            invocation,
            profile: profile,
            outputSchemaJSON: schema,
        )
        #expect(plan.outputSchema == invocation.outputSchema)
    }
}
