import Darwin
import Foundation
import Testing
@testable import FactoryCore

@Suite("Private filesystem ACL authority")
struct PrivateFilesystemACLTests {
    @Test("Scratch projection rejects ACL authority on its source root")
    func projectionSourceRootACL() throws {
        try withBase { base in
            let source = try makeSource(at: base.appending(path: "source"))
            try addEvaluationACL("everyone allow list,search,add_file,delete_child", to: source)

            #expect(throws: FactoryValidationError.self) {
                _ = try ScratchProjectionBuilder.sourceIdentity(at: source)
            }
        }
    }

    @Test("Scratch projection rejects ACL authority on an input file")
    func projectionInputACL() throws {
        try withBase { base in
            let source = try makeSource(at: base.appending(path: "source"))
            let input = source.appending(path: "Sources/Allowed.swift")
            try addEvaluationACL("everyone allow write", to: input)
            let plan = try projectionPlan(
                source: source,
                destination: base.appending(path: "projection"),
            )

            #expect(throws: FactoryValidationError.self) {
                _ = try ScratchProjectionBuilder.build(plan)
            }
        }
    }

    @Test("Scratch projection rejects ACL authority on its destination parent")
    func projectionDestinationParentACL() throws {
        try withBase { base in
            let source = try makeSource(at: base.appending(path: "source"))
            let parent = base.appending(path: "destination-parent")
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
            #expect(Darwin.chmod(parent.path, 0o700) == 0)
            try addEvaluationACL(
                "everyone allow list,search,add_file,add_subdirectory,delete_child",
                to: parent,
            )
            let plan = try projectionPlan(
                source: source,
                destination: parent.appending(path: "projection"),
            )

            #expect(throws: FactoryValidationError.self) {
                _ = try ScratchProjectionBuilder.build(plan)
            }
        }
    }

    @Test("Private evaluation scaffold rejects ACL authority on its parent")
    func evaluationScaffoldParentACL() throws {
        try withBase { base in
            let parent = base.appending(path: "scaffold-parent")
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
            #expect(Darwin.chmod(parent.path, 0o700) == 0)
            try addEvaluationACL(
                "everyone allow list,search,add_file,add_subdirectory,delete_child",
                to: parent,
            )
            let manifest = try scaffoldManifest()

            #expect(throws: FactoryValidationError.self) {
                _ = try PrivateEvaluationScaffold.generate(
                    at: parent.appending(path: "scaffold"),
                    manifest: manifest,
                )
            }
        }
    }

    @Test("Private evaluation scaffold revalidates ACL authority before return")
    func evaluationScaffoldFinalACLValidation() throws {
        try withBase { base in
            let root = base.appending(path: "scaffold")
            let manifest = try scaffoldManifest()
            #expect(throws: FactoryValidationError.self) {
                _ = try PrivateEvaluationScaffold.generate(
                    at: root,
                    manifest: manifest,
                    afterMetadataCreated: {
                        try addEvaluationACL(
                            "everyone allow list,search,add_file,add_subdirectory,delete_child",
                            to: root,
                        )
                    },
                )
            }
            #expect(!FileManager.default.fileExists(atPath: root.path))
        }
    }

    private func projectionPlan(source: URL, destination: URL) throws -> ScratchProjectionPlan {
        try ScratchProjectionPlan(
            invocationID: "acl-denial",
            sourceRoot: source,
            destinationRoot: destination,
            sourcePaths: [RepositoryPath(validating: "Sources/Allowed.swift")],
            sourceIdentity: ScratchProjectionBuilder.sourceIdentity(at: source),
            deniedRoots: [source.deletingLastPathComponent().appending(path: "owner-home")],
        )
    }

    private func makeSource(at source: URL) throws -> URL {
        let input = source.appending(path: "Sources/Allowed.swift")
        try FileManager.default.createDirectory(
            at: input.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try Data("let value = 1\n".utf8).write(to: input)
        #expect(Darwin.chmod(source.path, 0o700) == 0)
        #expect(Darwin.chmod(input.path, 0o644) == 0)
        return source
    }

    private func scaffoldManifest() throws -> PrivateEvaluationRootManifest {
        let fixture = try EvaluationFixture()
        return try PrivateEvaluationRootManifest(
            acceptanceSHA256: fixture.policy.digest,
            casesPresent: false,
            epochZeroFrozen: false,
            evaluatorCodePresent: false,
            schemaDigests: [SchemaDigest(schemaID: "private-evaluation-case", sha256: TestValues.contract)],
            trustedRootSHA: TestValues.head,
        )
    }

    private func withBase(_ body: (URL) throws -> Void) throws {
        let base = TestValues.temporaryDirectory
            .appending(path: "factory-private-acl-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
        #expect(Darwin.chmod(base.path, 0o700) == 0)
        defer { try? FileManager.default.removeItem(at: base) }
        try body(base)
    }
}
