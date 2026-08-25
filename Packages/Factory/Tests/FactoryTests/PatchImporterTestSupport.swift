import struct CryptoKit.SHA256
import Darwin
import Foundation
import Testing
@testable import FactoryCore

extension PatchImporterTests {
    func addPatchAccessControl(_ rule: String, to url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+a", rule, url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FactoryValidationError(
                code: "test_fixture_acl",
                message: "Could not install the patch ACL denial fixture.",
            )
        }
    }

    func expectIncompleteGeneratedProvenance() {
        #expect(!AssetProvenance(
            generator: "",
            license: "",
            model: "",
            ownerApproval: .approved,
            promptSHA256: TestValues.context,
            sourceClass: .generated,
            sourceSHA256: nil,
        ).isComplete)
    }

    func expectBeforeMismatchAndDuplicateDenied(
        fixture: PatchFixture,
        original: RepositoryTree,
    ) throws {
        var beforeMismatch = try fixture.validEnvelope()
        let update = beforeMismatch.operations[2]
        beforeMismatch.operations[2] = PatchFileOperation(
            operationID: update.operationID,
            path: update.path,
            kind: update.kind,
            before: .regular(
                FileExpectation(
                    sha256: SHA256Digest.hashing(Data("wrong".utf8)),
                    bytes: 5,
                    executable: false,
                ),
            ),
            after: update.after,
        )
        try expectRejected(beforeMismatch, fixture: fixture, original: original)

        var duplicate = try fixture.validEnvelope()
        duplicate.operations.append(duplicate.operations[2])
        try expectRejected(duplicate, fixture: fixture, original: original)
    }

    func expectAncestryAliasDenied(fixture: PatchFixture, original: RepositoryTree) throws {
        let bytes = Data("alias\n".utf8)
        let contentRef = try fixture.writeContent(id: "alias", data: bytes)
        let paths = try ["Sources/a", "Sources/a-else", "Sources/a/b"].map(RepositoryPath.init(validating:))
        let envelope = try fixture.envelope(
            operations: paths.enumerated().map { index, path in
                PatchFileOperation(
                    operationID: "alias-\(index)",
                    path: path,
                    kind: .create,
                    before: .absent,
                    after: .regular(
                        PatchFilePayload(
                            expectation: FileExpectation(data: bytes, executable: false),
                            contentRef: contentRef,
                            contentKind: .text,
                            assetProvenance: nil,
                        ),
                    ),
                )
            },
            envelopeID: "envelope-ancestry-alias",
        )
        try expectRejected(envelope, fixture: fixture, original: original)
    }

    func expectTextBinaryDenied(fixture: PatchFixture, original: RepositoryTree) throws {
        let bytes = Data([0, 1, 2, 3])
        let contentRef = try fixture.writeContent(id: "binary", data: bytes)
        let envelope = try fixture.envelope(
            operations: [
                PatchFileOperation(
                    operationID: "binary",
                    path: RepositoryPath(validating: "Sources/blob.bin"),
                    kind: .create,
                    before: .absent,
                    after: .regular(
                        PatchFilePayload(
                            expectation: FileExpectation(data: bytes, executable: false),
                            contentRef: contentRef,
                            contentKind: .text,
                            assetProvenance: nil,
                        ),
                    ),
                ),
            ],
            envelopeID: "envelope-binary",
        )
        try expectRejected(envelope, fixture: fixture, original: original)
    }

    func expectSymlinkTargetDenied(fixture: PatchFixture) throws {
        let expectedTreeSHA = try fixture.repositoryIdentity().tree
        let symlink = fixture.url("Sources/Linked.swift")
        try FileManager.default.createSymbolicLink(
            at: symlink,
            withDestinationURL: fixture.url("Sources/Old.swift"),
        )
        let bytes = Data("replace\n".utf8)
        let contentRef = try fixture.writeContent(id: "symlink", data: bytes)
        let envelope = try fixture.envelope(
            operations: [
                PatchFileOperation(
                    operationID: "symlink",
                    path: RepositoryPath(validating: "Sources/Linked.swift"),
                    kind: .update,
                    before: .regular(
                        FileExpectation(data: Data("let oldValue = 1\n".utf8), executable: false),
                    ),
                    after: .regular(
                        PatchFilePayload(
                            expectation: FileExpectation(data: bytes, executable: false),
                            contentRef: contentRef,
                            contentKind: .text,
                            assetProvenance: nil,
                        ),
                    ),
                ),
            ],
            envelopeID: "envelope-symlink",
            expectedTreeSHA: expectedTreeSHA,
        )
        #expect(throws: FactoryValidationError.self) {
            try fixture.apply(envelope)
        }
    }

    func expectRejected(
        _ envelope: PatchEnvelope,
        fixture: PatchFixture,
        original: RepositoryTree,
    ) throws {
        #expect(throws: FactoryValidationError.self) {
            try fixture.apply(envelope)
        }
        #expect(try RepositoryTree.capture(at: fixture.repository) == original)
    }

    func withFixture(_ body: (PatchFixture) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "factory-patch-\(UUID().uuidString)", directoryHint: .isDirectory)
        let repository = root.appending(path: "repository", directoryHint: .isDirectory)
        let scratch = root.appending(path: "scratch", directoryHint: .isDirectory)
        let recovery = root.appending(path: "recovery", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: repository.appending(path: "Sources"),
            withIntermediateDirectories: true,
        )
        try FileManager.default.createDirectory(
            at: scratch.appending(path: "output/files"),
            withIntermediateDirectories: true,
        )
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        #expect(Darwin.chmod(recovery.path, 0o700) == 0)
        let oldFile = repository.appending(path: "Sources/Old.swift")
        let deleteFile = repository.appending(path: "Sources/Delete.swift")
        try Data("let oldValue = 1\n".utf8).write(to: oldFile)
        try Data("delete me\n".utf8).write(to: deleteFile)
        #expect(Darwin.chmod(oldFile.path, 0o644) == 0)
        #expect(Darwin.chmod(deleteFile.path, 0o644) == 0)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(PatchFixture(repository: repository, scratch: scratch, recovery: recovery))
    }

    func writeSparseFile(at url: URL, bytes: Int) throws -> SHA256Digest {
        let fd = Darwin.open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o644)
        guard fd >= 0 else {
            throw FactoryValidationError(code: "sparse_fixture", message: "Could not create sparse fixture.")
        }
        defer { Darwin.close(fd) }
        guard Darwin.ftruncate(fd, off_t(bytes)) == 0,
              Darwin.fchmod(fd, 0o644) == 0
        else {
            throw FactoryValidationError(code: "sparse_fixture", message: "Could not size sparse fixture.")
        }

        var hasher = CryptoKit.SHA256()
        let chunk = Data(repeating: 0, count: 64 * 1024)
        var remaining = bytes
        while remaining > 0 {
            let count = min(remaining, chunk.count)
            hasher.update(data: chunk.prefix(count))
            remaining -= count
        }
        let raw = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return try SHA256Digest(validating: raw)
    }

    func fileSize(at url: URL) -> Int {
        var metadata = stat()
        guard Darwin.lstat(url.path, &metadata) == 0 else { return -1 }
        return Int(metadata.st_size)
    }

    func makeAssetEnvelope(
        id: String,
        path: RepositoryPath,
        contentRef: RepositoryPath,
        data: Data,
        provenance: AssetProvenance,
        policy: PatchImportPolicy,
    ) -> PatchEnvelope {
        PatchEnvelope(
            contractSHA256: TestValues.contract,
            envelopeID: id,
            expectedBaseSHA: TestValues.head,
            expectedTreeSHA: TestValues.nextHead,
            invocationID: "invocation-1",
            operations: [
                PatchFileOperation(
                    operationID: id,
                    path: path,
                    kind: .create,
                    before: .absent,
                    after: .regular(
                        PatchFilePayload(
                            expectation: FileExpectation(data: data, executable: false),
                            contentRef: contentRef,
                            contentKind: .asset,
                            assetProvenance: provenance,
                        ),
                    ),
                ),
            ],
            policySHA256: policy.digest,
            projectionSHA256: TestValues.context,
            runID: "run-1",
        )
    }

    func applyAsset(
        _ envelope: PatchEnvelope,
        fixture: PatchFixture,
        policy: PatchImportPolicy,
    ) throws -> PatchImportReceipt {
        try PatchImporter.apply(
            envelope,
            authoritativeRoot: fixture.repository,
            contentRoot: fixture.scratch,
            recoveryRoot: fixture.recovery,
            repositoryIdentity: { _ in (TestValues.head, TestValues.nextHead) },
            policy: policy,
        )
    }
}

struct PatchFixture {
    let repository: URL
    let scratch: URL
    let recovery: URL
    let policy: PatchImportPolicy

    init(repository: URL, scratch: URL, recovery: URL) throws {
        self.repository = repository
        self.scratch = scratch
        self.recovery = recovery
        policy = try PatchImportPolicy(
            purpose: .product,
            contractSHA256: TestValues.contract,
            expectedInvocationID: "invocation-1",
            expectedRunID: "run-1",
            projectionSHA256: TestValues.context,
            allowedRoots: [RepositoryPath(validating: "Sources")],
            approvedAssetExtensions: ["png"],
            maximumOperations: 10,
            maximumTotalBytes: 1_000_000,
        )
    }

    func validEnvelope(expectedTreeSHA: GitObjectID? = nil) throws -> PatchEnvelope {
        let created = Data("let newValue = 2\n".utf8)
        let updated = Data("let oldValue = 2\n".utf8)
        let createRef = try writeContent(id: "create", data: created)
        let updateRef = try writeContent(id: "update", data: updated)
        return try envelope(
            operations: [
                PatchFileOperation(
                    operationID: "delete",
                    path: RepositoryPath(validating: "Sources/Delete.swift"),
                    kind: .delete,
                    before: .regular(FileExpectation(data: Data("delete me\n".utf8), executable: false)),
                    after: .deleted,
                ),
                PatchFileOperation(
                    operationID: "create",
                    path: RepositoryPath(validating: "Sources/New.swift"),
                    kind: .create,
                    before: .absent,
                    after: .regular(
                        PatchFilePayload(
                            expectation: FileExpectation(data: created, executable: false),
                            contentRef: createRef,
                            contentKind: .text,
                            assetProvenance: nil,
                        ),
                    ),
                ),
                PatchFileOperation(
                    operationID: "update",
                    path: RepositoryPath(validating: "Sources/Old.swift"),
                    kind: .update,
                    before: .regular(
                        FileExpectation(data: Data("let oldValue = 1\n".utf8), executable: false),
                    ),
                    after: .regular(
                        PatchFilePayload(
                            expectation: FileExpectation(data: updated, executable: false),
                            contentRef: updateRef,
                            contentKind: .text,
                            assetProvenance: nil,
                        ),
                    ),
                ),
            ],
            expectedTreeSHA: expectedTreeSHA,
        )
    }

    func envelope(
        operations: [PatchFileOperation],
        envelopeID: String = "envelope-1",
        expectedTreeSHA: GitObjectID? = nil,
    ) throws -> PatchEnvelope {
        try PatchEnvelope(
            contractSHA256: TestValues.contract,
            envelopeID: envelopeID,
            expectedBaseSHA: TestValues.head,
            expectedTreeSHA: expectedTreeSHA ?? repositoryIdentity().tree,
            invocationID: "invocation-1",
            operations: operations,
            policySHA256: policy.digest,
            projectionSHA256: TestValues.context,
            runID: "run-1",
        )
    }

    func apply(
        _ envelope: PatchEnvelope,
        fault: PatchImportFault = PatchImportFault(),
    ) throws -> PatchImportReceipt {
        try PatchImporter.apply(
            envelope,
            authoritativeRoot: repository,
            contentRoot: scratch,
            recoveryRoot: recovery,
            repositoryIdentity: repositoryIdentity,
            policy: policy,
            fault: fault,
        )
    }

    func repositoryIdentity(
        excluding paths: [RepositoryPath] = [],
    ) throws -> (base: GitObjectID, tree: GitObjectID) {
        let excludedKeys = Set(paths.map(\.collisionKey))
        let captured = try RepositoryTree.capture(at: repository.appending(path: "Sources"))
        let files = captured.files.filter { file in
            !excludedKeys.contains("sources/\(file.path.collisionKey)")
        }
        let digest = CanonicalJSON.digest(files)
        let tree = try GitObjectID(validating: digest.rawValue)
        return (TestValues.head, tree)
    }

    func writeContent(id: String, data: Data) throws -> RepositoryPath {
        let path = try RepositoryPath(validating: "output/files/\(id)")
        try data.write(to: scratch.appending(path: path.rawValue), options: .atomic)
        return path
    }

    func url(_ path: String) -> URL {
        repository.appending(path: path)
    }

    func read(_ path: String) throws -> String {
        try String(contentsOf: url(path), encoding: .utf8)
    }
}
