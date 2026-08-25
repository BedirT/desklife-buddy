import CryptoKit
import Foundation

/// Stable broker decision recorded without source bytes, prose, or credentials.
public enum BrokerAuditDecision: String, Codable, Sendable {
    case accepted
    case rejected
}

/// Signed, hash-chained broker transaction fact with the exact public schema shape.
public struct BrokerAuditEntry: Codable, Equatable, Sendable {
    public let brokerIdentitySHA256: SHA256Digest
    public let decision: BrokerAuditDecision
    public let entrySHA256: SHA256Digest
    public let nextStateSHA256: SHA256Digest
    public let nonceSHA256: SHA256Digest
    public let operation: BrokerOperationKind
    public let previousEntrySHA256: SHA256Digest
    public var reasonCode: String
    public let requestID: String
    public let requestSHA256: SHA256Digest
    @RequiredNullable public var resultSHA256: SHA256Digest?
    public let runID: String
    public let schemaVersion: Int
    public let sequence: Int
    @RequiredNullable public var signature: Data?
    public let timestamp: String
    public let trustedBaseSHA: GitObjectID

    public init(
        brokerIdentitySHA256: SHA256Digest,
        decision: BrokerAuditDecision,
        entrySHA256: SHA256Digest,
        nextStateSHA256: SHA256Digest,
        nonceSHA256: SHA256Digest,
        operation: BrokerOperationKind,
        previousEntrySHA256: SHA256Digest,
        reasonCode: String,
        requestID: String,
        requestSHA256: SHA256Digest,
        resultSHA256: SHA256Digest?,
        runID: String,
        schemaVersion: Int = FactoryCore.schemaVersion,
        sequence: Int,
        signature: Data?,
        timestamp: String,
        trustedBaseSHA: GitObjectID,
    ) {
        self.brokerIdentitySHA256 = brokerIdentitySHA256
        self.decision = decision
        self.entrySHA256 = entrySHA256
        self.nextStateSHA256 = nextStateSHA256
        self.nonceSHA256 = nonceSHA256
        self.operation = operation
        self.previousEntrySHA256 = previousEntrySHA256
        self.reasonCode = reasonCode
        self.requestID = requestID
        self.requestSHA256 = requestSHA256
        self.resultSHA256 = resultSHA256
        self.runID = runID
        self.schemaVersion = schemaVersion
        self.sequence = sequence
        self.signature = signature
        self.timestamp = timestamp
        self.trustedBaseSHA = trustedBaseSHA
    }
}

/// One audit signature and the exact post-transition state covered by it.
package struct BrokerSignedAuditTransition: Sendable {
    package let entry: BrokerAuditEntry
    package let nextState: BrokerState

    package init(entry: BrokerAuditEntry, nextState: BrokerState) {
        self.entry = entry
        self.nextState = nextState
    }
}

/// Constructs and verifies the broker's aggregate-only append chain.
public enum BrokerAuditChain {
    /// Creates the only valid next entry from request-bound CAS facts.
    package static func sign(
        timestamp: String,
        brokerIdentitySHA256: SHA256Digest,
        request: BrokerRequest,
        decision: BrokerAuditDecision,
        reasonCode: String,
        resultSHA256: SHA256Digest?,
        nextState: (_ sequence: Int, _ entrySHA256: SHA256Digest) throws -> BrokerState,
        privateKey: Curve25519.Signing.PrivateKey,
    ) throws -> BrokerSignedAuditTransition {
        let transition = try makeTransitionIdentity(
            timestamp: timestamp,
            brokerIdentitySHA256: brokerIdentitySHA256,
            request: request,
            decision: decision,
            reasonCode: reasonCode,
            resultSHA256: resultSHA256,
        )
        let entrySHA256 = CanonicalJSON.digest(transition)
        let state = try nextState(transition.sequence, entrySHA256)
        guard state.runID == transition.runID,
              state.priorAuditSequence == transition.sequence,
              state.priorAuditDigest == entrySHA256
        else {
            throw FactoryValidationError(
                code: "invalid_audit_next_state",
                message: "The signed audit successor must be the exact next broker state.",
            )
        }
        let binding = AuditBinding(
            entrySHA256: entrySHA256,
            nextStateSHA256: CanonicalJSON.digest(state),
            transition: transition,
        )
        let bytes = try CanonicalJSON.encode(binding)
        let signature = try privateKey.signature(for: bytes)
        let entry = BrokerAuditEntry(
            brokerIdentitySHA256: transition.brokerIdentitySHA256,
            decision: transition.decision,
            entrySHA256: entrySHA256,
            nextStateSHA256: binding.nextStateSHA256,
            nonceSHA256: transition.nonceSHA256,
            operation: transition.operation,
            previousEntrySHA256: transition.previousEntrySHA256,
            reasonCode: transition.reasonCode,
            requestID: transition.requestID,
            requestSHA256: transition.requestSHA256,
            resultSHA256: transition.resultSHA256,
            runID: transition.runID,
            schemaVersion: transition.schemaVersion,
            sequence: transition.sequence,
            signature: signature,
            timestamp: transition.timestamp,
            trustedBaseSHA: transition.trustedBaseSHA,
        )
        return BrokerSignedAuditTransition(entry: entry, nextState: state)
    }

    /// Verifies order, continuity, terminal identity, content digests, and every signature.
    public static func verify(
        _ entries: [BrokerAuditEntry],
        expectedCount: Int,
        expectedHeadSHA256: SHA256Digest,
        publicKey: Curve25519.Signing.PublicKey,
    ) throws -> Bool {
        guard entries.count == expectedCount,
              entries.last?.entrySHA256 == expectedHeadSHA256,
              let first = entries.first
        else {
            return false
        }
        var previous = SHA256Digest.hashing(Data())
        for (index, entry) in entries.enumerated() {
            guard entry.schemaVersion == FactoryCore.schemaVersion,
                  entry.sequence == index + 1,
                  entry.previousEntrySHA256 == previous,
                  entry.runID == first.runID,
                  entry.trustedBaseSHA == first.trustedBaseSHA,
                  entry.brokerIdentitySHA256 == first.brokerIdentitySHA256,
                  let signature = entry.signature
            else {
                return false
            }
            let transition = TransitionIdentity(
                brokerIdentitySHA256: entry.brokerIdentitySHA256,
                decision: entry.decision,
                nonceSHA256: entry.nonceSHA256,
                operation: entry.operation,
                previousEntrySHA256: entry.previousEntrySHA256,
                reasonCode: entry.reasonCode,
                requestID: entry.requestID,
                requestSHA256: entry.requestSHA256,
                resultSHA256: entry.resultSHA256,
                runID: entry.runID,
                schemaVersion: entry.schemaVersion,
                sequence: entry.sequence,
                timestamp: entry.timestamp,
                trustedBaseSHA: entry.trustedBaseSHA,
            )
            guard isValid(transition),
                  entry.entrySHA256 == CanonicalJSON.digest(transition)
            else { return false }
            let binding = AuditBinding(
                entrySHA256: entry.entrySHA256,
                nextStateSHA256: entry.nextStateSHA256,
                transition: transition,
            )
            let bytes = try CanonicalJSON.encode(binding)
            guard publicKey.isValidSignature(signature, for: bytes)
            else {
                return false
            }
            previous = entry.entrySHA256
        }
        return true
    }

    /// Verifies that one entry is exactly the signed successor bound by its request.
    public static func verify(
        _ entry: BrokerAuditEntry,
        request: BrokerRequest,
        publicKey: Curve25519.Signing.PublicKey,
    ) throws -> Bool {
        let (expectedSequence, overflow) = request.precondition.priorAuditSequence.addingReportingOverflow(1)
        guard !overflow else { return false }
        guard entry.schemaVersion == FactoryCore.schemaVersion,
              entry.sequence == expectedSequence,
              entry.previousEntrySHA256 == request.precondition.priorAuditSHA256,
              entry.trustedBaseSHA == request.trustedBaseSHA,
              entry.runID == request.runID,
              entry.requestID == request.requestID,
              entry.nonceSHA256 == SHA256Digest.hashing(Data(request.nonce.utf8)),
              try entry.requestSHA256 == SHA256Digest.hashing(CanonicalJSON.encode(request)),
              entry.operation == request.operation.kind,
              let signature = entry.signature
        else {
            return false
        }
        let transition = TransitionIdentity(
            brokerIdentitySHA256: entry.brokerIdentitySHA256,
            decision: entry.decision,
            nonceSHA256: entry.nonceSHA256,
            operation: entry.operation,
            previousEntrySHA256: entry.previousEntrySHA256,
            reasonCode: entry.reasonCode,
            requestID: entry.requestID,
            requestSHA256: entry.requestSHA256,
            resultSHA256: entry.resultSHA256,
            runID: entry.runID,
            schemaVersion: entry.schemaVersion,
            sequence: entry.sequence,
            timestamp: entry.timestamp,
            trustedBaseSHA: entry.trustedBaseSHA,
        )
        guard isValid(transition),
              entry.entrySHA256 == CanonicalJSON.digest(transition)
        else { return false }
        let binding = AuditBinding(
            entrySHA256: entry.entrySHA256,
            nextStateSHA256: entry.nextStateSHA256,
            transition: transition,
        )
        let bytes = try CanonicalJSON.encode(binding)
        return publicKey.isValidSignature(signature, for: bytes)
    }

    private static func makeTransitionIdentity(
        timestamp: String,
        brokerIdentitySHA256: SHA256Digest,
        request: BrokerRequest,
        decision: BrokerAuditDecision,
        reasonCode: String,
        resultSHA256: SHA256Digest?,
    ) throws -> TransitionIdentity {
        let (sequence, overflow) = request.precondition.priorAuditSequence.addingReportingOverflow(1)
        guard !overflow else {
            throw FactoryValidationError(code: "audit_sequence_overflow", message: "Audit sequence is exhausted.")
        }
        let transition = try TransitionIdentity(
            brokerIdentitySHA256: brokerIdentitySHA256,
            decision: decision,
            nonceSHA256: SHA256Digest.hashing(Data(request.nonce.utf8)),
            operation: request.operation.kind,
            previousEntrySHA256: request.precondition.priorAuditSHA256,
            reasonCode: reasonCode,
            requestID: request.requestID,
            requestSHA256: SHA256Digest.hashing(CanonicalJSON.encode(request)),
            resultSHA256: resultSHA256,
            runID: request.runID,
            schemaVersion: FactoryCore.schemaVersion,
            sequence: sequence,
            timestamp: timestamp,
            trustedBaseSHA: request.trustedBaseSHA,
        )
        guard isValid(transition) else {
            throw FactoryValidationError(
                code: "invalid_audit_binding",
                message: "Audit sequence, time, or stable codes are invalid.",
            )
        }
        return transition
    }

    private static func isValid(_ binding: TransitionIdentity) -> Bool {
        let identifier = /^[a-z0-9][a-z0-9._:-]{0,127}$/
        let timestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
        return binding.schemaVersion == FactoryCore.schemaVersion
            && binding.sequence > 0
            && binding.timestamp.wholeMatch(of: timestamp) != nil
            && binding.requestID.wholeMatch(of: identifier) != nil
            && binding.runID.wholeMatch(of: identifier) != nil
            && binding.reasonCode.wholeMatch(of: identifier) != nil
    }

    private struct TransitionIdentity: Codable {
        let brokerIdentitySHA256: SHA256Digest
        let decision: BrokerAuditDecision
        let nonceSHA256: SHA256Digest
        let operation: BrokerOperationKind
        let previousEntrySHA256: SHA256Digest
        let reasonCode: String
        let requestID: String
        let requestSHA256: SHA256Digest
        @RequiredNullable var resultSHA256: SHA256Digest?
        let runID: String
        let schemaVersion: Int
        let sequence: Int
        let timestamp: String
        let trustedBaseSHA: GitObjectID
    }

    private struct AuditBinding: Codable {
        let entrySHA256: SHA256Digest
        let nextStateSHA256: SHA256Digest
        let transition: TransitionIdentity
    }
}
