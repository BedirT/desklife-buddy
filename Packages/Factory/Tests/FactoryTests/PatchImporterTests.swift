import struct CryptoKit.SHA256
import Darwin
import Foundation
import Testing
@testable import FactoryCore

@Suite("PatchEnvelope importer")
struct PatchImporterTests {
    @Test("Create, update, and delete import after complete preflight")
    func successfulImport() throws {
        try withFixture { fixture in
            let envelope = try fixture.validEnvelope()
            let paths = envelope.operations.map(\.path)
            try FileManager.default.createDirectory(
                at: fixture.url("artifacts/runtime"),
                withIntermediateDirectories: true,
            )
            try Data("ignored".utf8).write(to: fixture.url("artifacts/runtime/output.log"))
            try FileManager.default.createSymbolicLink(
                at: fixture.url("AdapterLink"),
                withDestinationURL: fixture.url("Sources"),
            )
            let original = try RepositoryTree.capture(at: fixture.repository, paths: paths)
            let receipt = try fixture.apply(envelope)

            #expect(try fixture.read("Sources/New.swift") == "let newValue = 2\n")
            #expect(try fixture.read("Sources/Old.swift") == "let oldValue = 2\n")
            #expect(!FileManager.default.fileExists(atPath: fixture.url("Sources/Delete.swift").path))
            #expect(receipt.beforeTree == original.digest)
            #expect(try receipt.afterTree == (RepositoryTree.capture(at: fixture.repository, paths: paths).digest))
            #expect(receipt.operationIDs == ["delete", "create", "update"])
        }
    }

    @Test("Stale hashes and product control-plane mutations fail without writes")
    func staleAndControlPlaneDenials() throws {
        try withFixture { fixture in
            let original = try RepositoryTree.capture(at: fixture.repository)
            try expectRejected(
                fixture.validEnvelope(expectedTreeSHA: TestValues.head),
                fixture: fixture,
                original: original,
            )

            let content = Data("{}\n".utf8)
            let contentRef = try fixture.writeContent(id: "control", data: content)
            let broadPolicy = try PatchImportPolicy(
                purpose: .product,
                contractSHA256: TestValues.contract,
                expectedInvocationID: "invocation-1",
                expectedRunID: "run-1",
                projectionSHA256: TestValues.context,
                allowedRoots: [RepositoryPath(validating: ".factory")],
                approvedAssetExtensions: [],
                maximumOperations: 10,
                maximumTotalBytes: 1_000_000,
            )
            let control = try PatchEnvelope(
                contractSHA256: TestValues.contract,
                envelopeID: "envelope-control",
                expectedBaseSHA: TestValues.head,
                expectedTreeSHA: TestValues.nextHead,
                invocationID: "invocation-1",
                operations: [
                    PatchFileOperation(
                        operationID: "control",
                        path: RepositoryPath(validating: ".factory/policy.json"),
                        kind: .create,
                        before: .absent,
                        after: .regular(
                            PatchFilePayload(
                                expectation: FileExpectation(data: content, executable: false),
                                contentRef: contentRef,
                                contentKind: .text,
                                assetProvenance: nil,
                            ),
                        ),
                    ),
                ],
                policySHA256: broadPolicy.digest,
                projectionSHA256: TestValues.context,
                runID: "run-1",
            )
            #expect(throws: FactoryValidationError.self) {
                try PatchImporter.apply(
                    control,
                    authoritativeRoot: fixture.repository,
                    contentRoot: fixture.scratch,
                    recoveryRoot: fixture.recovery,
                    repositoryIdentity: { _ in (TestValues.head, TestValues.nextHead) },
                    policy: broadPolicy,
                )
            }
            #expect(try RepositoryTree.capture(at: fixture.repository) == original)
        }
    }

    @Test("Links, before mismatches, aliases, and unapproved binaries are rejected")
    func structuralDenials() throws {
        expectIncompleteGeneratedProvenance()
        try withFixture { fixture in
            let original = try RepositoryTree.capture(at: fixture.repository)
            try expectBeforeMismatchAndDuplicateDenied(fixture: fixture, original: original)
            try expectAncestryAliasDenied(fixture: fixture, original: original)
            try expectTextBinaryDenied(fixture: fixture, original: original)
            try expectSymlinkTargetDenied(fixture: fixture)
        }
    }
}

extension PatchImporterTests {
    @Test("Patch transactions require a private exclusive lock entry")
    func transactionLock() throws {
        try withFixture { fixture in
            try FileManager.default.createSymbolicLink(
                at: fixture.recovery.appending(path: "transaction.lock"),
                withDestinationURL: fixture.url("Sources/Old.swift"),
            )
            #expect(throws: FactoryValidationError.self) {
                try fixture.apply(fixture.validEnvelope())
            }
        }
    }

    @Test("The authoritative root lock serializes importers across recovery roots")
    func authoritativeRootLock() throws {
        try withFixture { fixture in
            let lockURL = try AuthoritativePatchLock.lockURL(for: fixture.repository)
            let marker = fixture.recovery.appending(path: "second-lock-acquired")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [
                "-I", "-c",
                "import fcntl,pathlib,sys; f=open(sys.argv[1],'r+'); fcntl.lockf(f,fcntl.LOCK_EX); pathlib.Path(sys.argv[2]).write_text('locked')",
                lockURL.path, marker.path,
            ]

            try AuthoritativePatchLock.withExclusiveLock(at: fixture.repository) {
                try process.run()
                usleep(200_000)
                #expect(process.isRunning)
                #expect(!FileManager.default.fileExists(atPath: marker.path))
            }
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)
            #expect(FileManager.default.fileExists(atPath: marker.path))
        }
    }

    @Test("The authoritative root identity cannot change while its lock is held")
    func authoritativeRootIdentitySwap() throws {
        try withFixture { fixture in
            let displaced = fixture.repository.deletingLastPathComponent()
                .appending(path: "repository-displaced", directoryHint: .isDirectory)

            do {
                try AuthoritativePatchLock.withExclusiveLock(at: fixture.repository) {
                    try FileManager.default.moveItem(at: fixture.repository, to: displaced)
                    try FileManager.default.createDirectory(
                        at: fixture.repository,
                        withIntermediateDirectories: false,
                    )
                }
                Issue.record("The authoritative path changed identity without invalidating its lock")
            } catch let error as FactoryValidationError {
                #expect(error.code == "authoritative_root_changed")
            }

            #expect(FileManager.default.fileExists(atPath: displaced.appending(path: "Sources/Old.swift").path))
            #expect(!FileManager.default.fileExists(atPath: fixture.url("Sources/Old.swift").path))
        }
    }

    @Test("Malformed recovery trees and operation IDs reject without trapping")
    func malformedRecoveryJournal() throws {
        let path = try RepositoryPath(validating: "Sources/File.swift")
        let treeFile = RepositoryTreeFile(
            path: path,
            digest: TestValues.evidence,
            bytes: 1,
            executable: false,
        )
        let duplicateFiles = [treeFile, treeFile]
        let duplicateTree = RepositoryTree(
            files: duplicateFiles,
            digest: CanonicalJSON.digest(duplicateFiles),
        )
        let operation = PatchRecoveryOperation(
            operationID: "create",
            path: path,
            kind: .create,
            before: nil,
            after: FileExpectation(data: Data("x".utf8), executable: false),
        )
        #expect(throws: FactoryValidationError.self) {
            try PatchRecoveryRecord(
                schemaVersion: FactoryCore.schemaVersion,
                envelopeID: "envelope-1",
                envelopeDigest: TestValues.contract,
                state: .prepared,
                beforeTree: duplicateTree,
                completedTree: nil,
                operations: [operation],
            ).validate()
        }

        let unrelatedCompletedTree = RepositoryTree(
            files: [treeFile],
            digest: CanonicalJSON.digest([treeFile]),
        )
        #expect(throws: FactoryValidationError.self) {
            try PatchRecoveryRecord(
                schemaVersion: FactoryCore.schemaVersion,
                envelopeID: "envelope-completed-mismatch",
                envelopeDigest: TestValues.contract,
                state: .completed,
                beforeTree: RepositoryTree(files: [], digest: CanonicalJSON.digest([RepositoryTreeFile]())),
                completedTree: unrelatedCompletedTree,
                operations: [operation],
            ).validate()
        }

        let overCeiling = Array(
            repeating: operation,
            count: PatchImportPolicy.maximumKernelOperations + 1,
        )
        #expect(throws: FactoryValidationError.self) {
            try PatchRecoveryRecord(
                schemaVersion: FactoryCore.schemaVersion,
                envelopeID: "envelope-over-operation-ceiling",
                envelopeDigest: TestValues.contract,
                state: .prepared,
                beforeTree: RepositoryTree(files: [], digest: CanonicalJSON.digest([RepositoryTreeFile]())),
                completedTree: nil,
                operations: overCeiling,
            ).validate()
        }

        let emptyFiles: [RepositoryTreeFile] = []
        #expect(throws: FactoryValidationError.self) {
            try PatchRecoveryRecord(
                schemaVersion: FactoryCore.schemaVersion,
                envelopeID: "envelope-1",
                envelopeDigest: TestValues.contract,
                state: .prepared,
                beforeTree: RepositoryTree(files: emptyFiles, digest: CanonicalJSON.digest(emptyFiles)),
                completedTree: nil,
                operations: [PatchRecoveryOperation(
                    operationID: "../escape",
                    path: path,
                    kind: .create,
                    before: nil,
                    after: operation.after,
                )],
            ).validate()
        }
    }

    @Test("Declared and actual patch bytes fail closed before allocation")
    func byteBudgets() throws {
        try withFixture { fixture in
            let policy = try PatchImportPolicy(
                purpose: .product,
                contractSHA256: TestValues.contract,
                expectedInvocationID: "invocation-1",
                expectedRunID: "run-1",
                projectionSHA256: TestValues.context,
                allowedRoots: [RepositoryPath(validating: "Sources")],
                approvedAssetExtensions: [],
                maximumOperations: 2,
                maximumTotalBytes: Int.max,
            )
            let operations = try ["A", "B"].map { name in
                try PatchFileOperation(
                    operationID: "huge-\(name.lowercased())",
                    path: RepositoryPath(validating: "Sources/\(name).swift"),
                    kind: .create,
                    before: .absent,
                    after: .regular(
                        PatchFilePayload(
                            expectation: FileExpectation(
                                sha256: TestValues.evidence,
                                bytes: Int.max,
                                executable: false,
                            ),
                            contentRef: RepositoryPath(validating: "output/files/\(name.lowercased())"),
                            contentKind: .text,
                            assetProvenance: nil,
                        ),
                    ),
                )
            }
            let envelope = PatchEnvelope(
                contractSHA256: TestValues.contract,
                envelopeID: "envelope-overflow",
                expectedBaseSHA: TestValues.head,
                expectedTreeSHA: TestValues.nextHead,
                invocationID: "invocation-1",
                operations: operations,
                policySHA256: policy.digest,
                projectionSHA256: TestValues.context,
                runID: "run-1",
            )
            #expect(throws: FactoryValidationError.self) {
                try PatchImporter.apply(
                    envelope,
                    authoritativeRoot: fixture.repository,
                    contentRoot: fixture.scratch,
                    recoveryRoot: fixture.recovery,
                    repositoryIdentity: { _ in (TestValues.head, TestValues.nextHead) },
                    policy: policy,
                )
            }

            let oversized = Data("too-large".utf8)
            let contentRef = try fixture.writeContent(id: "oversized", data: oversized)
            let bounded = try fixture.envelope(
                operations: [
                    PatchFileOperation(
                        operationID: "bounded",
                        path: RepositoryPath(validating: "Sources/Bounded.swift"),
                        kind: .create,
                        before: .absent,
                        after: .regular(
                            PatchFilePayload(
                                expectation: FileExpectation(
                                    sha256: SHA256Digest.hashing(Data("t".utf8)),
                                    bytes: 1,
                                    executable: false,
                                ),
                                contentRef: contentRef,
                                contentKind: .text,
                                assetProvenance: nil,
                            ),
                        ),
                    ),
                ],
                envelopeID: "envelope-bounded-read",
            )
            do {
                _ = try fixture.apply(bounded)
                Issue.record("Oversized scratch content was accepted")
            } catch let error as FactoryValidationError {
                #expect(error.code == "unsafe_regular_file")
            }
        }
    }

    @Test("Patch policy decoding and construction enforce an absolute operation ceiling")
    func patchPolicyOperationCeiling() throws {
        let arguments = try (
            purpose: ChangePurpose.product,
            contractSHA256: TestValues.contract,
            expectedInvocationID: "invocation-1",
            expectedRunID: "run-1",
            projectionSHA256: TestValues.context,
            allowedRoots: [RepositoryPath(validating: "Sources")],
            approvedAssetExtensions: ["png"],
        )

        #expect(throws: FactoryValidationError.self) {
            try PatchImportPolicy(
                purpose: arguments.purpose,
                contractSHA256: arguments.contractSHA256,
                expectedInvocationID: arguments.expectedInvocationID,
                expectedRunID: arguments.expectedRunID,
                projectionSHA256: arguments.projectionSHA256,
                allowedRoots: arguments.allowedRoots,
                approvedAssetExtensions: arguments.approvedAssetExtensions,
                maximumOperations: Int.max,
                maximumTotalBytes: 1024,
            )
        }

        let valid = try PatchImportPolicy(
            purpose: arguments.purpose,
            contractSHA256: arguments.contractSHA256,
            expectedInvocationID: arguments.expectedInvocationID,
            expectedRunID: arguments.expectedRunID,
            projectionSHA256: arguments.projectionSHA256,
            allowedRoots: arguments.allowedRoots,
            approvedAssetExtensions: arguments.approvedAssetExtensions,
            maximumOperations: 1,
            maximumTotalBytes: 1024,
        )
        var object = try #require(JSONSerialization.jsonObject(with: CanonicalJSON.encode(valid)) as? [String: Any])
        for invalidMaximum in [0, Int.max] {
            object["maximum_operations"] = invalidMaximum
            let invalid = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys, .withoutEscapingSlashes],
            )
            #expect(throws: FactoryValidationError.self) {
                try CanonicalJSON.decode(PatchImportPolicy.self, from: invalid)
            }
        }

        let approvals = [TestValues.context, TestValues.evidence].sorted { $0.rawValue < $1.rawValue }
        let approvalPolicy = try PatchImportPolicy(
            purpose: arguments.purpose,
            contractSHA256: arguments.contractSHA256,
            expectedInvocationID: arguments.expectedInvocationID,
            expectedRunID: arguments.expectedRunID,
            projectionSHA256: arguments.projectionSHA256,
            allowedRoots: arguments.allowedRoots,
            approvedAssetExtensions: arguments.approvedAssetExtensions,
            maximumOperations: 2,
            maximumTotalBytes: 1024,
            approvedAssetBindingsSHA256: approvals,
        )
        var noncanonical = try #require(
            JSONSerialization.jsonObject(with: CanonicalJSON.encode(approvalPolicy)) as? [String: Any],
        )
        noncanonical["approved_asset_bindings_sha256"] = approvals.reversed().map(\.rawValue)
        let noncanonicalBytes = try JSONSerialization.data(
            withJSONObject: noncanonical,
            options: [.sortedKeys, .withoutEscapingSlashes],
        )
        #expect(throws: FactoryValidationError.self) {
            try CanonicalJSON.decode(PatchImportPolicy.self, from: noncanonicalBytes)
        }
    }
}

extension PatchImporterTests {
    @Test("Asset approval is trusted and bound to exact destination and bytes")
    func assetApprovalBinding() throws {
        try withFixture { fixture in
            let context = try makeAssetApprovalContext(fixture: fixture)
            try expectAssetPathReplayDenied(context, fixture: fixture)
            try expectAssetBytesReplayDenied(context, fixture: fixture)
            try expectGeneratedApprovalBypassDenied(context, fixture: fixture)
            try expectPlaceholderAndExactApprovalAccepted(context, fixture: fixture)
        }
    }

    @Test("Before and recovery bytes share the transaction byte ceiling")
    func beforeAndRecoveryByteBudget() throws {
        try withFixture { fixture in
            let sparse = fixture.url("Sources/Sparse.bin")
            let sparseBytes = 2 * 1024 * 1024
            let sparseDigest = try writeSparseFile(at: sparse, bytes: sparseBytes)
            let policy = try PatchImportPolicy(
                purpose: .product,
                contractSHA256: TestValues.contract,
                expectedInvocationID: "invocation-1",
                expectedRunID: "run-1",
                projectionSHA256: TestValues.context,
                allowedRoots: [RepositoryPath(validating: "Sources")],
                approvedAssetExtensions: [],
                maximumOperations: 1,
                maximumTotalBytes: 1024,
            )
            let envelope = try PatchEnvelope(
                contractSHA256: TestValues.contract,
                envelopeID: "envelope-before-budget",
                expectedBaseSHA: TestValues.head,
                expectedTreeSHA: TestValues.nextHead,
                invocationID: "invocation-1",
                operations: [
                    PatchFileOperation(
                        operationID: "delete-sparse",
                        path: RepositoryPath(validating: "Sources/Sparse.bin"),
                        kind: .delete,
                        before: .regular(
                            FileExpectation(sha256: sparseDigest, bytes: sparseBytes, executable: false),
                        ),
                        after: .deleted,
                    ),
                ],
                policySHA256: policy.digest,
                projectionSHA256: TestValues.context,
                runID: "run-1",
            )

            do {
                _ = try PatchImporter.apply(
                    envelope,
                    authoritativeRoot: fixture.repository,
                    contentRoot: fixture.scratch,
                    recoveryRoot: fixture.recovery,
                    repositoryIdentity: { _ in (TestValues.head, TestValues.nextHead) },
                    policy: policy,
                )
                Issue.record("Before-state bytes exceeded the transaction budget")
            } catch let error as FactoryValidationError {
                #expect(error.code == "patch_budget_exceeded")
            }
            #expect(fileSize(at: sparse) == sparseBytes)
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))
        }
    }

    @Test("Encoded recovery journals enforce their fixed byte ceiling")
    func encodedJournalBudget() throws {
        try withFixture { fixture in
            let files: [RepositoryTreeFile] = []
            let record = try PatchRecoveryRecord(
                schemaVersion: FactoryCore.schemaVersion,
                envelopeID: "journal-budget",
                envelopeDigest: TestValues.contract,
                state: .prepared,
                beforeTree: RepositoryTree(files: files, digest: CanonicalJSON.digest(files)),
                completedTree: nil,
                operations: [
                    PatchRecoveryOperation(
                        operationID: "create",
                        path: RepositoryPath(validating: "Sources/New.swift"),
                        kind: .create,
                        before: nil,
                        after: FileExpectation(data: Data("x".utf8), executable: false),
                    ),
                ],
            )
            try record.validate()

            do {
                try PatchRecoveryJournal.writePrepared(record, at: fixture.recovery, maximumEncodedBytes: 64)
                Issue.record("Oversized encoded recovery journal was written")
            } catch let error as FactoryValidationError {
                #expect(error.code == "patch_journal_budget")
            }
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))

            let beforeData = Data(repeating: 0x41, count: 1024)
            let beforePath = try RepositoryPath(validating: "Sources/Before.bin")
            let beforeFiles = [
                RepositoryTreeFile(
                    path: beforePath,
                    digest: SHA256Digest.hashing(beforeData),
                    bytes: beforeData.count,
                    executable: false,
                ),
            ]
            let amplified = PatchRecoveryRecord(
                schemaVersion: FactoryCore.schemaVersion,
                envelopeID: "journal-amplification",
                envelopeDigest: TestValues.contract,
                state: .prepared,
                beforeTree: RepositoryTree(files: beforeFiles, digest: CanonicalJSON.digest(beforeFiles)),
                completedTree: nil,
                operations: [
                    PatchRecoveryOperation(
                        operationID: "delete-before",
                        path: beforePath,
                        kind: .delete,
                        before: PatchRecoveryFile(data: beforeData, executable: false),
                        after: nil,
                    ),
                ],
            )
            var fullRecordEncoded = false
            do {
                try PatchRecoveryJournal.writePrepared(
                    amplified,
                    at: fixture.recovery,
                    maximumEncodedBytes: 1024,
                    encoder: { value in
                        fullRecordEncoded = true
                        return try CanonicalJSON.encode(value)
                    },
                )
                Issue.record("An amplified recovery journal was written")
            } catch let error as FactoryValidationError {
                #expect(error.code == "patch_journal_budget")
            }
            #expect(!fullRecordEncoded)
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))
        }
    }

    @Test("Product patches cannot update or delete snapshot baselines")
    func productSnapshotBaselineDenials() throws {
        try withFixture { fixture in
            let baselineRoot = fixture.url("Packages/Feature/Tests/__Snapshots__")
            try FileManager.default.createDirectory(at: baselineRoot, withIntermediateDirectories: true)
            let updateURL = baselineRoot.appending(path: "Feature.update.png")
            let deleteURL = baselineRoot.appending(path: "Feature.delete.png")
            let originalUpdate = Data([0, 1, 2, 3])
            let originalDelete = Data([4, 5, 6, 7])
            let replacement = Data([8, 9, 10, 11])
            try originalUpdate.write(to: updateURL)
            try originalDelete.write(to: deleteURL)
            #expect(Darwin.chmod(updateURL.path, 0o644) == 0)
            #expect(Darwin.chmod(deleteURL.path, 0o644) == 0)
            let replacementRef = try fixture.writeContent(id: "snapshot-approved", data: replacement)
            let policy = try PatchImportPolicy(
                purpose: .product,
                contractSHA256: TestValues.contract,
                expectedInvocationID: "invocation-1",
                expectedRunID: "run-1",
                projectionSHA256: TestValues.context,
                allowedRoots: [RepositoryPath(validating: "Packages")],
                approvedAssetExtensions: ["png"],
                maximumOperations: 2,
                maximumTotalBytes: 1024,
            )
            let envelope = try PatchEnvelope(
                contractSHA256: TestValues.contract,
                envelopeID: "envelope-snapshot-baseline",
                expectedBaseSHA: TestValues.head,
                expectedTreeSHA: TestValues.nextHead,
                invocationID: "invocation-1",
                operations: [
                    PatchFileOperation(
                        operationID: "delete-baseline",
                        path: RepositoryPath(
                            validating: "Packages/Feature/Tests/__Snapshots__/Feature.delete.png",
                        ),
                        kind: .delete,
                        before: .regular(FileExpectation(data: originalDelete, executable: false)),
                        after: .deleted,
                    ),
                    PatchFileOperation(
                        operationID: "update-baseline",
                        path: RepositoryPath(
                            validating: "Packages/Feature/Tests/__Snapshots__/Feature.update.png",
                        ),
                        kind: .update,
                        before: .regular(FileExpectation(data: originalUpdate, executable: false)),
                        after: .regular(
                            PatchFilePayload(
                                expectation: FileExpectation(data: replacement, executable: false),
                                contentRef: replacementRef,
                                contentKind: .asset,
                                assetProvenance: AssetProvenance(
                                    generator: "fixture-generator",
                                    license: "fixture-license",
                                    model: "fixture-model",
                                    ownerApproval: .approved,
                                    promptSHA256: TestValues.context,
                                    sourceClass: .generated,
                                    sourceSHA256: nil,
                                ),
                            ),
                        ),
                    ),
                ],
                policySHA256: policy.digest,
                projectionSHA256: TestValues.context,
                runID: "run-1",
            )

            do {
                _ = try PatchImporter.apply(
                    envelope,
                    authoritativeRoot: fixture.repository,
                    contentRoot: fixture.scratch,
                    recoveryRoot: fixture.recovery,
                    repositoryIdentity: { _ in (TestValues.head, TestValues.nextHead) },
                    policy: policy,
                )
                Issue.record("Product patch mutated snapshot baselines")
            } catch let error as FactoryValidationError {
                #expect(error.code == "product_snapshot_baseline_mutation")
            }
            #expect(try Data(contentsOf: updateURL) == originalUpdate)
            #expect(try Data(contentsOf: deleteURL) == originalDelete)
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))
        }
    }

    @Test("A mid-transaction failure restores the exact original tree")
    func rollback() throws {
        try withFixture { fixture in
            let original = try RepositoryTree.capture(at: fixture.repository)
            #expect(throws: FactoryValidationError.self) {
                try fixture.apply(
                    fixture.validEnvelope(),
                    fault: PatchImportFault(failAfterAppliedOperation: 1),
                )
            }
            #expect(try RepositoryTree.capture(at: fixture.repository) == original)
            #expect(try fixture.read("Sources/Old.swift") == "let oldValue = 1\n")
            #expect(try fixture.read("Sources/Delete.swift") == "delete me\n")
            #expect(!FileManager.default.fileExists(atPath: fixture.url("Sources/New.swift").path))
        }
    }

    @Test("A stale whole-tree identity rejects unrelated authoritative changes")
    func staleWholeTreeIdentity() throws {
        try withFixture { fixture in
            let envelope = try fixture.validEnvelope()
            try Data("unrelated change\n".utf8).write(
                to: fixture.url("Sources/Unrelated.swift"),
                options: .withoutOverwriting,
            )
            #expect(throws: FactoryValidationError.self) {
                try fixture.apply(envelope)
            }
        }
    }

    @Test("An unrelated mutation during identity observation rejects before import")
    func identityObservationRace() throws {
        try withFixture { fixture in
            let envelope = try fixture.validEnvelope()
            let paths = envelope.operations.map(\.path)
            let original = try RepositoryTree.capture(at: fixture.repository, paths: paths)
            let unrelated = fixture.url("Sources/Unrelated.swift")
            var injected = false

            do {
                _ = try PatchImporter.apply(
                    envelope,
                    authoritativeRoot: fixture.repository,
                    contentRoot: fixture.scratch,
                    recoveryRoot: fixture.recovery,
                    repositoryIdentity: { excluded in
                        let identity = try fixture.repositoryIdentity(excluding: excluded)
                        if excluded.isEmpty, !injected {
                            try Data("unrelated change\n".utf8).write(to: unrelated, options: .withoutOverwriting)
                            #expect(Darwin.chmod(unrelated.path, 0o644) == 0)
                            injected = true
                        }
                        return identity
                    },
                    policy: fixture.policy,
                )
                Issue.record("Repository identity changed during observation")
            } catch let error as FactoryValidationError {
                #expect(error.code == "patch_repository_changed")
            }

            #expect(injected)
            #expect(try RepositoryTree.capture(at: fixture.repository, paths: paths) == original)
            #expect(try String(contentsOf: unrelated, encoding: .utf8) == "unrelated change\n")
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))
        }
    }

    @Test("An unrelated mutation during import rolls back every envelope-owned path")
    func postMutationIdentityRace() throws {
        try withFixture { fixture in
            let envelope = try fixture.validEnvelope()
            let paths = envelope.operations.map(\.path)
            let original = try RepositoryTree.capture(at: fixture.repository, paths: paths)
            let unrelated = fixture.url("Sources/Unrelated.swift")
            var injected = false

            do {
                _ = try PatchImporter.apply(
                    envelope,
                    authoritativeRoot: fixture.repository,
                    contentRoot: fixture.scratch,
                    recoveryRoot: fixture.recovery,
                    repositoryIdentity: { excluded in
                        if !injected,
                           FileManager.default.fileExists(atPath: fixture.url("Sources/New.swift").path)
                        {
                            try Data("concurrent change\n".utf8).write(to: unrelated, options: .withoutOverwriting)
                            #expect(Darwin.chmod(unrelated.path, 0o644) == 0)
                            injected = true
                        }
                        return try fixture.repositoryIdentity(excluding: excluded)
                    },
                    policy: fixture.policy,
                )
                Issue.record("Repository identity changed during import")
            } catch let error as FactoryValidationError {
                #expect(error.code == "patch_repository_changed")
            }

            #expect(injected)
            #expect(try RepositoryTree.capture(at: fixture.repository, paths: paths) == original)
            #expect(try String(contentsOf: unrelated, encoding: .utf8) == "concurrent change\n")
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))
        }
    }

    @Test("A target mutation during final identity validation quarantines the import")
    func finalTargetMutationRace() throws {
        try withFixture { fixture in
            let envelope = try fixture.validEnvelope()
            let paths = envelope.operations.map(\.path)
            let original = try RepositoryTree.capture(at: fixture.repository, paths: paths)
            let created = fixture.url("Sources/New.swift")
            var injected = false

            do {
                _ = try PatchImporter.apply(
                    envelope,
                    authoritativeRoot: fixture.repository,
                    contentRoot: fixture.scratch,
                    recoveryRoot: fixture.recovery,
                    repositoryIdentity: { excluded in
                        if !injected, FileManager.default.fileExists(atPath: created.path) {
                            try Data("attacker bytes\n".utf8).write(to: created)
                            #expect(Darwin.chmod(created.path, 0o644) == 0)
                            injected = true
                        }
                        return try fixture.repositoryIdentity(excluding: excluded)
                    },
                    policy: fixture.policy,
                )
                Issue.record("An envelope-owned file changed during final validation")
            } catch let error as FactoryValidationError {
                #expect(error.code == "patch_import_quarantined")
            }

            #expect(injected)
            #expect(try RepositoryTree.capture(at: fixture.repository, paths: paths) != original)
            #expect(try String(contentsOf: created, encoding: .utf8) == "attacker bytes\n")
            #expect(try PatchImporter.hasPendingRecovery(at: fixture.recovery))
        }
    }

    @Test("A target mutation after durable completion stays journaled and quarantined")
    func postCompletionTargetMutationRace() throws {
        try withFixture { fixture in
            let envelope = try fixture.validEnvelope()
            let created = fixture.url("Sources/New.swift")
            var injected = false

            do {
                _ = try PatchImporter.apply(
                    envelope,
                    authoritativeRoot: fixture.repository,
                    contentRoot: fixture.scratch,
                    recoveryRoot: fixture.recovery,
                    repositoryIdentity: { excluded in
                        if !injected,
                           try PatchRecoveryJournal.load(at: fixture.recovery)?.state == .completed
                        {
                            try Data("attacker bytes\n".utf8).write(to: created)
                            #expect(Darwin.chmod(created.path, 0o644) == 0)
                            injected = true
                        }
                        return try fixture.repositoryIdentity(excluding: excluded)
                    },
                    policy: fixture.policy,
                )
                Issue.record("A completed transaction returned success after its output changed")
            } catch let error as FactoryValidationError {
                #expect(error.code == "patch_import_quarantined")
            }

            #expect(injected)
            #expect(try String(contentsOf: created, encoding: .utf8) == "attacker bytes\n")
            #expect(try PatchImporter.hasPendingRecovery(at: fixture.recovery))
            #expect(try PatchRecoveryJournal.load(at: fixture.recovery)?.state == .completed)
        }
    }

    @Test("Authoritative roots, directories, and files reject extended ACL authority")
    func authoritativeACLDenials() throws {
        try withFixture { fixture in
            let envelope = try fixture.validEnvelope()
            try addPatchAccessControl("everyone allow add_file,delete_child", to: fixture.repository)
            #expect(throws: FactoryValidationError.self) {
                try fixture.apply(envelope)
            }
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))
            #expect(try fixture.read("Sources/Old.swift") == "let oldValue = 1\n")
        }

        try withFixture { fixture in
            let envelope = try fixture.validEnvelope()
            try addPatchAccessControl("everyone allow add_file,delete_child", to: fixture.url("Sources"))
            #expect(throws: FactoryValidationError.self) {
                try fixture.apply(envelope)
            }
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))
            #expect(try fixture.read("Sources/Old.swift") == "let oldValue = 1\n")
        }

        try withFixture { fixture in
            let envelope = try fixture.validEnvelope()
            try addPatchAccessControl("everyone allow write", to: fixture.url("Sources/Old.swift"))
            #expect(throws: FactoryValidationError.self) {
                try fixture.apply(envelope)
            }
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))
            #expect(try fixture.read("Sources/Old.swift") == "let oldValue = 1\n")
        }
    }

    @Test("The installed authoritative lock cannot change while held")
    func authoritativeLockIdentitySwap() throws {
        try withFixture { fixture in
            let lockURL = try AuthoritativePatchLock.lockURL(for: fixture.repository)
            let displaced = lockURL.appendingPathExtension("displaced")
            do {
                try AuthoritativePatchLock.withExclusiveLock(at: fixture.repository) {
                    try FileManager.default.moveItem(at: lockURL, to: displaced)
                    let replacement = Darwin.open(
                        lockURL.path,
                        O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC,
                        0o600,
                    )
                    #expect(replacement >= 0)
                    if replacement >= 0 { Darwin.close(replacement) }
                }
                Issue.record("Replacing the installed authoritative lock was accepted")
            } catch let error as FactoryValidationError {
                #expect(error.code == "authoritative_lock_changed")
            }
        }
    }

    @Test("The authoritative lock rejects extended ACL authority")
    func authoritativeLockACL() throws {
        try withFixture { fixture in
            try AuthoritativePatchLock.withExclusiveLock(at: fixture.repository) {}
            let lockURL = try AuthoritativePatchLock.lockURL(for: fixture.repository)
            try addPatchAccessControl("everyone allow write", to: lockURL)
            #expect(throws: FactoryValidationError.self) {
                try AuthoritativePatchLock.withExclusiveLock(at: fixture.repository) {}
            }
        }
    }

    @Test("A prepared journal recovers an exact tree after simulated process death")
    func crashRecovery() throws {
        try withFixture { fixture in
            let original = try RepositoryTree.capture(at: fixture.repository)
            #expect(throws: FactoryValidationError.self) {
                try fixture.apply(
                    fixture.validEnvelope(),
                    fault: PatchImportFault(simulateProcessDeathAfterAppliedOperation: 1),
                )
            }
            #expect(try PatchImporter.hasPendingRecovery(at: fixture.recovery))
            #expect(try RepositoryTree.capture(at: fixture.repository) != original)
            #expect(throws: FactoryValidationError.self) {
                try fixture.apply(fixture.validEnvelope())
            }

            let result = try PatchImporter.recover(
                authoritativeRoot: fixture.repository,
                recoveryRoot: fixture.recovery,
            )
            #expect(result == .restoredPreparedTransaction)
            #expect(try RepositoryTree.capture(at: fixture.repository) == original)
            #expect(try !PatchImporter.hasPendingRecovery(at: fixture.recovery))
        }
    }
}
