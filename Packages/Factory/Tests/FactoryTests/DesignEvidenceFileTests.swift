import Darwin
import Foundation
import Testing
@testable import FactoryCore

@Suite("External design evidence files")
struct DesignEvidenceFileTests {
    @Test("Descriptor reads reject a detached parent directory")
    func detachedParentDirectoryIsRejected() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "factory-design-parent-race-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let installedDirectory = root.appending(path: "docs/design", directoryHint: .isDirectory)
        let detachedDirectory = root.appending(path: "docs/detached", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: installedDirectory, withIntermediateDirectories: true)
        #expect(chmod(root.path, 0o700) == 0)
        let installedFile = installedDirectory.appending(path: "evidence.bin")
        try Data("verified-old-bytes".utf8).write(to: installedFile, options: .withoutOverwriting)
        #expect(chmod(installedFile.path, 0o600) == 0)

        let rootFD = try SecureRepositoryFileSystem.openDirectory(root)
        defer { Darwin.close(rootFD) }
        let path = try RepositoryPath(validating: "docs/design/evidence.bin")
        #expect(throws: FactoryValidationError.self) {
            try SecureRepositoryFileSystem.readRegularFile(
                rootFD: rootFD,
                path: path,
                allowedModes: [0o600],
                maximumBytes: 1024,
                beforeRootIdentityValidation: {
                    try FileManager.default.moveItem(at: installedDirectory, to: detachedDirectory)
                    try FileManager.default.moveItem(at: detachedDirectory, to: installedDirectory)
                },
            )
        }
        #expect(throws: FactoryValidationError.self) {
            try SecureRepositoryFileSystem.readRegularFileSnapshot(
                rootFD: rootFD,
                path: path,
                allowedModes: [0o600],
                maximumBytes: 1024,
                afterDirectoryIdentityCapture: {
                    try FileManager.default.moveItem(at: installedDirectory, to: detachedDirectory)
                    try FileManager.default.moveItem(at: detachedDirectory, to: installedDirectory)
                },
            )
        }
    }

    @Test("Design inspection is read-only outside the repository")
    func verificationNeedsNoWritableParent() throws {
        let container = FileManager.default.temporaryDirectory
            .appending(path: "factory-design-read-only-\(UUID().uuidString)", directoryHint: .isDirectory)
        let root = container.appending(path: "repository", directoryHint: .isDirectory)
        defer {
            _ = chmod(container.path, 0o700)
            try? FileManager.default.removeItem(at: container)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        #expect(chmod(container.path, 0o500) == 0)
        #expect(chmod(root.path, 0o700) == 0)
        let sourceURL = root.appending(path: "source.png")
        let sourceBytes = Data("owner-source-image".utf8)
        try sourceBytes.write(to: sourceURL, options: .withoutOverwriting)
        #expect(chmod(sourceURL.path, 0o600) == 0)
        let source = try DesignSourceManifest(
            sourceID: "image-source",
            kind: .screenshot,
            authority: .canonical,
            contentSHA256: SHA256Digest.hashing(sourceBytes),
            sourceVersion: "owner-v1",
            origin: "owner-supplied",
            rights: .ownerProvided,
            sensitivity: .privateReference,
            ingestionMode: .inspectOnly,
            viewports: [DesignViewport(id: "desktop", width: 1440, height: 900, scale: 2)],
            stateIDs: ["rest"],
            assetPaths: [RepositoryPath(validating: "source.png")],
            evidenceArtifacts: [],
            videoEvidenceGaps: [],
            videoAnalysis: nil,
        )

        try DesignEvidenceFileVerifier.verify(source, repositoryRoot: root)
        #expect(try FileManager.default.contentsOfDirectory(atPath: container.path) == ["repository"])
    }

    @Test("Descriptor reads bind returned bytes to final file metadata")
    func inPlaceRewriteIsRejected() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "factory-design-file-race-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        #expect(chmod(root.path, 0o700) == 0)
        let file = root.appending(path: "evidence.bin")
        try Data("verified-bytes".utf8).write(to: file, options: .withoutOverwriting)
        #expect(chmod(file.path, 0o600) == 0)

        let rootFD = try SecureRepositoryFileSystem.openDirectory(root)
        defer { Darwin.close(rootFD) }
        #expect(throws: FactoryValidationError.self) {
            try SecureRepositoryFileSystem.readRegularFile(
                rootFD: rootFD,
                path: RepositoryPath(validating: "evidence.bin"),
                allowedModes: [0o600],
                maximumBytes: 1024,
                beforeRootIdentityValidation: {
                    try Data("changed--bytes".utf8).write(to: file)
                },
            )
        }
    }

    @Test("Descriptor reads enforce their deadline between chunks")
    func chunkDeadlineIsEnforced() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "factory-design-deadline-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        #expect(chmod(root.path, 0o700) == 0)
        let file = root.appending(path: "evidence.bin")
        try Data(repeating: 0x41, count: 128 * 1024).write(to: file, options: .withoutOverwriting)
        #expect(chmod(file.path, 0o600) == 0)

        let rootFD = try SecureRepositoryFileSystem.openDirectory(root)
        defer { Darwin.close(rootFD) }
        var deadlineChecks = 0
        #expect(throws: FactoryValidationError.self) {
            try SecureRepositoryFileSystem.readRegularFileSnapshot(
                rootFD: rootFD,
                path: RepositoryPath(validating: "evidence.bin"),
                allowedModes: [0o600],
                maximumBytes: 128 * 1024,
                deadlineCheck: {
                    deadlineChecks += 1
                    return deadlineChecks < 3
                },
            )
        }
        #expect(deadlineChecks == 3)
    }

    @Test("Special-file sources reject without a blocking open")
    func fifoSourceIsRejected() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "factory-design-fifo-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        #expect(chmod(root.path, 0o700) == 0)
        let fifo = root.appending(path: "source.png")
        #expect(mkfifo(fifo.path, 0o600) == 0)

        #expect(throws: FactoryValidationError.self) {
            try DesignEvidenceFileVerifier.verify(
                imageSource(contentSHA256: TestValues.evidence),
                repositoryRoot: root,
            )
        }
    }

    @Test("Final identity validation cannot outlive the total deadline")
    func finalIdentityDeadlineIsEnforced() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "factory-design-final-deadline-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        #expect(chmod(root.path, 0o700) == 0)
        let sourceBytes = Data("owner-source-image".utf8)
        let sourceURL = root.appending(path: "source.png")
        try sourceBytes.write(to: sourceURL, options: .withoutOverwriting)
        #expect(chmod(sourceURL.path, 0o600) == 0)
        var currentTime = ContinuousClock().now

        do {
            try DesignEvidenceFileVerifier.verify(
                imageSource(contentSHA256: SHA256Digest.hashing(sourceBytes)),
                repositoryRoot: root,
                maximumTotalBytes: sourceBytes.count,
                now: { currentTime },
                beforeFinalIdentityValidation: { _ in
                    currentTime = currentTime.advanced(by: .seconds(31))
                },
                afterRead: { _ in },
            )
            Issue.record("Verification accepted an identity check that crossed its total deadline.")
        } catch let error as FactoryValidationError {
            #expect(error.code == "design-verification-timeout")
        }
    }

    @Test("Final identity validation rejects a FIFO replacement without blocking")
    func finalIdentityFIFOReplacementIsRejected() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "factory-design-final-fifo-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        #expect(chmod(root.path, 0o700) == 0)
        let sourceBytes = Data("owner-source-image".utf8)
        let sourceURL = root.appending(path: "source.png")
        try sourceBytes.write(to: sourceURL, options: .withoutOverwriting)
        #expect(chmod(sourceURL.path, 0o600) == 0)
        var installedFIFO = false

        do {
            try DesignEvidenceFileVerifier.verify(
                imageSource(contentSHA256: SHA256Digest.hashing(sourceBytes)),
                repositoryRoot: root,
                maximumTotalBytes: sourceBytes.count,
                beforeFinalIdentityValidation: { _ in
                    try installFIFOReplacement(at: sourceURL)
                    installedFIFO = true
                },
                afterRead: { _ in },
            )
            Issue.record("Verification accepted a FIFO replacement during final identity validation.")
        } catch let error as FactoryValidationError {
            #expect(installedFIFO)
            #expect(error.code == "repository_path_changed")
        }
    }

    @Test("CLI binds design artifacts to descriptor-read repository bytes")
    func artifactBytesAreVerified() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "factory-design-evidence-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let evidenceRoot = root.appending(path: "docs/design/video-source", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: evidenceRoot, withIntermediateDirectories: true)
        #expect(chmod(root.path, 0o700) == 0)

        let contactPath = evidenceRoot.appending(path: "contact-sheet.png")
        let metadataPath = evidenceRoot.appending(path: "metadata.json")
        let sourcePath = evidenceRoot.appending(path: "source.mov")
        let contact = Data("static-contact-sheet".utf8)
        let metadata = Data("static-metadata".utf8)
        let sourceBytes = Data("owner-source-video".utf8)
        try contact.write(to: contactPath, options: .withoutOverwriting)
        try metadata.write(to: metadataPath, options: .withoutOverwriting)
        try sourceBytes.write(to: sourcePath, options: .withoutOverwriting)
        #expect(chmod(contactPath.path, 0o600) == 0)
        #expect(chmod(metadataPath.path, 0o600) == 0)
        #expect(chmod(sourcePath.path, 0o600) == 0)

        let source = try partialSource(sourceBytes: sourceBytes, contact: contact, metadata: metadata)
        var boundedReads: [RepositoryPath] = []
        #expect(throws: FactoryValidationError.self) {
            try DesignEvidenceFileVerifier.verify(
                source,
                repositoryRoot: root,
                maximumTotalBytes: sourceBytes.count,
            ) { boundedReads.append($0) }
        }
        #expect(boundedReads.map(\.rawValue) == ["docs/design/video-source/source.mov"])

        #expect(throws: FactoryValidationError.self) {
            try DesignEvidenceFileVerifier.verify(source, repositoryRoot: root) { path in
                if path.rawValue == "docs/design/video-source/source.mov" {
                    try Data("substituted-source".utf8).write(to: sourcePath)
                }
            }
        }
        try sourceBytes.write(to: sourcePath)
        try DesignEvidenceFileVerifier.verify(source, repositoryRoot: root)
        let accepted = try FactoryCLICommand.run(
            arguments: ["design", "inspect", root.path],
            standardInput: CanonicalJSON.encode(source),
        )
        #expect(accepted.exitCode == 0)

        try Data("substituted-source".utf8).write(to: sourcePath)
        #expect(throws: FactoryValidationError.self) {
            try DesignEvidenceFileVerifier.verify(source, repositoryRoot: root)
        }
        try sourceBytes.write(to: sourcePath)

        try Data("substituted".utf8).write(to: metadataPath)
        #expect(throws: FactoryValidationError.self) {
            try DesignEvidenceFileVerifier.verify(source, repositoryRoot: root)
        }
        let rejectedTranslation = try FactoryCLICommand.run(
            arguments: ["design", "translate", root.path],
            standardInput: CanonicalJSON.encode(
                DesignTranslationValidationInput(source: source, translation: translation()),
            ),
        )
        #expect(rejectedTranslation.exitCode == 1)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: rejectedTranslation.standardError)
            .reasonCode == "unresolved-video-evidence-gaps")

        let genericValidation = try FactoryCLICommand.run(
            arguments: ["validate", "design-source"],
            standardInput: CanonicalJSON.encode(source),
        )
        #expect(genericValidation.exitCode == 1)
        #expect(try CanonicalJSON.decode(FactoryCommandEnvelope.self, from: genericValidation.standardError)
            .reasonCode == "unknown-record")

        try metadata.write(to: metadataPath)
        try FileManager.default.removeItem(at: contactPath)
        try FileManager.default.createSymbolicLink(at: contactPath, withDestinationURL: metadataPath)
        #expect(throws: FactoryValidationError.self) {
            try DesignEvidenceFileVerifier.verify(source, repositoryRoot: root)
        }
    }

    private func partialSource(sourceBytes: Data, contact: Data, metadata: Data) throws -> DesignSourceManifest {
        try DesignSourceManifest(
            sourceID: "video-source",
            kind: .video,
            authority: .directional,
            contentSHA256: SHA256Digest.hashing(sourceBytes),
            sourceVersion: "owner-supplied-v1",
            origin: "owner-supplied",
            rights: .ownerProvided,
            sensitivity: .privateReference,
            ingestionMode: .inspectOnly,
            viewports: [DesignViewport(id: "desktop", width: 1440, height: 900, scale: 2)],
            stateIDs: ["rest"],
            assetPaths: [RepositoryPath(validating: "docs/design/video-source/source.mov")],
            evidenceArtifacts: [
                DesignEvidenceArtifact(
                    id: "contact-sheet",
                    kind: .contactSheet,
                    path: RepositoryPath(validating: "docs/design/video-source/contact-sheet.png"),
                    sha256: SHA256Digest.hashing(contact),
                    provenance: "owner-exported-contact-sheet",
                ),
                DesignEvidenceArtifact(
                    id: "metadata",
                    kind: .metadata,
                    path: RepositoryPath(validating: "docs/design/video-source/metadata.json"),
                    sha256: SHA256Digest.hashing(metadata),
                    provenance: "owner-supplied-metadata",
                ),
            ],
            videoEvidenceGaps: [
                DesignVideoEvidenceGap(
                    id: "motion-timing",
                    kind: .motionTiming,
                    detail: "Owner evidence does not establish interruption timing.",
                ),
            ],
            videoAnalysis: nil,
        )
    }

    private func imageSource(contentSHA256: SHA256Digest) throws -> DesignSourceManifest {
        try DesignSourceManifest(
            sourceID: "image-source",
            kind: .screenshot,
            authority: .canonical,
            contentSHA256: contentSHA256,
            sourceVersion: "owner-v1",
            origin: "owner-supplied",
            rights: .ownerProvided,
            sensitivity: .privateReference,
            ingestionMode: .inspectOnly,
            viewports: [DesignViewport(id: "desktop", width: 1440, height: 900, scale: 2)],
            stateIDs: ["rest"],
            assetPaths: [RepositoryPath(validating: "source.png")],
            evidenceArtifacts: [],
            videoEvidenceGaps: [],
            videoAnalysis: nil,
        )
    }

    private func translation() throws -> DesignTranslationContract {
        try DesignTranslationContract(
            translationID: "hero-translation",
            sourceID: "video-source",
            routeID: "route-external-design-motion-ui",
            targetPaths: [RepositoryPath(validating: "Packages/Features/Sources/HeroView.swift")],
            invariantIDs: ["hero-placement"],
            stateMappings: [DesignStateMapping(sourceStateID: "rest", targetPreviewID: "hero-rest")],
            deviations: [],
            confidence: .low,
        )
    }
}

private func installFIFOReplacement(at sourceURL: URL) throws {
    try FileManager.default.removeItem(at: sourceURL)
    guard mkfifo(sourceURL.path, 0o600) == 0 else {
        throw FactoryValidationError(
            code: "test-fixture",
            message: "Could not install the FIFO replacement fixture.",
        )
    }
}
