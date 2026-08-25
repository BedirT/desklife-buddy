import Foundation

public struct ContextFileDigest: Codable, Equatable, Sendable {
    public let path: RepositoryPath
    public let sha256: SHA256Digest
    public let sizeBytes: Int

    public init(path: RepositoryPath, sha256: SHA256Digest, sizeBytes: Int) {
        self.path = path
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}

public struct ContextSource: Codable, Equatable, Sendable {
    public let path: RepositoryPath
    public let text: String

    public init(path: RepositoryPath, text: String) {
        self.path = path
        self.text = text
    }
}

public struct ContextExclusion: Codable, Equatable, Sendable {
    public let pathOrClass: String
    public let reason: String

    public init(pathOrClass: String, reason: String) {
        self.pathOrClass = pathOrClass
        self.reason = reason
    }
}

public enum ClientLaunchNetworkPolicy: String, Codable, CaseIterable, Sendable {
    case brokeredProviderOnly = "brokered-provider-only"
    case denyAll = "deny-all"
}

public enum ClientLaunchPermissionMode: String, Codable, CaseIterable, Sendable {
    case readOnly = "read-only"
    case scratchWrite = "scratch-write"
    case toolLess = "tool-less"
}

/// Fully inventoried launch metadata embedded into every immutable context packet.
public struct ClientLaunchManifest: Codable, Equatable, Sendable {
    public let clientID: FactoryClient
    public let clientVersion: String
    public let discoveredComponents: [ContextFileDigest]
    public let environmentKeys: [String]
    public let fallbackIdentity: String
    public let minimumVersion: String
    public let networkPolicy: ClientLaunchNetworkPolicy
    public let outputSchema: RepositoryPath
    public let permissionMode: ClientLaunchPermissionMode
    public let promptSHA256: SHA256Digest
    public let projectionRootClass: String
    public let retryPolicy: String
    public let selectedSkillIDs: [String]
    public let timeoutSeconds: Int
    public let toolAllowlist: [String]
    public let userRootClass: String

    public init(
        clientID: FactoryClient,
        clientVersion: String,
        discoveredComponents: [ContextFileDigest],
        environmentKeys: [String],
        fallbackIdentity: String,
        minimumVersion: String,
        networkPolicy: ClientLaunchNetworkPolicy,
        outputSchema: RepositoryPath,
        permissionMode: ClientLaunchPermissionMode,
        promptSHA256: SHA256Digest,
        projectionRootClass: String = "invocation-scratch",
        retryPolicy: String = "one-structure-correction",
        selectedSkillIDs: [String],
        timeoutSeconds: Int,
        toolAllowlist: [String],
        userRootClass: String = "isolated",
    ) {
        self.clientID = clientID
        self.clientVersion = clientVersion
        self.discoveredComponents = discoveredComponents
        self.environmentKeys = environmentKeys
        self.fallbackIdentity = fallbackIdentity
        self.minimumVersion = minimumVersion
        self.networkPolicy = networkPolicy
        self.outputSchema = outputSchema
        self.permissionMode = permissionMode
        self.promptSHA256 = promptSHA256
        self.projectionRootClass = projectionRootClass
        self.retryPolicy = retryPolicy
        self.selectedSkillIDs = selectedSkillIDs
        self.timeoutSeconds = timeoutSeconds
        self.toolAllowlist = toolAllowlist
        self.userRootClass = userRootClass
    }

    public func validate() throws {
        guard FactoryTextRules.isBoundedText(clientVersion, maximumScalars: 128),
              FactoryTextRules.isBoundedText(minimumVersion, maximumScalars: 128),
              FactoryTextRules.isBoundedText(fallbackIdentity, maximumScalars: 256),
              environmentKeys == environmentKeys.sorted(),
              Set(environmentKeys).isSubset(of: ["HOME", "PATH", "TMPDIR"]),
              projectionRootClass == "invocation-scratch",
              retryPolicy == "one-structure-correction",
              userRootClass == "isolated",
              selectedSkillIDs == selectedSkillIDs.sorted(),
              Set(selectedSkillIDs).count == selectedSkillIDs.count,
              selectedSkillIDs.allSatisfy(FactoryTextRules.isStableID),
              (1 ... 7200).contains(timeoutSeconds),
              toolAllowlist == toolAllowlist.sorted(),
              Set(toolAllowlist).count == toolAllowlist.count,
              toolAllowlist.allSatisfy(FactoryTextRules.isStableID),
              discoveredComponents.map(\.path) == discoveredComponents.map(\.path).sorted()
        else {
            throw FactoryValidationError(
                code: "invalid-client-launch-manifest",
                message: "Client launch metadata must be hermetic, canonical, bounded, and explicit about selected skills.",
            )
        }
    }
}

/// Immutable, reconstructable context identity for exactly one role invocation.
public struct ContextPacket: Codable, Equatable, Sendable {
    public let cleanWorktree: Bool
    public let combinedContextSHA256: SHA256Digest
    public let contractSHA256: SHA256Digest
    public let excludedContext: [ContextExclusion]
    public let gitHeadSHA: GitObjectID
    public let includedFiles: [ContextFileDigest]
    public let invocationID: String
    public let issueNumber: Int
    public let launch: ClientLaunchManifest
    public let orderedPromptPaths: [RepositoryPath]
    public let planPath: RepositoryPath
    public let roleID: String
    public let schemaVersion: Int
    public let tokenEstimate: Int
    public let totalBytes: Int

    public init(
        cleanWorktree: Bool,
        combinedContextSHA256: SHA256Digest,
        contractSHA256: SHA256Digest,
        excludedContext: [ContextExclusion],
        gitHeadSHA: GitObjectID,
        includedFiles: [ContextFileDigest],
        invocationID: String,
        issueNumber: Int,
        launch: ClientLaunchManifest,
        orderedPromptPaths: [RepositoryPath],
        planPath: RepositoryPath,
        roleID: String,
        schemaVersion: Int = FactoryCore.schemaVersion,
        tokenEstimate: Int,
        totalBytes: Int,
    ) {
        self.cleanWorktree = cleanWorktree
        self.combinedContextSHA256 = combinedContextSHA256
        self.contractSHA256 = contractSHA256
        self.excludedContext = excludedContext
        self.gitHeadSHA = gitHeadSHA
        self.includedFiles = includedFiles
        self.invocationID = invocationID
        self.issueNumber = issueNumber
        self.launch = launch
        self.orderedPromptPaths = orderedPromptPaths
        self.planPath = planPath
        self.roleID = roleID
        self.schemaVersion = schemaVersion
        self.tokenEstimate = tokenEstimate
        self.totalBytes = totalBytes
    }

    public func validate() throws {
        try launch.validate()
        guard cleanWorktree,
              schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(invocationID),
              FactoryTextRules.isStableID(roleID),
              issueNumber > 0,
              totalBytes > 0,
              totalBytes == includedFiles.reduce(0, { $0 + $1.sizeBytes }),
              tokenEstimate >= 0,
              !includedFiles.isEmpty,
              Set(includedFiles.map(\.path)).count == includedFiles.count,
              !orderedPromptPaths.isEmpty,
              Set(orderedPromptPaths).isSubset(of: Set(includedFiles.map(\.path))),
              combinedContextSHA256 == CanonicalJSON.digest(includedFiles),
              excludedContext.allSatisfy({
                  FactoryTextRules.isBoundedText($0.pathOrClass, maximumScalars: 512)
                      && FactoryTextRules.isBoundedText($0.reason, maximumScalars: 512)
              })
        else {
            throw FactoryValidationError(
                code: "invalid-context-packet",
                message: "Context packets require a clean SHA-bound tree, exact file inventory, prompts, and finite budgets.",
            )
        }
    }
}

public struct ContextCompilationRequest: Codable, Equatable, Sendable {
    public let invocationID: String
    public let issueNumber: Int
    public let role: WorkflowRole
    public let headSHA: GitObjectID
    public let contractSHA256: SHA256Digest
    public let cleanWorktree: Bool
    public let planPath: RepositoryPath
    public let orderedPaths: [RepositoryPath]
    public let orderedPromptPaths: [RepositoryPath]
    public let sources: [ContextSource]
    public let excludedContext: [ContextExclusion]
    public let selectedSkills: [String]
    public let client: FactoryClient
    public let clientVersion: String
    public let minimumVersion: String
    public let permissionMode: ClientLaunchPermissionMode
    public let networkPolicy: ClientLaunchNetworkPolicy
    public let outputSchema: RepositoryPath
    public let toolAllowlist: [String]
    public let timeoutSeconds: Int
    public let maximumBytes: Int

    public init(
        invocationID: String,
        issueNumber: Int,
        role: WorkflowRole,
        headSHA: GitObjectID,
        contractSHA256: SHA256Digest,
        cleanWorktree: Bool,
        planPath: RepositoryPath,
        orderedPaths: [RepositoryPath],
        orderedPromptPaths: [RepositoryPath],
        sources: [ContextSource],
        excludedContext: [ContextExclusion],
        selectedSkills: [String],
        client: FactoryClient,
        clientVersion: String,
        minimumVersion: String,
        permissionMode: ClientLaunchPermissionMode,
        networkPolicy: ClientLaunchNetworkPolicy,
        outputSchema: RepositoryPath,
        toolAllowlist: [String],
        timeoutSeconds: Int,
        maximumBytes: Int,
    ) {
        self.invocationID = invocationID
        self.issueNumber = issueNumber
        self.role = role
        self.headSHA = headSHA
        self.contractSHA256 = contractSHA256
        self.cleanWorktree = cleanWorktree
        self.planPath = planPath
        self.orderedPaths = orderedPaths
        self.orderedPromptPaths = orderedPromptPaths
        self.sources = sources
        self.excludedContext = excludedContext
        self.selectedSkills = selectedSkills
        self.client = client
        self.clientVersion = clientVersion
        self.minimumVersion = minimumVersion
        self.permissionMode = permissionMode
        self.networkPolicy = networkPolicy
        self.outputSchema = outputSchema
        self.toolAllowlist = toolAllowlist
        self.timeoutSeconds = timeoutSeconds
        self.maximumBytes = maximumBytes
    }

    public init(
        copying source: ContextCompilationRequest,
        cleanWorktree: Bool? = nil,
        maximumBytes: Int? = nil,
    ) {
        self.init(
            invocationID: source.invocationID,
            issueNumber: source.issueNumber,
            role: source.role,
            headSHA: source.headSHA,
            contractSHA256: source.contractSHA256,
            cleanWorktree: cleanWorktree ?? source.cleanWorktree,
            planPath: source.planPath,
            orderedPaths: source.orderedPaths,
            orderedPromptPaths: source.orderedPromptPaths,
            sources: source.sources,
            excludedContext: source.excludedContext,
            selectedSkills: source.selectedSkills,
            client: source.client,
            clientVersion: source.clientVersion,
            minimumVersion: source.minimumVersion,
            permissionMode: source.permissionMode,
            networkPolicy: source.networkPolicy,
            outputSchema: source.outputSchema,
            toolAllowlist: source.toolAllowlist,
            timeoutSeconds: source.timeoutSeconds,
            maximumBytes: maximumBytes ?? source.maximumBytes,
        )
    }
}

public enum FactoryContextCompiler {
    public static func compile(_ request: ContextCompilationRequest) throws -> ContextPacket {
        var byPath: [RepositoryPath: ContextSource] = [:]
        for source in request.sources {
            byPath[source.path] = source
        }
        let sourcePaths = request.sources.map(\.path)
        let selectedSkills = Set(request.selectedSkills)
        let totalBytes = request.sources.reduce(0) { $0 + $1.text.utf8.count }
        let orderedSources = request.orderedPaths.compactMap { byPath[$0] }
        let promptText = request.orderedPromptPaths.compactMap { byPath[$0]?.text }.joined(separator: "\n\n")
        guard request.cleanWorktree,
              FactoryTextRules.isStableID(request.invocationID),
              request.issueNumber > 0,
              request.orderedPaths.count == request.sources.count,
              Set(request.orderedPaths).count == request.orderedPaths.count,
              Set(request.orderedPaths) == Set(sourcePaths),
              Set(sourcePaths).count == sourcePaths.count,
              !request.orderedPromptPaths.isEmpty,
              Set(request.orderedPromptPaths).isSubset(of: Set(request.orderedPaths)),
              request.selectedSkills == request.selectedSkills.sorted(),
              Set(request.selectedSkills).count == request.selectedSkills.count,
              request.selectedSkills.allSatisfy(FactoryTextRules.isStableID),
              (1 ... 262_144).contains(request.maximumBytes),
              totalBytes > 0,
              totalBytes <= request.maximumBytes,
              orderedSources.allSatisfy({
                  !$0.text.isEmpty && !$0.text.unicodeScalars.contains(where: { $0.value == 0 })
              }),
              orderedSources.allSatisfy({ source in
                  let components = source.path.components
                  guard components.count >= 4, components[0 ... 1] == [".agents", "skills"] else { return true }
                  return selectedSkills.contains(components[2])
              })
        else {
            throw FactoryValidationError(
                code: "context-compilation-denied",
                message: "Context compilation rejected dirty, over-budget, ambiguous, or unselected content.",
            )
        }

        let includedFiles = orderedSources.map { source in
            let data = Data(source.text.utf8)
            return ContextFileDigest(path: source.path, sha256: SHA256Digest.hashing(data), sizeBytes: data.count)
        }
        let discovered = includedFiles
            .filter { $0.path.components.starts(with: [".agents", "skills"]) }
            .sorted { $0.path < $1.path }
        let launch = ClientLaunchManifest(
            clientID: request.client,
            clientVersion: request.clientVersion,
            discoveredComponents: discovered,
            environmentKeys: [],
            fallbackIdentity: "none",
            minimumVersion: request.minimumVersion,
            networkPolicy: request.networkPolicy,
            outputSchema: request.outputSchema,
            permissionMode: request.permissionMode,
            promptSHA256: SHA256Digest.hashing(Data(promptText.utf8)),
            selectedSkillIDs: request.selectedSkills,
            timeoutSeconds: request.timeoutSeconds,
            toolAllowlist: request.toolAllowlist,
        )
        let packet = ContextPacket(
            cleanWorktree: request.cleanWorktree,
            combinedContextSHA256: CanonicalJSON.digest(includedFiles),
            contractSHA256: request.contractSHA256,
            excludedContext: request.excludedContext,
            gitHeadSHA: request.headSHA,
            includedFiles: includedFiles,
            invocationID: request.invocationID,
            issueNumber: request.issueNumber,
            launch: launch,
            orderedPromptPaths: request.orderedPromptPaths,
            planPath: request.planPath,
            roleID: request.role.rawValue,
            tokenEstimate: (totalBytes + 3) / 4,
            totalBytes: totalBytes,
        )
        try packet.validate()
        return packet
    }
}
