import CryptoKit
import Foundation

/// Sensitive root categories that every qualifying backend must deny.
public enum DeniedRootClass: String, Codable, CaseIterable, Hashable, Sendable {
    case ambientConfig = "ambient_config"
    case brokerState = "broker_state"
    case gitCommon = "git_common"
    case keychain
    case ownerHome = "owner_home"
    case siblingWorktree = "sibling_worktree"
    case ssh
}

/// Public backend identity; qualifying is verified against installed policy rather than trusted alone.
public struct IsolationBackend: Codable, Equatable, Sendable {
    public let id: String
    public var qualifying: Bool
    public let version: String

    public init(id: String, qualifying: Bool, version: String) {
        self.id = id
        self.qualifying = qualifying
        self.version = version
    }
}

/// Dedicated account and exact runner executable used for one invocation.
public struct RunnerIdentity: Codable, Equatable, Sendable {
    public let account: String
    public let executableSHA256: SHA256Digest
    public let gid: Int
    public let uid: Int

    public init(account: String, executableSHA256: SHA256Digest, gid: Int, uid: Int) {
        self.account = account
        self.executableSHA256 = executableSHA256
        self.gid = gid
        self.uid = uid
    }
}

/// Explicit brokered-network exception; live writer policy currently permits none.
public struct NetworkException: Codable, Equatable, Sendable {
    public let domain: String
    public let port: Int

    public init(domain: String, port: Int) {
        self.domain = domain
        self.port = port
    }
}

/// Tool-process network posture; provider transport remains outside this boundary.
public struct NetworkPolicy: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable {
        case brokered
        case denyAll = "deny_all"
    }

    public let exceptions: [NetworkException]
    public let mode: Mode

    public init(exceptions: [NetworkException], mode: Mode) {
        self.exceptions = exceptions
        self.mode = mode
    }
}

/// PID, process-group, and boot/process-start identity bound to a launch.
public struct RunnerProcessIdentity: Codable, Equatable, Sendable {
    public let launchIdentitySHA256: SHA256Digest
    public let pid: Int
    public let processGroupID: Int

    public init(launchIdentitySHA256: SHA256Digest, pid: Int, processGroupID: Int) {
        self.launchIdentitySHA256 = launchIdentitySHA256
        self.pid = pid
        self.processGroupID = processGroupID
    }
}

/// Hard execution ceilings applied to the client and every spawned tool.
public struct ResourceCeilings: Codable, Equatable, Sendable {
    public let cpuSeconds: Int
    public let diskBytes: Int
    public let memoryBytes: Int
    public let openFiles: Int
    public let outputBytes: Int
    public let processes: Int
    public let tokens: Int
    public let wallSeconds: Int

    public init(
        cpuSeconds: Int,
        diskBytes: Int,
        memoryBytes: Int,
        openFiles: Int,
        outputBytes: Int,
        processes: Int,
        tokens: Int,
        wallSeconds: Int,
    ) {
        self.cpuSeconds = cpuSeconds
        self.diskBytes = diskBytes
        self.memoryBytes = memoryBytes
        self.openFiles = openFiles
        self.outputBytes = outputBytes
        self.processes = processes
        self.tokens = tokens
        self.wallSeconds = wallSeconds
    }

    fileprivate var isPositive: Bool {
        [cpuSeconds, diskBytes, memoryBytes, openFiles, outputBytes, processes, tokens, wallSeconds]
            .allSatisfy { $0 > 0 }
    }
}

/// Aggregate denial-suite proof emitted by the installed doctor.
public struct IsolationDoctorProof: Codable, Equatable, Sendable {
    public let canarySetSHA256: SHA256Digest
    public let clientID: FactoryClient
    public let clientVersion: String
    public let expiresAt: String
    public let osBuild: String
    public let passedAt: String
    public let proofSHA256: SHA256Digest

    public init(
        canarySetSHA256: SHA256Digest,
        clientID: FactoryClient,
        clientVersion: String,
        expiresAt: String,
        osBuild: String,
        passedAt: String,
        proofSHA256: SHA256Digest,
    ) {
        self.canarySetSHA256 = canarySetSHA256
        self.clientID = clientID
        self.clientVersion = clientVersion
        self.expiresAt = expiresAt
        self.osBuild = osBuild
        self.passedAt = passedAt
        self.proofSHA256 = proofSHA256
    }
}

/// Typed public boundary required before any model may produce a qualifying patch.
public struct RunnerIsolation: Codable, Equatable, Sendable {
    public let allowedRoots: [String]
    public var backend: IsolationBackend
    public var credentialInventory: [String]
    public let deniedRootClasses: [DeniedRootClass]
    public let doctorProof: IsolationDoctorProof
    public let environmentKeys: [String]
    public let invocationID: String
    public let network: NetworkPolicy
    public let policySHA256: SHA256Digest
    public let process: RunnerProcessIdentity
    public let projectionSHA256: SHA256Digest
    public let resources: ResourceCeilings
    public let runner: RunnerIdentity
    public let schemaVersion: Int

    public init(
        allowedRoots: [String],
        backend: IsolationBackend,
        credentialInventory: [String],
        deniedRootClasses: [DeniedRootClass],
        doctorProof: IsolationDoctorProof,
        environmentKeys: [String],
        invocationID: String,
        network: NetworkPolicy,
        policySHA256: SHA256Digest,
        process: RunnerProcessIdentity,
        projectionSHA256: SHA256Digest,
        resources: ResourceCeilings,
        runner: RunnerIdentity,
        schemaVersion: Int = FactoryCore.schemaVersion,
    ) {
        self.allowedRoots = allowedRoots
        self.backend = backend
        self.credentialInventory = credentialInventory
        self.deniedRootClasses = deniedRootClasses
        self.doctorProof = doctorProof
        self.environmentKeys = environmentKeys
        self.invocationID = invocationID
        self.network = network
        self.policySHA256 = policySHA256
        self.process = process
        self.projectionSHA256 = projectionSHA256
        self.resources = resources
        self.runner = runner
        self.schemaVersion = schemaVersion
    }

    /// Validates the complete public manifest without claiming that its private canaries passed.
    func validateStructure() throws {
        let allowedEnvironment = Set([
            "DEVELOPER_DIR", "HOME", "LANG", "LC_CTYPE", "LOGNAME", "PATH", "SHELL", "TMPDIR", "USER",
        ])
        let expectedDenied = DeniedRootClass.allCases.sorted { $0.rawValue < $1.rawValue }
        let allowedPaths = try allowedRoots.map(RepositoryPath.init(validating:))
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(invocationID),
              FactoryTextRules.isStableID(backend.id),
              FactoryTextRules.isBoundedText(backend.version, maximumScalars: 128),
              FactoryTextRules.isBoundedText(runner.account, maximumScalars: 128),
              FactoryTextRules.isBoundedText(doctorProof.clientVersion, maximumScalars: 128),
              FactoryTextRules.isBoundedText(doctorProof.osBuild, maximumScalars: 128),
              runner.uid > 0,
              runner.gid > 0,
              process.pid > 1,
              process.processGroupID > 1,
              resources.isPositive,
              !allowedRoots.isEmpty,
              allowedRoots.count <= 10000,
              allowedRoots == Array(Set(allowedRoots)).sorted(),
              allowedPaths.map(\.rawValue) == allowedRoots,
              network.mode == .denyAll,
              network.exceptions.isEmpty,
              deniedRootClasses == expectedDenied,
              credentialInventory.isEmpty,
              environmentKeys == Array(Set(environmentKeys)).sorted(),
              Set(environmentKeys).isSubset(of: allowedEnvironment),
              validIsolationInterval(passedAt: doctorProof.passedAt, expiresAt: doctorProof.expiresAt)
        else {
            throw FactoryValidationError(
                code: "isolation_contract_incomplete",
                message: "The runner boundary is credentialed, broadened, stale, or incomplete.",
            )
        }
    }
}

/// Denial-suite capability exercised by both client and child tool.
public enum IsolationProbeKind: String, Codable, CaseIterable, Hashable, Sendable {
    case deniedNetwork = "denied_network"
    case processCleanup = "process_cleanup"
    case readBrokerState = "read_broker_state"
    case readGitCommon = "read_git_common"
    case readOwnerSecrets = "read_owner_secrets"
    case readSiblingWorktree = "read_sibling_worktree"
    case writeOutsideProjection = "write_outside_projection"
}

/// Process layer at which an isolation canary was attempted.
public enum IsolationProbeSubject: String, Codable, CaseIterable, Hashable, Sendable {
    case client
    case spawnedTool = "spawned_tool"
}

/// Observed canary result with no sensitive path or value.
public enum IsolationProbeOutcome: String, Codable, Sendable {
    case allowed
    case denied
    case terminated
    case unknown
}

/// One reproducible canary result retained outside the aggregate public proof.
public struct IsolationProbeResult: Codable, Equatable, Sendable {
    public let kind: IsolationProbeKind
    public let subject: IsolationProbeSubject
    public var outcome: IsolationProbeOutcome

    public init(kind: IsolationProbeKind, subject: IsolationProbeSubject, outcome: IsolationProbeOutcome) {
        self.kind = kind
        self.subject = subject
        self.outcome = outcome
    }
}

/// Private deterministic evidence used to reproduce the aggregate doctor proof.
public struct IsolationDoctorEvidence: Codable, Equatable, Sendable {
    public var probes: [IsolationProbeResult]

    public init(probes: [IsolationProbeResult]) {
        self.probes = probes
    }

    public var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }
}

/// Trust state installed from merged trusted root rather than asserted by a runner request.
public enum IsolationTrustActivation: String, Codable, Sendable {
    case activated
    case buildCandidateFixtureOnly = "build_candidate_fixture_only"
}

/// Broker-owned ceiling for one reviewed backend, runner, proof, and launch identity.
public struct IsolationTrustPolicy: Equatable, Sendable {
    public let activation: IsolationTrustActivation
    public let backendID: String
    public let backendVersion: String
    public let runnerExecutableSHA256: SHA256Digest
    public let policySHA256: SHA256Digest
    public let canarySetSHA256: SHA256Digest
    public let proofSHA256: SHA256Digest
    public let launchIdentitySHA256: SHA256Digest
    public let activationReceiptSHA256: SHA256Digest?
    public let backendQualifying: Bool

    fileprivate init(
        activation: IsolationTrustActivation,
        backendID: String,
        backendVersion: String,
        runnerExecutableSHA256: SHA256Digest,
        policySHA256: SHA256Digest,
        canarySetSHA256: SHA256Digest,
        proofSHA256: SHA256Digest,
        launchIdentitySHA256: SHA256Digest,
        activationReceiptSHA256: SHA256Digest? = nil,
        backendQualifying: Bool,
    ) {
        self.activation = activation
        self.backendID = backendID
        self.backendVersion = backendVersion
        self.runnerExecutableSHA256 = runnerExecutableSHA256
        self.policySHA256 = policySHA256
        self.canarySetSHA256 = canarySetSHA256
        self.proofSHA256 = proofSHA256
        self.launchIdentitySHA256 = launchIdentitySHA256
        self.activationReceiptSHA256 = activationReceiptSHA256
        self.backendQualifying = backendQualifying
    }

    /// Creates the maximum authority available to unmerged build candidate code.
    public static func buildCandidateFixture(
        for isolation: RunnerIsolation,
        evidence: IsolationDoctorEvidence,
    ) -> IsolationTrustPolicy {
        IsolationTrustPolicy(
            activation: .buildCandidateFixtureOnly,
            backendID: isolation.backend.id,
            backendVersion: isolation.backend.version,
            runnerExecutableSHA256: isolation.runner.executableSHA256,
            policySHA256: isolation.policySHA256,
            canarySetSHA256: isolation.doctorProof.canarySetSHA256,
            proofSHA256: RunnerIsolationDoctor.proofSHA256(for: isolation, evidence: evidence),
            launchIdentitySHA256: isolation.process.launchIdentitySHA256,
            activationReceiptSHA256: nil,
            backendQualifying: false,
        )
    }
}

/// Signed activation receipt for one exact isolation proof and launch identity.
struct IsolationActivationReceipt: Codable, Equatable, Sendable {
    let backendID: String
    let backendQualifying: Bool
    let backendVersion: String
    let brokerIdentitySHA256: SHA256Digest
    let canarySetSHA256: SHA256Digest
    let expiresAt: String
    let issuedAt: String
    let launchIdentitySHA256: SHA256Digest
    let policySHA256: SHA256Digest
    let proofSHA256: SHA256Digest
    let receiptID: String
    let runnerExecutableSHA256: SHA256Digest
    let schemaVersion: Int
    let signature: Data
    let trustedRootSHA: GitObjectID

    fileprivate init(unsigned: IsolationActivationBinding, signature: Data) {
        backendID = unsigned.backendID
        backendQualifying = unsigned.backendQualifying
        backendVersion = unsigned.backendVersion
        brokerIdentitySHA256 = unsigned.brokerIdentitySHA256
        canarySetSHA256 = unsigned.canarySetSHA256
        expiresAt = unsigned.expiresAt
        issuedAt = unsigned.issuedAt
        launchIdentitySHA256 = unsigned.launchIdentitySHA256
        policySHA256 = unsigned.policySHA256
        proofSHA256 = unsigned.proofSHA256
        receiptID = unsigned.receiptID
        runnerExecutableSHA256 = unsigned.runnerExecutableSHA256
        schemaVersion = unsigned.schemaVersion
        self.signature = signature
        trustedRootSHA = unsigned.trustedRootSHA
    }

    fileprivate var unsigned: IsolationActivationBinding {
        IsolationActivationBinding(
            backendID: backendID,
            backendQualifying: backendQualifying,
            backendVersion: backendVersion,
            brokerIdentitySHA256: brokerIdentitySHA256,
            canarySetSHA256: canarySetSHA256,
            expiresAt: expiresAt,
            issuedAt: issuedAt,
            launchIdentitySHA256: launchIdentitySHA256,
            policySHA256: policySHA256,
            proofSHA256: proofSHA256,
            receiptID: receiptID,
            runnerExecutableSHA256: runnerExecutableSHA256,
            schemaVersion: schemaVersion,
            trustedRootSHA: trustedRootSHA,
        )
    }
}

/// Receipt signer/verifier. Production verification anchors the public key in the installed trusted root.
enum IsolationActivationAuthority {
    static func sign(
        isolation: RunnerIsolation,
        evidence: IsolationDoctorEvidence,
        trustedRootSHA: GitObjectID,
        brokerIdentitySHA256: SHA256Digest,
        receiptID: String,
        issuedAt: String,
        expiresAt: String,
        privateKey: Curve25519.Signing.PrivateKey,
    ) throws -> IsolationActivationReceipt {
        let binding = IsolationActivationBinding(
            backendID: isolation.backend.id,
            backendQualifying: isolation.backend.qualifying,
            backendVersion: isolation.backend.version,
            brokerIdentitySHA256: brokerIdentitySHA256,
            canarySetSHA256: isolation.doctorProof.canarySetSHA256,
            expiresAt: expiresAt,
            issuedAt: issuedAt,
            launchIdentitySHA256: isolation.process.launchIdentitySHA256,
            policySHA256: isolation.policySHA256,
            proofSHA256: RunnerIsolationDoctor.proofSHA256(for: isolation, evidence: evidence),
            receiptID: receiptID,
            runnerExecutableSHA256: isolation.runner.executableSHA256,
            schemaVersion: FactoryCore.schemaVersion,
            trustedRootSHA: trustedRootSHA,
        )
        guard binding.backendQualifying,
              validActivationTime(issuedAt: issuedAt, expiresAt: expiresAt, now: issuedAt),
              receiptID.wholeMatch(of: /^[a-z0-9][a-z0-9._:-]{0,127}$/) != nil
        else {
            throw FactoryValidationError(
                code: "invalid_isolation_activation",
                message: "Only a canonical qualifying isolation proof can be activated.",
            )
        }
        let signature = try privateKey.signature(for: CanonicalJSON.encode(binding))
        return IsolationActivationReceipt(unsigned: binding, signature: signature)
    }

    static func verify(
        _ receipt: IsolationActivationReceipt,
        isolation: RunnerIsolation,
        evidence: IsolationDoctorEvidence,
        expectedTrustedRootSHA: GitObjectID,
        expectedBrokerIdentitySHA256: SHA256Digest,
        now: String,
        publicKey: Curve25519.Signing.PublicKey,
    ) throws -> IsolationTrustPolicy {
        let binding = receipt.unsigned
        guard receipt.schemaVersion == FactoryCore.schemaVersion,
              receipt.signature.count == 64,
              receipt.trustedRootSHA == expectedTrustedRootSHA,
              receipt.brokerIdentitySHA256 == expectedBrokerIdentitySHA256,
              receipt.backendID == isolation.backend.id,
              receipt.backendVersion == isolation.backend.version,
              receipt.backendQualifying,
              isolation.backend.qualifying,
              receipt.runnerExecutableSHA256 == isolation.runner.executableSHA256,
              receipt.policySHA256 == isolation.policySHA256,
              receipt.canarySetSHA256 == isolation.doctorProof.canarySetSHA256,
              receipt.proofSHA256 == RunnerIsolationDoctor.proofSHA256(for: isolation, evidence: evidence),
              receipt.proofSHA256 == isolation.doctorProof.proofSHA256,
              receipt.launchIdentitySHA256 == isolation.process.launchIdentitySHA256,
              validActivationTime(issuedAt: receipt.issuedAt, expiresAt: receipt.expiresAt, now: now),
              try publicKey.isValidSignature(receipt.signature, for: CanonicalJSON.encode(binding))
        else {
            throw FactoryValidationError(
                code: "invalid_isolation_activation",
                message: "The isolation activation receipt is untrusted, stale, or bound to another launch.",
            )
        }
        return IsolationTrustPolicy(
            activation: .activated,
            backendID: receipt.backendID,
            backendVersion: receipt.backendVersion,
            runnerExecutableSHA256: receipt.runnerExecutableSHA256,
            policySHA256: receipt.policySHA256,
            canarySetSHA256: receipt.canarySetSHA256,
            proofSHA256: receipt.proofSHA256,
            launchIdentitySHA256: receipt.launchIdentitySHA256,
            activationReceiptSHA256: CanonicalJSON.digest(receipt),
            backendQualifying: true,
        )
    }
}

private struct IsolationActivationBinding: Codable {
    let backendID: String
    let backendQualifying: Bool
    let backendVersion: String
    let brokerIdentitySHA256: SHA256Digest
    let canarySetSHA256: SHA256Digest
    let expiresAt: String
    let issuedAt: String
    let launchIdentitySHA256: SHA256Digest
    let policySHA256: SHA256Digest
    let proofSHA256: SHA256Digest
    let receiptID: String
    let runnerExecutableSHA256: SHA256Digest
    let schemaVersion: Int
    let trustedRootSHA: GitObjectID
}

private func validActivationTime(issuedAt: String, expiresAt: String, now: String) -> Bool {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let issued = formatter.date(from: issuedAt),
          let expires = formatter.date(from: expiresAt),
          let current = formatter.date(from: now),
          formatter.string(from: issued) == issuedAt,
          formatter.string(from: expires) == expiresAt,
          formatter.string(from: current) == now
    else {
        return false
    }
    return issued <= current && current < expires
}

/// Requested authority for an isolation proof.
public enum IsolationRequestedUse: String, Codable, Sendable {
    case bootstrapFixture = "bootstrap_fixture"
    case liveModelWriting = "live_model_writing"
}

/// Maximum authority actually established by the trusted doctor.
public enum IsolationQualification: String, Codable, Sendable {
    case fixtureQualified = "fixture_qualified"
    case liveWritingQualified = "live_writing_qualified"
}

/// Fail-closed verifier for an installed policy plus reproducible private denial evidence.
public enum RunnerIsolationDoctor {
    /// Canonical digest of every public launch identity and every private probe outcome.
    public static func proofSHA256(
        for isolation: RunnerIsolation,
        evidence: IsolationDoctorEvidence,
    ) -> SHA256Digest {
        CanonicalJSON.digest(
            IsolationProofBinding(
                allowedRoots: isolation.allowedRoots,
                backend: isolation.backend,
                credentialInventory: isolation.credentialInventory,
                deniedRootClasses: isolation.deniedRootClasses,
                doctor: DoctorMetadata(
                    canarySetSHA256: isolation.doctorProof.canarySetSHA256,
                    clientID: isolation.doctorProof.clientID,
                    clientVersion: isolation.doctorProof.clientVersion,
                    expiresAt: isolation.doctorProof.expiresAt,
                    osBuild: isolation.doctorProof.osBuild,
                    passedAt: isolation.doctorProof.passedAt,
                ),
                environmentKeys: isolation.environmentKeys,
                evidence: evidence,
                invocationID: isolation.invocationID,
                network: isolation.network,
                policySHA256: isolation.policySHA256,
                process: isolation.process,
                projectionSHA256: isolation.projectionSHA256,
                resources: isolation.resources,
                runner: isolation.runner,
                schemaVersion: isolation.schemaVersion,
            ),
        )
    }

    public static func validate(
        _ isolation: RunnerIsolation,
        trustPolicy: IsolationTrustPolicy,
        evidence: IsolationDoctorEvidence,
        requestedUse: IsolationRequestedUse,
        now: String,
    ) throws -> IsolationQualification {
        try isolation.validateStructure()
        let proofSHA256 = proofSHA256(for: isolation, evidence: evidence)
        guard isolation.backend.id == trustPolicy.backendID,
              isolation.backend.version == trustPolicy.backendVersion,
              isolation.runner.executableSHA256 == trustPolicy.runnerExecutableSHA256,
              isolation.policySHA256 == trustPolicy.policySHA256,
              isolation.process.launchIdentitySHA256 == trustPolicy.launchIdentitySHA256,
              isolation.doctorProof.canarySetSHA256 == trustPolicy.canarySetSHA256,
              isolation.doctorProof.proofSHA256 == proofSHA256,
              trustPolicy.proofSHA256 == proofSHA256
        else {
            throw FactoryValidationError(
                code: "isolation_contract_incomplete",
                message: "The runner boundary is credentialed, broadened, stale, or incomplete.",
            )
        }
        try validateTime(proof: isolation.doctorProof, now: now)

        let expected = Set(IsolationProbeKind.allCases.flatMap { kind in
            IsolationProbeSubject.allCases.map { ProbeKey(kind: kind, subject: $0) }
        })
        let observed = Set(evidence.probes.map { ProbeKey(kind: $0.kind, subject: $0.subject) })
        guard observed == expected,
              observed.count == evidence.probes.count,
              evidence.probes == evidence.probes.sorted(by: probeOrder)
        else {
            throw FactoryValidationError(
                code: "incomplete_isolation_proof",
                message: "Every client and child canary must run once.",
            )
        }
        for probe in evidence.probes {
            let expectedOutcome: IsolationProbeOutcome = probe.kind == .processCleanup ? .terminated : .denied
            guard probe.outcome == expectedOutcome else {
                throw FactoryValidationError(
                    code: "isolation_canary_failed",
                    message: "An isolation canary escaped its boundary.",
                )
            }
        }
        switch requestedUse {
        case .bootstrapFixture:
            return .fixtureQualified
        case .liveModelWriting:
            guard trustPolicy.activation == .activated,
                  trustPolicy.activationReceiptSHA256 != nil,
                  trustPolicy.backendQualifying,
                  isolation.backend.qualifying
            else {
                throw FactoryValidationError(
                    code: "isolation_not_activated",
                    message: "Build-candidate fixtures cannot authorize live model writing before activation.",
                )
            }
            return .liveWritingQualified
        }
    }

    private static func validateTime(proof: IsolationDoctorProof, now: String) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let passed = formatter.date(from: proof.passedAt),
              let expires = formatter.date(from: proof.expiresAt),
              let current = formatter.date(from: now),
              formatter.string(from: passed) == proof.passedAt,
              formatter.string(from: expires) == proof.expiresAt,
              formatter.string(from: current) == now,
              passed <= current,
              current < expires
        else {
            throw FactoryValidationError(
                code: "stale_isolation_proof",
                message: "The denial proof is expired or uses noncanonical time.",
            )
        }
    }

    private struct ProbeKey: Hashable {
        let kind: IsolationProbeKind
        let subject: IsolationProbeSubject
    }

    private static func probeOrder(_ lhs: IsolationProbeResult, _ rhs: IsolationProbeResult) -> Bool {
        if lhs.kind.rawValue != rhs.kind.rawValue {
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        return lhs.subject.rawValue < rhs.subject.rawValue
    }

    private struct DoctorMetadata: Codable {
        let canarySetSHA256: SHA256Digest
        let clientID: FactoryClient
        let clientVersion: String
        let expiresAt: String
        let osBuild: String
        let passedAt: String
    }

    private struct IsolationProofBinding: Codable {
        let allowedRoots: [String]
        let backend: IsolationBackend
        let credentialInventory: [String]
        let deniedRootClasses: [DeniedRootClass]
        let doctor: DoctorMetadata
        let environmentKeys: [String]
        let evidence: IsolationDoctorEvidence
        let invocationID: String
        let network: NetworkPolicy
        let policySHA256: SHA256Digest
        let process: RunnerProcessIdentity
        let projectionSHA256: SHA256Digest
        let resources: ResourceCeilings
        let runner: RunnerIdentity
        let schemaVersion: Int
    }
}

private func validIsolationInterval(passedAt: String, expiresAt: String) -> Bool {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let passed = formatter.date(from: passedAt),
          let expires = formatter.date(from: expiresAt),
          formatter.string(from: passed) == passedAt,
          formatter.string(from: expires) == expiresAt
    else {
        return false
    }
    return passed < expires
}
