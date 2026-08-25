import CryptoKit
import Darwin
import Foundation

/// Root-installed facts shared by both private evaluator identities.
struct EvaluatorRuntimeAnchor: Codable, Equatable {
    let evaluatorSHA256: SHA256Digest
    let policySHA256: SHA256Digest
    let schemaVersion: Int
    let sealedExecutionPublicKey: Data
    let sealedSigningPublicKeySHA256: SHA256Digest
    let sealedUserID: Int
    let selectionExecutionPublicKey: Data
    let selectionSigningPublicKeySHA256: SHA256Digest
    let selectionUserID: Int
    let trustedRootSHA: GitObjectID

    init(
        evaluatorSHA256: SHA256Digest,
        policySHA256: SHA256Digest,
        schemaVersion: Int = FactoryCore.schemaVersion,
        sealedExecutionPublicKey: Data,
        sealedSigningPublicKeySHA256: SHA256Digest,
        sealedUserID: Int,
        selectionExecutionPublicKey: Data,
        selectionSigningPublicKeySHA256: SHA256Digest,
        selectionUserID: Int,
        trustedRootSHA: GitObjectID,
    ) throws {
        let keyIdentities = Set([
            sealedSigningPublicKeySHA256,
            selectionSigningPublicKeySHA256,
            SHA256Digest.hashing(sealedExecutionPublicKey),
            SHA256Digest.hashing(selectionExecutionPublicKey),
        ])
        guard schemaVersion == FactoryCore.schemaVersion,
              sealedUserID > 0,
              sealedUserID <= Int(uid_t.max),
              selectionUserID > 0,
              selectionUserID <= Int(uid_t.max),
              sealedUserID != selectionUserID,
              keyIdentities.count == 4,
              (try? Curve25519.Signing.PublicKey(rawRepresentation: sealedExecutionPublicKey)) != nil,
              (try? Curve25519.Signing.PublicKey(rawRepresentation: selectionExecutionPublicKey)) != nil
        else {
            throw Self.invalid()
        }
        self.evaluatorSHA256 = evaluatorSHA256
        self.policySHA256 = policySHA256
        self.schemaVersion = schemaVersion
        self.sealedExecutionPublicKey = sealedExecutionPublicKey
        self.sealedSigningPublicKeySHA256 = sealedSigningPublicKeySHA256
        self.sealedUserID = sealedUserID
        self.selectionExecutionPublicKey = selectionExecutionPublicKey
        self.selectionSigningPublicKeySHA256 = selectionSigningPublicKeySHA256
        self.selectionUserID = selectionUserID
        self.trustedRootSHA = trustedRootSHA
    }

    init(from decoder: Decoder) throws {
        let stored = try Stored(from: decoder)
        try self.init(
            evaluatorSHA256: stored.evaluatorSHA256,
            policySHA256: stored.policySHA256,
            schemaVersion: stored.schemaVersion,
            sealedExecutionPublicKey: stored.sealedExecutionPublicKey,
            sealedSigningPublicKeySHA256: stored.sealedSigningPublicKeySHA256,
            sealedUserID: stored.sealedUserID,
            selectionExecutionPublicKey: stored.selectionExecutionPublicKey,
            selectionSigningPublicKeySHA256: stored.selectionSigningPublicKeySHA256,
            selectionUserID: stored.selectionUserID,
            trustedRootSHA: stored.trustedRootSHA,
        )
    }

    func encode(to encoder: Encoder) throws {
        try Stored(
            evaluatorSHA256: evaluatorSHA256,
            policySHA256: policySHA256,
            schemaVersion: schemaVersion,
            sealedExecutionPublicKey: sealedExecutionPublicKey,
            sealedSigningPublicKeySHA256: sealedSigningPublicKeySHA256,
            sealedUserID: sealedUserID,
            selectionExecutionPublicKey: selectionExecutionPublicKey,
            selectionSigningPublicKeySHA256: selectionSigningPublicKeySHA256,
            selectionUserID: selectionUserID,
            trustedRootSHA: trustedRootSHA,
        ).encode(to: encoder)
    }

    func signingPublicKeySHA256(for partition: EvaluationPartition) -> SHA256Digest {
        switch partition {
        case .selection: selectionSigningPublicKeySHA256
        case .sealed: sealedSigningPublicKeySHA256
        }
    }

    func executionPublicKey(for partition: EvaluationPartition) throws -> Curve25519.Signing.PublicKey {
        let bytes = switch partition {
        case .selection: selectionExecutionPublicKey
        case .sealed: sealedExecutionPublicKey
        }
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: bytes) else {
            throw Self.invalid()
        }
        return key
    }

    func userID(for partition: EvaluationPartition) -> uid_t {
        switch partition {
        case .selection: uid_t(selectionUserID)
        case .sealed: uid_t(sealedUserID)
        }
    }

    static func invalid() -> FactoryValidationError {
        FactoryValidationError(
            code: "untrusted_evaluator_anchor",
            message: "Private evaluation requires the shared root-installed trusted root evaluator anchor.",
        )
    }

    private struct Stored: Codable {
        let evaluatorSHA256: SHA256Digest
        let policySHA256: SHA256Digest
        let schemaVersion: Int
        let sealedExecutionPublicKey: Data
        let sealedSigningPublicKeySHA256: SHA256Digest
        let sealedUserID: Int
        let selectionExecutionPublicKey: Data
        let selectionSigningPublicKeySHA256: SHA256Digest
        let selectionUserID: Int
        let trustedRootSHA: GitObjectID
    }
}

enum EvaluatorRuntimeAnchorLoader {
    static let installationURL = URL(
        fileURLWithPath: "/Library/Application Support/SwiftMacFactory/evaluator-anchor.json",
    )

    static func load(partition: EvaluationPartition) throws -> EvaluatorRuntimeBinding {
        guard let executableURL = BrokerExecutableIdentity.runningExecutableURL(),
              let mappedIdentity = BrokerExecutableIdentity.runningMappedIdentity()
        else {
            throw EvaluatorRuntimeAnchor.invalid()
        }
        do {
            let bytes = try EvaluationProtectedFileLoader.load(
                at: installationURL,
                maximumBytes: 64 * 1024,
                requiredMode: 0o444,
                requiredOwnerUID: 0,
            )
            let anchor = try CanonicalJSON.decode(EvaluatorRuntimeAnchor.self, from: bytes)
            let expectedUserID = anchor.userID(for: partition)
            guard Darwin.geteuid() == expectedUserID,
                  Darwin.getuid() == expectedUserID
            else {
                throw EvaluatorRuntimeAnchor.invalid()
            }
            try BrokerExecutableIdentity.validate(
                at: executableURL,
                expectedSHA256: anchor.evaluatorSHA256,
                mappedIdentity: mappedIdentity,
                requiredOwnerUID: 0,
            )
            return EvaluatorRuntimeBinding(anchor: anchor, partition: partition)
        } catch {
            throw EvaluatorRuntimeAnchor.invalid()
        }
    }
}
