import Foundation

enum BrokerAuthorityMode {
    case activated
    case buildCandidateFixtureOnly
}

/// Authoritative state values that every broker side effect must compare atomically.
public struct BrokerState: Codable, Equatable, Sendable {
    public let runID: String
    public let issueNumber: Int
    public let pullRequestNumber: Int?
    public let contractDigest: SHA256Digest
    public let head: GitObjectID
    public let tree: GitObjectID
    public let generation: Int
    public let leaseID: String
    public let policyDigest: SHA256Digest
    public let priorAuditSequence: Int
    public let priorAuditDigest: SHA256Digest

    public init(
        runID: String,
        issueNumber: Int,
        pullRequestNumber: Int?,
        contractDigest: SHA256Digest,
        head: GitObjectID,
        tree: GitObjectID,
        generation: Int,
        leaseID: String,
        policyDigest: SHA256Digest,
        priorAuditSequence: Int,
        priorAuditDigest: SHA256Digest,
    ) {
        self.runID = runID
        self.issueNumber = issueNumber
        self.pullRequestNumber = pullRequestNumber
        self.contractDigest = contractDigest
        self.head = head
        self.tree = tree
        self.generation = generation
        self.leaseID = leaseID
        self.policyDigest = policyDigest
        self.priorAuditSequence = priorAuditSequence
        self.priorAuditDigest = priorAuditDigest
    }
}

/// Complete compare-and-swap guard copied into one broker request.
public struct BrokerPrecondition: Codable, Equatable, Sendable {
    public let contractSHA256: SHA256Digest
    public let expectedHeadSHA: GitObjectID
    public let expectedTreeSHA: GitObjectID
    public var leaseGeneration: Int
    public let leaseID: String
    public let policySHA256: SHA256Digest
    public let priorAuditSequence: Int
    public let priorAuditSHA256: SHA256Digest

    public init(expected state: BrokerState) {
        contractSHA256 = state.contractDigest
        expectedHeadSHA = state.head
        expectedTreeSHA = state.tree
        leaseGeneration = state.generation
        leaseID = state.leaseID
        policySHA256 = state.policyDigest
        priorAuditSequence = state.priorAuditSequence
        priorAuditSHA256 = state.priorAuditDigest
    }

    /// Whether every field guarded by the broker is still the expected value.
    public func matches(_ state: BrokerState) -> Bool {
        contractSHA256 == state.contractDigest
            && expectedHeadSHA == state.head
            && expectedTreeSHA == state.tree
            && leaseGeneration == state.generation
            && leaseID == state.leaseID
            && policySHA256 == state.policyDigest
            && priorAuditSequence == state.priorAuditSequence
            && priorAuditSHA256 == state.priorAuditDigest
    }
}

/// GitHub transaction kinds whose prose is referenced only by digest.
public enum BrokerGitHubTransactionKind: String, Codable, Sendable {
    case createIssue = "create_issue"
    case createPR = "create_pr"
    case markPRReady = "mark_pr_ready"
    case updateIssue = "update_issue"
    case updatePR = "update_pr"
}

/// Bounded GitHub side effect with no raw prose, URL, GraphQL, or merge authority.
public struct BrokerGitHubTransaction: Codable, Equatable, Sendable {
    public let transaction: BrokerGitHubTransactionKind
    public let bodySHA256: SHA256Digest
    public let issueNumber: Int
    @RequiredNullable public var prNumber: Int?

    public init(
        transaction: BrokerGitHubTransactionKind,
        bodySHA256: SHA256Digest,
        issueNumber: Int,
        prNumber: Int?,
    ) {
        self.transaction = transaction
        self.bodySHA256 = bodySHA256
        self.issueNumber = issueNumber
        self.prNumber = prNumber
    }
}

/// Closed operation identity shared by requests and append-only audit facts.
public enum BrokerOperationKind: String, Codable, Hashable, Sendable {
    case claimWorktree = "claim_worktree"
    case prepareProjection = "prepare_projection"
    case launchRunner = "launch_runner"
    case importPatch = "import_patch"
    case runGate = "run_gate"
    case commitCheckpoint = "commit_checkpoint"
    case pushAgentBranch = "push_agent_branch"
    case githubTransaction = "github_transaction"
    case dispatchEvaluation = "dispatch_evaluation"
    case generateEvalScaffold = "generate_eval_scaffold"
    case doctor
}

/// Closed broker operation set; arbitrary commands, refs, URLs, and merge/admin actions are absent.
public enum BrokerOperation: Equatable, Sendable {
    case claimWorktree(branch: String, issueNumber: Int, worktreeSlug: String)
    case prepareProjection(allowedPaths: [RepositoryPath], invocationID: String)
    case launchRunner(clientID: FactoryClient, invocationID: String, roleID: String)
    case importPatch(envelopeSHA256: SHA256Digest)
    case runGate(gateID: String)
    case commitCheckpoint(messageSHA256: SHA256Digest)
    case pushAgentBranch(branch: String)
    case githubTransaction(BrokerGitHubTransaction)
    case dispatchEvaluation(requestSHA256: SHA256Digest)
    case generateEvalScaffold(repository: String, scaffoldSHA256: SHA256Digest)
    case doctor(doctorID: String)

    var kind: BrokerOperationKind {
        switch self {
        case .claimWorktree: .claimWorktree
        case .prepareProjection: .prepareProjection
        case .launchRunner: .launchRunner
        case .importPatch: .importPatch
        case .runGate: .runGate
        case .commitCheckpoint: .commitCheckpoint
        case .pushAgentBranch: .pushAgentBranch
        case .githubTransaction: .githubTransaction
        case .dispatchEvaluation: .dispatchEvaluation
        case .generateEvalScaffold: .generateEvalScaffold
        case .doctor: .doctor
        }
    }
}

extension BrokerOperation: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case payload
    }

    private enum PayloadKeys: String, CodingKey {
        case branch
        case issueNumber
        case worktreeSlug
        case allowedPaths
        case invocationID
        case clientID
        case roleID
        case envelopeSHA256
        case gateID
        case messageSHA256
        case requestSHA256
        case bodySHA256
        case prNumber
        case transaction
        case repository
        case scaffoldSHA256
        case doctorID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payload = try container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
        switch try container.decode(BrokerOperationKind.self, forKey: .kind) {
        case .claimWorktree:
            self = try .claimWorktree(
                branch: payload.decode(String.self, forKey: .branch),
                issueNumber: payload.decode(Int.self, forKey: .issueNumber),
                worktreeSlug: payload.decode(String.self, forKey: .worktreeSlug),
            )
        case .prepareProjection:
            self = try .prepareProjection(
                allowedPaths: payload.decode([RepositoryPath].self, forKey: .allowedPaths),
                invocationID: payload.decode(String.self, forKey: .invocationID),
            )
        case .launchRunner:
            self = try .launchRunner(
                clientID: payload.decode(FactoryClient.self, forKey: .clientID),
                invocationID: payload.decode(String.self, forKey: .invocationID),
                roleID: payload.decode(String.self, forKey: .roleID),
            )
        case .importPatch:
            self = try .importPatch(envelopeSHA256: payload.decode(SHA256Digest.self, forKey: .envelopeSHA256))
        case .runGate:
            self = try .runGate(gateID: payload.decode(String.self, forKey: .gateID))
        case .commitCheckpoint:
            self = try .commitCheckpoint(messageSHA256: payload.decode(SHA256Digest.self, forKey: .messageSHA256))
        case .pushAgentBranch:
            self = try .pushAgentBranch(branch: payload.decode(String.self, forKey: .branch))
        case .githubTransaction:
            self = try .githubTransaction(
                BrokerGitHubTransaction(
                    transaction: payload.decode(BrokerGitHubTransactionKind.self, forKey: .transaction),
                    bodySHA256: payload.decode(SHA256Digest.self, forKey: .bodySHA256),
                    issueNumber: payload.decode(Int.self, forKey: .issueNumber),
                    prNumber: payload.decodeIfPresent(Int.self, forKey: .prNumber),
                ),
            )
        case .dispatchEvaluation:
            self = try .dispatchEvaluation(requestSHA256: payload.decode(SHA256Digest.self, forKey: .requestSHA256))
        case .generateEvalScaffold:
            self = try .generateEvalScaffold(
                repository: payload.decode(String.self, forKey: .repository),
                scaffoldSHA256: payload.decode(SHA256Digest.self, forKey: .scaffoldSHA256),
            )
        case .doctor:
            self = try .doctor(doctorID: payload.decode(String.self, forKey: .doctorID))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
        switch self {
        case let .claimWorktree(branch, issueNumber, worktreeSlug):
            try payload.encode(branch, forKey: .branch)
            try payload.encode(issueNumber, forKey: .issueNumber)
            try payload.encode(worktreeSlug, forKey: .worktreeSlug)
        case let .prepareProjection(allowedPaths, invocationID):
            try payload.encode(allowedPaths, forKey: .allowedPaths)
            try payload.encode(invocationID, forKey: .invocationID)
        case let .launchRunner(clientID, invocationID, roleID):
            try payload.encode(clientID, forKey: .clientID)
            try payload.encode(invocationID, forKey: .invocationID)
            try payload.encode(roleID, forKey: .roleID)
        case let .importPatch(envelopeSHA256):
            try payload.encode(envelopeSHA256, forKey: .envelopeSHA256)
        case let .runGate(gateID):
            try payload.encode(gateID, forKey: .gateID)
        case let .commitCheckpoint(messageSHA256):
            try payload.encode(messageSHA256, forKey: .messageSHA256)
        case let .pushAgentBranch(branch):
            try payload.encode(branch, forKey: .branch)
        case let .githubTransaction(transaction):
            try payload.encode(transaction.transaction, forKey: .transaction)
            try payload.encode(transaction.bodySHA256, forKey: .bodySHA256)
            try payload.encode(transaction.issueNumber, forKey: .issueNumber)
            try payload.encode(transaction.prNumber, forKey: .prNumber)
        case let .dispatchEvaluation(requestSHA256):
            try payload.encode(requestSHA256, forKey: .requestSHA256)
        case let .generateEvalScaffold(repository, scaffoldSHA256):
            try payload.encode(repository, forKey: .repository)
            try payload.encode(scaffoldSHA256, forKey: .scaffoldSHA256)
        case let .doctor(doctorID):
            try payload.encode(doctorID, forKey: .doctorID)
        }
    }
}

/// Nonce-bound, data-only request accepted by the immutable broker.
public struct BrokerRequest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: String
    public let nonce: String
    public let issuedAt: String
    public let expiresAt: String
    public let trustedBaseSHA: GitObjectID
    public let runID: String
    public let operation: BrokerOperation
    public let precondition: BrokerPrecondition

    public init(
        schemaVersion: Int = FactoryCore.schemaVersion,
        requestID: String,
        nonce: String,
        issuedAt: String,
        expiresAt: String,
        trustedBaseSHA: GitObjectID,
        runID: String,
        operation: BrokerOperation,
        precondition: BrokerPrecondition,
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.nonce = nonce
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.trustedBaseSHA = trustedBaseSHA
        self.runID = runID
        self.operation = operation
        self.precondition = precondition
    }
}

/// Immutable trusted-base constraints used to reject broadened broker authority.
public struct BrokerPolicy: Codable, Equatable, Sendable {
    public let activationPublicKeySHA256: SHA256Digest
    public let trustedBase: GitObjectID
    public let repository: String
    public let branchPrefix: String
    public let brokerIdentitySHA256: SHA256Digest
    public let maximumPullRequestNumber: Int
    public let maximumRequestLifetimeSeconds: Int
    public let maximumReplayEntries: Int
    public let allowedOperationKinds: [BrokerOperationKind]
    public let allowedProjectionRoots: [RepositoryPath]
    public let allowedClients: [FactoryClient]
    public let allowedRoleIDs: [String]
    public let allowedGateIDs: [String]
    public let allowedDoctorIDs: [String]

    public init(
        activationPublicKeySHA256: SHA256Digest,
        trustedBase: GitObjectID,
        repository: String,
        branchPrefix: String,
        brokerIdentitySHA256: SHA256Digest,
        maximumPullRequestNumber: Int,
        maximumRequestLifetimeSeconds: Int,
        maximumReplayEntries: Int,
        allowedOperationKinds: [BrokerOperationKind],
        allowedProjectionRoots: [RepositoryPath],
        allowedClients: [FactoryClient],
        allowedRoleIDs: [String],
        allowedGateIDs: [String],
        allowedDoctorIDs: [String],
    ) {
        self.activationPublicKeySHA256 = activationPublicKeySHA256
        self.trustedBase = trustedBase
        self.repository = repository
        self.branchPrefix = branchPrefix
        self.brokerIdentitySHA256 = brokerIdentitySHA256
        self.maximumPullRequestNumber = maximumPullRequestNumber
        self.maximumRequestLifetimeSeconds = maximumRequestLifetimeSeconds
        self.maximumReplayEntries = maximumReplayEntries
        self.allowedOperationKinds = allowedOperationKinds
        self.allowedProjectionRoots = allowedProjectionRoots
        self.allowedClients = allowedClients
        self.allowedRoleIDs = allowedRoleIDs
        self.allowedGateIDs = allowedGateIDs
        self.allowedDoctorIDs = allowedDoctorIDs
    }

    /// Canonical installed-policy identity copied into every broker CAS precondition.
    public var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }
}

/// Stable decision returned by the broker without echoing request content.
public enum BrokerResponseDecision: String, Codable, Sendable {
    case accepted
    case rejected
}

/// Canonical broker response bound to the next durable audit position.
public struct BrokerResponse: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: String
    public let decision: BrokerResponseDecision
    public let reasonCode: String
    @RequiredNullable public var receiptSHA256: SHA256Digest?
    public let auditSequence: Int
    public let auditSHA256: SHA256Digest

    public init(
        schemaVersion: Int = FactoryCore.schemaVersion,
        requestID: String,
        decision: BrokerResponseDecision,
        reasonCode: String,
        receiptSHA256: SHA256Digest?,
        auditSequence: Int,
        auditSHA256: SHA256Digest,
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.decision = decision
        self.reasonCode = reasonCode
        self.receiptSHA256 = receiptSHA256
        self.auditSequence = auditSequence
        self.auditSHA256 = auditSHA256
    }
}

/// In-memory nonce ledger used by a broker transaction boundary to reject replay.
public final class BrokerReplayLedger {
    private var consumed: Set<SHA256Digest> = []

    public init() {}

    public var consumedCount: Int {
        consumed.count
    }

    fileprivate func consume(_ nonce: String) throws {
        guard consumed.insert(SHA256Digest.hashing(Data(nonce.utf8))).inserted else {
            throw FactoryValidationError(code: "broker_replay", message: "The broker nonce was already consumed.")
        }
    }
}

/// Semantic validator applied before a trusted transport sees any request.
public enum BrokerRequestValidator {
    /// Validates every request invariant that is independent of installed policy and live CAS state.
    static func validateStructure(_ request: BrokerRequest) throws {
        let identifier = /^[a-z0-9][a-z0-9._:-]{0,127}$/
        let nonceLength = request.nonce.unicodeScalars.count
        guard request.schemaVersion == FactoryCore.schemaVersion,
              request.requestID.wholeMatch(of: identifier) != nil,
              nonceLength >= 32,
              nonceLength <= 256,
              request.runID.wholeMatch(of: identifier) != nil,
              request.precondition.leaseGeneration >= 0,
              request.precondition.priorAuditSequence >= 0,
              request.precondition.leaseID.wholeMatch(of: identifier) != nil,
              validRequestInterval(issuedAt: request.issuedAt, expiresAt: request.expiresAt)
        else {
            throw FactoryValidationError(code: "invalid_broker_request", message: "Broker request metadata is invalid.")
        }
        try validateOperationStructure(request.operation)
    }

    public static func validate(
        _ request: BrokerRequest,
        policy: BrokerPolicy,
        state: BrokerState,
        replayLedger: BrokerReplayLedger,
        now: String,
    ) throws {
        try validateSemantics(
            request,
            policy: policy,
            state: state,
            authority: .buildCandidateFixtureOnly,
            now: now,
        )
        try replayLedger.consume(request.nonce)
    }

    static func validateActivatedFixture(
        _ request: BrokerRequest,
        policy: BrokerPolicy,
        state: BrokerState,
        replayLedger: BrokerReplayLedger,
        now: String,
    ) throws {
        try validateSemantics(request, policy: policy, state: state, authority: .activated, now: now)
        try replayLedger.consume(request.nonce)
    }

    static func validateSemantics(
        _ request: BrokerRequest,
        policy: BrokerPolicy,
        state: BrokerState,
        authority: BrokerAuthorityMode,
        now: String,
    ) throws {
        try validateStructure(request)
        try validatePolicy(policy)
        guard request.trustedBaseSHA == policy.trustedBase,
              request.runID == state.runID,
              policy.digest == state.policyDigest,
              policy.allowedOperationKinds.contains(request.operation.kind)
        else {
            throw FactoryValidationError(
                code: "wrong_trust_root",
                message: "The request targets a different trusted base.",
            )
        }
        if authority == .buildCandidateFixtureOnly, request.operation.kind != .doctor {
            throw FactoryValidationError(
                code: "build_candidate_fixture_only",
                message: "Unmerged build candidate state cannot authorize mutating broker operations.",
            )
        }
        try validateTime(request, policy: policy, now: now)
        guard request.precondition.matches(state) else {
            throw FactoryValidationError(code: "stale_broker_cas", message: "Authoritative broker state changed.")
        }
        try validate(request.operation, policy: policy, state: state)
    }

    static func validatePolicy(_ policy: BrokerPolicy) throws {
        let identifier = /^[a-z0-9][a-z0-9._:-]{0,127}$/
        let repository = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/
        guard policy.branchPrefix == "agent/",
              policy.repository.wholeMatch(of: repository) != nil,
              policy.maximumRequestLifetimeSeconds > 0,
              policy.maximumPullRequestNumber > 0,
              policy.maximumReplayEntries > 0,
              !policy.allowedOperationKinds.isEmpty,
              policy.allowedOperationKinds == Array(Set(policy.allowedOperationKinds))
              .sorted(by: { $0.rawValue < $1.rawValue }),
              !policy.allowedProjectionRoots.isEmpty,
              policy.allowedProjectionRoots == policy.allowedProjectionRoots.sorted(),
              Set(policy.allowedProjectionRoots.map(\.collisionKey)).count == policy.allowedProjectionRoots.count,
              !policy.allowedClients.isEmpty,
              policy.allowedClients == Array(Set(policy.allowedClients)).sorted(by: { $0.rawValue < $1.rawValue }),
              !policy.allowedRoleIDs.isEmpty,
              policy.allowedRoleIDs == Array(Set(policy.allowedRoleIDs)).sorted(),
              policy.allowedRoleIDs.allSatisfy({ $0.wholeMatch(of: identifier) != nil }),
              policy.allowedGateIDs == Array(Set(policy.allowedGateIDs)).sorted(),
              policy.allowedGateIDs.allSatisfy({ $0.wholeMatch(of: identifier) != nil }),
              policy.allowedDoctorIDs == Array(Set(policy.allowedDoctorIDs)).sorted(),
              policy.allowedDoctorIDs.allSatisfy({ $0.wholeMatch(of: identifier) != nil })
        else {
            throw FactoryValidationError(
                code: "invalid_broker_policy",
                message: "Broker policy must be bounded, canonical, and scoped to agent branches.",
            )
        }
    }

    private static func validateTime(_ request: BrokerRequest, policy: BrokerPolicy, now: String) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let issuedAt = formatter.date(from: request.issuedAt),
              let expiresAt = formatter.date(from: request.expiresAt),
              let current = formatter.date(from: now),
              formatter.string(from: issuedAt) == request.issuedAt,
              formatter.string(from: expiresAt) == request.expiresAt,
              formatter.string(from: current) == now,
              issuedAt <= current,
              current < expiresAt,
              expiresAt.timeIntervalSince(issuedAt) <= Double(policy.maximumRequestLifetimeSeconds)
        else {
            throw FactoryValidationError(
                code: "expired_broker_request",
                message: "Broker request timestamps are invalid, stale, or over budget.",
            )
        }
    }

    private static func validRequestInterval(issuedAt: String, expiresAt: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let issued = formatter.date(from: issuedAt),
              let expires = formatter.date(from: expiresAt),
              formatter.string(from: issued) == issuedAt,
              formatter.string(from: expires) == expiresAt
        else {
            return false
        }
        return issued < expires
    }

    private static func validateOperationStructure(_ operation: BrokerOperation) throws {
        let identifier = /^[a-z0-9][a-z0-9._:-]{0,127}$/
        let repository = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/
        switch operation {
        case let .claimWorktree(branch, issueNumber, worktreeSlug):
            try validateBranch(branch, prefix: "agent/")
            guard issueNumber > 0,
                  worktreeSlug.wholeMatch(of: identifier) != nil
            else {
                throw FactoryValidationError(
                    code: "wrong_worktree_claim",
                    message: "The worktree claim targets an invalid issue or slug.",
                )
            }
        case let .prepareProjection(allowedPaths, invocationID):
            guard !allowedPaths.isEmpty,
                  allowedPaths.count <= 10000,
                  allowedPaths == allowedPaths.sorted(),
                  Set(allowedPaths.map(\.collisionKey)).count == allowedPaths.count,
                  invocationID.wholeMatch(of: identifier) != nil
            else {
                throw FactoryValidationError(
                    code: "invalid_projection_request",
                    message: "Projection paths and invocation identity must be canonical.",
                )
            }
        case let .launchRunner(_, invocationID, roleID):
            guard invocationID.wholeMatch(of: identifier) != nil,
                  roleID.wholeMatch(of: identifier) != nil
            else {
                throw FactoryValidationError(
                    code: "invalid_runner_request",
                    message: "Runner invocation and role IDs must be canonical.",
                )
            }
        case .importPatch, .commitCheckpoint, .dispatchEvaluation:
            break
        case let .runGate(gateID):
            guard gateID.wholeMatch(of: identifier) != nil else {
                throw FactoryValidationError(code: "unknown_gate_id", message: "Gate IDs must be canonical.")
            }
        case let .pushAgentBranch(branch):
            try validateBranch(branch, prefix: "agent/")
        case let .githubTransaction(transaction):
            guard transaction.issueNumber > 0,
                  transaction.prNumber.map({ $0 > 0 }) ?? true
            else {
                throw FactoryValidationError(
                    code: "wrong_issue",
                    message: "GitHub transaction issue and PR numbers must be positive.",
                )
            }
        case let .generateEvalScaffold(repositoryName, _):
            guard repositoryName.wholeMatch(of: repository) != nil else {
                throw FactoryValidationError(
                    code: "wrong_repository",
                    message: "Evaluation scaffold repositories must use an owner/name identity.",
                )
            }
        case let .doctor(doctorID):
            guard doctorID.wholeMatch(of: identifier) != nil else {
                throw FactoryValidationError(code: "unknown_doctor_id", message: "Doctor IDs must be canonical.")
            }
        }
    }

    private static func validate(
        _ operation: BrokerOperation,
        policy: BrokerPolicy,
        state: BrokerState,
    ) throws {
        let identifier = /^[a-z0-9][a-z0-9._:-]{0,127}$/
        switch operation {
        case let .claimWorktree(branch, issueNumber, worktreeSlug):
            try validateBranch(branch, prefix: policy.branchPrefix)
            guard issueNumber == state.issueNumber,
                  worktreeSlug.wholeMatch(of: identifier) != nil
            else {
                throw FactoryValidationError(
                    code: "wrong_worktree_claim",
                    message: "The worktree claim targets another issue or invalid slug.",
                )
            }
        case let .prepareProjection(allowedPaths, invocationID):
            guard !allowedPaths.isEmpty,
                  allowedPaths == allowedPaths.sorted(),
                  Set(allowedPaths.map(\.collisionKey)).count == allowedPaths.count,
                  allowedPaths.allSatisfy({ path in
                      policy.allowedProjectionRoots.contains(where: { path.isWithin($0) })
                  }),
                  invocationID.wholeMatch(of: identifier) != nil
            else {
                throw FactoryValidationError(
                    code: "invalid_projection_request",
                    message: "Projection paths and invocation identity must be canonical.",
                )
            }
        case let .launchRunner(clientID, invocationID, roleID):
            guard invocationID.wholeMatch(of: identifier) != nil,
                  roleID.wholeMatch(of: identifier) != nil,
                  policy.allowedClients.contains(clientID),
                  policy.allowedRoleIDs.contains(roleID)
            else {
                throw FactoryValidationError(
                    code: "invalid_runner_request",
                    message: "Runner invocation and role IDs must be canonical.",
                )
            }
        case .importPatch, .commitCheckpoint, .dispatchEvaluation:
            break
        case let .runGate(gateID):
            guard policy.allowedGateIDs.contains(gateID) else {
                throw FactoryValidationError(
                    code: "unknown_gate_id",
                    message: "The broker runs only trusted-policy gate IDs.",
                )
            }
        case let .pushAgentBranch(branch):
            try validateBranch(branch, prefix: policy.branchPrefix)
        case let .githubTransaction(transaction):
            guard transaction.issueNumber == state.issueNumber else {
                throw FactoryValidationError(
                    code: "wrong_issue",
                    message: "The GitHub transaction targets another issue.",
                )
            }
            if let prNumber = transaction.prNumber {
                try validatePullRequest(prNumber, policy: policy, state: state)
            } else if ![BrokerGitHubTransactionKind.createIssue, .createPR].contains(transaction.transaction) {
                throw FactoryValidationError(
                    code: "missing_pull_request",
                    message: "This GitHub transaction requires the bound PR number.",
                )
            }
        case let .generateEvalScaffold(repository, _):
            guard repository == policy.repository else {
                throw FactoryValidationError(
                    code: "wrong_repository",
                    message: "The broker cannot scaffold an unrelated repository.",
                )
            }
        case let .doctor(doctorID):
            guard policy.allowedDoctorIDs.contains(doctorID) else {
                throw FactoryValidationError(
                    code: "unknown_doctor_id",
                    message: "The broker runs only trusted-policy doctors.",
                )
            }
        }
    }

    private static func validateBranch(_ branch: String, prefix: String) throws {
        let safe = /^agent\/[a-z0-9][a-z0-9._\/-]{0,249}$/
        guard prefix == "agent/",
              branch.hasPrefix(prefix),
              branch != "main",
              !branch.contains(".."),
              !branch.contains("//"),
              !branch.hasSuffix("/"),
              branch.wholeMatch(of: safe) != nil
        else {
            throw FactoryValidationError(
                code: "forbidden_branch",
                message: "The broker may push only an agent task branch.",
            )
        }
    }

    private static func validatePullRequest(
        _ number: Int,
        policy: BrokerPolicy,
        state: BrokerState,
    ) throws {
        guard number > 0,
              number <= policy.maximumPullRequestNumber,
              number == state.pullRequestNumber
        else {
            throw FactoryValidationError(code: "wrong_pull_request", message: "The broker request targets another PR.")
        }
    }
}
