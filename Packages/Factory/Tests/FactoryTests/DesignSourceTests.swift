import Foundation
import Testing
@testable import FactoryCore

@Suite("External design source contracts")
struct DesignSourceTests {
    @Test("Every source kind supports every owner-selected authority mode")
    func universalAuthorityModes() throws {
        for kind in DesignSourceKind.allCases {
            for authority in DesignAuthorityMode.allCases {
                let manifest = try fixture(kind: kind, authority: authority)
                try manifest.validate()
                #expect(manifest.kind == kind)
                #expect(manifest.authority == authority)
            }
        }
    }

    @Test("React and HTML are inert inputs, never executable authority")
    func executableSourcesStayInert() throws {
        for kind in [DesignSourceKind.react, .standaloneHTML] {
            var manifest = try fixture(kind: kind, authority: .canonical)
            manifest = DesignSourceManifest(
                sourceID: manifest.sourceID,
                kind: manifest.kind,
                authority: manifest.authority,
                contentSHA256: manifest.contentSHA256,
                sourceVersion: manifest.sourceVersion,
                origin: manifest.origin,
                rights: manifest.rights,
                sensitivity: manifest.sensitivity,
                ingestionMode: .executeSource,
                viewports: manifest.viewports,
                stateIDs: manifest.stateIDs,
                assetPaths: manifest.assetPaths,
                evidenceArtifacts: manifest.evidenceArtifacts,
                videoEvidenceGaps: manifest.videoEvidenceGaps,
                videoAnalysis: manifest.videoAnalysis,
            )
            #expect(throws: FactoryValidationError.self) { try manifest.validate() }
        }
    }

    @Test("Video intake preserves partial evidence while unresolved gaps block translation")
    func partialVideoEvidence() throws {
        let missing = try fixture(
            kind: .video,
            authority: .directional,
            includeVideoAnalysis: false,
            includeVideoGaps: false,
        )
        #expect(throws: FactoryValidationError.self) { try missing.validate() }

        let partial = try fixture(kind: .video, authority: .directional, includeVideoAnalysis: false)
        try partial.validate()
        #expect(partial.videoEvidenceGaps.map(\.kind) == [.motionTiming, .technicalMetadata])
        #expect(partial.evidenceArtifacts.first(where: { $0.id == "contact-sheet" })?.sha256 == TestValues.evidence)
        let decoded = try CanonicalJSON.decode(
            DesignSourceManifest.self,
            from: CanonicalJSON.encode(partial),
        )
        #expect(decoded == partial)

        do {
            try translation().validate(source: partial)
            Issue.record("Translation accepted unresolved video evidence gaps")
        } catch let error as FactoryValidationError {
            #expect(error.code == "unresolved-video-evidence-gaps")
        }
    }

    @Test("Complete video analysis references content-addressed evidence without prescribing a decoder")
    func completeVideoAnalysis() throws {
        let complete = try fixture(kind: .video, authority: .canonical)
        let analysis = try #require(complete.videoAnalysis)
        #expect(analysis.tools.isEmpty)
        #expect(analysis.frameSelectionStrategies == [.fixedInterval, .sceneChange, .visualChange])
        #expect(analysis.evidenceArtifactIDs == ["audio-timeline", "contact-sheet", "metadata"])
        #expect(analysis.motionSegments.first?.reducedMotionExpectation == "crossfade-without-spatial-travel")
        try complete.validate()
        try translation().validate(source: complete)

        let unbound = DesignSourceManifest(
            sourceID: complete.sourceID,
            kind: complete.kind,
            authority: complete.authority,
            contentSHA256: complete.contentSHA256,
            sourceVersion: complete.sourceVersion,
            origin: complete.origin,
            rights: complete.rights,
            sensitivity: complete.sensitivity,
            ingestionMode: complete.ingestionMode,
            viewports: complete.viewports,
            stateIDs: complete.stateIDs,
            assetPaths: complete.assetPaths,
            evidenceArtifacts: [],
            videoEvidenceGaps: [],
            videoAnalysis: analysis,
        )
        do {
            try unbound.validate()
            Issue.record("Video analysis accepted an undeclared evidence artifact")
        } catch let error as FactoryValidationError {
            #expect(error.code == "unknown-video-evidence-artifact")
        }

        let irrelevant = try DesignSourceManifest(
            sourceID: complete.sourceID,
            kind: complete.kind,
            authority: complete.authority,
            contentSHA256: complete.contentSHA256,
            sourceVersion: complete.sourceVersion,
            origin: complete.origin,
            rights: complete.rights,
            sensitivity: complete.sensitivity,
            ingestionMode: complete.ingestionMode,
            viewports: complete.viewports,
            stateIDs: complete.stateIDs,
            assetPaths: complete.assetPaths,
            evidenceArtifacts: [
                DesignEvidenceArtifact(
                    id: "render",
                    kind: .render,
                    path: RepositoryPath(validating: "docs/design/video-source/render.png"),
                    sha256: TestValues.evidence,
                    provenance: "owner-render",
                ),
            ],
            videoEvidenceGaps: [],
            videoAnalysis: videoAnalysis(evidenceArtifactIDs: ["render"]),
        )
        do {
            try irrelevant.validate()
            Issue.record("Complete video analysis accepted irrelevant evidence")
        } catch let error as FactoryValidationError {
            #expect(error.code == "insufficient-video-evidence")
        }
    }

    @Test("Video evidence states and motion semantics are canonical")
    func canonicalVideoSemantics() throws {
        let complete = try fixture(kind: .video, authority: .canonical)
        let analysis = try #require(complete.videoAnalysis)
        let hybrid = DesignSourceManifest(
            sourceID: complete.sourceID,
            kind: complete.kind,
            authority: complete.authority,
            contentSHA256: complete.contentSHA256,
            sourceVersion: complete.sourceVersion,
            origin: complete.origin,
            rights: complete.rights,
            sensitivity: complete.sensitivity,
            ingestionMode: complete.ingestionMode,
            viewports: complete.viewports,
            stateIDs: complete.stateIDs,
            assetPaths: complete.assetPaths,
            evidenceArtifacts: complete.evidenceArtifacts,
            videoEvidenceGaps: [
                DesignVideoEvidenceGap(id: "motion-timing", kind: .motionTiming, detail: "Timing is unresolved."),
            ],
            videoAnalysis: analysis,
        )
        do {
            try hybrid.validate()
            Issue.record("Video source accepted complete analysis with unresolved gaps")
        } catch let error as FactoryValidationError {
            #expect(error.code == "ambiguous-video-evidence-state")
        }

        let first = try #require(analysis.motionSegments.first)
        let duplicateID = DesignMotionSegment(
            id: first.id,
            startMilliseconds: 700,
            endMilliseconds: 900,
            properties: [.opacity],
            trajectory: "rest-to-hidden",
            easing: "linear",
            interactionCue: nil,
            reducedMotionExpectation: "instant",
            confidence: .medium,
        )
        let duplicateAnalysis = videoAnalysis(motionSegments: [first, duplicateID])
        #expect(throws: FactoryValidationError.self) { try duplicateAnalysis.validate() }

        let oversizedSegments = [
            motionSegment(trajectory: String(repeating: "t", count: 513)),
            motionSegment(interactionCue: String(repeating: "i", count: 257)),
            motionSegment(easing: String(repeating: "e", count: 257)),
            motionSegment(reducedMotion: String(repeating: "r", count: 1025)),
        ]
        for segment in oversizedSegments {
            #expect(throws: FactoryValidationError.self) {
                try videoAnalysis(motionSegments: [segment]).validate()
            }
        }
        #expect(throws: FactoryValidationError.self) {
            try videoAnalysis(audioCueSummary: String(repeating: "a", count: 2049)).validate()
        }
        #expect(throws: FactoryValidationError.self) {
            try videoAnalysis(framesPerSecond: 480.5).validate()
        }
    }

    private func translation() throws -> DesignTranslationContract {
        try DesignTranslationContract(
            translationID: "hero-translation",
            sourceID: "video-source",
            routeID: "route-external-design-motion-ui",
            targetPaths: [RepositoryPath(validating: "Packages/Features/Sources/HeroView.swift")],
            invariantIDs: ["hero-placement", "reveal-order"],
            stateMappings: [
                DesignStateMapping(sourceStateID: "rest", targetPreviewID: "hero-rest"),
                DesignStateMapping(sourceStateID: "expanded", targetPreviewID: "hero-expanded"),
            ],
            deviations: [
                DesignDeviation(
                    invariantID: "material",
                    reason: "Use the native macOS material selected by the design system.",
                    ownerApprovalRequired: false,
                ),
            ],
            confidence: .high,
        )
    }

    private func fixture(
        kind: DesignSourceKind,
        authority: DesignAuthorityMode,
        includeVideoAnalysis: Bool = true,
        includeVideoGaps: Bool = true,
    ) throws -> DesignSourceManifest {
        let sourceID = kind == .video ? "video-source" : "\(kind.rawValue)-source"
        let analysis: DesignVideoAnalysis? = if kind == .video, includeVideoAnalysis {
            videoAnalysis()
        } else {
            nil
        }
        return try DesignSourceManifest(
            sourceID: sourceID,
            kind: kind,
            authority: authority,
            contentSHA256: TestValues.evidence,
            sourceVersion: "owner-supplied-v1",
            origin: "owner-supplied",
            rights: .ownerProvided,
            sensitivity: .privateReference,
            ingestionMode: .inspectOnly,
            viewports: [DesignViewport(id: "desktop", width: 1440, height: 900, scale: 2)],
            stateIDs: ["expanded", "rest"],
            assetPaths: [RepositoryPath(validating: "docs/design/\(sourceID)/source.bin")],
            evidenceArtifacts: kind == .video ? evidenceArtifacts(sourceID: sourceID) : [],
            videoEvidenceGaps: kind == .video && !includeVideoAnalysis && includeVideoGaps ? [
                DesignVideoEvidenceGap(
                    id: "motion-timing",
                    kind: .motionTiming,
                    detail: "Owner evidence does not establish interruption or easing timing.",
                ),
                DesignVideoEvidenceGap(
                    id: "technical-metadata",
                    kind: .technicalMetadata,
                    detail: "Owner evidence does not include authoritative duration or frame rate.",
                ),
            ] : [],
            videoAnalysis: analysis,
        )
    }

    private func evidenceArtifacts(sourceID: String) throws -> [DesignEvidenceArtifact] {
        try [
            DesignEvidenceArtifact(
                id: "audio-timeline",
                kind: .audioTimeline,
                path: RepositoryPath(validating: "docs/design/\(sourceID)/audio-timeline.json"),
                sha256: TestValues.contract,
                provenance: "owner-supplied-audio-timeline",
            ),
            DesignEvidenceArtifact(
                id: "contact-sheet",
                kind: .contactSheet,
                path: RepositoryPath(validating: "docs/design/\(sourceID)/frames/contact-sheet.png"),
                sha256: TestValues.evidence,
                provenance: "owner-exported-contact-sheet",
            ),
            DesignEvidenceArtifact(
                id: "metadata",
                kind: .metadata,
                path: RepositoryPath(validating: "docs/design/\(sourceID)/metadata.json"),
                sha256: TestValues.contract,
                provenance: "owner-supplied-metadata",
            ),
        ]
    }

    private func videoAnalysis(
        evidenceArtifactIDs: [String] = ["audio-timeline", "contact-sheet", "metadata"],
        motionSegments: [DesignMotionSegment]? = nil,
        framesPerSecond: Double = 60,
        audioCueSummary: String = "A soft confirmation sound aligns with the settled endpoint.",
    ) -> DesignVideoAnalysis {
        DesignVideoAnalysis(
            tools: [],
            durationMilliseconds: 2400,
            framesPerSecond: framesPerSecond,
            pixelWidth: 1440,
            pixelHeight: 900,
            hasAudio: true,
            frameSelectionStrategies: [.fixedInterval, .sceneChange, .visualChange],
            evidenceArtifactIDs: evidenceArtifactIDs,
            motionSegments: motionSegments ?? [
                DesignMotionSegment(
                    id: "hero-reveal",
                    startMilliseconds: 120,
                    endMilliseconds: 680,
                    properties: [.opacity, .position, .scale],
                    trajectory: "bottom-to-rest",
                    easing: "measured-cubic-approximation",
                    interactionCue: "pointer-click",
                    reducedMotionExpectation: "crossfade-without-spatial-travel",
                    confidence: .high,
                ),
            ],
            audioCueSummary: audioCueSummary,
        )
    }

    private func motionSegment(
        trajectory: String = "trajectory",
        interactionCue: String? = nil,
        easing: String = "ease",
        reducedMotion: String = "reduced",
    ) -> DesignMotionSegment {
        DesignMotionSegment(
            id: "oversized",
            startMilliseconds: 0,
            endMilliseconds: 100,
            properties: [.opacity],
            trajectory: trajectory,
            easing: easing,
            interactionCue: interactionCue,
            reducedMotionExpectation: reducedMotion,
            confidence: .low,
        )
    }
}
