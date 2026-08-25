import Testing
@testable import FactoryCore

@Suite("Owner-gated product learning")
struct ProductLearningTests {
    @Test("The checked-in adapter is disabled and can never mutate product code")
    func defaultDisabled() throws {
        let policy = ProductAdapterPolicy.factoryV1()
        #expect(!policy.enabled)
        #expect(!policy.automaticMutation)
        #expect(throws: FactoryValidationError.self) {
            try ProductLearningClassifier.classify(
                input(disposition: .actionableDefect),
                policy: policy,
            )
        }
    }

    @Test("An owner-approved actionable recurrence becomes an eval target, not a code change")
    func actionableClassification() throws {
        let policy = ProductAdapterPolicy(
            automaticMutation: false,
            authority: .ownerApprovedPostMerge,
            enabled: true,
            minimumActionableRecurrence: 3,
            retention: .sanitizedDurable,
            schemaVersion: 1,
        )
        let finding = try ProductLearningClassifier.classify(
            input(disposition: .actionableDefect),
            policy: policy,
        )
        #expect(finding.status == .evalTargetReady)
        #expect(finding.evalTargetRequired)
        #expect(finding.recurrenceCount == 3)
    }

    @Test("Noise and uncertainty remain non-actionable")
    func nonActionable() throws {
        let policy = ProductAdapterPolicy(
            automaticMutation: false,
            authority: .ownerApprovedPostMerge,
            enabled: true,
            minimumActionableRecurrence: 3,
            retention: .sanitizedDurable,
            schemaVersion: 1,
        )
        let noise = try ProductLearningClassifier.classify(
            input(disposition: .expectedNoise),
            policy: policy,
        )
        #expect(noise.status == .noise)
        #expect(!noise.evalTargetRequired)

        let uncertain = try ProductLearningClassifier.classify(
            input(disposition: .uncertain),
            policy: policy,
        )
        #expect(uncertain.status == .uncertain)
        #expect(!uncertain.evalTargetRequired)
    }

    private func input(disposition: ExpertDispositionKind) -> ProductClassificationInput {
        ProductClassificationInput(
            affectedSurface: "item-list",
            corrections: [
                ProductCorrection(
                    acceptedSHA256: TestValues.evidence,
                    actor: .owner,
                    capturedAt: "2026-07-14T00:00:00Z",
                    correctionID: "correction-1",
                    proposedSHA256: TestValues.contract,
                    schemaVersion: 1,
                    summary: "Owner selected the expected local result.",
                    traceID: "trace-1",
                ),
            ],
            disposition: ExpertDisposition(
                confidence: .confirmed,
                correctionIDs: ["correction-1"],
                decidedAt: "2026-07-14T00:01:00Z",
                decidedBy: .owner,
                disposition: disposition,
                dispositionID: "disposition-1",
                rationale: "Owner-reviewed local evidence.",
                schemaVersion: 1,
            ),
            evidenceRefs: ["artifacts/sanitized/finding-1.json"],
            findingID: "finding-1",
            recurrenceCount: 3,
            severity: .high,
            trace: ProductTrace(
                acceptedOutcome: nil,
                collectedAt: "2026-07-14T00:00:00Z",
                observedAction: "Owner accepted a corrected local result.",
                path: [TraceValue(contentSHA256: TestValues.contract, summary: "Sanitized input")],
                proposedResult: TraceValue(contentSHA256: TestValues.evidence, summary: "Sanitized proposal"),
                redaction: ProductTraceRedaction(contentRemoved: true, policyID: "privacy-v1"),
                schemaVersion: 1,
                source: ProductTraceSource(
                    consent: .ownerImported,
                    contentSHA256: TestValues.evidence,
                    kind: .manualImport,
                    provenance: "Owner-selected local record",
                    retentionClass: .sanitizedDurable,
                ),
                traceID: "trace-1",
            ),
        )
    }
}
