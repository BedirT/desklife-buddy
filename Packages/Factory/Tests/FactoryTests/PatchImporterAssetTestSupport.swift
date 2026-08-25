import Foundation
import Testing
@testable import FactoryCore

struct AssetApprovalContext {
    let bytes: Data
    let contentRef: RepositoryPath
    let path: RepositoryPath
    let provenance: AssetProvenance
    let policy: PatchImportPolicy
}

extension PatchImporterTests {
    func makeAssetApprovalContext(fixture: PatchFixture) throws -> AssetApprovalContext {
        let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let contentRef = try fixture.writeContent(id: "self-approved.png", data: bytes)
        let path = try RepositoryPath(validating: "Sources/SelfApproved.png")
        let provenance = AssetProvenance(
            generator: nil,
            license: "claimed-license",
            model: nil,
            ownerApproval: .approved,
            promptSHA256: nil,
            sourceClass: .licensed,
            sourceSHA256: SHA256Digest.hashing(bytes),
        )
        try expectModelSuppliedApprovalDenied(
            bytes: bytes,
            contentRef: contentRef,
            path: path,
            provenance: provenance,
            fixture: fixture,
        )
        let policy = try approvedAssetPolicy(bytes: bytes, path: path, provenance: provenance)
        return AssetApprovalContext(
            bytes: bytes,
            contentRef: contentRef,
            path: path,
            provenance: provenance,
            policy: policy,
        )
    }

    private func expectModelSuppliedApprovalDenied(
        bytes: Data,
        contentRef: RepositoryPath,
        path: RepositoryPath,
        provenance: AssetProvenance,
        fixture: PatchFixture,
    ) throws {
        let envelope = try fixture.envelope(
            operations: [
                PatchFileOperation(
                    operationID: "self-approved-asset",
                    path: path,
                    kind: .create,
                    before: .absent,
                    after: .regular(
                        PatchFilePayload(
                            expectation: FileExpectation(data: bytes, executable: false),
                            contentRef: contentRef,
                            contentKind: .asset,
                            assetProvenance: provenance,
                        ),
                    ),
                ),
            ],
            envelopeID: "envelope-self-approved-asset",
        )
        do {
            _ = try fixture.apply(envelope)
            Issue.record("Model-supplied owner approval authorized a binary asset")
        } catch let error as FactoryValidationError {
            #expect(error.code == "unapproved_binary_asset")
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.url(path.rawValue).path))
    }

    private func approvedAssetPolicy(
        bytes: Data,
        path: RepositoryPath,
        provenance: AssetProvenance,
    ) throws -> PatchImportPolicy {
        let binding = PatchImportPolicy.assetApprovalBindingSHA256(
            path: path,
            contentSHA256: SHA256Digest.hashing(bytes),
            bytes: bytes.count,
            provenance: provenance,
        )
        return try PatchImportPolicy(
            purpose: .product,
            contractSHA256: TestValues.contract,
            expectedInvocationID: "invocation-1",
            expectedRunID: "run-1",
            projectionSHA256: TestValues.context,
            allowedRoots: [RepositoryPath(validating: "Sources")],
            approvedAssetExtensions: ["png"],
            maximumOperations: 2,
            maximumTotalBytes: 1024,
            approvedAssetBindingsSHA256: [binding],
        )
    }

    func expectAssetPathReplayDenied(_ context: AssetApprovalContext, fixture: PatchFixture) throws {
        let replayPath = try RepositoryPath(validating: "Sources/Replayed.png")
        do {
            _ = try applyAsset(
                makeAssetEnvelope(
                    id: "replayed-path",
                    path: replayPath,
                    contentRef: context.contentRef,
                    data: context.bytes,
                    provenance: context.provenance,
                    policy: context.policy,
                ), fixture: fixture, policy: context.policy,
            )
            Issue.record("An asset approval was replayed at another destination")
        } catch let error as FactoryValidationError {
            #expect(error.code == "unapproved_binary_asset")
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.url(replayPath.rawValue).path))
    }

    func expectAssetBytesReplayDenied(_ context: AssetApprovalContext, fixture: PatchFixture) throws {
        let changedBytes = context.bytes + Data([0x00])
        let changedRef = try fixture.writeContent(id: "changed-approved.png", data: changedBytes)
        do {
            _ = try applyAsset(
                makeAssetEnvelope(
                    id: "replayed-bytes",
                    path: context.path,
                    contentRef: changedRef,
                    data: changedBytes,
                    provenance: context.provenance,
                    policy: context.policy,
                ), fixture: fixture, policy: context.policy,
            )
            Issue.record("An asset approval was replayed for other bytes")
        } catch let error as FactoryValidationError {
            #expect(error.code == "unapproved_binary_asset")
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.url(context.path.rawValue).path))
    }

    func expectGeneratedApprovalBypassDenied(
        _ context: AssetApprovalContext,
        fixture: PatchFixture,
    ) throws {
        let provenance = AssetProvenance(
            generator: "fixture-generator",
            license: "fixture-license",
            model: "fixture-model",
            ownerApproval: .notRequired,
            promptSHA256: TestValues.context,
            sourceClass: .generated,
            sourceSHA256: nil,
        )
        #expect(throws: FactoryValidationError.self) {
            try CanonicalJSON.decode(AssetProvenance.self, from: CanonicalJSON.encode(provenance))
        }
        do {
            _ = try applyAsset(
                makeAssetEnvelope(
                    id: "generated-not-required",
                    path: context.path,
                    contentRef: context.contentRef,
                    data: context.bytes,
                    provenance: provenance,
                    policy: context.policy,
                ), fixture: fixture, policy: context.policy,
            )
            Issue.record("Generated assets bypassed trusted approval with not_required")
        } catch let error as FactoryValidationError {
            #expect(error.code == "unapproved_binary_asset")
        }
    }

    func expectPlaceholderAndExactApprovalAccepted(
        _ context: AssetApprovalContext,
        fixture: PatchFixture,
    ) throws {
        let placeholderPath = try RepositoryPath(validating: "Sources/Placeholder.png")
        let placeholder = AssetProvenance(
            generator: nil,
            license: nil,
            model: nil,
            ownerApproval: .notRequired,
            promptSHA256: nil,
            sourceClass: .placeholder,
            sourceSHA256: nil,
        )
        _ = try applyAsset(
            makeAssetEnvelope(
                id: "placeholder-not-required",
                path: placeholderPath,
                contentRef: context.contentRef,
                data: context.bytes,
                provenance: placeholder,
                policy: context.policy,
            ), fixture: fixture, policy: context.policy,
        )
        #expect(try Data(contentsOf: fixture.url(placeholderPath.rawValue)) == context.bytes)

        _ = try applyAsset(
            makeAssetEnvelope(
                id: "exact-approved-asset",
                path: context.path,
                contentRef: context.contentRef,
                data: context.bytes,
                provenance: context.provenance,
                policy: context.policy,
            ), fixture: fixture, policy: context.policy,
        )
        #expect(try Data(contentsOf: fixture.url(context.path.rawValue)) == context.bytes)
    }
}
