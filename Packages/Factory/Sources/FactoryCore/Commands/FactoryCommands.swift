import Darwin
import Foundation

/// Stable status emitted by both offline trusted root executables.
public enum FactoryCommandStatus: String, Codable, Sendable {
    case accepted
    case fixtureOnly = "fixture-only"
    case rejected
}

/// Canonical, non-secret command result shared by stdout and stderr.
public struct FactoryCommandEnvelope: Codable, Equatable, Sendable {
    public let command: String
    @RequiredNullable public var inputSHA256: SHA256Digest?
    public let reasonCode: String
    public let schemaVersion: Int
    public let status: FactoryCommandStatus

    public init(
        command: String,
        inputSHA256: SHA256Digest?,
        reasonCode: String,
        schemaVersion: Int = FactoryCore.schemaVersion,
        status: FactoryCommandStatus,
    ) {
        self.command = command
        self.inputSHA256 = inputSHA256
        self.reasonCode = reasonCode
        self.schemaVersion = schemaVersion
        self.status = status
    }
}

/// Process-facing bytes and exit code without ambient logging or exceptions.
public struct FactoryCommandResult: Equatable, Sendable {
    public let exitCode: Int32
    public let standardError: Data
    public let standardOutput: Data

    public init(exitCode: Int32, standardError: Data, standardOutput: Data) {
        self.exitCode = exitCode
        self.standardError = standardError
        self.standardOutput = standardOutput
    }
}

/// Synthetic-only broker validation input. It cannot execute an operation.
public struct BrokerBootstrapValidation: Codable, Equatable, Sendable {
    public let now: String
    public let policy: BrokerPolicy
    public let request: BrokerRequest
    public let state: BrokerState

    public init(now: String, policy: BrokerPolicy, request: BrokerRequest, state: BrokerState) {
        self.now = now
        self.policy = policy
        self.request = request
        self.state = state
    }
}

struct BrokerStateInitializationCommand: Codable {
    let policy: BrokerPolicy
    let state: BrokerState
}

struct BrokerActivationCommand: Codable {
    let receipt: BrokerActivationReceipt
}

struct EvaluationScaffoldCommand: Codable {
    let acceptanceSHA256: SHA256Digest
    let schemaDigests: [SchemaDigest]
    let trustedRootSHA: GitObjectID
}

struct BrokerCommandRuntime {
    let anchorOwnerUserID: uid_t
    let anchorURL: URL
    let brokerExecutableOwnerUserID: uid_t
    let brokerExecutableMappedIdentity: BrokerExecutableMappedIdentity?
    let brokerExecutableURL: URL?
    let currentTime: String
    let effectiveUserID: uid_t
    let realUserID: uid_t

    static func production() -> BrokerCommandRuntime {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return BrokerCommandRuntime(
            anchorOwnerUserID: 0,
            anchorURL: BrokerTrustAnchorLoader.installationURL,
            brokerExecutableOwnerUserID: 0,
            brokerExecutableMappedIdentity: BrokerExecutableIdentity.runningMappedIdentity(),
            brokerExecutableURL: BrokerExecutableIdentity.runningExecutableURL(),
            currentTime: formatter.string(from: Date()),
            effectiveUserID: geteuid(),
            realUserID: getuid(),
        )
    }
}

/// Read-only typed contract inspection available before trust activation.
public enum FactoryCLICommand {
    public static func requiresStandardInput(arguments: [String]) -> Bool {
        (arguments.count == 2 && arguments.first == "validate")
            || arguments == ["client", "compile"]
            || (arguments.count == 3 && arguments[0 ... 1] == ["client", "normalize"])
            || arguments == ["context", "compile"]
            || (arguments.count == 3 && arguments[0 ... 1] == ["controller", "plan"])
            || (arguments.count == 3 && arguments[0 ... 1] == ["design", "inspect"])
            || (arguments.count == 3 && arguments[0 ... 1] == ["design", "translate"])
            || arguments == ["learn", "freeze"]
            || arguments == ["learn", "harvest"]
            || arguments == ["report", "html"]
            || arguments == ["report", "json"]
            || arguments == ["report", "pr-summary"]
            || arguments == ["repair", "evaluate"]
            || arguments == ["product", "classify"]
            || arguments == ["skill", "migration"]
            || arguments == ["route", "explain"]
            || arguments == ["route", "resolve"]
    }

    public static func run(arguments: [String], standardInput: Data) -> FactoryCommandResult {
        let handlers: [([String], Data) -> FactoryCommandResult?] = [
            runMetadataCommand,
            runClientCommand,
            runPlanningCommand,
            runDesignCommand,
            runLearningCommand,
            runReportCommand,
        ]
        for handler in handlers {
            if let result = handler(arguments, standardInput) {
                return result
            }
        }
        return runValidationCommand(arguments: arguments, standardInput: standardInput)
    }
}

private extension FactoryCLICommand {
    private static func runMetadataCommand(_ arguments: [String], _ standardInput: Data) -> FactoryCommandResult? {
        if arguments == ["--version"] || arguments == ["version"] {
            return success(command: "version", status: .accepted, reasonCode: "version", input: nil)
        }
        if arguments == ["route", "policy"] {
            return encodedResult(command: "route-policy") {
                try CanonicalJSON.encode(WorkflowRoutePolicy.factoryV1())
            }
        }
        if arguments == ["client", "profiles"] {
            return encodedResult(command: "client-profiles") {
                try CanonicalJSON.encode(FactoryClientProfile.factoryV1())
            }
        }
        if arguments == ["product", "policy"] {
            return encodedResult(command: "product-policy") {
                try CanonicalJSON.encode(ProductAdapterPolicy.factoryV1())
            }
        }
        if arguments == ["learn", "skillopt-policy"] {
            return encodedResult(command: "learn-skillopt-policy") {
                let policy = try SkillOptAdapterPolicy.factoryV1()
                try policy.validate()
                return try CanonicalJSON.encode(policy)
            }
        }
        return nil
    }

    private static func runClientCommand(_ arguments: [String], _ standardInput: Data) -> FactoryCommandResult? {
        if arguments == ["client", "compile"] {
            return encodedResult(command: "client-compile", input: standardInput) {
                let input = try CanonicalJSON.decode(FactoryClientCompilationInput.self, from: standardInput)
                guard let profile = try FactoryClientProfile.factoryV1().first(where: { $0.client == input.client })
                else {
                    throw FactoryValidationError(
                        code: "unknown-client-profile",
                        message: "The requested client has no frozen factory v1 compatibility profile.",
                    )
                }
                return try CanonicalJSON.encode(
                    FactoryClientAdapterCompiler.compile(
                        input.invocation,
                        profile: profile,
                        outputSchemaJSON: input.outputSchemaText,
                    ),
                )
            }
        }
        if arguments.count == 3, arguments[0 ... 1] == ["client", "normalize"] {
            return encodedResult(command: "client-normalize", input: standardInput) {
                guard let client = FactoryClient(rawValue: arguments[2]) else {
                    throw FactoryValidationError(
                        code: "unknown-client-profile",
                        message: "The requested transcript client is outside the frozen compatibility surface.",
                    )
                }
                return try CanonicalJSON.encode(
                    FactoryClientTranscriptNormalizer.normalize(client: client, data: standardInput),
                )
            }
        }
        return nil
    }

    private static func runPlanningCommand(_ arguments: [String], _ standardInput: Data) -> FactoryCommandResult? {
        if arguments == ["context", "compile"] {
            return encodedResult(command: "context-compile", input: standardInput) {
                let input = try CanonicalJSON.decode(ContextCompilationRequest.self, from: standardInput)
                return try CanonicalJSON.encode(FactoryContextCompiler.compile(input))
            }
        }
        if arguments.count == 3, arguments[0 ... 1] == ["controller", "plan"] {
            return encodedResult(command: "controller-plan", input: standardInput) {
                guard let operation = FactoryControlOperation(rawValue: arguments[2]) else {
                    throw FactoryValidationError(
                        code: "unknown-controller-operation",
                        message: "The requested operation is outside the closed controller surface.",
                    )
                }
                let input = try CanonicalJSON.decode(FactoryControllerPlanningInput.self, from: standardInput)
                return try CanonicalJSON.encode(FactoryController.plan(operation: operation, input: input))
            }
        }
        if arguments == ["route", "resolve"] || arguments == ["route", "explain"] {
            return encodedResult(command: arguments.joined(separator: "-"), input: standardInput) {
                let request = try CanonicalJSON.decode(WorkflowRouteRequest.self, from: standardInput)
                let route = try WorkflowRouteCompiler.compile(request, policy: WorkflowRoutePolicy.factoryV1())
                return try CanonicalJSON.encode(route)
            }
        }
        return nil
    }

    private static func runDesignCommand(_ arguments: [String], _ standardInput: Data) -> FactoryCommandResult? {
        if arguments.count == 3, arguments[0 ... 1] == ["design", "inspect"] {
            return encodedResult(command: "design-inspect", input: standardInput) {
                let manifest = try CanonicalJSON.decode(DesignSourceManifest.self, from: standardInput)
                try DesignEvidenceFileVerifier.verify(
                    manifest,
                    repositoryRoot: designRepositoryRoot(arguments[2]),
                )
                return try CanonicalJSON.encode(manifest)
            }
        }
        if arguments.count == 3, arguments[0 ... 1] == ["design", "translate"] {
            return encodedResult(command: "design-translate", input: standardInput) {
                let value = try CanonicalJSON.decode(DesignTranslationValidationInput.self, from: standardInput)
                try value.validate()
                try DesignEvidenceFileVerifier.verify(
                    value.source,
                    repositoryRoot: designRepositoryRoot(arguments[2]),
                )
                return try CanonicalJSON.encode(value.translation)
            }
        }
        return nil
    }

    private static func designRepositoryRoot(_ path: String) throws -> URL {
        guard path.hasPrefix("/") else {
            throw FactoryValidationError(
                code: "invalid-design-repository-root",
                message: "Design inspection requires an explicit absolute repository root.",
            )
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func runLearningCommand(_ arguments: [String], _ standardInput: Data) -> FactoryCommandResult? {
        if arguments == ["learn", "harvest"] {
            return encodedResult(command: "learn-harvest", input: standardInput) {
                let episodes = try CanonicalJSON.decode([FactoryEpisode].self, from: standardInput)
                return try CanonicalJSON.encode(FactoryEpisodeLedger.harvest(episodes))
            }
        }
        if arguments == ["learn", "freeze"] {
            return encodedResult(command: "learn-freeze", input: standardInput) {
                let input = try CanonicalJSON.decode(SkillFreezeRequest.self, from: standardInput)
                let candidate = try BoundedSkillOptimizer.freeze(
                    candidateID: input.candidateID,
                    targetComponentID: input.targetComponentID,
                    baselineSHA256: input.baselineSHA256,
                    priorRegressionID: input.priorRegressionID,
                    samples: input.samples,
                )
                return try CanonicalJSON.encode(candidate)
            }
        }
        if arguments == ["repair", "evaluate"] {
            return encodedResult(command: "repair-evaluate", input: standardInput) {
                let history = try CanonicalJSON.decode([[FactoryFinding]].self, from: standardInput)
                return try CanonicalJSON.encode(FactoryRepairCircuit.evaluate(history: history))
            }
        }
        if arguments == ["product", "classify"] {
            return encodedResult(command: "product-classify", input: standardInput) {
                let request = try CanonicalJSON.decode(ProductClassificationRequest.self, from: standardInput)
                return try CanonicalJSON.encode(
                    ProductLearningClassifier.classify(request.input, policy: request.policy),
                )
            }
        }
        if arguments == ["skill", "migration"] {
            return encodedResult(command: "skill-migration", input: standardInput) {
                let input = try CanonicalJSON.decode(SkillMigrationAuditInput.self, from: standardInput)
                try input.migration.validate(registry: input.registry)
                return try CanonicalJSON.encode(input.migration)
            }
        }
        return nil
    }

    private static func runReportCommand(_ arguments: [String], _ standardInput: Data) -> FactoryCommandResult? {
        if arguments.count == 2, arguments.first == "report" {
            return encodedResult(command: "report-\(arguments[1])", input: standardInput) {
                let report = try CanonicalJSON.decode(FactoryReport.self, from: standardInput)
                let bundle = try FactoryReporter.render(report)
                switch arguments[1] {
                case "html": return bundle.reportHTML
                case "json": return bundle.reportJSON
                case "pr-summary": return bundle.pullRequestSummary
                default:
                    throw FactoryValidationError(
                        code: "unknown-report-format",
                        message: "Reports render only as canonical JSON, standalone HTML, or a PR summary.",
                    )
                }
            }
        }
        return nil
    }

    private static func runValidationCommand(
        arguments: [String],
        standardInput: Data,
    ) -> FactoryCommandResult {
        guard arguments.count == 2, arguments.first == "validate" else {
            return denied(
                command: arguments.first ?? "missing",
                reasonCode: "factory-inert-before-activation",
                exitCode: 2,
            )
        }
        do {
            try validate(record: arguments[1], bytes: standardInput)
            return success(
                command: "validate-\(arguments[1])",
                status: .accepted,
                reasonCode: "canonical-record",
                input: standardInput,
            )
        } catch let error as FactoryValidationError {
            return denied(
                command: "validate-\(arguments[1])",
                reasonCode: error.code,
                exitCode: 1,
                input: standardInput,
            )
        } catch {
            return denied(
                command: "validate-\(arguments[1])",
                reasonCode: "invalid-record",
                exitCode: 1,
                input: standardInput,
            )
        }
    }

    private static func validate(record: String, bytes: Data) throws {
        guard !bytes.isEmpty, bytes.count <= 16 * 1024 * 1024 else {
            throw FactoryValidationError(
                code: "input-budget",
                message: "Typed validation input is empty or over budget.",
            )
        }
        if try validateExecutionRecord(record, bytes) { return }
        if try validateFactoryRecord(record, bytes) { return }
        if try validateTrustRecord(record, bytes) { return }
        if try validateKernelRecord(record, bytes) { return }
        throw FactoryValidationError(
            code: "unknown-record",
            message: "The requested record has no trusted root typed validator.",
        )
    }

    private static func validateExecutionRecord(_ record: String, _ bytes: Data) throws -> Bool {
        switch record {
        case "aggregate-attestation": try decode(AggregateAttestation.self, bytes)
        case "compiled-route":
            let route = try decoded(CompiledWorkflowRoute.self, bytes)
            _ = try route.validatedExecutionOrder()
        case "client-profile":
            let profile = try decoded(FactoryClientProfile.self, bytes)
            try profile.validate()
        case "client-invocation":
            let invocation = try decoded(FactoryRoleInvocation.self, bytes)
            try invocation.validate()
        case "client-launch-manifest":
            let manifest = try decoded(ClientLaunchManifest.self, bytes)
            try manifest.validate()
        case "context-packet":
            let packet = try decoded(ContextPacket.self, bytes)
            try packet.validate()
        default: return false
        }
        return true
    }

    private static func validateFactoryRecord(_ record: String, _ bytes: Data) throws -> Bool {
        switch record {
        case "controller-input":
            let input = try decoded(FactoryControllerPlanningInput.self, bytes)
            try input.validate()
        case "controller-plan":
            let plan = try decoded(FactoryControllerPlan.self, bytes)
            try plan.validate()
        case "factory-episode":
            let episode = try decoded(FactoryEpisode.self, bytes)
            try episode.validate()
        case "factory-report":
            let report = try decoded(FactoryReport.self, bytes)
            try report.validate()
        case "factory-finding":
            let finding = try decoded(FactoryFinding.self, bytes)
            try finding.validate()
        case "repair-outcome":
            let outcome = try decoded(FactoryRepairOutcome.self, bytes)
            try outcome.validate()
        case "product-adapter-policy":
            let policy = try decoded(ProductAdapterPolicy.self, bytes)
            try policy.validate()
        case "product-trace":
            let trace = try decoded(ProductTrace.self, bytes)
            try trace.validate()
        default: return false
        }
        return true
    }

    private static func validateTrustRecord(_ record: String, _ bytes: Data) throws -> Bool {
        switch record {
        case "skill-migration": try decode(SkillMigrationPortfolio.self, bytes)
        case "frozen-skill-candidate":
            let candidate = try decoded(FrozenSkillCandidate.self, bytes)
            try candidate.validate()
        case "skillopt-policy":
            let policy = try decoded(SkillOptAdapterPolicy.self, bytes)
            try policy.validate()
        case "skill-registry":
            let registry = try decoded(SkillRegistry.self, bytes)
            try registry.validate()
        case "broker-trust-anchor": try decode(BrokerTrustAnchor.self, bytes)
        case "broker-request":
            let request = try decoded(BrokerRequest.self, bytes)
            try BrokerRequestValidator.validateStructure(request)
        case "evaluation-request":
            let request = try decoded(EvaluationRequest.self, bytes)
            try request.validateStructure()
        case "evaluation-root": try decode(PrivateEvaluationRootManifest.self, bytes)
        default: return false
        }
        return true
    }

    private static func validateKernelRecord(_ record: String, _ bytes: Data) throws -> Bool {
        switch record {
        case "factory-state": try decode(FactoryState.self, bytes)
        case "patch-envelope":
            let envelope = try decoded(PatchEnvelope.self, bytes)
            try envelope.validateStructure()
        case "runner-isolation":
            let isolation = try decoded(RunnerIsolation.self, bytes)
            try isolation.validateStructure()
        case "scratch-projection":
            let inventory = try decoded(ScratchProjectionInventory.self, bytes)
            try inventory.validateStructure()
        case "state-cas":
            let cas = try decoded(StateCAS.self, bytes)
            _ = try lifecycleState(from: cas)
        case "evolution-policy": try decode(EvolutionAcceptancePolicy.self, bytes)
        case "transition-request":
            let request = try decoded(TransitionRequest.self, bytes)
            _ = try FactoryStateMachine.apply(request, to: lifecycleState(from: request.cas))
        case "work-item-graph":
            let graph = try decoded(WorkItemGraph.self, bytes)
            _ = try graph.validatedTopologicalOrder()
        case "workflow-route-policy":
            let policy = try decoded(WorkflowRoutePolicy.self, bytes)
            try policy.validate()
        default: return false
        }
        return true
    }

    private static func encodedResult(
        command: String,
        input: Data? = nil,
        operation: () throws -> Data,
    ) -> FactoryCommandResult {
        do {
            return try FactoryCommandResult(
                exitCode: 0,
                standardError: Data(),
                standardOutput: operation(),
            )
        } catch let error as FactoryValidationError {
            return denied(command: command, reasonCode: error.code, exitCode: 1, input: input)
        } catch {
            return denied(command: command, reasonCode: "invalid-record", exitCode: 1, input: input)
        }
    }

    private static func decode(_ type: (some Codable).Type, _ bytes: Data) throws {
        _ = try CanonicalJSON.decode(type, from: bytes)
    }

    private static func decoded<T: Codable>(_ type: T.Type, _ bytes: Data) throws -> T {
        try CanonicalJSON.decode(type, from: bytes)
    }

    private static func lifecycleState(from cas: StateCAS) throws -> FactoryState {
        let state = FactoryState(
            runID: cas.runID,
            phase: cas.phase,
            resumePhase: cas.resumePhase,
            issueNumber: cas.issueNumber,
            pullRequestNumber: cas.pullRequestNumber,
            contractDigest: cas.contractDigest,
            head: cas.head,
            generation: cas.generation,
            evidenceInvalidatedAtGeneration: cas.evidenceInvalidatedAtGeneration,
            schemaVersion: cas.schemaVersion,
        )
        try state.validateStructure()
        return state
    }
}

/// Offline broker inspection surface. No command here performs Git, GitHub, model, or credential work.
package enum FactoryBrokerCommand {
    package static func requiresStandardInput(arguments: [String]) -> Bool {
        arguments == ["activate-receipt"]
            || arguments == ["scaffold-evaluator"]
            || arguments == ["state", "initialize"]
            || arguments == ["validate-request", "--bootstrap-fixture"]
    }

    package static func run(arguments: [String], standardInput: Data) -> FactoryCommandResult {
        run(arguments: arguments, standardInput: standardInput, runtime: .production())
    }

    static func run(
        arguments: [String],
        standardInput: Data,
        runtime: BrokerCommandRuntime,
    ) -> FactoryCommandResult {
        if arguments == ["--version"] || arguments == ["version"] {
            return success(command: "version", status: .accepted, reasonCode: "version", input: nil)
        }
        if arguments == ["doctor", "isolation", "--bootstrap-fixture"] {
            return success(
                command: "doctor-isolation",
                status: .fixtureOnly,
                reasonCode: "isolation-not-activated",
                input: nil,
            )
        }
        if arguments == ["state", "initialize"] {
            return initializeState(standardInput: standardInput, runtime: runtime)
        }
        if arguments == ["activate-receipt"] {
            return activate(standardInput: standardInput, runtime: runtime)
        }
        if arguments == ["scaffold-evaluator"] {
            return scaffoldEvaluator(standardInput: standardInput, runtime: runtime)
        }
        guard arguments == ["validate-request", "--bootstrap-fixture"] else {
            return denied(
                command: arguments.first ?? "missing",
                reasonCode: "build-candidate-fixture-only",
                exitCode: 2,
            )
        }
        return validateBootstrapRequest(standardInput)
    }

    private static func requiredBrokerExecutableURL(_ runtime: BrokerCommandRuntime) throws -> URL {
        guard let url = runtime.brokerExecutableURL else { throw BrokerTrustAnchor.invalid() }
        return url
    }

    private static func requiredBrokerExecutableMappedIdentity(
        _ runtime: BrokerCommandRuntime,
    ) throws -> BrokerExecutableMappedIdentity {
        guard let identity = runtime.brokerExecutableMappedIdentity else {
            throw BrokerTrustAnchor.invalid()
        }
        return identity
    }
}

private extension FactoryBrokerCommand {
    static func initializeState(
        standardInput: Data,
        runtime: BrokerCommandRuntime,
    ) -> FactoryCommandResult {
        runBrokerMutation(command: "state-initialize", input: standardInput) {
            let input = try CanonicalJSON.decode(BrokerStateInitializationCommand.self, from: standardInput)
            let anchor = try loadAnchor(runtime)
            try anchor.validate(policy: input.policy)
            let root = URL(fileURLWithPath: anchor.brokerStateRootPath, isDirectory: true)
            try BrokerCASStore.initialize(at: root, state: input.state, policy: input.policy)
            return (.fixtureOnly, "broker-state-initialized")
        }
    }

    static func activate(
        standardInput: Data,
        runtime: BrokerCommandRuntime,
    ) -> FactoryCommandResult {
        runBrokerMutation(command: "activate-receipt", input: standardInput) {
            let input = try CanonicalJSON.decode(BrokerActivationCommand.self, from: standardInput)
            let anchor = try loadAnchor(runtime)
            let root = URL(fileURLWithPath: anchor.brokerStateRootPath, isDirectory: true)
            _ = try BrokerCASStore.activate(
                at: root,
                anchor: anchor,
                receipt: input.receipt,
                now: runtime.currentTime,
            )
            return (.accepted, "broker-activated")
        }
    }

    static func scaffoldEvaluator(
        standardInput: Data,
        runtime: BrokerCommandRuntime,
    ) -> FactoryCommandResult {
        runBrokerMutation(command: "scaffold-evaluator", input: standardInput) {
            let input = try CanonicalJSON.decode(EvaluationScaffoldCommand.self, from: standardInput)
            let anchor = try loadAnchor(runtime)
            let manifest = try PrivateEvaluationRootManifest(
                acceptanceSHA256: input.acceptanceSHA256,
                casesPresent: false,
                epochZeroFrozen: false,
                evaluatorCodePresent: false,
                schemaDigests: input.schemaDigests,
                trustedRootSHA: input.trustedRootSHA,
            )
            let root = URL(fileURLWithPath: anchor.evaluationScaffoldRootPath, isDirectory: true)
            try anchor.validateScaffold(root: root, manifest: manifest)
            _ = try PrivateEvaluationScaffold.generate(at: root, manifest: manifest)
            return (.fixtureOnly, "evaluation-scaffold-created")
        }
    }

    static func validateBootstrapRequest(_ standardInput: Data) -> FactoryCommandResult {
        do {
            guard !standardInput.isEmpty, standardInput.count <= 16 * 1024 * 1024 else {
                throw FactoryValidationError(
                    code: "input-budget",
                    message: "Broker validation input is empty or over budget.",
                )
            }
            let input = try CanonicalJSON.decode(BrokerBootstrapValidation.self, from: standardInput)
            try BrokerRequestValidator.validate(
                input.request,
                policy: input.policy,
                state: input.state,
                replayLedger: BrokerReplayLedger(),
                now: input.now,
            )
            return success(
                command: "validate-request",
                status: .fixtureOnly,
                reasonCode: "request-valid-not-executed",
                input: standardInput,
            )
        } catch let error as FactoryValidationError {
            return denied(command: "validate-request", reasonCode: error.code, exitCode: 1, input: standardInput)
        } catch {
            return denied(command: "validate-request", reasonCode: "invalid-request", exitCode: 1, input: standardInput)
        }
    }

    static func loadAnchor(_ runtime: BrokerCommandRuntime) throws -> BrokerTrustAnchor {
        try BrokerTrustAnchorLoader.load(
            at: runtime.anchorURL,
            requiredOwnerUID: runtime.anchorOwnerUserID,
            brokerExecutableURL: requiredBrokerExecutableURL(runtime),
            brokerExecutableMappedIdentity: requiredBrokerExecutableMappedIdentity(runtime),
            requiredExecutableOwnerUID: runtime.brokerExecutableOwnerUserID,
            effectiveUserID: runtime.effectiveUserID,
            realUserID: runtime.realUserID,
        )
    }
}

/// Bounded process-input reader shared by both executable entry points.
package enum FactoryProcessInput {
    package static let maximumBytes = 16 * 1024 * 1024
    private static let nanosecondsPerMillisecond: UInt64 = 1_000_000

    package static func read(
        fileDescriptor: Int32,
        maximumBytes: Int = maximumBytes,
        idleTimeoutMilliseconds: Int32 = 5000,
        totalTimeoutMilliseconds: Int32 = 30000,
    ) throws -> Data {
        guard maximumBytes > 0,
              maximumBytes < Int.max,
              idleTimeoutMilliseconds > 0,
              totalTimeoutMilliseconds > 0
        else {
            throw FactoryValidationError(code: "input-budget", message: "Process input limits are invalid.")
        }

        var data = Data()
        data.reserveCapacity(min(maximumBytes + 1, 64 * 1024))
        let started = try monotonicNanoseconds()
        let (duration, durationOverflow) = UInt64(totalTimeoutMilliseconds)
            .multipliedReportingOverflow(by: nanosecondsPerMillisecond)
        let (deadline, deadlineOverflow) = started.addingReportingOverflow(duration)
        guard !durationOverflow, !deadlineOverflow else {
            throw FactoryValidationError(code: "input-budget", message: "Process input limits are invalid.")
        }
        while data.count <= maximumBytes {
            let beforePoll = try monotonicNanoseconds()
            guard beforePoll < deadline else {
                throw FactoryValidationError(
                    code: "input-budget",
                    message: "Process input exceeded its total deadline.",
                )
            }
            let remainingNanoseconds = deadline - beforePoll
            let remainingMilliseconds = max(
                1,
                (remainingNanoseconds + nanosecondsPerMillisecond - 1) / nanosecondsPerMillisecond,
            )
            let pollTimeout = Int32(min(UInt64(idleTimeoutMilliseconds), remainingMilliseconds))
            var descriptor = pollfd(
                fd: fileDescriptor,
                events: Int16(POLLIN | POLLHUP),
                revents: 0,
            )
            let pollResult = Darwin.poll(&descriptor, 1, pollTimeout)
            if pollResult < 0, errno == EINTR { continue }
            guard pollResult > 0,
                  descriptor.revents & Int16(POLLERR | POLLNVAL) == 0
            else {
                throw FactoryValidationError(
                    code: "input-budget",
                    message: "Process input timed out or became unreadable.",
                )
            }
            guard try monotonicNanoseconds() < deadline else {
                throw FactoryValidationError(
                    code: "input-budget",
                    message: "Process input exceeded its total deadline.",
                )
            }

            let remaining = maximumBytes - data.count + 1
            var buffer = [UInt8](repeating: 0, count: min(remaining, 64 * 1024))
            let bytesRead = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(fileDescriptor, bytes.baseAddress, bytes.count)
            }
            if bytesRead < 0, errno == EINTR { continue }
            guard bytesRead >= 0 else {
                throw FactoryValidationError(code: "input-budget", message: "Process input could not be read.")
            }
            if bytesRead == 0 { return data }
            data.append(contentsOf: buffer.prefix(bytesRead))
        }
        return data
    }

    private static func monotonicNanoseconds() throws -> UInt64 {
        var time = timespec()
        guard Darwin.clock_gettime(CLOCK_MONOTONIC_RAW, &time) == 0,
              time.tv_sec >= 0,
              time.tv_nsec >= 0
        else {
            throw FactoryValidationError(code: "input-budget", message: "The monotonic input clock failed.")
        }
        let (seconds, secondsOverflow) = UInt64(time.tv_sec).multipliedReportingOverflow(by: 1_000_000_000)
        let (value, valueOverflow) = seconds.addingReportingOverflow(UInt64(time.tv_nsec))
        guard !secondsOverflow, !valueOverflow else {
            throw FactoryValidationError(code: "input-budget", message: "The monotonic input clock overflowed.")
        }
        return value
    }
}

private func runBrokerMutation(
    command: String,
    input: Data,
    operation: () throws -> (FactoryCommandStatus, String),
) -> FactoryCommandResult {
    do {
        guard !input.isEmpty, input.count <= 16 * 1024 * 1024 else {
            throw FactoryValidationError(code: "input-budget", message: "Broker input is empty or over budget.")
        }
        let (status, reason) = try operation()
        return success(command: command, status: status, reasonCode: reason, input: input)
    } catch let error as FactoryValidationError {
        return denied(command: command, reasonCode: error.code, exitCode: 1, input: input)
    } catch {
        return denied(command: command, reasonCode: "invalid-record", exitCode: 1, input: input)
    }
}

private func success(
    command: String,
    status: FactoryCommandStatus,
    reasonCode: String,
    input: Data?,
) -> FactoryCommandResult {
    let envelope = FactoryCommandEnvelope(
        command: command,
        inputSHA256: input.map(SHA256Digest.hashing),
        reasonCode: reasonCode,
        status: status,
    )
    return FactoryCommandResult(
        exitCode: 0,
        standardError: Data(),
        standardOutput: encoded(envelope),
    )
}

private func denied(
    command: String,
    reasonCode: String,
    exitCode: Int32,
    input: Data? = nil,
) -> FactoryCommandResult {
    let envelope = FactoryCommandEnvelope(
        command: command,
        inputSHA256: input.map(SHA256Digest.hashing),
        reasonCode: reasonCode,
        status: .rejected,
    )
    return FactoryCommandResult(
        exitCode: exitCode,
        standardError: encoded(envelope),
        standardOutput: Data(),
    )
}

private func encoded(_ envelope: FactoryCommandEnvelope) -> Data {
    do {
        return try CanonicalJSON.encode(envelope)
    } catch {
        preconditionFailure("Factory command envelopes must always encode: \(error)")
    }
}
