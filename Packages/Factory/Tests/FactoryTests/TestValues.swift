import enum CryptoKit.Curve25519
import Darwin
import Foundation
@testable import FactoryCore

enum TestValues {
    static let head = gitObjectID(repeating: "a")
    static let nextHead = gitObjectID(repeating: "b")
    static let zero = SHA256Digest.hashing(Data())
    static let tree = SHA256Digest.hashing(Data("tree".utf8))
    static let contract = SHA256Digest.hashing(Data("contract".utf8))
    static let context = SHA256Digest.hashing(Data("context".utf8))
    static let evidence = SHA256Digest.hashing(Data("evidence".utf8))
    static let packages = repositoryPath("Packages")
    static let activationPrivateKey = Curve25519.Signing.PrivateKey()
    static let auditPrivateKey = Curve25519.Signing.PrivateKey()
    static let activationPublicKeySHA256 = SHA256Digest.hashing(activationPrivateKey.publicKey.rawRepresentation)
    static let brokerIdentity = SHA256Digest.hashing(Data("installed-broker".utf8))
    static let operatorUserID = Int(geteuid()) == 1 ? 2 : 1
    static let temporaryDirectory = canonicalTemporaryDirectory()

    static func evaluationManifest(
        acceptanceSHA256: SHA256Digest = contract,
        schemaDigests: [SchemaDigest] = [SchemaDigest(schemaID: "evaluation-case", sha256: context)],
    ) -> PrivateEvaluationRootManifest {
        do {
            return try PrivateEvaluationRootManifest(
                acceptanceSHA256: acceptanceSHA256,
                casesPresent: false,
                epochZeroFrozen: false,
                evaluatorCodePresent: false,
                schemaDigests: schemaDigests,
                trustedRootSHA: head,
            )
        } catch {
            preconditionFailure("Invalid private evaluation manifest fixture: \(error)")
        }
    }

    private static func gitObjectID(repeating character: Character) -> GitObjectID {
        do {
            return try GitObjectID(validating: String(repeating: character, count: 40))
        } catch {
            preconditionFailure("Invalid fixed Git fixture: \(error)")
        }
    }

    private static func repositoryPath(_ value: String) -> RepositoryPath {
        do {
            return try RepositoryPath(validating: value)
        } catch {
            preconditionFailure("Invalid fixed repository path fixture: \(error)")
        }
    }

    private static func canonicalTemporaryDirectory() -> URL {
        guard let resolved = Darwin.realpath(FileManager.default.temporaryDirectory.path, nil) else {
            preconditionFailure("Could not resolve the temporary directory")
        }
        defer { Darwin.free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    }

    static func trustAnchor(
        brokerStateRoot: URL,
        evaluationScaffoldRoot: URL,
        manifest: PrivateEvaluationRootManifest,
    ) -> BrokerTrustAnchor {
        do {
            return try BrokerTrustAnchor(
                activationPublicKeySHA256: activationPublicKeySHA256,
                brokerIdentitySHA256: brokerIdentity,
                brokerStateRootPath: brokerStateRoot.path,
                brokerUserID: Int(geteuid()),
                evaluationScaffoldManifestSHA256: CanonicalJSON.digest(manifest),
                evaluationScaffoldRootPath: evaluationScaffoldRoot.path,
                operatorUserID: operatorUserID,
                repository: "BedirT/swiftmac-base",
                signingKeyID: "owner-trusted-root-key",
                trustedRootSHA: head,
                evolutionAcceptanceSHA256: contract,
            )
        } catch {
            preconditionFailure("Invalid fixed trust anchor fixture: \(error)")
        }
    }
}
