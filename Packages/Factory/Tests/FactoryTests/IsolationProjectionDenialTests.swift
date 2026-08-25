import Darwin
import Foundation
import Testing
@testable import FactoryCore

extension IsolationTests {
    @Test("Scratch projection rejects symlinks, hard links, and sensitive destinations")
    func scratchProjectionDenials() throws {
        try withTemporaryRoots { source, destination in
            let regular = try makeRegularScratchSource(at: source)
            try expectInvalidInvocationIDDenied(source: source, destination: destination)
            try expectSensitiveSourceDenied(source: source, destination: destination)
            try expectSymlinkDenied(regular: regular, source: source, destination: destination)
            try expectHardLinkDenied(regular: regular, source: source, destination: destination)
            try expectSensitiveDestinationDenied(source: source)
            try expectFileBudgetDenied(source: source, destination: destination)
            try expectSourceIdentityRaceDenied(source: source, destination: destination)
        }
    }

    private func makeRegularScratchSource(at source: URL) throws -> URL {
        let regular = source.appending(path: "Sources/Regular.swift")
        try FileManager.default.createDirectory(
            at: regular.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try Data("safe".utf8).write(to: regular)
        #expect(Darwin.chmod(regular.path, 0o644) == 0)
        return regular
    }

    private func expectInvalidInvocationIDDenied(source: URL, destination: URL) throws {
        #expect(throws: FactoryValidationError.self) {
            try ScratchProjectionBuilder.build(
                ScratchProjectionPlan(
                    invocationID: "Invocation-1",
                    sourceRoot: source,
                    destinationRoot: destination.deletingLastPathComponent()
                        .appending(path: "projection-uppercase-id"),
                    sourcePaths: [RepositoryPath(validating: "Sources/Regular.swift")],
                    sourceIdentity: ScratchProjectionBuilder.sourceIdentity(at: source),
                    deniedRoots: [source.deletingLastPathComponent().appending(path: "owner-home")],
                ),
            )
        }
    }

    private func expectSensitiveSourceDenied(source: URL, destination: URL) throws {
        #expect(throws: FactoryValidationError.self) {
            try ScratchProjectionBuilder.build(
                ScratchProjectionPlan(
                    invocationID: "invocation-sensitive-source",
                    sourceRoot: source,
                    destinationRoot: destination.deletingLastPathComponent()
                        .appending(path: "projection-sensitive-source"),
                    sourcePaths: [RepositoryPath(validating: "Sources/Regular.swift")],
                    sourceIdentity: ScratchProjectionBuilder.sourceIdentity(at: source),
                    deniedRoots: [source],
                ),
            )
        }
    }

    private func expectSymlinkDenied(regular: URL, source: URL, destination: URL) throws {
        let symlink = source.appending(path: "Sources/Link.swift")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: regular)
        #expect(throws: FactoryValidationError.self) {
            try ScratchProjectionBuilder.build(
                ScratchProjectionPlan(
                    invocationID: "invocation-symlink",
                    sourceRoot: source,
                    destinationRoot: destination,
                    sourcePaths: [RepositoryPath(validating: "Sources/Link.swift")],
                    sourceIdentity: ScratchProjectionBuilder.sourceIdentity(at: source),
                    deniedRoots: [source.deletingLastPathComponent().appending(path: "owner-home")],
                ),
            )
        }
    }

    private func expectHardLinkDenied(regular: URL, source: URL, destination: URL) throws {
        let hardLink = source.appending(path: "Sources/Hard.swift")
        #expect(Darwin.link(regular.path, hardLink.path) == 0)
        #expect(throws: FactoryValidationError.self) {
            try ScratchProjectionBuilder.build(
                ScratchProjectionPlan(
                    invocationID: "invocation-hardlink",
                    sourceRoot: source,
                    destinationRoot: destination.deletingLastPathComponent().appending(path: "projection-hard"),
                    sourcePaths: [RepositoryPath(validating: "Sources/Hard.swift")],
                    sourceIdentity: ScratchProjectionBuilder.sourceIdentity(at: source),
                    deniedRoots: [source.deletingLastPathComponent().appending(path: "owner-home")],
                ),
            )
        }
    }

    private func expectSensitiveDestinationDenied(source: URL) throws {
        #expect(throws: FactoryValidationError.self) {
            try ScratchProjectionBuilder.build(
                ScratchProjectionPlan(
                    invocationID: "invocation-sensitive",
                    sourceRoot: source,
                    destinationRoot: source.appending(path: "nested-projection"),
                    sourcePaths: [RepositoryPath(validating: "Sources/Regular.swift")],
                    sourceIdentity: ScratchProjectionBuilder.sourceIdentity(at: source),
                    deniedRoots: [source.deletingLastPathComponent().appending(path: "owner-home")],
                ),
            )
        }
    }

    private func expectFileBudgetDenied(source: URL, destination: URL) throws {
        let budgetDestination = destination.deletingLastPathComponent().appending(path: "projection-budget")
        #expect(throws: FactoryValidationError.self) {
            try ScratchProjectionBuilder.build(
                ScratchProjectionPlan(
                    invocationID: "invocation-budget",
                    sourceRoot: source,
                    destinationRoot: budgetDestination,
                    sourcePaths: [RepositoryPath(validating: "Sources/Regular.swift")],
                    sourceIdentity: ScratchProjectionBuilder.sourceIdentity(at: source),
                    deniedRoots: [source.deletingLastPathComponent().appending(path: "owner-home")],
                    maximumFileBytes: 1,
                ),
            )
        }
        #expect(!FileManager.default.fileExists(atPath: budgetDestination.path))
    }

    private func expectSourceIdentityRaceDenied(source: URL, destination: URL) throws {
        let identity = try ScratchProjectionBuilder.sourceIdentity(at: source)
        #expect(throws: FactoryValidationError.self) {
            try ScratchProjectionBuilder.build(
                ScratchProjectionPlan(
                    invocationID: "invocation-source-race",
                    sourceRoot: source,
                    destinationRoot: destination.deletingLastPathComponent()
                        .appending(path: "projection-source-race"),
                    sourcePaths: [RepositoryPath(validating: "Sources/Regular.swift")],
                    sourceIdentity: ScratchSourceIdentity(
                        device: identity.device,
                        inode: identity.inode + 1,
                        ownerUID: identity.ownerUID,
                    ),
                    deniedRoots: [source.deletingLastPathComponent().appending(path: "owner-home")],
                ),
            )
        }
    }
}
