import CryptoKit
import Foundation

/// Signature algorithm fixed by the public evaluator contract.
public enum EvaluationSignatureAlgorithm: String, Codable, Sendable {
    case ed25519
}

/// Cryptographically bound aggregate returned without scores, counts, or raw private data.
public struct AggregateAttestation: Codable, Equatable, Sendable {
    public let budgetSHA256: SHA256Digest
    public let candidateComponentID: String
    public let candidateSHA256: SHA256Digest
    public let clientID: String
    public let decision: EvaluationDecision
    public let epoch: String
    public let epochSHA256: SHA256Digest
    public let evaluatorSHA256: SHA256Digest
    public let executionReceiptSHA256: SHA256Digest
    public let expiresAt: String
    public let failureClass: EvaluationFailureClass
    public let issuedAt: String
    public let modelID: String
    public let nonceSHA256: SHA256Digest
    public let partition: EvaluationPartition
    public let policySHA256: SHA256Digest
    public let queryLedgerSHA256: SHA256Digest
    public let queryOrdinal: Int
    public let rawOutputIncluded: Bool
    public let requestID: String
    public let requestSHA256: SHA256Digest
    public let schemaVersion: Int
    public let signature: Data
    public let signatureAlgorithm: EvaluationSignatureAlgorithm
    public let signingKeyID: String
    public let strataSHA256: SHA256Digest
    public let trustedBaseSHA: GitObjectID

    public init(
        budgetSHA256: SHA256Digest,
        candidateComponentID: String,
        candidateSHA256: SHA256Digest,
        clientID: String,
        decision: EvaluationDecision,
        epoch: String,
        epochSHA256: SHA256Digest,
        evaluatorSHA256: SHA256Digest,
        executionReceiptSHA256: SHA256Digest,
        expiresAt: String,
        failureClass: EvaluationFailureClass,
        issuedAt: String,
        modelID: String,
        nonceSHA256: SHA256Digest,
        partition: EvaluationPartition,
        policySHA256: SHA256Digest,
        queryLedgerSHA256: SHA256Digest,
        queryOrdinal: Int,
        rawOutputIncluded: Bool,
        requestID: String,
        requestSHA256: SHA256Digest,
        schemaVersion: Int = FactoryCore.schemaVersion,
        signature: Data,
        signatureAlgorithm: EvaluationSignatureAlgorithm,
        signingKeyID: String,
        strataSHA256: SHA256Digest,
        trustedBaseSHA: GitObjectID,
    ) throws {
        self.budgetSHA256 = budgetSHA256
        self.candidateComponentID = candidateComponentID
        self.candidateSHA256 = candidateSHA256
        self.clientID = clientID
        self.decision = decision
        self.epoch = epoch
        self.epochSHA256 = epochSHA256
        self.evaluatorSHA256 = evaluatorSHA256
        self.executionReceiptSHA256 = executionReceiptSHA256
        self.expiresAt = expiresAt
        self.failureClass = failureClass
        self.issuedAt = issuedAt
        self.modelID = modelID
        self.nonceSHA256 = nonceSHA256
        self.partition = partition
        self.policySHA256 = policySHA256
        self.queryLedgerSHA256 = queryLedgerSHA256
        self.queryOrdinal = queryOrdinal
        self.rawOutputIncluded = rawOutputIncluded
        self.requestID = requestID
        self.requestSHA256 = requestSHA256
        self.schemaVersion = schemaVersion
        self.signature = signature
        self.signatureAlgorithm = signatureAlgorithm
        self.signingKeyID = signingKeyID
        self.strataSHA256 = strataSHA256
        self.trustedBaseSHA = trustedBaseSHA
        try validateStructure()
    }

    public init(from decoder: Decoder) throws {
        let value = try StoredAttestation(from: decoder)
        try self.init(
            budgetSHA256: value.budgetSHA256,
            candidateComponentID: value.candidateComponentID,
            candidateSHA256: value.candidateSHA256,
            clientID: value.clientID,
            decision: value.decision,
            epoch: value.epoch,
            epochSHA256: value.epochSHA256,
            evaluatorSHA256: value.evaluatorSHA256,
            executionReceiptSHA256: value.executionReceiptSHA256,
            expiresAt: value.expiresAt,
            failureClass: value.failureClass,
            issuedAt: value.issuedAt,
            modelID: value.modelID,
            nonceSHA256: value.nonceSHA256,
            partition: value.partition,
            policySHA256: value.policySHA256,
            queryLedgerSHA256: value.queryLedgerSHA256,
            queryOrdinal: value.queryOrdinal,
            rawOutputIncluded: value.rawOutputIncluded,
            requestID: value.requestID,
            requestSHA256: value.requestSHA256,
            schemaVersion: value.schemaVersion,
            signature: value.signature,
            signatureAlgorithm: value.signatureAlgorithm,
            signingKeyID: value.signingKeyID,
            strataSHA256: value.strataSHA256,
            trustedBaseSHA: value.trustedBaseSHA,
        )
    }

    public func encode(to encoder: Encoder) throws {
        try stored.encode(to: encoder)
    }

    fileprivate var unsigned: UnsignedAttestation {
        UnsignedAttestation(
            budgetSHA256: budgetSHA256,
            candidateComponentID: candidateComponentID,
            candidateSHA256: candidateSHA256,
            clientID: clientID,
            decision: decision,
            epoch: epoch,
            epochSHA256: epochSHA256,
            evaluatorSHA256: evaluatorSHA256,
            executionReceiptSHA256: executionReceiptSHA256,
            expiresAt: expiresAt,
            failureClass: failureClass,
            issuedAt: issuedAt,
            modelID: modelID,
            nonceSHA256: nonceSHA256,
            partition: partition,
            policySHA256: policySHA256,
            queryLedgerSHA256: queryLedgerSHA256,
            queryOrdinal: queryOrdinal,
            rawOutputIncluded: rawOutputIncluded,
            requestID: requestID,
            requestSHA256: requestSHA256,
            schemaVersion: schemaVersion,
            signatureAlgorithm: signatureAlgorithm,
            signingKeyID: signingKeyID,
            strataSHA256: strataSHA256,
            trustedBaseSHA: trustedBaseSHA,
        )
    }

    private var stored: StoredAttestation {
        StoredAttestation(unsigned: unsigned, signature: signature)
    }

    private func validateStructure() throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(requestID),
              FactoryTextRules.isStableID(candidateComponentID),
              FactoryTextRules.isStableID(epoch),
              FactoryTextRules.isStableID(signingKeyID),
              FactoryTextRules.isBoundedText(clientID, maximumScalars: 128),
              FactoryTextRules.isBoundedText(modelID, maximumScalars: 256),
              queryOrdinal > 0,
              !rawOutputIncluded,
              signature.count == 64,
              validAttestationLifetime(issuedAt: issuedAt, expiresAt: expiresAt),
              (decision == .accept) == (failureClass == .none),
              !(partition == .sealed && decision == .revise)
        else {
            throw FactoryValidationError(
                code: "invalid_aggregate_attestation",
                message: "The aggregate attestation is malformed or leaks a forbidden result.",
            )
        }
    }

    private struct StoredAttestation: Codable {
        let budgetSHA256: SHA256Digest
        let candidateComponentID: String
        let candidateSHA256: SHA256Digest
        let clientID: String
        let decision: EvaluationDecision
        let epoch: String
        let epochSHA256: SHA256Digest
        let evaluatorSHA256: SHA256Digest
        let executionReceiptSHA256: SHA256Digest
        let expiresAt: String
        let failureClass: EvaluationFailureClass
        let issuedAt: String
        let modelID: String
        let nonceSHA256: SHA256Digest
        let partition: EvaluationPartition
        let policySHA256: SHA256Digest
        let queryLedgerSHA256: SHA256Digest
        let queryOrdinal: Int
        let rawOutputIncluded: Bool
        let requestID: String
        let requestSHA256: SHA256Digest
        let schemaVersion: Int
        let signature: Data
        let signatureAlgorithm: EvaluationSignatureAlgorithm
        let signingKeyID: String
        let strataSHA256: SHA256Digest
        let trustedBaseSHA: GitObjectID

        init(unsigned: UnsignedAttestation, signature: Data) {
            budgetSHA256 = unsigned.budgetSHA256
            candidateComponentID = unsigned.candidateComponentID
            candidateSHA256 = unsigned.candidateSHA256
            clientID = unsigned.clientID
            decision = unsigned.decision
            epoch = unsigned.epoch
            epochSHA256 = unsigned.epochSHA256
            evaluatorSHA256 = unsigned.evaluatorSHA256
            executionReceiptSHA256 = unsigned.executionReceiptSHA256
            expiresAt = unsigned.expiresAt
            failureClass = unsigned.failureClass
            issuedAt = unsigned.issuedAt
            modelID = unsigned.modelID
            nonceSHA256 = unsigned.nonceSHA256
            partition = unsigned.partition
            policySHA256 = unsigned.policySHA256
            queryLedgerSHA256 = unsigned.queryLedgerSHA256
            queryOrdinal = unsigned.queryOrdinal
            rawOutputIncluded = unsigned.rawOutputIncluded
            requestID = unsigned.requestID
            requestSHA256 = unsigned.requestSHA256
            schemaVersion = unsigned.schemaVersion
            self.signature = signature
            signatureAlgorithm = unsigned.signatureAlgorithm
            signingKeyID = unsigned.signingKeyID
            strataSHA256 = unsigned.strataSHA256
            trustedBaseSHA = unsigned.trustedBaseSHA
        }
    }
}

/// Curve25519 binding helper used with synthetic keys before trust activation.
enum EvaluationAttestationSigner {
    static func sign(
        request: EvaluationRequest,
        policy: EvolutionAcceptancePolicy,
        result: EvaluationResult,
        issuedAt: String,
        expiresAt: String,
        signingKeyID: String,
        privateKey: Curve25519.Signing.PrivateKey,
    ) throws -> AggregateAttestation {
        try policy.validate(request)
        let unsigned = UnsignedAttestation(
            request: request,
            result: result,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            signingKeyID: signingKeyID,
        )
        let signature = try privateKey.signature(for: CanonicalJSON.encode(unsigned))
        return try AggregateAttestation(
            budgetSHA256: unsigned.budgetSHA256,
            candidateComponentID: unsigned.candidateComponentID,
            candidateSHA256: unsigned.candidateSHA256,
            clientID: unsigned.clientID,
            decision: unsigned.decision,
            epoch: unsigned.epoch,
            epochSHA256: unsigned.epochSHA256,
            evaluatorSHA256: unsigned.evaluatorSHA256,
            executionReceiptSHA256: unsigned.executionReceiptSHA256,
            expiresAt: unsigned.expiresAt,
            failureClass: unsigned.failureClass,
            issuedAt: unsigned.issuedAt,
            modelID: unsigned.modelID,
            nonceSHA256: unsigned.nonceSHA256,
            partition: unsigned.partition,
            policySHA256: unsigned.policySHA256,
            queryLedgerSHA256: unsigned.queryLedgerSHA256,
            queryOrdinal: unsigned.queryOrdinal,
            rawOutputIncluded: unsigned.rawOutputIncluded,
            requestID: unsigned.requestID,
            requestSHA256: unsigned.requestSHA256,
            signature: signature,
            signatureAlgorithm: unsigned.signatureAlgorithm,
            signingKeyID: unsigned.signingKeyID,
            strataSHA256: unsigned.strataSHA256,
            trustedBaseSHA: unsigned.trustedBaseSHA,
        )
    }

    /// Verifies every request binding, lifetime, and signature before accepting an action.
    static func verify(
        _ attestation: AggregateAttestation,
        request: EvaluationRequest,
        policy: EvolutionAcceptancePolicy,
        expectedQueryLedgerSHA256: SHA256Digest,
        expectedSigningKeyID: String,
        now: String,
        replayLedger: EvaluationAttestationReplayLedger,
        publicKey: Curve25519.Signing.PublicKey,
    ) throws -> Bool {
        try policy.validate(request)
        let expected = try UnsignedAttestation(
            request: request,
            result: EvaluationResult(
                aggregate: EvaluationAggregate(
                    decision: attestation.decision,
                    failureClass: attestation.failureClass,
                ),
                executionReceiptSHA256: attestation.executionReceiptSHA256,
                queryLedgerSHA256: attestation.queryLedgerSHA256,
            ),
            issuedAt: attestation.issuedAt,
            expiresAt: attestation.expiresAt,
            signingKeyID: expectedSigningKeyID,
        )
        guard attestation.unsigned == expected,
              attestation.queryLedgerSHA256 == expectedQueryLedgerSHA256,
              expectedSigningKeyID == attestation.signingKeyID,
              isWithinAttestationLifetime(
                  issuedAt: attestation.issuedAt,
                  expiresAt: attestation.expiresAt,
                  now: now,
              ),
              try publicKey.isValidSignature(attestation.signature, for: CanonicalJSON.encode(expected))
        else {
            return false
        }
        try replayLedger.consume(attestation)
        return true
    }
}

private struct UnsignedAttestation: Codable, Equatable {
    let budgetSHA256: SHA256Digest
    let candidateComponentID: String
    let candidateSHA256: SHA256Digest
    let clientID: String
    let decision: EvaluationDecision
    let epoch: String
    let epochSHA256: SHA256Digest
    let evaluatorSHA256: SHA256Digest
    let executionReceiptSHA256: SHA256Digest
    let expiresAt: String
    let failureClass: EvaluationFailureClass
    let issuedAt: String
    let modelID: String
    let nonceSHA256: SHA256Digest
    let partition: EvaluationPartition
    let policySHA256: SHA256Digest
    let queryLedgerSHA256: SHA256Digest
    let queryOrdinal: Int
    let rawOutputIncluded: Bool
    let requestID: String
    let requestSHA256: SHA256Digest
    let schemaVersion: Int
    let signatureAlgorithm: EvaluationSignatureAlgorithm
    let signingKeyID: String
    let strataSHA256: SHA256Digest
    let trustedBaseSHA: GitObjectID

    init(
        budgetSHA256: SHA256Digest,
        candidateComponentID: String,
        candidateSHA256: SHA256Digest,
        clientID: String,
        decision: EvaluationDecision,
        epoch: String,
        epochSHA256: SHA256Digest,
        evaluatorSHA256: SHA256Digest,
        executionReceiptSHA256: SHA256Digest,
        expiresAt: String,
        failureClass: EvaluationFailureClass,
        issuedAt: String,
        modelID: String,
        nonceSHA256: SHA256Digest,
        partition: EvaluationPartition,
        policySHA256: SHA256Digest,
        queryLedgerSHA256: SHA256Digest,
        queryOrdinal: Int,
        rawOutputIncluded: Bool,
        requestID: String,
        requestSHA256: SHA256Digest,
        schemaVersion: Int,
        signatureAlgorithm: EvaluationSignatureAlgorithm,
        signingKeyID: String,
        strataSHA256: SHA256Digest,
        trustedBaseSHA: GitObjectID,
    ) {
        self.budgetSHA256 = budgetSHA256
        self.candidateComponentID = candidateComponentID
        self.candidateSHA256 = candidateSHA256
        self.clientID = clientID
        self.decision = decision
        self.epoch = epoch
        self.epochSHA256 = epochSHA256
        self.evaluatorSHA256 = evaluatorSHA256
        self.executionReceiptSHA256 = executionReceiptSHA256
        self.expiresAt = expiresAt
        self.failureClass = failureClass
        self.issuedAt = issuedAt
        self.modelID = modelID
        self.nonceSHA256 = nonceSHA256
        self.partition = partition
        self.policySHA256 = policySHA256
        self.queryLedgerSHA256 = queryLedgerSHA256
        self.queryOrdinal = queryOrdinal
        self.rawOutputIncluded = rawOutputIncluded
        self.requestID = requestID
        self.requestSHA256 = requestSHA256
        self.schemaVersion = schemaVersion
        self.signatureAlgorithm = signatureAlgorithm
        self.signingKeyID = signingKeyID
        self.strataSHA256 = strataSHA256
        self.trustedBaseSHA = trustedBaseSHA
    }

    init(
        request: EvaluationRequest,
        result: EvaluationResult,
        issuedAt: String,
        expiresAt: String,
        signingKeyID: String,
    ) {
        budgetSHA256 = request.budgetSHA256
        candidateComponentID = request.candidateComponentID
        candidateSHA256 = request.candidateSHA256
        clientID = request.clientID
        decision = result.aggregate.decision
        epoch = request.epoch
        epochSHA256 = request.epochSHA256
        evaluatorSHA256 = request.evaluatorSHA256
        executionReceiptSHA256 = result.executionReceiptSHA256
        self.expiresAt = expiresAt
        failureClass = result.aggregate.failureClass
        self.issuedAt = issuedAt
        modelID = request.modelID
        nonceSHA256 = SHA256Digest.hashing(Data(request.nonce.utf8))
        partition = request.partition
        policySHA256 = request.policySHA256
        queryLedgerSHA256 = result.queryLedgerSHA256
        queryOrdinal = request.queryOrdinal
        rawOutputIncluded = false
        requestID = request.requestID
        requestSHA256 = request.digest
        schemaVersion = FactoryCore.schemaVersion
        signatureAlgorithm = .ed25519
        self.signingKeyID = signingKeyID
        strataSHA256 = request.strataSHA256
        trustedBaseSHA = request.trustedBaseSHA
    }
}

private func validAttestationLifetime(issuedAt: String, expiresAt: String) -> Bool {
    guard let issued = canonicalAttestationDate(issuedAt),
          let expires = canonicalAttestationDate(expiresAt)
    else {
        return false
    }
    return issued < expires
}

private func isWithinAttestationLifetime(issuedAt: String, expiresAt: String, now: String) -> Bool {
    guard let issued = canonicalAttestationDate(issuedAt),
          let expires = canonicalAttestationDate(expiresAt),
          let current = canonicalAttestationDate(now)
    else {
        return false
    }
    return issued <= current && current < expires
}

private func canonicalAttestationDate(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
        return nil
    }
    return date
}
