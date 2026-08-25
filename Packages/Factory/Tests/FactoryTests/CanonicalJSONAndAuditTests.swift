import enum CryptoKit.Curve25519
import Foundation
import Testing
@testable import FactoryCore

@Suite("Canonical broker transport and audit chain")
struct CanonicalJSONAndAuditTests {
    @Test("Canonical decoding rejects unknown, duplicate, reordered, and trailing bytes")
    func strictCanonicalDecode() throws {
        let request = brokerRequest()
        let canonical = try CanonicalJSON.encode(request)
        #expect(try CanonicalJSON.decode(BrokerRequest.self, from: canonical) == request)

        let text = String(decoding: canonical, as: UTF8.self)
        #expect(text.contains("\"schema_version\""))
        #expect(text.contains("\"trusted_base_sha\""))
        #expect(text.contains("\"expected_head_sha\""))
        #expect(!text.contains("schemaVersion"))
        let unknown = Data(text.replacingOccurrences(
            of: "{",
            with: "{\"unknown\":true,",
            options: [],
            range: text.startIndex ..< text.index(after: text.startIndex),
        ).utf8)
        let duplicate = Data(text.replacingOccurrences(
            of: "{",
            with: "{\"schema_version\":1,",
            options: [],
            range: text.startIndex ..< text.index(after: text.startIndex),
        ).utf8)
        let whitespace = Data((" " + text).utf8)
        let trailing = Data((text + "\n").utf8)

        for invalid in [unknown, duplicate, whitespace, trailing] {
            #expect(throws: FactoryValidationError.self) {
                try CanonicalJSON.decode(BrokerRequest.self, from: invalid)
            }
        }
    }

    @Test("Signed audit entries are ordered, hash chained, and content free")
    func auditChain() throws {
        let key = Curve25519.Signing.PrivateKey()
        let request = brokerRequest()
        let firstTransition = try BrokerAuditChain.sign(
            timestamp: "2026-07-11T00:00:00Z",
            brokerIdentitySHA256: SHA256Digest.hashing(Data("broker".utf8)),
            request: request,
            decision: .accepted,
            reasonCode: "policy_valid",
            resultSHA256: nil,
            nextState: { sequence, digest in
                nextState(for: request, sequence: sequence, auditSHA256: digest)
            },
            privateKey: key,
        )
        let first = firstTransition.entry
        let secondRequest = brokerRequest(
            requestID: "request-2",
            nonce: "nonce-1123456789abcdef0123456789",
            priorAuditSequence: 1,
            priorAuditSHA256: first.entrySHA256,
        )
        let secondTransition = try BrokerAuditChain.sign(
            timestamp: "2026-07-11T00:00:01Z",
            brokerIdentitySHA256: SHA256Digest.hashing(Data("broker".utf8)),
            request: secondRequest,
            decision: .accepted,
            reasonCode: "push_succeeded",
            resultSHA256: TestValues.evidence,
            nextState: { sequence, digest in
                nextState(for: secondRequest, sequence: sequence, auditSHA256: digest)
            },
            privateKey: key,
        )
        let second = secondTransition.entry

        #expect(try BrokerAuditChain.verify(
            [first, second],
            expectedCount: 2,
            expectedHeadSHA256: second.entrySHA256,
            publicKey: key.publicKey,
        ))
        #expect(try !BrokerAuditChain.verify(
            [second, first],
            expectedCount: 2,
            expectedHeadSHA256: second.entrySHA256,
            publicKey: key.publicKey,
        ))
        #expect(try !BrokerAuditChain.verify(
            [first],
            expectedCount: 2,
            expectedHeadSHA256: second.entrySHA256,
            publicKey: key.publicKey,
        ))

        var tampered = second
        tampered.reasonCode = "bypass"
        #expect(try !BrokerAuditChain.verify(
            [first, tampered],
            expectedCount: 2,
            expectedHeadSHA256: second.entrySHA256,
            publicKey: key.publicKey,
        ))

        let json = try String(decoding: CanonicalJSON.encode(second), as: UTF8.self).lowercased()
        #expect(!json.contains(request.nonce.lowercased()))
        #expect(!json.contains("api_key"))
        #expect(!json.contains("credential"))
        #expect(!json.contains("body_text"))
    }

    @Test("Audit signing rejects an exhausted sequence without trapping")
    func auditSequenceOverflow() throws {
        let key = Curve25519.Signing.PrivateKey()
        let request = brokerRequest(priorAuditSequence: Int.max)

        do {
            _ = try BrokerAuditChain.sign(
                timestamp: "2026-07-11T00:00:00Z",
                brokerIdentitySHA256: TestValues.brokerIdentity,
                request: request,
                decision: .accepted,
                reasonCode: "policy-valid",
                resultSHA256: nil,
                nextState: { sequence, digest in
                    nextState(for: request, sequence: sequence, auditSHA256: digest)
                },
                privateKey: key,
            )
            Issue.record("Expected exhausted audit sequence to reject signing")
        } catch let error as FactoryValidationError {
            #expect(error.code == "audit_sequence_overflow")
        }
    }

    private func brokerRequest(
        requestID: String = "request-1",
        nonce: String = "nonce-0123456789abcdef0123456789",
        priorAuditSequence: Int = 0,
        priorAuditSHA256: SHA256Digest = TestValues.zero,
    ) -> BrokerRequest {
        let state = BrokerState(
            runID: "run-1",
            issueNumber: 42,
            pullRequestNumber: 2,
            contractDigest: TestValues.contract,
            head: TestValues.head,
            tree: TestValues.head,
            generation: 1,
            leaseID: "lease-0123456789abcdef",
            policyDigest: TestValues.context,
            priorAuditSequence: priorAuditSequence,
            priorAuditDigest: priorAuditSHA256,
        )
        return BrokerRequest(
            requestID: requestID,
            nonce: nonce,
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T00:01:00Z",
            trustedBaseSHA: TestValues.head,
            runID: state.runID,
            operation: .pushAgentBranch(branch: "agent/42-factory-kernel"),
            precondition: BrokerPrecondition(expected: state),
        )
    }

    private func nextState(
        for request: BrokerRequest,
        sequence: Int,
        auditSHA256: SHA256Digest,
    ) -> BrokerState {
        BrokerState(
            runID: request.runID,
            issueNumber: 42,
            pullRequestNumber: 2,
            contractDigest: request.precondition.contractSHA256,
            head: request.precondition.expectedHeadSHA,
            tree: request.precondition.expectedTreeSHA,
            generation: request.precondition.leaseGeneration + 1,
            leaseID: request.precondition.leaseID,
            policyDigest: request.precondition.policySHA256,
            priorAuditSequence: sequence,
            priorAuditDigest: auditSHA256,
        )
    }
}
