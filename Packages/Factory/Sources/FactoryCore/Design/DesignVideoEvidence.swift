import Darwin
import Foundation

public struct DesignToolIdentity: Codable, Equatable, Sendable {
    public let executable: String
    public let version: String
    public let executableSHA256: SHA256Digest

    public init(executable: String, version: String, executableSHA256: SHA256Digest) {
        self.executable = executable
        self.version = version
        self.executableSHA256 = executableSHA256
    }
}

/// The semantic role of a static design-evidence derivative.
public enum DesignEvidenceKind: String, Codable, CaseIterable, Sendable {
    case audioTimeline = "audio-timeline"
    case contactSheet = "contact-sheet"
    case frameSet = "frame-set"
    case metadata
    case render
}

/// One inert, content-addressed derivative supplied as design evidence.
public struct DesignEvidenceArtifact: Codable, Equatable, Sendable {
    public let id: String
    public let kind: DesignEvidenceKind
    public let path: RepositoryPath
    public let sha256: SHA256Digest
    public let provenance: String

    public init(
        id: String,
        kind: DesignEvidenceKind,
        path: RepositoryPath,
        sha256: SHA256Digest,
        provenance: String,
    ) {
        self.id = id
        self.kind = kind
        self.path = path
        self.sha256 = sha256
        self.provenance = provenance
    }

    func validate() throws {
        guard FactoryTextRules.isStableID(id),
              FactoryTextRules.isBoundedText(provenance, maximumScalars: 1024)
        else {
            throw FactoryValidationError(
                code: "invalid-design-evidence-artifact",
                message: "Design evidence must have a stable identity, repository path, digest, and bounded provenance.",
            )
        }
    }
}

public enum DesignVideoEvidenceGapKind: String, Codable, CaseIterable, Sendable {
    case audioTimeline = "audio-timeline"
    case frameCoverage = "frame-coverage"
    case motionTiming = "motion-timing"
    case technicalMetadata = "technical-metadata"
}

/// A typed reason why static owner-provided video evidence is not translation-ready.
public struct DesignVideoEvidenceGap: Codable, Equatable, Sendable {
    public let id: String
    public let kind: DesignVideoEvidenceGapKind
    public let detail: String

    public init(id: String, kind: DesignVideoEvidenceGapKind, detail: String) {
        self.id = id
        self.kind = kind
        self.detail = detail
    }

    func validate() throws {
        guard FactoryTextRules.isStableID(id),
              FactoryTextRules.isBoundedText(detail, maximumScalars: 2048)
        else {
            throw FactoryValidationError(
                code: "invalid-video-evidence-gap",
                message: "Video evidence gaps require a stable identity, typed kind, and bounded detail.",
            )
        }
    }
}

public enum DesignFrameSelectionStrategy: String, Codable, CaseIterable, Sendable {
    case fixedInterval = "fixed-interval"
    case sceneChange = "scene-change"
    case visualChange = "visual-change"
}

public enum DesignMotionProperty: String, Codable, CaseIterable, Sendable {
    case color
    case mask
    case opacity
    case position
    case rotation
    case scale
}

/// One semantically interpreted movement span backed by extracted media evidence.
public struct DesignMotionSegment: Codable, Equatable, Sendable {
    public let id: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let properties: [DesignMotionProperty]
    public let trajectory: String
    public let easing: String
    public let interactionCue: String?
    public let reducedMotionExpectation: String
    public let confidence: DesignConfidence

    public init(
        id: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        properties: [DesignMotionProperty],
        trajectory: String,
        easing: String,
        interactionCue: String?,
        reducedMotionExpectation: String,
        confidence: DesignConfidence,
    ) {
        self.id = id
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.properties = properties
        self.trajectory = trajectory
        self.easing = easing
        self.interactionCue = interactionCue
        self.reducedMotionExpectation = reducedMotionExpectation
        self.confidence = confidence
    }
}

/// Available technical metadata plus semantic motion decomposition for a video source.
public struct DesignVideoAnalysis: Codable, Equatable, Sendable {
    public let tools: [DesignToolIdentity]
    public let durationMilliseconds: Int
    public let framesPerSecond: Double
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let hasAudio: Bool
    public let frameSelectionStrategies: [DesignFrameSelectionStrategy]
    public let evidenceArtifactIDs: [String]
    public let motionSegments: [DesignMotionSegment]
    public let audioCueSummary: String?

    public init(
        tools: [DesignToolIdentity],
        durationMilliseconds: Int,
        framesPerSecond: Double,
        pixelWidth: Int,
        pixelHeight: Int,
        hasAudio: Bool,
        frameSelectionStrategies: [DesignFrameSelectionStrategy],
        evidenceArtifactIDs: [String],
        motionSegments: [DesignMotionSegment],
        audioCueSummary: String?,
    ) {
        self.tools = tools
        self.durationMilliseconds = durationMilliseconds
        self.framesPerSecond = framesPerSecond
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.hasAudio = hasAudio
        self.frameSelectionStrategies = frameSelectionStrategies
        self.evidenceArtifactIDs = evidenceArtifactIDs
        self.motionSegments = motionSegments
        self.audioCueSummary = audioCueSummary
    }

    func validate() throws {
        let toolNames = tools.map(\.executable)
        guard toolNames == toolNames.sorted(),
              Set(toolNames).count == toolNames.count,
              tools.allSatisfy({
                  FactoryTextRules.isBoundedText($0.executable, maximumScalars: 128)
                      && FactoryTextRules.isBoundedText($0.version, maximumScalars: 128)
              }),
              durationMilliseconds > 0,
              framesPerSecond > 0,
              framesPerSecond <= 480,
              pixelWidth > 0,
              pixelHeight > 0,
              frameSelectionStrategies == DesignFrameSelectionStrategy.allCases,
              !evidenceArtifactIDs.isEmpty,
              evidenceArtifactIDs == evidenceArtifactIDs.sorted(),
              Set(evidenceArtifactIDs).count == evidenceArtifactIDs.count,
              evidenceArtifactIDs.allSatisfy(FactoryTextRules.isStableID),
              !motionSegments.isEmpty,
              motionSegments.map(\.id) == motionSegments.map(\.id).sorted(),
              Set(motionSegments.map(\.id)).count == motionSegments.count,
              hasAudio == (audioCueSummary?.isEmpty == false),
              audioCueSummary.map({
                  FactoryTextRules.isBoundedText($0, maximumScalars: 2048)
              }) ?? true
        else {
            throw FactoryValidationError(
                code: "incomplete-video-analysis",
                message: "Video analysis must bind static evidence, media metadata, multiple frame strategies, and motion semantics.",
            )
        }
        for segment in motionSegments {
            guard FactoryTextRules.isStableID(segment.id),
                  segment.startMilliseconds >= 0,
                  segment.endMilliseconds > segment.startMilliseconds,
                  segment.endMilliseconds <= durationMilliseconds,
                  !segment.properties.isEmpty,
                  segment.properties.map(\.rawValue) == segment.properties.map(\.rawValue).sorted(),
                  Set(segment.properties).count == segment.properties.count,
                  FactoryTextRules.isBoundedText(segment.trajectory, maximumScalars: 512),
                  FactoryTextRules.isBoundedText(segment.easing, maximumScalars: 256),
                  segment.interactionCue.map({
                      FactoryTextRules.isBoundedText($0, maximumScalars: 256)
                  }) ?? true,
                  FactoryTextRules.isBoundedText(segment.reducedMotionExpectation, maximumScalars: 1024)
            else {
                throw FactoryValidationError(
                    code: "invalid-motion-segment",
                    message: "A video motion segment is incomplete or non-canonical.",
                )
            }
        }
    }
}

enum DesignEvidenceFileVerifier {
    private struct SourceAssetIdentity: Codable {
        let path: RepositoryPath
        let sha256: SHA256Digest
    }

    private static let maximumArtifactBytes = 64 * 1024 * 1024
    private static let maximumSourceAssetBytes = 256 * 1024 * 1024
    private static let maximumTotalBytes = 512 * 1024 * 1024
    private static let maximumDuration: Duration = .seconds(30)
    private static let allowedArtifactModes: Set<mode_t> = [0o400, 0o440, 0o444, 0o600, 0o640, 0o644]

    static func verify(_ source: DesignSourceManifest, repositoryRoot: URL) throws {
        try verify(source, repositoryRoot: repositoryRoot, afterRead: { _ in })
    }

    static func verify(
        _ source: DesignSourceManifest,
        repositoryRoot: URL,
        afterRead: (RepositoryPath) throws -> Void,
    ) throws {
        try verify(
            source,
            repositoryRoot: repositoryRoot,
            maximumTotalBytes: maximumTotalBytes,
            afterRead: afterRead,
        )
    }

    static func verify(
        _ source: DesignSourceManifest,
        repositoryRoot: URL,
        maximumTotalBytes: Int,
        now: () -> ContinuousClock.Instant = { ContinuousClock().now },
        beforeFinalIdentityValidation: (RepositoryPath) throws -> Void = { _ in },
        afterRead: (RepositoryPath) throws -> Void,
    ) throws {
        try source.validate()
        guard maximumTotalBytes > 0,
              maximumTotalBytes <= Self.maximumTotalBytes
        else {
            throw FactoryValidationError(
                code: "design-verification-budget",
                message: "Design source and evidence exceed the aggregate verification budget.",
            )
        }
        let deadline = now().advanced(by: maximumDuration)
        try checkDeadline(deadline, now: now)
        let canonicalRoot = try SecureRepositoryFileSystem.canonicalExistingURL(repositoryRoot)
        try checkDeadline(deadline, now: now)
        let rootFD = try SecureRepositoryFileSystem.openDirectory(canonicalRoot)
        defer { Darwin.close(rootFD) }
        var rootMetadata = stat()
        guard Darwin.fstat(rootFD, &rootMetadata) == 0 else {
            throw FactoryValidationError(
                code: "unsafe-design-root",
                message: "The design repository root identity could not be read.",
            )
        }
        try validateRootIdentity(canonicalRoot, expected: rootMetadata)
        try checkDeadline(deadline, now: now)
        try verifyOpenedRoot(
            source,
            rootFD: rootFD,
            maximumTotalBytes: maximumTotalBytes,
            deadline: deadline,
            now: now,
            beforeFinalIdentityValidation: beforeFinalIdentityValidation,
            afterRead: afterRead,
        )
        try validateRootIdentity(canonicalRoot, expected: rootMetadata)
        try checkDeadline(deadline, now: now)
    }

    private static func verifyOpenedRoot(
        _ source: DesignSourceManifest,
        rootFD: Int32,
        maximumTotalBytes: Int,
        deadline: ContinuousClock.Instant,
        now: () -> ContinuousClock.Instant,
        beforeFinalIdentityValidation: (RepositoryPath) throws -> Void,
        afterRead: (RepositoryPath) throws -> Void,
    ) throws {
        var totalBytes = 0
        var sourceIdentities: [SourceAssetIdentity] = []
        var identities: [SecureRegularFileIdentity] = []
        for path in source.assetPaths {
            let snapshot = try verifiedRead(
                rootFD: rootFD,
                path: path,
                maximumBytes: maximumSourceAssetBytes,
                maximumTotalBytes: maximumTotalBytes,
                totalBytes: &totalBytes,
                deadline: deadline,
                now: now,
            )
            identities.append(snapshot.identity)
            try sourceIdentities.append(
                SourceAssetIdentity(path: path, sha256: digest(snapshot.file.data, deadline: deadline, now: now)),
            )
            try afterRead(path)
        }
        let observedContentSHA256 = sourceIdentities.count == 1
            ? sourceIdentities[0].sha256
            : CanonicalJSON.digest(sourceIdentities)
        guard observedContentSHA256 == source.contentSHA256 else {
            throw FactoryValidationError(
                code: "design-source-digest-mismatch",
                message: "Design source bytes do not match the manifest digest.",
            )
        }

        for artifact in source.evidenceArtifacts {
            let snapshot = try verifiedRead(
                rootFD: rootFD,
                path: artifact.path,
                maximumBytes: maximumArtifactBytes,
                maximumTotalBytes: maximumTotalBytes,
                totalBytes: &totalBytes,
                deadline: deadline,
                now: now,
            )
            identities.append(snapshot.identity)
            guard try digest(snapshot.file.data, deadline: deadline, now: now) == artifact.sha256 else {
                throw FactoryValidationError(
                    code: "design-evidence-digest-mismatch",
                    message: "Design evidence bytes do not match the manifest digest.",
                )
            }
            try afterRead(artifact.path)
        }
        for identity in identities {
            try checkDeadline(deadline, now: now)
            try beforeFinalIdentityValidation(identity.path)
            try SecureRepositoryFileSystem.validateInstalled(identity, rootFD: rootFD)
            try checkDeadline(deadline, now: now)
        }
    }

    private static func verifiedRead(
        rootFD: Int32,
        path: RepositoryPath,
        maximumBytes: Int,
        maximumTotalBytes: Int,
        totalBytes: inout Int,
        deadline: ContinuousClock.Instant,
        now: () -> ContinuousClock.Instant,
    ) throws -> SecureRegularFileSnapshot {
        try checkDeadline(deadline, now: now)
        let remainingBytes = maximumTotalBytes - totalBytes
        guard remainingBytes > 0 else {
            throw FactoryValidationError(
                code: "design-verification-budget",
                message: "Design source and evidence exceed the aggregate verification budget.",
            )
        }
        let snapshot = try SecureRepositoryFileSystem.readRegularFileSnapshot(
            rootFD: rootFD,
            path: path,
            allowedModes: allowedArtifactModes,
            maximumBytes: min(maximumBytes, remainingBytes),
            deadlineCheck: { now() < deadline },
        )
        let (nextTotal, overflow) = totalBytes.addingReportingOverflow(snapshot.file.data.count)
        guard !overflow, nextTotal <= maximumTotalBytes else {
            throw FactoryValidationError(
                code: "design-verification-budget",
                message: "Design source and evidence exceed the aggregate verification budget.",
            )
        }
        try checkDeadline(deadline, now: now)
        totalBytes = nextTotal
        return snapshot
    }

    private static func digest(
        _ data: Data,
        deadline: ContinuousClock.Instant,
        now: () -> ContinuousClock.Instant,
    ) throws -> SHA256Digest {
        try checkDeadline(deadline, now: now)
        let value = SHA256Digest.hashing(data)
        try checkDeadline(deadline, now: now)
        return value
    }

    private static func checkDeadline(
        _ deadline: ContinuousClock.Instant,
        now: () -> ContinuousClock.Instant,
    ) throws {
        guard now() < deadline else {
            throw FactoryValidationError(
                code: "design-verification-timeout",
                message: "Design evidence verification exceeded its total deadline.",
            )
        }
    }

    private static func validateRootIdentity(_ root: URL, expected: stat) throws {
        let observedFD = Darwin.open(
            root.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY,
        )
        guard observedFD >= 0 else {
            throw FactoryValidationError(
                code: "design-root-changed",
                message: "The design repository root changed while it was inspected.",
            )
        }
        defer { Darwin.close(observedFD) }
        var observed = stat()
        guard Darwin.fstat(observedFD, &observed) == 0,
              observed.st_mode & S_IFMT == S_IFDIR,
              observed.st_dev == expected.st_dev,
              observed.st_ino == expected.st_ino,
              observed.st_uid == expected.st_uid
        else {
            throw FactoryValidationError(
                code: "design-root-changed",
                message: "The design repository root changed while it was inspected.",
            )
        }
    }
}
