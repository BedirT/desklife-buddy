import CryptoKit
import Foundation

/// Owner-signed one-time capability that turns a merged trusted-root state into live broker authority.
struct BrokerActivationReceipt: Codable, Equatable, Sendable {
    let activationPublicKey: Data
    let auditPublicKey: Data
    let brokerIdentitySHA256: SHA256Digest
    let contractSHA256: SHA256Digest
    let evaluatorProofSHA256: SHA256Digest
    let expiresAt: String
    let isolationProofSHA256: SHA256Digest
    let issueNumber: Int
    let issuedAt: String
    let leaseID: String
    let policySHA256: SHA256Digest
    let priorGeneration: Int
    let receiptID: String
    let runID: String
    let schemaVersion: Int
    let sealedEpochSHA256: SHA256Digest
    let selectionEpochSHA256: SHA256Digest
    let signature: Data
    let signingKeyID: String
    let trustedRootSHA: GitObjectID
    let stateSHA256: SHA256Digest

    fileprivate init(unsigned: BrokerActivationBinding, signature: Data) {
        activationPublicKey = unsigned.activationPublicKey
        auditPublicKey = unsigned.auditPublicKey
        brokerIdentitySHA256 = unsigned.brokerIdentitySHA256
        contractSHA256 = unsigned.contractSHA256
        evaluatorProofSHA256 = unsigned.evaluatorProofSHA256
        expiresAt = unsigned.expiresAt
        isolationProofSHA256 = unsigned.isolationProofSHA256
        issueNumber = unsigned.issueNumber
        issuedAt = unsigned.issuedAt
        leaseID = unsigned.leaseID
        policySHA256 = unsigned.policySHA256
        priorGeneration = unsigned.priorGeneration
        receiptID = unsigned.receiptID
        runID = unsigned.runID
        schemaVersion = unsigned.schemaVersion
        sealedEpochSHA256 = unsigned.sealedEpochSHA256
        selectionEpochSHA256 = unsigned.selectionEpochSHA256
        self.signature = signature
        signingKeyID = unsigned.signingKeyID
        trustedRootSHA = unsigned.trustedRootSHA
        stateSHA256 = unsigned.stateSHA256
    }

    fileprivate var unsigned: BrokerActivationBinding {
        BrokerActivationBinding(
            activationPublicKey: activationPublicKey,
            auditPublicKey: auditPublicKey,
            brokerIdentitySHA256: brokerIdentitySHA256,
            contractSHA256: contractSHA256,
            evaluatorProofSHA256: evaluatorProofSHA256,
            expiresAt: expiresAt,
            isolationProofSHA256: isolationProofSHA256,
            issueNumber: issueNumber,
            issuedAt: issuedAt,
            leaseID: leaseID,
            policySHA256: policySHA256,
            priorGeneration: priorGeneration,
            receiptID: receiptID,
            runID: runID,
            schemaVersion: schemaVersion,
            sealedEpochSHA256: sealedEpochSHA256,
            selectionEpochSHA256: selectionEpochSHA256,
            signingKeyID: signingKeyID,
            trustedRootSHA: trustedRootSHA,
            stateSHA256: stateSHA256,
        )
    }

    var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }
}

enum BrokerActivationAuthority {
    static func sign(
        policy: BrokerPolicy,
        state: BrokerState,
        input: BrokerActivationSigningInput,
    ) throws -> BrokerActivationReceipt {
        let binding = BrokerActivationBinding(
            activationPublicKey: input.privateKey.publicKey.rawRepresentation,
            auditPublicKey: input.auditPublicKey.rawRepresentation,
            brokerIdentitySHA256: policy.brokerIdentitySHA256,
            contractSHA256: state.contractDigest,
            evaluatorProofSHA256: input.evaluatorProofSHA256,
            expiresAt: input.expiresAt,
            isolationProofSHA256: input.isolationProofSHA256,
            issueNumber: state.issueNumber,
            issuedAt: input.issuedAt,
            leaseID: state.leaseID,
            policySHA256: policy.digest,
            priorGeneration: state.generation,
            receiptID: input.receiptID,
            runID: state.runID,
            schemaVersion: FactoryCore.schemaVersion,
            sealedEpochSHA256: input.sealedEpochSHA256,
            selectionEpochSHA256: input.selectionEpochSHA256,
            signingKeyID: input.signingKeyID,
            trustedRootSHA: policy.trustedBase,
            stateSHA256: CanonicalJSON.digest(state),
        )
        try validateStructure(binding, policy: policy)
        let signature = try input.privateKey.signature(for: CanonicalJSON.encode(binding))
        return BrokerActivationReceipt(unsigned: binding, signature: signature)
    }

    static func verifyForActivation(
        _ receipt: BrokerActivationReceipt,
        anchor: BrokerTrustAnchor,
        policy: BrokerPolicy,
        state: BrokerState,
        now: String,
    ) throws -> Bool {
        try anchor.validate(policy: policy)
        guard receipt.signingKeyID == anchor.signingKeyID,
              receipt.stateSHA256 == CanonicalJSON.digest(state),
              receipt.contractSHA256 == state.contractDigest,
              receipt.issueNumber == state.issueNumber,
              receipt.leaseID == state.leaseID,
              receipt.priorGeneration == state.generation,
              receipt.runID == state.runID,
              isWithinLifetime(issuedAt: receipt.issuedAt, expiresAt: receipt.expiresAt, now: now)
        else {
            return false
        }
        return try verifySignature(receipt, policy: policy)
    }

    static func verifyInstalled(
        _ receipt: BrokerActivationReceipt,
        policy: BrokerPolicy,
        state: BrokerState,
    ) throws -> Bool {
        guard receipt.contractSHA256 == state.contractDigest,
              receipt.issueNumber == state.issueNumber,
              receipt.leaseID == state.leaseID,
              receipt.priorGeneration < state.generation,
              receipt.runID == state.runID
        else {
            return false
        }
        return try verifySignature(receipt, policy: policy)
    }

    private static func verifySignature(
        _ receipt: BrokerActivationReceipt,
        policy: BrokerPolicy,
    ) throws -> Bool {
        try validateStructure(receipt.unsigned, policy: policy)
        guard receipt.signature.count == 64 else { return false }
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: receipt.activationPublicKey)
        return try publicKey.isValidSignature(receipt.signature, for: CanonicalJSON.encode(receipt.unsigned))
    }

    private static func validateStructure(
        _ binding: BrokerActivationBinding,
        policy: BrokerPolicy,
    ) throws {
        guard binding.schemaVersion == FactoryCore.schemaVersion,
              binding.activationPublicKey.count == 32,
              binding.auditPublicKey.count == 32,
              SHA256Digest.hashing(binding.activationPublicKey) == policy.activationPublicKeySHA256,
              binding.brokerIdentitySHA256 == policy.brokerIdentitySHA256,
              binding.policySHA256 == policy.digest,
              binding.trustedRootSHA == policy.trustedBase,
              FactoryTextRules.isStableID(binding.receiptID),
              FactoryTextRules.isStableID(binding.signingKeyID),
              FactoryTextRules.isStableID(binding.runID),
              FactoryTextRules.isStableID(binding.leaseID),
              binding.issueNumber > 0,
              binding.priorGeneration > 0,
              validLifetime(issuedAt: binding.issuedAt, expiresAt: binding.expiresAt)
        else {
            throw FactoryValidationError(
                code: "invalid_broker_activation",
                message: "Broker activation is malformed or bound to another trusted root.",
            )
        }
    }

    private static func validLifetime(issuedAt: String, expiresAt: String) -> Bool {
        guard let issued = canonicalDate(issuedAt), let expires = canonicalDate(expiresAt) else { return false }
        let lifetime = expires.timeIntervalSince(issued)
        return lifetime > 0 && lifetime <= 86400
    }

    private static func isWithinLifetime(issuedAt: String, expiresAt: String, now: String) -> Bool {
        guard let issued = canonicalDate(issuedAt),
              let expires = canonicalDate(expiresAt),
              let current = canonicalDate(now)
        else {
            return false
        }
        return issued <= current && current < expires
    }

    private static func canonicalDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }
}

struct BrokerActivationSigningInput {
    let auditPublicKey: Curve25519.Signing.PublicKey
    let isolationProofSHA256: SHA256Digest
    let evaluatorProofSHA256: SHA256Digest
    let selectionEpochSHA256: SHA256Digest
    let sealedEpochSHA256: SHA256Digest
    let receiptID: String
    let signingKeyID: String
    let issuedAt: String
    let expiresAt: String
    let privateKey: Curve25519.Signing.PrivateKey
}

private struct BrokerActivationBinding: Codable, Equatable {
    let activationPublicKey: Data
    let auditPublicKey: Data
    let brokerIdentitySHA256: SHA256Digest
    let contractSHA256: SHA256Digest
    let evaluatorProofSHA256: SHA256Digest
    let expiresAt: String
    let isolationProofSHA256: SHA256Digest
    let issueNumber: Int
    let issuedAt: String
    let leaseID: String
    let policySHA256: SHA256Digest
    let priorGeneration: Int
    let receiptID: String
    let runID: String
    let schemaVersion: Int
    let sealedEpochSHA256: SHA256Digest
    let selectionEpochSHA256: SHA256Digest
    let signingKeyID: String
    let trustedRootSHA: GitObjectID
    let stateSHA256: SHA256Digest
}
