import Foundation
import Testing
@testable import FactoryCore

@Suite("Deterministic factory report")
struct FactoryReportTests {
    @Test("JSON, HTML, and PR summary bind the same current SHA")
    func deterministicBundle() throws {
        let report = try FactoryReport(
            reportID: "report-run-42",
            runID: "run-42",
            issueNumber: 42,
            pullRequestNumber: 7,
            headSHA: TestValues.head,
            contractSHA256: TestValues.contract,
            routeID: "route-external-design-motion-ui",
            phase: .readyForOwner,
            qualification: .nonqualifyingBootstrap,
            criteria: [
                FactoryReportCriterion(id: "criterion-1", status: .passed, evidenceIDs: ["snapshot-review"]),
            ],
            evidence: [
                FactoryReportEvidence(
                    id: "snapshot-review",
                    kind: .visual,
                    path: RepositoryPath(validating: "artifacts/preview-review/contact-sheet.png"),
                    sha256: TestValues.evidence,
                    status: .passed,
                ),
            ],
            roleResults: [
                FactoryRoleResult(role: .productWitness, client: .claude, status: .passed, findingIDs: []),
            ],
            designComparisons: [
                FactoryDesignComparison(
                    sourceID: "hero-reference",
                    authority: .canonical,
                    sourceEvidenceID: "source-hero",
                    resultEvidenceID: "snapshot-review",
                    deviationIDs: [],
                ),
            ],
            repairAttempts: 0,
            risks: ["Owner review remains required before merge. <script>alert(1)</script>"],
        )

        let first = try FactoryReporter.render(report)
        let second = try FactoryReporter.render(report)
        #expect(first == second)
        #expect(first.reportJSONSHA256 == SHA256Digest.hashing(first.reportJSON))
        let html = try #require(String(data: first.reportHTML, encoding: .utf8))
        assertDashboard(html)
        let summary = try #require(String(data: first.pullRequestSummary, encoding: .utf8))
        #expect(summary.contains("nonqualifying-bootstrap"))
        #expect(summary.contains("Open `report.html`"))
    }

    @Test("A stale or incomplete criterion cannot render owner-ready")
    func incompleteDenial() throws {
        let report = FactoryReport(
            reportID: "report-run-42",
            runID: "run-42",
            issueNumber: 42,
            pullRequestNumber: 7,
            headSHA: TestValues.head,
            contractSHA256: TestValues.contract,
            routeID: "route-logic",
            phase: .readyForOwner,
            qualification: .qualifying,
            criteria: [FactoryReportCriterion(id: "criterion-1", status: .failed, evidenceIDs: [])],
            evidence: [],
            roleResults: [],
            designComparisons: [],
            repairAttempts: 1,
            risks: [],
        )
        #expect(throws: FactoryValidationError.self) { try FactoryReporter.render(report) }
    }

    private func assertDashboard(_ html: String) {
        #expect(html.contains(TestValues.head.rawValue))
        #expect(html.contains("Review dashboard"))
        #expect(html.contains("Acceptance criteria"))
        #expect(html.contains("Independent roles"))
        #expect(html.contains("product-witness"))
        #expect(html.contains("Design comparison"))
        #expect(html.contains("hero-reference"))
        #expect(html.contains("source-hero"))
        #expect(html.contains("snapshot-review"))
        #expect(html.contains("class=\"status passed\""))
        #expect(!html.contains("<script>alert(1)</script>"))
    }
}
