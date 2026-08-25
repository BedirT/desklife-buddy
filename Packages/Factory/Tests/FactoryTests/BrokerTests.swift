import Foundation
import Testing
@testable import FactoryCore

@Suite("Narrow broker CAS API")
struct BrokerTests {
    @Test("A bound request is accepted once")
    func acceptedOnce() throws {
        let state = brokerState()
        let ledger = BrokerReplayLedger()
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

        try BrokerRequestValidator.validate(
            request,
            policy: brokerPolicy(),
            state: state,
            replayLedger: ledger,
            now: "2026-07-11T00:00:30Z",
        )
        #expect(ledger.consumedCount == 1)
        #expect(throws: FactoryValidationError.self) {
            try BrokerRequestValidator.validate(
                request,
                policy: brokerPolicy(),
                state: state,
                replayLedger: ledger,
                now: "2026-07-11T00:00:30Z",
            )
        }
    }

    @Test("Stale CAS, wrong trust root, and main pushes fail closed")
    func policyDenials() throws {
        let state = brokerState()
        var stale = BrokerPrecondition(expected: state)
        stale.leaseGeneration += 1

        let requests = [
            BrokerRequest(
                requestID: "stale",
                nonce: "nonce-stale-0123456789abcdef0123",
                issuedAt: "2026-07-11T00:00:00Z",
                expiresAt: "2026-07-11T00:01:00Z",
                trustedBaseSHA: TestValues.head,
                runID: state.runID,
                operation: .pushAgentBranch(branch: "agent/42-factory-kernel"),
                precondition: stale,
            ),
            BrokerRequest(
                requestID: "wrong-base",
                nonce: "nonce-base-0123456789abcdef01234",
                issuedAt: "2026-07-11T00:00:00Z",
                expiresAt: "2026-07-11T00:01:00Z",
                trustedBaseSHA: TestValues.nextHead,
                runID: state.runID,
                operation: .pushAgentBranch(branch: "agent/42-factory-kernel"),
                precondition: BrokerPrecondition(expected: state),
            ),
            BrokerRequest(
                requestID: "main",
                nonce: "nonce-main-0123456789abcdef01234",
                issuedAt: "2026-07-11T00:00:00Z",
                expiresAt: "2026-07-11T00:01:00Z",
                trustedBaseSHA: TestValues.head,
                runID: state.runID,
                operation: .pushAgentBranch(branch: "main"),
                precondition: BrokerPrecondition(expected: state),
            ),
        ]

        for request in requests {
            #expect(throws: FactoryValidationError.self) {
                try BrokerRequestValidator.validateActivatedFixture(
                    request,
                    policy: brokerPolicy(),
                    state: state,
                    replayLedger: BrokerReplayLedger(),
                    now: "2026-07-11T00:00:30Z",
                )
            }
        }
    }

    @Test("Unknown or privileged operations are not representable")
    func unknownOperations() {
        for kind in ["merge_pull_request", "administer_repository", "bypass_protection", "arbitrary_github"] {
            let json = Data("{\"kind\":\"\(kind)\"}".utf8)
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(BrokerOperation.self, from: json)
            }
        }
    }

    @Test("Runtime metadata is at least as strict as the public broker schema")
    func schemaBoundMetadata() throws {
        let state = brokerState()
        let requests = [
            BrokerRequest(
                requestID: "request-short-nonce",
                nonce: "short-nonce-1234",
                issuedAt: "2026-07-11T00:00:00Z",
                expiresAt: "2026-07-11T00:01:00Z",
                trustedBaseSHA: TestValues.head,
                runID: state.runID,
                operation: .pushAgentBranch(branch: "agent/42-factory-kernel"),
                precondition: BrokerPrecondition(expected: state),
            ),
            BrokerRequest(
                requestID: "Request-uppercase",
                nonce: "nonce-0123456789abcdef0123456789",
                issuedAt: "2026-07-11T00:00:00Z",
                expiresAt: "2026-07-11T00:01:00Z",
                trustedBaseSHA: TestValues.head,
                runID: state.runID,
                operation: .pushAgentBranch(branch: "agent/42-factory-kernel"),
                precondition: BrokerPrecondition(expected: state),
            ),
        ]
        for request in requests {
            #expect(throws: FactoryValidationError.self) {
                try BrokerRequestValidator.validate(
                    request,
                    policy: brokerPolicy(),
                    state: state,
                    replayLedger: BrokerReplayLedger(),
                    now: "2026-07-11T00:00:30Z",
                )
            }
        }
    }

    @Test("Policy IDs use StableId grammar and branches stay in the exact lowercase agent namespace")
    func strictPolicyIDsAndBranches() throws {
        let validPolicy = brokerPolicy(
            allowedRoleIDs: ["builder:primary"],
            allowedGateIDs: ["test:domain"],
            allowedDoctorIDs: ["isolation:strict"],
        )
        let validState = brokerState(policy: validPolicy)
        let validRequest = BrokerRequest(
            requestID: "stable-policy-ids",
            nonce: "nonce-stable-policy-ids-0123456789",
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T00:01:00Z",
            trustedBaseSHA: TestValues.head,
            runID: validState.runID,
            operation: .doctor(doctorID: "isolation:strict"),
            precondition: BrokerPrecondition(expected: validState),
        )
        try BrokerRequestValidator.validate(
            validRequest,
            policy: validPolicy,
            state: validState,
            replayLedger: BrokerReplayLedger(),
            now: "2026-07-11T00:00:30Z",
        )

        let invalidPolicies = [
            brokerPolicy(branchPrefix: "feature/"),
            brokerPolicy(allowedRoleIDs: ["Builder"]),
            brokerPolicy(allowedGateIDs: ["test/domain"]),
            brokerPolicy(allowedDoctorIDs: [""]),
        ]
        for policy in invalidPolicies {
            let state = brokerState(policy: policy)
            let request = BrokerRequest(
                requestID: "invalid-policy",
                nonce: "nonce-invalid-policy-0123456789012",
                issuedAt: "2026-07-11T00:00:00Z",
                expiresAt: "2026-07-11T00:01:00Z",
                trustedBaseSHA: TestValues.head,
                runID: state.runID,
                operation: .doctor(doctorID: "isolation"),
                precondition: BrokerPrecondition(expected: state),
            )
            #expect(throws: FactoryValidationError.self) {
                try BrokerRequestValidator.validate(
                    request,
                    policy: policy,
                    state: state,
                    replayLedger: BrokerReplayLedger(),
                    now: "2026-07-11T00:00:30Z",
                )
            }
        }

        let branchState = brokerState()
        for branch in ["agent/Uppercase", "agent/trailing/", "agent/a//b", "agent/a..b", "feature/task"] {
            let request = BrokerRequest(
                requestID: "invalid-branch",
                nonce: "nonce-invalid-branch-0123456789012",
                issuedAt: "2026-07-11T00:00:00Z",
                expiresAt: "2026-07-11T00:01:00Z",
                trustedBaseSHA: TestValues.head,
                runID: branchState.runID,
                operation: .pushAgentBranch(branch: branch),
                precondition: BrokerPrecondition(expected: branchState),
            )
            #expect(throws: FactoryValidationError.self) {
                try BrokerRequestValidator.validateActivatedFixture(
                    request,
                    policy: brokerPolicy(),
                    state: branchState,
                    replayLedger: BrokerReplayLedger(),
                    now: "2026-07-11T00:00:30Z",
                )
            }
        }
    }

    @Test("Broker responses preserve required nulls from the public schema")
    func responseRequiredNull() throws {
        let response = BrokerResponse(
            requestID: "request-1",
            decision: .rejected,
            reasonCode: "fixture-only",
            receiptSHA256: nil,
            auditSequence: 1,
            auditSHA256: TestValues.evidence,
        )
        let encoded = try String(decoding: CanonicalJSON.encode(response), as: UTF8.self)
        #expect(encoded.contains("\"receipt_sha256\":null"))
    }

    @Test("Requests carry digests, never credentials or publishable prose")
    func dataOnlyRequest() throws {
        let state = brokerState()
        let request = BrokerRequest(
            requestID: "request-1",
            nonce: "nonce-0123456789abcdef0123456789",
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T00:01:00Z",
            trustedBaseSHA: TestValues.head,
            runID: state.runID,
            operation: .githubTransaction(
                BrokerGitHubTransaction(
                    transaction: .updatePR,
                    bodySHA256: TestValues.context,
                    issueNumber: 42,
                    prNumber: 2,
                ),
            ),
            precondition: BrokerPrecondition(expected: state),
        )
        let json = try String(decoding: CanonicalJSON.encode(request), as: UTF8.self).lowercased()

        #expect(json.contains("\"trusted_base_sha\""))
        #expect(json.contains("\"contract_sha256\""))
        #expect(json.contains("\"prior_audit_sha256\""))
        #expect(!json.contains("credential"))
        #expect(!json.contains("api_key"))
        #expect(!json.contains("token"))
        #expect(!json.contains("body_text"))
    }

    private func brokerState(policy: BrokerPolicy? = nil) -> BrokerState {
        let policy = policy ?? brokerPolicy()
        return BrokerState(
            runID: "run-1",
            issueNumber: 42,
            pullRequestNumber: 2,
            contractDigest: TestValues.contract,
            head: TestValues.head,
            tree: TestValues.head,
            generation: 7,
            leaseID: "lease-0123456789abcdef",
            policyDigest: policy.digest,
            priorAuditSequence: 9,
            priorAuditDigest: TestValues.evidence,
        )
    }

    private func brokerPolicy(
        branchPrefix: String = "agent/",
        allowedRoleIDs: [String] = ["builder"],
        allowedGateIDs: [String] = ["test-domain"],
        allowedDoctorIDs: [String] = ["isolation"],
    ) -> BrokerPolicy {
        BrokerPolicy(
            activationPublicKeySHA256: TestValues.activationPublicKeySHA256,
            trustedBase: TestValues.head,
            repository: "BedirT/swiftmac-base",
            branchPrefix: branchPrefix,
            brokerIdentitySHA256: TestValues.brokerIdentity,
            maximumPullRequestNumber: 1_000_000_000,
            maximumRequestLifetimeSeconds: 300,
            maximumReplayEntries: 10000,
            allowedOperationKinds: [.doctor, .pushAgentBranch],
            allowedProjectionRoots: [TestValues.packages],
            allowedClients: [.codex],
            allowedRoleIDs: allowedRoleIDs,
            allowedGateIDs: allowedGateIDs,
            allowedDoctorIDs: allowedDoctorIDs,
        )
    }
}
