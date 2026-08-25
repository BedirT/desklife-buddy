import Foundation

/// Owner-supplied visual source formats understood by the factory.
public enum DesignSourceKind: String, Codable, CaseIterable, Sendable {
    case assetPackage = "asset-package"
    case figma
    case react
    case screenshot
    case standaloneHTML = "standalone-html"
    case video
}

/// How strongly an external source constrains the product result.
public enum DesignAuthorityMode: String, Codable, CaseIterable, Sendable {
    case canonical
    case directional
    case nativeAdaptation = "native-adaptation"
}

public enum DesignSourceRights: String, Codable, Sendable {
    case ownerProvided = "owner-provided"
    case repositoryOwned = "repository-owned"
    case thirdPartyLicensed = "third-party-licensed"
}

public enum DesignSourceSensitivity: String, Codable, Sendable {
    case privateReference = "private-reference"
    case publicReference = "public-reference"
    case repositorySafe = "repository-safe"
}

/// Ingestion behavior. `execute-source` exists only so validators can reject it explicitly.
public enum DesignIngestionMode: String, Codable, Sendable {
    case executeSource = "execute-source"
    case inspectOnly = "inspect-only"
    case renderedExport = "rendered-export"
}

public enum DesignConfidence: String, Codable, CaseIterable, Sendable {
    case high
    case low
    case medium
}

public struct DesignViewport: Codable, Equatable, Sendable {
    public let id: String
    public let width: Int
    public let height: Int
    public let scale: Int

    public init(id: String, width: Int, height: Int, scale: Int) {
        self.id = id
        self.width = width
        self.height = height
        self.scale = scale
    }
}

/// Content-addressed, non-executable inventory of one external design reference.
public struct DesignSourceManifest: Codable, Equatable, Sendable {
    private static let maximumAssetPaths = 64
    private static let maximumEvidenceArtifacts = 64

    public let sourceID: String
    public let kind: DesignSourceKind
    public let authority: DesignAuthorityMode
    public let contentSHA256: SHA256Digest
    public let sourceVersion: String
    public let origin: String
    public let rights: DesignSourceRights
    public let sensitivity: DesignSourceSensitivity
    public let ingestionMode: DesignIngestionMode
    public let viewports: [DesignViewport]
    public let stateIDs: [String]
    public let assetPaths: [RepositoryPath]
    public let evidenceArtifacts: [DesignEvidenceArtifact]
    public let videoEvidenceGaps: [DesignVideoEvidenceGap]
    @RequiredNullable public var videoAnalysis: DesignVideoAnalysis?

    public init(
        sourceID: String,
        kind: DesignSourceKind,
        authority: DesignAuthorityMode,
        contentSHA256: SHA256Digest,
        sourceVersion: String,
        origin: String,
        rights: DesignSourceRights,
        sensitivity: DesignSourceSensitivity,
        ingestionMode: DesignIngestionMode,
        viewports: [DesignViewport],
        stateIDs: [String],
        assetPaths: [RepositoryPath],
        evidenceArtifacts: [DesignEvidenceArtifact],
        videoEvidenceGaps: [DesignVideoEvidenceGap],
        videoAnalysis: DesignVideoAnalysis?,
    ) {
        self.sourceID = sourceID
        self.kind = kind
        self.authority = authority
        self.contentSHA256 = contentSHA256
        self.sourceVersion = sourceVersion
        self.origin = origin
        self.rights = rights
        self.sensitivity = sensitivity
        self.ingestionMode = ingestionMode
        self.viewports = viewports
        self.stateIDs = stateIDs
        self.assetPaths = assetPaths
        self.evidenceArtifacts = evidenceArtifacts
        self.videoEvidenceGaps = videoEvidenceGaps
        _videoAnalysis = RequiredNullable(wrappedValue: videoAnalysis)
    }

    public func validate() throws {
        guard FactoryTextRules.isStableID(sourceID),
              FactoryTextRules.isBoundedText(sourceVersion, maximumScalars: 256),
              FactoryTextRules.isBoundedText(origin, maximumScalars: 1024),
              ingestionMode != .executeSource,
              !viewports.isEmpty,
              viewports.map(\.id) == viewports.map(\.id).sorted(),
              Set(viewports.map(\.id)).count == viewports.count,
              viewports.allSatisfy({
                  FactoryTextRules.isStableID($0.id) && $0.width > 0 && $0.height > 0 && (1 ... 4).contains($0.scale)
              }),
              !stateIDs.isEmpty,
              stateIDs == stateIDs.sorted(),
              Set(stateIDs).count == stateIDs.count,
              stateIDs.allSatisfy(FactoryTextRules.isStableID),
              !assetPaths.isEmpty,
              assetPaths.count <= Self.maximumAssetPaths,
              assetPaths == assetPaths.sorted(by: { $0.rawValue < $1.rawValue }),
              Set(assetPaths.map(\.collisionKey)).count == assetPaths.count,
              evidenceArtifacts.count <= Self.maximumEvidenceArtifacts,
              evidenceArtifacts.map(\.id) == evidenceArtifacts.map(\.id).sorted(),
              Set(evidenceArtifacts.map(\.id)).count == evidenceArtifacts.count,
              Set(evidenceArtifacts.map(\.path.collisionKey)).count == evidenceArtifacts.count,
              Set((assetPaths + evidenceArtifacts.map(\.path)).map(\.collisionKey)).count
              == assetPaths.count + evidenceArtifacts.count,
              videoEvidenceGaps.map(\.id) == videoEvidenceGaps.map(\.id).sorted(),
              Set(videoEvidenceGaps.map(\.id)).count == videoEvidenceGaps.count,
              Set(videoEvidenceGaps.map(\.kind)).count == videoEvidenceGaps.count
        else {
            throw FactoryValidationError(
                code: "invalid-design-source",
                message: "A design source must be content-addressed, inert, state-complete, and canonical.",
            )
        }
        try evidenceArtifacts.forEach { try $0.validate() }
        try videoEvidenceGaps.forEach { try $0.validate() }
        try validateVideoEvidence()
    }

    private func validateVideoEvidence() throws {
        if kind == .video {
            guard videoAnalysis != nil || (!evidenceArtifacts.isEmpty && !videoEvidenceGaps.isEmpty) else {
                throw FactoryValidationError(
                    code: "missing-video-evidence",
                    message: "Video intake requires either complete analysis or content-addressed static evidence with explicit gaps.",
                )
            }
            if let videoAnalysis {
                try validateCompleteVideoAnalysis(videoAnalysis)
            } else {
                try validatePartialVideoEvidence()
            }
        } else if videoAnalysis != nil || !videoEvidenceGaps.isEmpty {
            throw FactoryValidationError(
                code: "unexpected-video-analysis",
                message: "Only video design sources may carry video analysis or video evidence gaps.",
            )
        }
    }

    private func validateCompleteVideoAnalysis(_ analysis: DesignVideoAnalysis) throws {
        guard videoEvidenceGaps.isEmpty else {
            throw FactoryValidationError(
                code: "ambiguous-video-evidence-state",
                message: "A video source cannot claim complete analysis while retaining unresolved evidence gaps.",
            )
        }
        try analysis.validate()
        let artifactsByID = Dictionary(uniqueKeysWithValues: evidenceArtifacts.map { ($0.id, $0) })
        guard Set(analysis.evidenceArtifactIDs).isSubset(of: Set(artifactsByID.keys)) else {
            throw FactoryValidationError(
                code: "unknown-video-evidence-artifact",
                message: "Video analysis may reference only content-addressed evidence declared by its source manifest.",
            )
        }
        let referencedKinds = Set(analysis.evidenceArtifactIDs.compactMap { artifactsByID[$0]?.kind })
        let hasFrames = !referencedKinds.isDisjoint(with: [.contactSheet, .frameSet])
        guard referencedKinds.contains(.metadata),
              hasFrames,
              !analysis.hasAudio || referencedKinds.contains(.audioTimeline)
        else {
            throw FactoryValidationError(
                code: "insufficient-video-evidence",
                message: "Complete video analysis requires referenced metadata, frame coverage, and any asserted audio timeline.",
            )
        }
    }

    private func validatePartialVideoEvidence() throws {
        let artifactKinds = Set(evidenceArtifacts.map(\.kind))
        let gapKinds = Set(videoEvidenceGaps.map(\.kind))
        let missingFrameEvidence = artifactKinds.isDisjoint(with: [.contactSheet, .frameSet])
        guard artifactKinds.contains(.metadata) || gapKinds.contains(.technicalMetadata),
              !missingFrameEvidence || gapKinds.contains(.frameCoverage)
        else {
            throw FactoryValidationError(
                code: "incomplete-video-evidence-gaps",
                message: "Partial video intake must type every missing metadata and frame-coverage class.",
            )
        }
    }
}

public struct DesignStateMapping: Codable, Equatable, Sendable {
    public let sourceStateID: String
    public let targetPreviewID: String

    public init(sourceStateID: String, targetPreviewID: String) {
        self.sourceStateID = sourceStateID
        self.targetPreviewID = targetPreviewID
    }
}

public struct DesignDeviation: Codable, Equatable, Sendable {
    public let invariantID: String
    public let reason: String
    public let ownerApprovalRequired: Bool

    public init(invariantID: String, reason: String, ownerApprovalRequired: Bool) {
        self.invariantID = invariantID
        self.reason = reason
        self.ownerApprovalRequired = ownerApprovalRequired
    }
}

/// Exact mapping from a frozen external source to native implementation and proof surfaces.
public struct DesignTranslationContract: Codable, Equatable, Sendable {
    public let translationID: String
    public let sourceID: String
    public let routeID: String
    public let targetPaths: [RepositoryPath]
    public let invariantIDs: [String]
    public let stateMappings: [DesignStateMapping]
    public let deviations: [DesignDeviation]
    public let confidence: DesignConfidence

    public init(
        translationID: String,
        sourceID: String,
        routeID: String,
        targetPaths: [RepositoryPath],
        invariantIDs: [String],
        stateMappings: [DesignStateMapping],
        deviations: [DesignDeviation],
        confidence: DesignConfidence,
    ) {
        self.translationID = translationID
        self.sourceID = sourceID
        self.routeID = routeID
        self.targetPaths = targetPaths
        self.invariantIDs = invariantIDs
        self.stateMappings = stateMappings
        self.deviations = deviations
        self.confidence = confidence
    }

    public func validate(source: DesignSourceManifest) throws {
        try source.validate()
        guard source.videoEvidenceGaps.isEmpty else {
            throw FactoryValidationError(
                code: "unresolved-video-evidence-gaps",
                message: "A design source with unresolved video evidence gaps is not translation-ready.",
            )
        }
        let mappedStates = stateMappings.map(\.sourceStateID).sorted()
        let targetCollisionKeys = Set(targetPaths.map(\.collisionKey))
        let frozenSourceCollisionKeys = Set(
            (source.assetPaths + source.evidenceArtifacts.map(\.path)).map(\.collisionKey),
        )
        guard FactoryTextRules.isStableID(translationID),
              sourceID == source.sourceID,
              FactoryTextRules.isStableID(routeID),
              !targetPaths.isEmpty,
              targetPaths == targetPaths.sorted(by: { $0.rawValue < $1.rawValue }),
              targetCollisionKeys.count == targetPaths.count,
              targetCollisionKeys.isDisjoint(with: frozenSourceCollisionKeys),
              !invariantIDs.isEmpty,
              invariantIDs == invariantIDs.sorted(),
              Set(invariantIDs).count == invariantIDs.count,
              invariantIDs.allSatisfy(FactoryTextRules.isStableID),
              mappedStates == source.stateIDs,
              Set(mappedStates).count == mappedStates.count,
              stateMappings.allSatisfy({
                  FactoryTextRules.isStableID($0.sourceStateID) && FactoryTextRules.isStableID($0.targetPreviewID)
              }),
              deviations.map(\.invariantID) == deviations.map(\.invariantID).sorted(),
              deviations.allSatisfy({
                  FactoryTextRules.isStableID($0.invariantID)
                      && FactoryTextRules.isBoundedText($0.reason, maximumScalars: 2048)
              })
        else {
            throw FactoryValidationError(
                code: "invalid-design-translation",
                message: "The design translation does not map every source state and invariant to bounded native work.",
            )
        }
    }
}

/// Read-only CLI input that proves a translation against its exact source manifest.
public struct DesignTranslationValidationInput: Codable, Equatable, Sendable {
    public let source: DesignSourceManifest
    public let translation: DesignTranslationContract

    public init(source: DesignSourceManifest, translation: DesignTranslationContract) {
        self.source = source
        self.translation = translation
    }

    public func validate() throws {
        try translation.validate(source: source)
    }
}
