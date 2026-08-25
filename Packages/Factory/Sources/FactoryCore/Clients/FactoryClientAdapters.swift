import Foundation

/// Structured event stream emitted by an agent client transport.
public enum FactoryClientEventFormat: String, Codable, Sendable {
    case json
    case streamJSON = "stream-json"
}

/// How a client receives the repository-owned, human-visible system prompt.
public enum FactorySystemPromptMode: String, Codable, Sendable {
    case appendVisiblePrompt = "append-visible-prompt"
    case replaceVisiblePrompt = "replace-visible-prompt"
}

/// The exact mechanism the observed client version exposes for result schemas.
public enum FactorySchemaDeliveryMode: String, Codable, Sendable {
    case downstreamValidation = "downstream-validation"
    case filePath = "file-path"
    case inlineJSON = "inline-json"
}

public enum FactorySessionAction: String, Codable, Sendable {
    case fork
    case new
    case resume
}

/// Versioned, credential-free compatibility profile for one supported client.
public struct FactoryClientProfile: Codable, Equatable, Sendable {
    public let profileID: String
    public let client: FactoryClient
    public let executable: String
    public let minimumVersion: String
    public let eventFormat: FactoryClientEventFormat
    public let baseArguments: [String]
    public let readOnlyTools: [String]
    public let writerTools: [String]
    public let systemPromptMode: FactorySystemPromptMode
    public let supportsResume: Bool
    public let supportsFork: Bool
    public let supportsCancellation: Bool
    public let schemaDelivery: FactorySchemaDeliveryMode

    public init(
        profileID: String,
        client: FactoryClient,
        executable: String,
        minimumVersion: String,
        eventFormat: FactoryClientEventFormat,
        baseArguments: [String],
        readOnlyTools: [String],
        writerTools: [String],
        systemPromptMode: FactorySystemPromptMode,
        supportsResume: Bool,
        supportsFork: Bool,
        supportsCancellation: Bool,
        schemaDelivery: FactorySchemaDeliveryMode,
    ) {
        self.profileID = profileID
        self.client = client
        self.executable = executable
        self.minimumVersion = minimumVersion
        self.eventFormat = eventFormat
        self.baseArguments = baseArguments
        self.readOnlyTools = readOnlyTools
        self.writerTools = writerTools
        self.systemPromptMode = systemPromptMode
        self.supportsResume = supportsResume
        self.supportsFork = supportsFork
        self.supportsCancellation = supportsCancellation
        self.schemaDelivery = schemaDelivery
    }

    public static func factoryV1() throws -> [FactoryClientProfile] {
        let profiles = [
            FactoryClientProfile(
                profileID: "claude-code-v1",
                client: .claude,
                executable: "claude",
                minimumVersion: "2.1.197",
                eventFormat: .streamJSON,
                baseArguments: [
                    "--print", "--output-format", "stream-json", "--permission-mode", "dontAsk", "--safe-mode",
                ],
                readOnlyTools: ["Glob", "Grep", "Read"],
                writerTools: ["Bash", "Edit", "Glob", "Grep", "Read", "Write"],
                systemPromptMode: .replaceVisiblePrompt,
                supportsResume: true,
                supportsFork: true,
                supportsCancellation: true,
                schemaDelivery: .inlineJSON,
            ),
            FactoryClientProfile(
                profileID: "codex-cli-v1",
                client: .codex,
                executable: "codex",
                minimumVersion: "0.144.3",
                eventFormat: .json,
                baseArguments: ["exec", "--json", "--ignore-user-config"],
                readOnlyTools: ["read", "search"],
                writerTools: ["edit", "read", "search", "shell"],
                systemPromptMode: .appendVisiblePrompt,
                supportsResume: true,
                supportsFork: false,
                supportsCancellation: true,
                schemaDelivery: .filePath,
            ),
            FactoryClientProfile(
                profileID: "pi-cli-v1",
                client: .pi,
                executable: "pi",
                minimumVersion: "0.80.3",
                eventFormat: .json,
                baseArguments: [
                    "--print", "--mode", "json", "--no-extensions", "--no-prompt-templates", "--no-themes",
                    "--no-context-files", "--no-skills",
                ],
                readOnlyTools: ["find", "grep", "ls", "read"],
                writerTools: ["bash", "edit", "find", "grep", "ls", "read", "write"],
                systemPromptMode: .replaceVisiblePrompt,
                supportsResume: true,
                supportsFork: true,
                supportsCancellation: true,
                schemaDelivery: .downstreamValidation,
            ),
        ]
        for profile in profiles {
            try profile.validate()
        }
        return profiles
    }

    public func validate() throws {
        let prohibitedFragments = [
            "allow-dangerously-skip-permissions", "api-key", "bypass-approvals", "danger-full-access",
            "dangerously-bypass", "disable-sandbox", "password", "token=",
        ]
        let argumentsAreSafe = baseArguments.allSatisfy { argument in
            let folded = argument.lowercased()
            return prohibitedFragments.allSatisfy { !folded.contains($0) }
        }
        let toolSetsAreCanonical = readOnlyTools == readOnlyTools.sorted()
            && writerTools == writerTools.sorted()
            && Set(readOnlyTools).count == readOnlyTools.count
            && Set(writerTools).count == writerTools.count
            && Set(readOnlyTools).isSubset(of: Set(writerTools))
        guard FactoryTextRules.isStableID(profileID),
              executable.wholeMatch(of: /^[a-z][a-z0-9-]{0,63}$/) != nil,
              minimumVersion.wholeMatch(of: /^[0-9]+\.[0-9]+\.[0-9]+$/) != nil,
              !baseArguments.isEmpty,
              argumentsAreSafe,
              toolSetsAreCanonical,
              supportsResume,
              supportsCancellation
        else {
            throw FactoryValidationError(
                code: "invalid-client-profile",
                message: "Client profiles must be explicit, capability-complete, credential-free, and authority-bounded.",
            )
        }
    }
}

/// The path used for audit plus the digest of the canonical JSON delivered to the client or downstream gate.
public struct FactoryOutputSchemaBinding: Codable, Equatable, Sendable {
    public let repositoryPath: RepositoryPath
    public let sha256: SHA256Digest

    public init(repositoryPath: RepositoryPath, sha256: SHA256Digest) {
        self.repositoryPath = repositoryPath
        self.sha256 = sha256
    }
}

/// Content-addressed skill selected before a provider transport is chosen.
public struct SelectedSkillBinding: Codable, Equatable, Hashable, Sendable {
    public let skillID: String
    public let version: Int
    public let sourceSHA256: SHA256Digest

    public init(skillID: String, version: Int, sourceSHA256: SHA256Digest) {
        self.skillID = skillID
        self.version = version
        self.sourceSHA256 = sourceSHA256
    }
}

/// Provider-independent role request. Its digest is the cross-model authority boundary.
public struct FactoryRoleInvocation: Codable, Equatable, Sendable {
    public let invocationID: String
    public let runID: String
    public let role: WorkflowRole
    public let mutationMode: WorkflowMutationMode
    public let promptSHA256: SHA256Digest
    public let contextSHA256: SHA256Digest
    public let selectedSkills: [SelectedSkillBinding]
    public let outputSchema: FactoryOutputSchemaBinding
    public let workingDirectory: RepositoryPath
    public let timeoutSeconds: Int
    public let sessionAction: FactorySessionAction
    @RequiredNullable public var sessionID: String?

    public init(
        invocationID: String,
        runID: String,
        role: WorkflowRole,
        mutationMode: WorkflowMutationMode,
        promptSHA256: SHA256Digest,
        contextSHA256: SHA256Digest,
        selectedSkills: [SelectedSkillBinding],
        outputSchema: FactoryOutputSchemaBinding,
        workingDirectory: RepositoryPath,
        timeoutSeconds: Int,
        sessionAction: FactorySessionAction,
        sessionID: String?,
    ) {
        self.invocationID = invocationID
        self.runID = runID
        self.role = role
        self.mutationMode = mutationMode
        self.promptSHA256 = promptSHA256
        self.contextSHA256 = contextSHA256
        self.selectedSkills = selectedSkills
        self.outputSchema = outputSchema
        self.workingDirectory = workingDirectory
        self.timeoutSeconds = timeoutSeconds
        self.sessionAction = sessionAction
        self.sessionID = sessionID
    }

    public func validate() throws {
        let skillKeys = selectedSkills.map { "\($0.skillID):\($0.version)" }
        guard FactoryTextRules.isStableID(invocationID),
              FactoryTextRules.isStableID(runID),
              mutationMode != .trustedController,
              !workingDirectory.isControlPlane,
              (1 ... 7200).contains(timeoutSeconds),
              skillKeys == skillKeys.sorted(),
              Set(skillKeys).count == skillKeys.count,
              selectedSkills.allSatisfy({ FactoryTextRules.isStableID($0.skillID) && $0.version > 0 }),
              sessionID.map(FactoryTextRules.isStableID) ?? true,
              (sessionAction == .new) == (sessionID == nil)
        else {
            throw FactoryValidationError(
                code: "invalid-role-invocation",
                message: "Role invocations must be canonical and may grant only bounded scratch or read authority.",
            )
        }
    }
}

/// Exact client launch arguments derived from a shared invocation without ambient environment authority.
public struct FactoryClientLaunchPlan: Codable, Equatable, Sendable {
    public let client: FactoryClient
    public let profileID: String
    public let invocationSHA256: SHA256Digest
    public let promptSHA256: SHA256Digest
    public let contextSHA256: SHA256Digest
    public let selectedSkills: [SelectedSkillBinding]
    public let mutationMode: WorkflowMutationMode
    public let executable: String
    public let arguments: [String]
    public let toolAllowlist: [String]
    public let environmentKeys: [String]
    public let timeoutSeconds: Int
    public let outputSchema: FactoryOutputSchemaBinding
    public let schemaDelivery: FactorySchemaDeliveryMode

    public init(
        client: FactoryClient,
        profileID: String,
        invocationSHA256: SHA256Digest,
        promptSHA256: SHA256Digest,
        contextSHA256: SHA256Digest,
        selectedSkills: [SelectedSkillBinding],
        mutationMode: WorkflowMutationMode,
        executable: String,
        arguments: [String],
        toolAllowlist: [String],
        environmentKeys: [String],
        timeoutSeconds: Int,
        outputSchema: FactoryOutputSchemaBinding,
        schemaDelivery: FactorySchemaDeliveryMode,
    ) {
        self.client = client
        self.profileID = profileID
        self.invocationSHA256 = invocationSHA256
        self.promptSHA256 = promptSHA256
        self.contextSHA256 = contextSHA256
        self.selectedSkills = selectedSkills
        self.mutationMode = mutationMode
        self.executable = executable
        self.arguments = arguments
        self.toolAllowlist = toolAllowlist
        self.environmentKeys = environmentKeys
        self.timeoutSeconds = timeoutSeconds
        self.outputSchema = outputSchema
        self.schemaDelivery = schemaDelivery
    }
}

/// Read-only CLI request that chooses a transport only after the invocation is frozen.
public struct FactoryClientCompilationInput: Codable, Equatable, Sendable {
    public let client: FactoryClient
    public let invocation: FactoryRoleInvocation
    @RequiredNullable public var outputSchemaText: String?

    public init(client: FactoryClient, invocation: FactoryRoleInvocation, outputSchemaText: String?) {
        self.client = client
        self.invocation = invocation
        self.outputSchemaText = outputSchemaText
    }
}

public enum FactoryClientAdapterCompiler {
    public static func compile(
        _ invocation: FactoryRoleInvocation,
        profile: FactoryClientProfile,
        outputSchemaJSON: String? = nil,
    ) throws -> FactoryClientLaunchPlan {
        try profile.validate()
        try invocation.validate()

        let tools = invocation.mutationMode == .readOnly ? profile.readOnlyTools : profile.writerTools
        var arguments = profile.baseArguments
        switch profile.client {
        case .claude:
            let schema = try verifiedInlineSchema(outputSchemaJSON, binding: invocation.outputSchema)
            arguments += ["--json-schema", schema, "--allowedTools", tools.joined(separator: ",")]
        case .codex:
            arguments += [
                "--output-schema", invocation.outputSchema.repositoryPath.rawValue,
                "--sandbox", invocation.mutationMode == .readOnly ? "read-only" : "workspace-write",
                "--cd", invocation.workingDirectory.rawValue,
            ]
        case .pi:
            arguments += ["--tools", tools.joined(separator: ",")]
        }
        arguments += try sessionArguments(invocation: invocation, profile: profile)

        return FactoryClientLaunchPlan(
            client: profile.client,
            profileID: profile.profileID,
            invocationSHA256: CanonicalJSON.digest(invocation),
            promptSHA256: invocation.promptSHA256,
            contextSHA256: invocation.contextSHA256,
            selectedSkills: invocation.selectedSkills,
            mutationMode: invocation.mutationMode,
            executable: profile.executable,
            arguments: arguments,
            toolAllowlist: tools,
            environmentKeys: [],
            timeoutSeconds: invocation.timeoutSeconds,
            outputSchema: invocation.outputSchema,
            schemaDelivery: profile.schemaDelivery,
        )
    }

    private static func verifiedInlineSchema(
        _ value: String?,
        binding: FactoryOutputSchemaBinding,
    ) throws -> String {
        guard let value,
              let object = try? JSONSerialization.jsonObject(with: Data(value.utf8)),
              JSONSerialization.isValidJSONObject(object),
              let canonical = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.sortedKeys, .withoutEscapingSlashes],
              ),
              SHA256Digest.hashing(canonical) == binding.sha256,
              let canonicalString = String(data: canonical, encoding: .utf8)
        else {
            throw FactoryValidationError(
                code: "output-schema-binding-mismatch",
                message: "Inline schema JSON must be canonical and match the invocation's frozen schema digest.",
            )
        }
        return canonicalString
    }

    private static func sessionArguments(
        invocation: FactoryRoleInvocation,
        profile: FactoryClientProfile,
    ) throws -> [String] {
        switch invocation.sessionAction {
        case .new:
            return []
        case .resume:
            guard profile.supportsResume, let sessionID = invocation.sessionID else {
                throw unsupportedSessionAction(invocation.sessionAction, profile: profile)
            }
            switch profile.client {
            case .claude: return ["--resume", sessionID]
            case .codex: return ["resume", sessionID]
            case .pi: return ["--session", sessionID]
            }
        case .fork:
            guard profile.supportsFork, let sessionID = invocation.sessionID else {
                throw unsupportedSessionAction(invocation.sessionAction, profile: profile)
            }
            switch profile.client {
            case .claude: return ["--resume", sessionID, "--fork-session"]
            case .pi: return ["--fork", sessionID]
            case .codex: throw unsupportedSessionAction(invocation.sessionAction, profile: profile)
            }
        }
    }

    private static func unsupportedSessionAction(
        _ action: FactorySessionAction,
        profile: FactoryClientProfile,
    ) -> FactoryValidationError {
        FactoryValidationError(
            code: "unsupported-session-action",
            message: "Client profile \(profile.profileID) does not support session action \(action.rawValue).",
        )
    }
}
