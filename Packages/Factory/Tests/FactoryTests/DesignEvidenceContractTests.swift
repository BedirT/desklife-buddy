import Foundation
import Testing
@testable import FactoryCore

@Suite("External design evidence contracts")
struct DesignEvidenceContractTests {
    @Test("Design evidence paths and work budgets are canonical")
    func canonicalEvidenceInventory() throws {
        let aliased = try manifest(
            evidenceArtifacts: [
                DesignEvidenceArtifact(
                    id: "audio-timeline",
                    kind: .audioTimeline,
                    path: RepositoryPath(validating: "docs/design/Evidence.bin"),
                    sha256: TestValues.evidence,
                    provenance: "owner-audio",
                ),
                DesignEvidenceArtifact(
                    id: "contact-sheet",
                    kind: .contactSheet,
                    path: RepositoryPath(validating: "docs/design/evidence.bin"),
                    sha256: TestValues.evidence,
                    provenance: "owner-frames",
                ),
                DesignEvidenceArtifact(
                    id: "metadata",
                    kind: .metadata,
                    path: RepositoryPath(validating: "docs/design/EVIDENCE.bin"),
                    sha256: TestValues.evidence,
                    provenance: "owner-metadata",
                ),
            ],
        )
        #expect(throws: FactoryValidationError.self) { try aliased.validate() }

        let excessiveArtifacts = try (0 ... 64).map { index in
            try DesignEvidenceArtifact(
                id: String(format: "artifact-%02d", index),
                kind: .render,
                path: RepositoryPath(validating: String(format: "docs/design/render-%02d.png", index)),
                sha256: TestValues.evidence,
                provenance: "owner-render",
            )
        }
        let excessive = try manifest(evidenceArtifacts: excessiveArtifacts)
        #expect(throws: FactoryValidationError.self) { try excessive.validate() }
    }

    @Test("Design source text matches schema bounds")
    func sourceTextBounds() throws {
        #expect(throws: FactoryValidationError.self) {
            try manifest(evidenceArtifacts: [], sourceVersion: String(repeating: "v", count: 257)).validate()
        }
        #expect(throws: FactoryValidationError.self) {
            try manifest(evidenceArtifacts: [], origin: String(repeating: "o", count: 1025)).validate()
        }
    }

    private func manifest(
        evidenceArtifacts: [DesignEvidenceArtifact],
        sourceVersion: String = "owner-supplied-v1",
        origin: String = "owner-supplied",
    ) throws -> DesignSourceManifest {
        try DesignSourceManifest(
            sourceID: "screenshot-source",
            kind: .screenshot,
            authority: .directional,
            contentSHA256: TestValues.evidence,
            sourceVersion: sourceVersion,
            origin: origin,
            rights: .ownerProvided,
            sensitivity: .privateReference,
            ingestionMode: .inspectOnly,
            viewports: [DesignViewport(id: "desktop", width: 1440, height: 900, scale: 2)],
            stateIDs: ["rest"],
            assetPaths: [RepositoryPath(validating: "docs/design/source.png")],
            evidenceArtifacts: evidenceArtifacts,
            videoEvidenceGaps: [],
            videoAnalysis: nil,
        )
    }
}
