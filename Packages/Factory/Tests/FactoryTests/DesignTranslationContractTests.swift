import Testing
@testable import FactoryCore

@Suite("External design translation contracts")
struct DesignTranslationContractTests {
    @Test("Translation records preserve mappings, canonical targets, and bounded deviations")
    func translationContract() throws {
        let source = try source()
        let translation = try translation()
        try translation.validate(source: source)

        let unmapped = copy(translation, stateMappings: [])
        #expect(throws: FactoryValidationError.self) { try unmapped.validate(source: source) }

        for targetPaths in try [
            [translation.targetPaths[0], translation.targetPaths[0]],
            [
                RepositoryPath(validating: "Packages/Features/Sources/HeroView.swift"),
                RepositoryPath(validating: "Packages/Features/Sources/heroview.swift"),
            ],
        ] {
            let duplicateTarget = copy(translation, targetPaths: targetPaths)
            #expect(throws: FactoryValidationError.self) { try duplicateTarget.validate(source: source) }
        }

        for frozenSourceAlias in [
            "docs/design/hero.png",
            "docs/design/HERO.png",
            "docs/design/hero-render.png",
            "docs/design/HERO-RENDER.png",
        ] {
            let aliasedTarget = try copy(
                translation,
                targetPaths: [RepositoryPath(validating: frozenSourceAlias)],
            )
            #expect(throws: FactoryValidationError.self) { try aliasedTarget.validate(source: source) }
        }

        let oversizedReason = copy(
            translation,
            deviations: [
                DesignDeviation(
                    invariantID: "material",
                    reason: String(repeating: "r", count: 2049),
                    ownerApprovalRequired: false,
                ),
            ],
        )
        #expect(throws: FactoryValidationError.self) { try oversizedReason.validate(source: source) }
    }

    private func source() throws -> DesignSourceManifest {
        try DesignSourceManifest(
            sourceID: "hero-source",
            kind: .screenshot,
            authority: .nativeAdaptation,
            contentSHA256: TestValues.evidence,
            sourceVersion: "owner-v1",
            origin: "owner-supplied",
            rights: .ownerProvided,
            sensitivity: .privateReference,
            ingestionMode: .inspectOnly,
            viewports: [DesignViewport(id: "desktop", width: 1440, height: 900, scale: 2)],
            stateIDs: ["rest"],
            assetPaths: [RepositoryPath(validating: "docs/design/hero.png")],
            evidenceArtifacts: [
                DesignEvidenceArtifact(
                    id: "hero-render",
                    kind: .render,
                    path: RepositoryPath(validating: "docs/design/hero-render.png"),
                    sha256: TestValues.evidence,
                    provenance: "owner-exported-render",
                ),
            ],
            videoEvidenceGaps: [],
            videoAnalysis: nil,
        )
    }

    private func translation() throws -> DesignTranslationContract {
        try DesignTranslationContract(
            translationID: "hero-translation",
            sourceID: "hero-source",
            routeID: "route-external-design-ui",
            targetPaths: [RepositoryPath(validating: "Packages/Features/Sources/HeroView.swift")],
            invariantIDs: ["hero-placement"],
            stateMappings: [DesignStateMapping(sourceStateID: "rest", targetPreviewID: "hero-rest")],
            deviations: [],
            confidence: .high,
        )
    }

    private func copy(
        _ translation: DesignTranslationContract,
        targetPaths: [RepositoryPath]? = nil,
        stateMappings: [DesignStateMapping]? = nil,
        deviations: [DesignDeviation]? = nil,
    ) -> DesignTranslationContract {
        DesignTranslationContract(
            translationID: translation.translationID,
            sourceID: translation.sourceID,
            routeID: translation.routeID,
            targetPaths: targetPaths ?? translation.targetPaths,
            invariantIDs: translation.invariantIDs,
            stateMappings: stateMappings ?? translation.stateMappings,
            deviations: deviations ?? translation.deviations,
            confidence: translation.confidence,
        )
    }
}
