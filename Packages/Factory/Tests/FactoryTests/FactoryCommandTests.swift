import Darwin
import Foundation
import Testing
@testable import FactoryCore

private struct EvaluatorValidationCase {
    let record: String
    let fixture: String
    let mutate: (inout [String: Any]) throws -> Void
}

private struct KernelValidationCase {
    let record: String
    let file: String
    let fixture: String
    let mutate: (inout [String: Any]) -> Void
}

private struct TrustedRuntimeFixture {
    let root: URL
    let anchorRoot: URL
    let anchorURL: URL
    let brokerExecutableURL: URL
    let scaffold: URL
    let manifest: PrivateEvaluationRootManifest
    let policy: BrokerPolicy
    let state: BrokerState
    let initializationInput: Data
    let runtime: BrokerCommandRuntime

    func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: anchorRoot)
        try? FileManager.default.removeItem(at: scaffold)
    }
}

@Suite("Offline Factory executables")
struct FactoryCommandTests {
    @Test("CLI version and typed validation emit canonical data-only results")
    func cliValidation() throws {
        let version = FactoryCLICommand.run(arguments: ["--version"], standardInput: Data())
        #expect(version.exitCode == 0)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: version.standardOutput)
            .reasonCode == "version")

        let graph = try WorkItemGraph(
            issueNumber: 42,
            contractSHA256: TestValues.contract,
            items: [
                WorkItem(
                    id: "work-1",
                    owner: "builder",
                    dependencyIDs: [],
                    criterionIDs: ["criterion-1"],
                    allowedPaths: [RepositoryPath(validating: "Packages/Domain")],
                    allowedTools: ["shell"],
                    contextEstimateBytes: 1024,
                    risk: .low,
                    initialState: .planned,
                    expectedCheckpointCommit: nil,
                    skillExposures: [],
                ),
            ],
        )
        let validation = try FactoryCLICommand.run(
            arguments: ["validate", "work-item-graph"],
            standardInput: CanonicalJSON.encode(graph),
        )
        #expect(validation.exitCode == 0)
        let envelope = try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: validation.standardOutput)
        #expect(envelope.status == .accepted)
        #expect(envelope.reasonCode == "canonical-record")
    }

    @Test("CLI resolves the same provider-neutral route and inspects design data without side effects")
    func routeAndDesignInspection() throws {
        let policyResult = FactoryCLICommand.run(arguments: ["route", "policy"], standardInput: Data())
        #expect(policyResult.exitCode == 0)
        let policy = try CanonicalJSON.decode(WorkflowRoutePolicy.self, from: policyResult.standardOutput)
        try policy.validate()

        let request = try WorkflowRouteRequest(
            dimensions: [.externalDesign, .motion, .ui],
            requestedRisk: .medium,
            changedPaths: [RepositoryPath(validating: "Packages/Features/Sources/HeroView.swift")],
            designSourceIDs: ["hero-reference"],
        )
        let routeResult = try FactoryCLICommand.run(
            arguments: ["route", "resolve"],
            standardInput: CanonicalJSON.encode(request),
        )
        #expect(routeResult.exitCode == 0)
        let route = try CanonicalJSON.decode(CompiledWorkflowRoute.self, from: routeResult.standardOutput)
        #expect(route.steps.map(\.role).contains(.designIngestor))
        #expect(route.steps.map(\.role).contains(.motionWitness))
    }

    @Test("CLI exposes the same checked-in profiles and plans only typed controller effects")
    func clientAndControllerPlanning() throws {
        let profileResult = FactoryCLICommand.run(arguments: ["client", "profiles"], standardInput: Data())
        #expect(profileResult.exitCode == 0)
        let profiles = try CanonicalJSON.decode([FactoryClientProfile].self, from: profileResult.standardOutput)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { path in
            FactoryJSONKey(snakeCase: path.last?.stringValue ?? "")
        }
        let checkedInProfiles = try decoder.decode(
            [FactoryClientProfile].self,
            from: Data(contentsOf: repositoryRoot().appending(path: ".factory/clients.json")),
        )
        #expect(profiles == checkedInProfiles)

        let transcript = Data(
            """
            {"thread_id":"codex-session-1","type":"thread.started"}
            {"item":{"text":"{\\"status\\":\\"passed\\"}","type":"agent_message"},"type":"item.completed"}
            {"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}
            """.utf8,
        )
        let normalizedResult = FactoryCLICommand.run(
            arguments: ["client", "normalize", "codex"],
            standardInput: transcript,
        )
        #expect(normalizedResult.exitCode == 0)
        let normalized = try CanonicalJSON.decode(
            FactoryNormalizedClientResult.self,
            from: normalizedResult.standardOutput,
        )
        #expect(normalized.client == .codex)
        #expect(normalized.status == .succeeded)
        #expect(normalized.outputText == "{\"status\":\"passed\"}")

        let input = FactoryControllerPlanningInput(
            authority: .buildCandidate,
            mode: .bootstrapFixture,
            runID: "run-42",
            issueNumber: 42,
            headSHA: TestValues.head,
            contractSHA256: TestValues.contract,
            routeSHA256: TestValues.evidence,
            generation: 3,
            stopRequested: false,
        )
        let planResult = try FactoryCLICommand.run(
            arguments: ["controller", "plan", "start"],
            standardInput: CanonicalJSON.encode(input),
        )
        #expect(planResult.exitCode == 0)
        let plan = try CanonicalJSON.decode(FactoryControllerPlan.self, from: planResult.standardOutput)
        #expect(plan.qualification == .nonqualifyingBootstrap)
        #expect(!plan.effects.contains { $0.kind == .brokerTransaction })
    }

    @Test("CLI report and learning surfaces render only validated data")
    func reportAndLearning() throws {
        let report = try FactoryReport(
            reportID: "report-run-42",
            runID: "run-42",
            issueNumber: 42,
            pullRequestNumber: 7,
            headSHA: TestValues.head,
            contractSHA256: TestValues.contract,
            routeID: "route-logic",
            phase: .readyForOwner,
            qualification: .nonqualifyingBootstrap,
            criteria: [FactoryReportCriterion(id: "criterion-1", status: .passed, evidenceIDs: ["test-log"])],
            evidence: [
                FactoryReportEvidence(
                    id: "test-log",
                    kind: .test,
                    path: RepositoryPath(validating: "artifacts/factory/test.log"),
                    sha256: TestValues.evidence,
                    status: .passed,
                ),
            ],
            roleResults: [],
            designComparisons: [],
            repairAttempts: 0,
            risks: [],
        )
        let html = try FactoryCLICommand.run(
            arguments: ["report", "html"],
            standardInput: CanonicalJSON.encode(report),
        )
        #expect(html.exitCode == 0)
        #expect(String(decoding: html.standardOutput, as: UTF8.self).contains(TestValues.head.rawValue))

        let episodes = [
            FactoryEpisode(
                episodeID: "episode-success",
                runID: "run-42",
                headSHA: TestValues.head,
                contractSHA256: TestValues.contract,
                routeID: "route-logic",
                outcome: .success,
                componentExposureIDs: ["prompt-builder-v1"],
                skillExposureIDs: ["design-system-v1"],
                incidentIDs: [],
            ),
        ]
        let harvest = try FactoryCLICommand.run(
            arguments: ["learn", "harvest"],
            standardInput: CanonicalJSON.encode(episodes),
        )
        #expect(harvest.exitCode == 0)
        #expect(try CanonicalJSON.decode(FactoryEpisodeLedger.self, from: harvest.standardOutput).episodes == episodes)
    }

    @Test("CLI rejects schema-invalid evaluator semantics after canonical decoding")
    func evaluatorSemanticValidation() throws {
        let cases = [
            EvaluatorValidationCase(record: "evolution-policy", fixture: "EvolutionAcceptancePolicy", mutate: { value in
                var components = try #require(value["components"] as? [[String: Any]])
                var component = try #require(components.first)
                component["allowed_client_ids"] = [""]
                component["allowed_model_ids"] = [""]
                var schemas = try #require(component["required_schema_digests"] as? [[String: Any]])
                schemas[0]["schema_id"] = "NOT VALID"
                component["required_schema_digests"] = schemas
                components[0] = component
                value["components"] = components
            }),
            EvaluatorValidationCase(record: "evaluation-request", fixture: "EvaluationRequest", mutate: { value in
                value["client_id"] = ""
                value["model_id"] = ""
                value["request_id"] = "NOT VALID"
            }),
            EvaluatorValidationCase(record: "aggregate-attestation", fixture: "AggregateAttestation", mutate: { value in
                value["epoch"] = "NOT VALID"
            }),
            EvaluatorValidationCase(
                record: "evaluation-root",
                fixture: "PrivateEvaluationRootManifest",
                mutate: { value in
                    var schemas = try #require(value["schema_digests"] as? [[String: Any]])
                    schemas[0]["schema_id"] = "NOT VALID"
                    value["schema_digests"] = schemas
                },
            ),
        ]

        for item in cases {
            var value = try evaluatorFixture(named: item.fixture)
            try item.mutate(&value)
            let result = try FactoryCLICommand.run(
                arguments: ["validate", item.record],
                standardInput: JSONSerialization.data(
                    withJSONObject: value,
                    options: [.sortedKeys, .withoutEscapingSlashes],
                ),
            )
            #expect(result.exitCode == 1)
        }
    }

    @Test("CLI rejects semantically invalid kernel and registry records")
    func kernelSemanticValidation() throws {
        for item in kernelValidationCases() {
            var value = try schemaFixture(file: item.file, record: item.fixture)
            let valid = try FactoryCLICommand.run(
                arguments: ["validate", item.record],
                standardInput: JSONSerialization.data(
                    withJSONObject: value,
                    options: [.sortedKeys, .withoutEscapingSlashes],
                ),
            )
            #expect(valid.exitCode == 0)

            item.mutate(&value)
            let result = try FactoryCLICommand.run(
                arguments: ["validate", item.record],
                standardInput: JSONSerialization.data(
                    withJSONObject: value,
                    options: [.sortedKeys, .withoutEscapingSlashes],
                ),
            )
            #expect(result.exitCode == 1)
        }

        let registry = SkillRegistry(
            portfolioStatus: "production-qualified",
            skills: [],
        )
        let registryResult = try FactoryCLICommand.run(
            arguments: ["validate", "skill-registry"],
            standardInput: CanonicalJSON.encode(registry),
        )
        #expect(registryResult.exitCode == 1)
    }

    @Test("Unmerged CLI and broker reject production commands")
    func productionCommandsDenied() throws {
        #expect(!FactoryCLICommand.requiresStandardInput(arguments: ["validate"]))
        #expect(!FactoryBrokerCommand.requiresStandardInput(arguments: ["state", "unknown"]))
        #expect(FactoryBrokerCommand.requiresStandardInput(arguments: ["state", "initialize"]))
        for result in [
            FactoryCLICommand.run(arguments: ["start"], standardInput: Data()),
            FactoryBrokerCommand.run(arguments: ["push"], standardInput: Data()),
            FactoryBrokerCommand.run(arguments: ["activate"], standardInput: Data()),
            FactoryBrokerCommand.run(arguments: ["launch-model"], standardInput: Data()),
        ] {
            #expect(result.exitCode == 2)
            let envelope = try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: result.standardError)
            #expect(envelope.status == .rejected)
            #expect(envelope.reasonCode == "factory-inert-before-activation" || envelope
                .reasonCode == "build-candidate-fixture-only")
        }
    }

    @Test("Process input stops at the byte ceiling and idle timeout")
    func boundedProcessInput() throws {
        let input = FileManager.default.temporaryDirectory
            .appending(path: "factory-process-input-\(UUID().uuidString)")
        try Data(repeating: 0x41, count: 2048).write(to: input)
        defer { try? FileManager.default.removeItem(at: input) }

        let inputFD = Darwin.open(input.path, O_RDONLY | O_CLOEXEC)
        #expect(inputFD >= 0)
        if inputFD >= 0 {
            defer { Darwin.close(inputFD) }
            let bounded = try FactoryProcessInput.read(
                fileDescriptor: inputFD,
                maximumBytes: 1024,
                idleTimeoutMilliseconds: 100,
            )
            #expect(bounded.count == 1025)
        }

        var pipeFDs = [Int32](repeating: -1, count: 2)
        let pipeResult = pipeFDs.withUnsafeMutableBufferPointer { descriptors in
            Darwin.pipe(descriptors.baseAddress)
        }
        #expect(pipeResult == 0)
        if pipeResult == 0 {
            defer {
                Darwin.close(pipeFDs[0])
                Darwin.close(pipeFDs[1])
            }
            #expect(throws: FactoryValidationError.self) {
                try FactoryProcessInput.read(
                    fileDescriptor: pipeFDs[0],
                    maximumBytes: 1024,
                    idleTimeoutMilliseconds: 10,
                )
            }
        }
    }

    @Test("Broker validates a synthetic request but never executes it")
    func brokerFixtureValidation() throws {
        let policy = brokerPolicy()
        let state = brokerState(policy: policy)
        let request = BrokerRequest(
            requestID: "request-1",
            nonce: "nonce-0123456789abcdef0123456789",
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T00:01:00Z",
            trustedBaseSHA: TestValues.head,
            runID: state.runID,
            operation: .doctor(doctorID: "isolation"),
            precondition: BrokerPrecondition(expected: state),
        )
        let input = BrokerBootstrapValidation(
            now: "2026-07-11T00:00:30Z",
            policy: policy,
            request: request,
            state: state,
        )
        let result = try FactoryBrokerCommand.run(
            arguments: ["validate-request", "--bootstrap-fixture"],
            standardInput: CanonicalJSON.encode(input),
        )
        #expect(result.exitCode == 0)
        let output = try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: result.standardOutput)
        #expect(output.status == .fixtureOnly)
        #expect(output.reasonCode == "request-valid-not-executed")

        let doctor = FactoryBrokerCommand.run(
            arguments: ["doctor", "isolation", "--bootstrap-fixture"],
            standardInput: Data(),
        )
        #expect(doctor.exitCode == 0)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: doctor.standardOutput)
            .reasonCode == "isolation-not-activated")
    }
}

extension FactoryCommandTests {
    @Test("Merged broker commands require a root-owned trusted root trust anchor")
    func trustedRuntimeCommands() throws {
        let fixture = try trustedRuntimeFixture(prefix: "factory-command", currentTime: "2026-07-11T00:30:00Z")
        defer { fixture.removeTemporaryFiles() }

        try verifyRuntimeTrustBoundary(fixture)
        try initializeBroker(fixture)
        try activateBroker(fixture)
        try verifyEvaluatorScaffolding(fixture)
    }

    private func evaluatorFixture(named record: String) throws -> [String: Any] {
        try schemaFixture(file: "evaluator-fixtures.json", record: record)
    }

    private func kernelValidationCases() -> [KernelValidationCase] {
        [
            KernelValidationCase(
                record: "broker-request",
                file: "kernel-fixtures.json",
                fixture: "BrokerRequest",
                mutate: { value in value["request_id"] = "NOT VALID" },
            ),
            KernelValidationCase(
                record: "patch-envelope",
                file: "kernel-fixtures.json",
                fixture: "PatchEnvelope",
                mutate: { value in value["operations"] = [] },
            ),
            KernelValidationCase(
                record: "runner-isolation",
                file: "kernel-fixtures.json",
                fixture: "RunnerIsolation",
                mutate: { value in value["invocation_id"] = "NOT VALID" },
            ),
            KernelValidationCase(
                record: "scratch-projection",
                file: "kernel-fixtures.json",
                fixture: "ScratchProjectionInventory",
                mutate: { value in value["files"] = [] },
            ),
            KernelValidationCase(
                record: "factory-state",
                file: "factory-fixtures.json",
                fixture: "FactoryState",
                mutate: { value in value["pull_request_number"] = 9 },
            ),
            KernelValidationCase(
                record: "state-cas",
                file: "factory-fixtures.json",
                fixture: "StateCAS",
                mutate: { value in value["phase"] = "READY_TO_BUILD" },
            ),
            KernelValidationCase(
                record: "transition-request",
                file: "factory-fixtures.json",
                fixture: "TransitionRequest",
                mutate: { value in value["next_pull_request_number"] = NSNull() },
            ),
            KernelValidationCase(
                record: "work-item-graph",
                file: "factory-fixtures.json",
                fixture: "WorkItemGraph",
                mutate: { value in value["issue_number"] = 0 },
            ),
        ]
    }

    private func schemaFixture(file: String, record: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repositoryRoot().appending(path: ".factory/evals/public/schemas/\(file)"))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let fixtures = try #require(root["fixtures"] as? [[String: Any]])
        let fixture = try #require(fixtures.first(where: { $0["record_name"] as? String == record }))
        return try #require(fixture["valid"] as? [String: Any])
    }

    private func repositoryRoot() -> URL {
        var cursor = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while cursor.path != "/",
              !FileManager.default.fileExists(atPath: cursor.appending(path: ".factory").path)
        {
            cursor.deleteLastPathComponent()
        }
        return cursor
    }

    private func brokerPolicy() -> BrokerPolicy {
        BrokerPolicy(
            activationPublicKeySHA256: TestValues.activationPublicKeySHA256,
            trustedBase: TestValues.head,
            repository: "BedirT/swiftmac-base",
            branchPrefix: "agent/",
            brokerIdentitySHA256: TestValues.brokerIdentity,
            maximumPullRequestNumber: 1_000_000,
            maximumRequestLifetimeSeconds: 300,
            maximumReplayEntries: 100,
            allowedOperationKinds: [.doctor],
            allowedProjectionRoots: [TestValues.packages],
            allowedClients: [.codex],
            allowedRoleIDs: ["builder"],
            allowedGateIDs: ["test-domain"],
            allowedDoctorIDs: ["isolation"],
        )
    }

    private func brokerState(policy: BrokerPolicy) -> BrokerState {
        BrokerState(
            runID: "run-1",
            issueNumber: 42,
            pullRequestNumber: 2,
            contractDigest: TestValues.contract,
            head: TestValues.head,
            tree: TestValues.head,
            generation: 1,
            leaseID: "lease-0123456789abcdef",
            policyDigest: policy.digest,
            priorAuditSequence: 0,
            priorAuditDigest: TestValues.zero,
        )
    }

    private func trustedRuntimeFixture(prefix: String, currentTime: String) throws -> TrustedRuntimeFixture {
        let temporary = TestValues.temporaryDirectory
        let root = temporary
            .appending(path: "\(prefix)-state-\(UUID().uuidString)", directoryHint: .isDirectory)
        let anchorRoot = temporary
            .appending(path: "\(prefix)-anchor-\(UUID().uuidString)", directoryHint: .isDirectory)
        let anchorURL = anchorRoot.appending(path: "trust-anchor.json")
        let brokerExecutableURL = anchorRoot.appending(path: "FactoryBroker")
        let scaffold = temporary
            .appending(path: "\(prefix)-scaffold-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: anchorRoot, withIntermediateDirectories: false)
        #expect(chmod(root.path, 0o700) == 0)
        #expect(chmod(anchorRoot.path, 0o700) == 0)
        try Data("installed-broker".utf8).write(to: brokerExecutableURL, options: .withoutOverwriting)
        #expect(chmod(brokerExecutableURL.path, 0o555) == 0)
        let manifest = TestValues.evaluationManifest()
        let anchor = TestValues.trustAnchor(
            brokerStateRoot: root,
            evaluationScaffoldRoot: scaffold,
            manifest: manifest,
        )
        try CanonicalJSON.encode(anchor).write(to: anchorURL, options: .withoutOverwriting)
        #expect(chmod(anchorURL.path, 0o600) == 0)
        let policy = brokerPolicy()
        let state = brokerState(policy: policy)
        return try TrustedRuntimeFixture(
            root: root,
            anchorRoot: anchorRoot,
            anchorURL: anchorURL,
            brokerExecutableURL: brokerExecutableURL,
            scaffold: scaffold,
            manifest: manifest,
            policy: policy,
            state: state,
            initializationInput: CanonicalJSON.encode(BrokerStateInitializationCommand(
                policy: policy,
                state: state,
            )),
            runtime: BrokerCommandRuntime(
                anchorOwnerUserID: getuid(),
                anchorURL: anchorURL,
                brokerExecutableOwnerUserID: getuid(),
                brokerExecutableMappedIdentity: BrokerExecutableIdentity.fileIdentity(
                    at: brokerExecutableURL,
                ),
                brokerExecutableURL: brokerExecutableURL,
                currentTime: currentTime,
                effectiveUserID: geteuid(),
                realUserID: getuid(),
            ),
        )
    }

    private func verifyRuntimeTrustBoundary(_ fixture: TrustedRuntimeFixture) throws {
        let mismatchedIdentity = FactoryBrokerCommand.run(
            arguments: ["state", "initialize"],
            standardInput: fixture.initializationInput,
            runtime: BrokerCommandRuntime(
                anchorOwnerUserID: getuid(),
                anchorURL: fixture.anchorURL,
                brokerExecutableOwnerUserID: getuid(),
                brokerExecutableMappedIdentity: fixture.runtime.brokerExecutableMappedIdentity,
                brokerExecutableURL: fixture.brokerExecutableURL,
                currentTime: fixture.runtime.currentTime,
                effectiveUserID: geteuid(),
                realUserID: uid_t(TestValues.operatorUserID),
            ),
        )
        #expect(mismatchedIdentity.exitCode == 1)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: mismatchedIdentity.standardError)
            .reasonCode == "untrusted_broker_anchor")

        let raw = try JSONSerialization.jsonObject(with: fixture.initializationInput)
        var callerSelected = try #require(raw as? [String: Any])
        callerSelected["anchor_path"] = fixture.anchorURL.path
        callerSelected["root_path"] = fixture.root.path
        let callerSelectedResult = try FactoryBrokerCommand.run(
            arguments: ["state", "initialize"],
            standardInput: JSONSerialization.data(
                withJSONObject: callerSelected,
                options: [.sortedKeys, .withoutEscapingSlashes],
            ),
            runtime: fixture.runtime,
        )
        #expect(callerSelectedResult.exitCode == 1)
        let stateURL = fixture.root.appending(path: "broker-state.json")
        #expect(!FileManager.default.fileExists(atPath: stateURL.path))
    }

    @Test("Broker rejects a substituted executable before state mutation")
    func substitutedBrokerExecutable() throws {
        let fixture = try trustedRuntimeFixture(
            prefix: "factory-substituted-executable",
            currentTime: "2026-07-11T00:30:00Z",
        )
        defer { fixture.removeTemporaryFiles() }
        let substitutedURL = fixture.anchorRoot.appending(path: "SubstitutedBroker")
        try Data("substituted-broker".utf8).write(to: substitutedURL, options: .withoutOverwriting)
        #expect(chmod(substitutedURL.path, 0o555) == 0)
        let substitutedRuntime = try BrokerCommandRuntime(
            anchorOwnerUserID: fixture.runtime.anchorOwnerUserID,
            anchorURL: fixture.runtime.anchorURL,
            brokerExecutableOwnerUserID: fixture.runtime.brokerExecutableOwnerUserID,
            brokerExecutableMappedIdentity: BrokerExecutableIdentity.fileIdentity(at: substitutedURL),
            brokerExecutableURL: substitutedURL,
            currentTime: fixture.runtime.currentTime,
            effectiveUserID: fixture.runtime.effectiveUserID,
            realUserID: fixture.runtime.realUserID,
        )

        let result = FactoryBrokerCommand.run(
            arguments: ["state", "initialize"],
            standardInput: fixture.initializationInput,
            runtime: substitutedRuntime,
        )

        #expect(result.exitCode == 1)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: result.standardError)
            .reasonCode == "untrusted_broker_anchor")
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appending(path: "broker-state.json").path))
    }

    @Test("Broker executable ownership, links, and mode fail closed")
    func brokerExecutableFilesystemDenials() throws {
        let ownerWritable = try trustedRuntimeFixture(
            prefix: "factory-owner-writable-executable",
            currentTime: "2026-07-11T00:30:00Z",
        )
        defer { ownerWritable.removeTemporaryFiles() }
        #expect(chmod(ownerWritable.brokerExecutableURL.path, 0o755) == 0)
        try expectExecutableRejected(ownerWritable, runtime: ownerWritable.runtime)

        let writable = try trustedRuntimeFixture(
            prefix: "factory-writable-executable",
            currentTime: "2026-07-11T00:30:00Z",
        )
        defer { writable.removeTemporaryFiles() }
        #expect(chmod(writable.brokerExecutableURL.path, 0o577) == 0)
        try expectExecutableRejected(writable, runtime: writable.runtime)

        let hardLinked = try trustedRuntimeFixture(
            prefix: "factory-hard-linked-executable",
            currentTime: "2026-07-11T00:30:00Z",
        )
        defer { hardLinked.removeTemporaryFiles() }
        let hardLink = hardLinked.anchorRoot.appending(path: "FactoryBroker-copy")
        #expect(Darwin.link(hardLinked.brokerExecutableURL.path, hardLink.path) == 0)
        try expectExecutableRejected(hardLinked, runtime: hardLinked.runtime)

        let symbolic = try trustedRuntimeFixture(
            prefix: "factory-symbolic-executable",
            currentTime: "2026-07-11T00:30:00Z",
        )
        defer { symbolic.removeTemporaryFiles() }
        let symbolicLink = symbolic.anchorRoot.appending(path: "FactoryBroker-link")
        try FileManager.default.createSymbolicLink(
            at: symbolicLink,
            withDestinationURL: symbolic.brokerExecutableURL,
        )
        try expectExecutableRejected(
            symbolic,
            runtime: runtime(for: symbolic, executableURL: symbolicLink),
        )

        let wrongOwner = try trustedRuntimeFixture(
            prefix: "factory-wrong-owner-executable",
            currentTime: "2026-07-11T00:30:00Z",
        )
        defer { wrongOwner.removeTemporaryFiles() }
        try expectExecutableRejected(
            wrongOwner,
            runtime: runtime(
                for: wrongOwner,
                executableURL: wrongOwner.brokerExecutableURL,
                ownerUserID: uid_t(TestValues.operatorUserID),
            ),
        )

        let replaced = try trustedRuntimeFixture(
            prefix: "factory-replaced-running-executable",
            currentTime: "2026-07-11T00:30:00Z",
        )
        defer { replaced.removeTemporaryFiles() }
        let originalMappedIdentity = try #require(replaced.runtime.brokerExecutableMappedIdentity)
        let replacement = replaced.anchorRoot.appending(path: "FactoryBroker-replacement")
        try Data("installed-broker".utf8).write(to: replacement, options: .withoutOverwriting)
        #expect(chmod(replacement.path, 0o555) == 0)
        #expect(rename(replacement.path, replaced.brokerExecutableURL.path) == 0)
        try expectExecutableRejected(
            replaced,
            runtime: runtime(
                for: replaced,
                executableURL: replaced.brokerExecutableURL,
                mappedIdentity: originalMappedIdentity,
            ),
        )

        let accessControlled = try trustedRuntimeFixture(
            prefix: "factory-acl-executable",
            currentTime: "2026-07-11T00:30:00Z",
        )
        defer { accessControlled.removeTemporaryFiles() }
        try addAccessControl("everyone allow write", to: accessControlled.brokerExecutableURL)
        try expectExecutableRejected(accessControlled, runtime: accessControlled.runtime)

        let accessControlledAncestor = try trustedRuntimeFixture(
            prefix: "factory-acl-executable-ancestor",
            currentTime: "2026-07-11T00:30:00Z",
        )
        defer { accessControlledAncestor.removeTemporaryFiles() }
        try addAccessControl(
            "everyone allow add_file,delete_child",
            to: accessControlledAncestor.anchorRoot,
        )
        try expectExecutableRejected(accessControlledAncestor, runtime: accessControlledAncestor.runtime)
    }

    private func addAccessControl(_ rule: String, to url: URL) throws {
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
                message: "Could not install the extended ACL denial fixture.",
            )
        }
    }

    private func runtime(
        for fixture: TrustedRuntimeFixture,
        executableURL: URL,
        ownerUserID: uid_t = getuid(),
        mappedIdentity: BrokerExecutableMappedIdentity? = nil,
    ) -> BrokerCommandRuntime {
        BrokerCommandRuntime(
            anchorOwnerUserID: fixture.runtime.anchorOwnerUserID,
            anchorURL: fixture.runtime.anchorURL,
            brokerExecutableOwnerUserID: ownerUserID,
            brokerExecutableMappedIdentity: mappedIdentity ?? (try? BrokerExecutableIdentity.fileIdentity(
                at: executableURL,
            )),
            brokerExecutableURL: executableURL,
            currentTime: fixture.runtime.currentTime,
            effectiveUserID: fixture.runtime.effectiveUserID,
            realUserID: fixture.runtime.realUserID,
        )
    }

    private func expectExecutableRejected(
        _ fixture: TrustedRuntimeFixture,
        runtime: BrokerCommandRuntime,
    ) throws {
        let result = FactoryBrokerCommand.run(
            arguments: ["state", "initialize"],
            standardInput: fixture.initializationInput,
            runtime: runtime,
        )
        #expect(result.exitCode == 1)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: result.standardError)
            .reasonCode == "untrusted_broker_anchor")
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appending(path: "broker-state.json").path))
    }

    private func initializeBroker(_ fixture: TrustedRuntimeFixture) throws {
        let initialize = FactoryBrokerCommand.run(
            arguments: ["state", "initialize"],
            standardInput: fixture.initializationInput,
            runtime: fixture.runtime,
        )
        #expect(
            initialize.exitCode == 0,
            "initialize failed: \(String(decoding: initialize.standardError, as: UTF8.self))",
        )
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: initialize.standardOutput)
            .reasonCode == "broker-state-initialized")
    }

    private func activationReceipt(
        for fixture: TrustedRuntimeFixture,
        receiptID: String,
        issuedAt: String,
        expiresAt: String,
    ) throws -> BrokerActivationReceipt {
        try BrokerActivationAuthority.sign(
            policy: fixture.policy,
            state: fixture.state,
            input: BrokerActivationSigningInput(
                auditPublicKey: TestValues.auditPrivateKey.publicKey,
                isolationProofSHA256: TestValues.evidence,
                evaluatorProofSHA256: TestValues.context,
                selectionEpochSHA256: TestValues.tree,
                sealedEpochSHA256: TestValues.contract,
                receiptID: receiptID,
                signingKeyID: "owner-trusted-root-key",
                issuedAt: issuedAt,
                expiresAt: expiresAt,
                privateKey: TestValues.activationPrivateKey,
            ),
        )
    }

    private func activateBroker(_ fixture: TrustedRuntimeFixture) throws {
        let receipt = try activationReceipt(
            for: fixture,
            receiptID: "broker-activation-1",
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T01:00:00Z",
        )
        let activation = try FactoryBrokerCommand.run(
            arguments: ["activate-receipt"],
            standardInput: CanonicalJSON.encode(BrokerActivationCommand(receipt: receipt)),
            runtime: fixture.runtime,
        )
        #expect(activation.exitCode == 0)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: activation.standardOutput)
            .reasonCode == "broker-activated")
    }

    private func verifyEvaluatorScaffolding(_ fixture: TrustedRuntimeFixture) throws {
        let alteredSchemaResult = try FactoryBrokerCommand.run(
            arguments: ["scaffold-evaluator"],
            standardInput: CanonicalJSON.encode(EvaluationScaffoldCommand(
                acceptanceSHA256: TestValues.contract,
                schemaDigests: [SchemaDigest(schemaID: "altered-schema", sha256: TestValues.evidence)],
                trustedRootSHA: TestValues.head,
            )),
            runtime: fixture.runtime,
        )
        #expect(alteredSchemaResult.exitCode == 1)
        #expect(!FileManager.default.fileExists(atPath: fixture.scaffold.path))

        let scaffoldResult = try FactoryBrokerCommand.run(
            arguments: ["scaffold-evaluator"],
            standardInput: CanonicalJSON.encode(EvaluationScaffoldCommand(
                acceptanceSHA256: fixture.manifest.acceptanceSHA256,
                schemaDigests: fixture.manifest.schemaDigests,
                trustedRootSHA: fixture.manifest.trustedRootSHA,
            )),
            runtime: fixture.runtime,
        )
        #expect(scaffoldResult.exitCode == 0)
        let rootManifest = fixture.scaffold.appending(path: ".factory/evaluation-root.json")
        #expect(FileManager.default.fileExists(atPath: rootManifest.path))
    }
}

extension FactoryCommandTests {
    @Test("Activation lifetime uses a trusted process clock, not request JSON")
    func historicalInputClockCannotActivate() throws {
        let fixture = try trustedRuntimeFixture(prefix: "factory-clock", currentTime: "2026-07-11T02:00:00Z")
        defer { fixture.removeTemporaryFiles() }
        try initializeBroker(fixture)
        let receipt = try activationReceipt(
            for: fixture,
            receiptID: "expired-broker-activation",
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T00:01:00Z",
        )
        let activationInput = try CanonicalJSON.encode(BrokerActivationCommand(receipt: receipt))
        let raw = try JSONSerialization.jsonObject(with: activationInput)
        var callerClock = try #require(raw as? [String: Any])
        callerClock["now"] = "2026-07-11T00:00:30Z"
        let callerClockResult = try FactoryBrokerCommand.run(
            arguments: ["activate-receipt"],
            standardInput: JSONSerialization.data(
                withJSONObject: callerClock,
                options: [.sortedKeys, .withoutEscapingSlashes],
            ),
            runtime: fixture.runtime,
        )
        #expect(callerClockResult.exitCode == 1)
        let activation = FactoryBrokerCommand.run(
            arguments: ["activate-receipt"],
            standardInput: activationInput,
            runtime: fixture.runtime,
        )
        #expect(activation.exitCode == 1)
    }

    @Test("Process input has a total deadline even while bytes keep arriving")
    func slowDripProcessInput() throws {
        var descriptors = [Int32](repeating: -1, count: 2)
        #expect(descriptors.withUnsafeMutableBufferPointer { Darwin.pipe($0.baseAddress) } == 0)
        let writer = Process()
        writer.executableURL = URL(fileURLWithPath: "/bin/sh")
        writer.arguments = ["-c", "i=0; while [ $i -lt 64 ]; do printf A || exit; sleep 0.005; i=$((i+1)); done"]
        let writeHandle = FileHandle(fileDescriptor: descriptors[1], closeOnDealloc: true)
        writer.standardOutput = writeHandle
        try writer.run()
        try writeHandle.close()
        defer {
            Darwin.close(descriptors[0])
            if writer.isRunning { writer.terminate() }
            writer.waitUntilExit()
        }
        #expect(throws: FactoryValidationError.self) {
            try FactoryProcessInput.read(
                fileDescriptor: descriptors[0],
                maximumBytes: 1024,
                idleTimeoutMilliseconds: 20,
                totalTimeoutMilliseconds: 30,
            )
        }
    }
}
